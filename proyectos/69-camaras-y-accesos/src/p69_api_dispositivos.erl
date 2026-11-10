%% Handler de /api/dispositivos y /api/dispositivos/:id.
-module(p69_api_dispositivos).

-export([init/2]).

init(Req0, State) ->
  case cowboy_req:method(Req0) of
    <<"GET">> -> get(Req0, State);
    _ ->
      {ok, Req, _} = p69_api:error(405, <<"metodo_no_permitido">>,
        <<"use GET">>, Req0),
      {ok, Req, State}
  end.

get(Req0, State) ->
  Id = cowboy_req:binding(id, Req0, undefined),
  case Id of
    undefined -> listar(Req0, State);
    _ -> detalle(Id, Req0, State)
  end.

listar(Req0, State) ->
  Query = p69_api:qs(Req0),
  Edificio = p69_api:q(Query, <<"edificio">>, undefined),
  Estado = p69_api:q(Query, <<"estado">>, undefined),
  Dispositivos = [
    D
   || D <- p69_sitios:dispositivos(),
      coincide(Edificio, maps:get(edificio, D)),
      coincide(Estado, p69_api:a_bin(maps:get(estado, D)))
  ],
  {ok, Req, _} = p69_api:json(200, #{
    total => length(Dispositivos),
    dispositivos => [p69_api:dispositivo(D) || D <- Dispositivos]
  }, Req0),
  {ok, Req, State}.

detalle(Id, Req0, State) ->
  Query = p69_api:qs(Req0),
  Encontrado = case p69_api:q(Query, <<"edificio">>, undefined) of
    undefined ->
      buscar_por_id(Id, p69_sitios:dispositivos());
    Edificio ->
      p69_sitios:dispositivo(Edificio, Id)
  end,
  case Encontrado of
    {ok, D} ->
      {ok, Req, _} = p69_api:json(200, p69_api:dispositivo(D), Req0),
      {ok, Req, State};
    {error, no_encontrado} ->
      {ok, Req, _} = p69_api:error(404, <<"no_encontrado">>,
        <<"dispositivo no encontrado">>, Req0),
      {ok, Req, State}
  end.

buscar_por_id(Id, [D | Resto]) ->
  case maps:get(id, D) of
    Id -> {ok, D};
    _ -> buscar_por_id(Id, Resto)
  end;
buscar_por_id(_Id, []) ->
  {error, no_encontrado}.

coincide(undefined, _Valor) -> true;
coincide(Esperado, Valor) -> Esperado =:= Valor.
