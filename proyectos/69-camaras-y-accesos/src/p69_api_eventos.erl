%% Handler de /api/eventos: alta (uno o lote) y busqueda por rango.
-module(p69_api_eventos).

-export([init/2]).

init(Req0, State) ->
  case cowboy_req:method(Req0) of
    <<"POST">> -> post(Req0, State);
    <<"GET">> -> get(Req0, State);
    _ ->
      {ok, Req, _} = p69_api:error(405, <<"metodo_no_permitido">>,
        <<"use GET o POST">>, Req0),
      {ok, Req, State}
  end.

post(Req0, State) ->
  case p69_api:leer_json(Req0) of
    {ok, Termino, Req} ->
      procesar_alta(Termino, Req, State);
    {error, Motivo, Req} ->
      {ok, Req2, _} = p69_api:error(400, p69_api:a_bin(Motivo),
        <<"cuerpo JSON invalido">>, Req),
      {ok, Req2, State}
  end.

procesar_alta(Eventos, Req, State) when is_list(Eventos) ->
  alta_lote(Eventos, Req, State);
procesar_alta(#{<<"eventos">> := Eventos}, Req, State) when is_list(Eventos) ->
  alta_lote(Eventos, Req, State);
procesar_alta(#{<<"evento">> := Evento}, Req, State) when is_map(Evento) ->
  alta_uno(Evento, Req, State);
procesar_alta(Evento, Req, State) when is_map(Evento) ->
  alta_uno(Evento, Req, State);
procesar_alta(_Otro, Req0, State) ->
  {ok, Req, _} = p69_api:error(400, <<"formato_invalido">>,
    <<"se esperaba un evento, un arreglo o {eventos: []}">>, Req0),
  {ok, Req, State}.

alta_uno(Evento, Req0, State) ->
  case p69_bitacora:ingresar(Evento) of
    {ok, Ev} ->
      {ok, Req, _} = p69_api:json(201, #{evento => p69_api:evento(Ev)}, Req0),
      {ok, Req, State};
    {error, Motivo} ->
      responder_error(Motivo, Req0, State)
  end.

alta_lote([], Req0, State) ->
  {ok, Req, _} = p69_api:error(400, <<"lote_vacio">>,
    <<"el lote no contiene eventos">>, Req0),
  {ok, Req, State};
alta_lote(Eventos, Req0, State) ->
  case p69_bitacora:ingresar_lote(Eventos) of
    {ok, Evs} ->
      {ok, Req, _} = p69_api:json(201, #{
        recibidos => length(Evs),
        eventos => [p69_api:evento(Ev) || Ev <- Evs]
      }, Req0),
      {ok, Req, State};
    {error, Motivo} ->
      responder_error(Motivo, Req0, State)
  end.

get(Req0, State) ->
  Query = p69_api:qs(Req0),
  try
    Hasta = case p69_api:ts(Query, <<"hasta">>) of
      undefined -> erlang:system_time(microsecond);
      H -> H
    end,
    Desde = case p69_api:ts(Query, <<"desde">>) of
      undefined -> Hasta - 3600 * 1000000;
      D -> D
    end,
    caso_rango(Desde, Hasta, Query, Req0, State)
  catch
    throw:{error, {parametro_invalido, Nombre, Motivo}} ->
      {ok, Req, _} = p69_api:error(400, <<"parametro_invalido">>,
        iolist_to_binary(io_lib:format("~s: ~p", [Nombre, Motivo])), Req0),
      {ok, Req, State}
  end.

caso_rango(Desde, Hasta, _Query, Req0, State) when Desde > Hasta ->
  {ok, Req, _} = p69_api:error(400, <<"rango_invalido">>,
    <<"desde debe ser menor o igual que hasta">>, Req0),
  {ok, Req, State};
caso_rango(Desde, Hasta, Query, Req0, State) ->
  Filtros = p69_api:filtros(Query),
  Limite = entero_query(Query, <<"limite">>, 1000, 1, 10000),
  Offset = entero_query(Query, <<"offset">>, 0, 0, 1000000000),
  case p69_consulta:buscar(Desde, Hasta, Filtros, 30000) of
    {ok, Lista} ->
      Paginada = lists:sublist(drop(Offset, Lista), Limite),
      {ok, Req, _} = p69_api:json(200, #{
        total => length(Lista),
        desde => Desde,
        desde_iso => p69_api:iso(Desde),
        hasta => Hasta,
        hasta_iso => p69_api:iso(Hasta),
        limite => Limite,
        offset => Offset,
        eventos => [p69_api:evento(Ev) || Ev <- Paginada]
      }, Req0),
      {ok, Req, State};
    {error, timeout} ->
      {ok, Req, _} = p69_api:error(503, <<"consulta_lenta">>,
        <<"la consulta excedio el tiempo maximo">>, Req0),
      {ok, Req, State};
    {error, Motivo} ->
      {ok, Req, _} = p69_api:error(500, <<"consulta_fallo">>,
        p69_api:a_bin(Motivo), Req0),
      {ok, Req, State}
  end.

responder_error(sobrecarga, Req0, State) ->
  {ok, Req, _} = p69_api:sobrecarga(Req0),
  {ok, Req, State};
responder_error(fuera_de_retencion, Req0, State) ->
  {ok, Req, _} = p69_api:error(400, <<"fuera_de_retencion">>,
    <<"el evento es mas antiguo que la retencion configurada">>, Req0),
  {ok, Req, State};
responder_error({evento_invalido, N, Motivo}, Req0, State) ->
  {ok, Req, _} = p69_api:error(400, <<"evento_invalido">>,
    iolist_to_binary(io_lib:format("evento ~p: ~p", [N, Motivo])), Req0),
  {ok, Req, State};
responder_error(Motivo, Req0, State) ->
  {ok, Req, _} = p69_api:error(500, <<"ingesta_fallo">>,
    p69_api:a_bin(Motivo), Req0),
  {ok, Req, State}.

entero_query(Query, Nombre, Default, Min, Max) ->
  case p69_api:q(Query, Nombre, undefined) of
    undefined -> Default;
    Bin ->
      try binary_to_integer(Bin) of
        N when N >= Min, N =< Max -> N;
        _ -> throw({error, {parametro_invalido, Nombre, fuera_de_rango}})
      catch
        error:badarg -> throw({error, {parametro_invalido, Nombre, no_entero}})
      end
  end.

drop(0, Lista) -> Lista;
drop(_N, []) -> [];
drop(N, [_ | Resto]) -> drop(N - 1, Resto).
