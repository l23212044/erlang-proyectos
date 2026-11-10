%% Operaciones sobre un segmento temporal. Cada segmento tiene dos tablas ETS
%% ordered_set: una por tiempo y otra con indices secundarios (edificio,
%% dispositivo) que incluyen el tiempo para poder buscar rangos sin recorrer
%% el segmento completo.
-module(p69_almacen).

-export([crear/0, borrar/1, insertar/2, buscar/5, contar/1, plegar/3]).

-export_type([segmento/0]).

-type segmento() :: #{
  eventos := ets:tid(),
  indices := ets:tid()
}.

-spec crear() -> segmento().
crear() ->
  Eventos = ets:new(p69_eventos_segmento, [
    ordered_set, protected, {read_concurrency, true}
  ]),
  Indices = ets:new(p69_indices_segmento, [
    ordered_set, protected, {read_concurrency, true}
  ]),
  #{eventos => Eventos, indices => Indices}.

-spec borrar(segmento()) -> ok.
borrar(#{eventos := Eventos, indices := Indices}) ->
  true = ets:delete(Eventos),
  true = ets:delete(Indices),
  ok.

-spec insertar(segmento(), map()) -> ok.
insertar(#{eventos := Eventos, indices := Indices}, Ev) ->
  Ts = maps:get(ts_corregido, Ev),
  Seq = maps:get(seq, Ev),
  true = ets:insert(Eventos, {{Ts, Seq}, Ev}),
  Edificio = maps:get(edificio, Ev),
  Disp = maps:get(dispositivo_id, Ev),
  true = ets:insert(Indices, [
    {{edificio, Edificio, Ts, Seq}},
    {{dispositivo, Disp, Ts, Seq}}
  ]),
  ok.

%% Busca eventos con ts_corregido en [Desde, Hasta] y seq =< MaxSeq.
%% Si hay filtro por dispositivo o edificio se usa el indice; asi el costo
%% depende del rango pedido y no del tamano total del segmento.
-spec buscar(segmento(), integer(), integer(), map(), non_neg_integer()) -> [map()].
buscar(Seg, Desde, Hasta, Filtros, MaxSeq) when Desde =< Hasta ->
  case elegir_indice(Filtros) of
    none ->
      recorrer_eventos(Seg, Desde, Hasta, Filtros, MaxSeq, []);
    {Tipo, Valor} ->
      recorrer_indice(Seg, Tipo, Valor, Desde, Hasta, Filtros, MaxSeq, [])
  end.

-spec contar(segmento()) -> non_neg_integer().
contar(#{eventos := Eventos}) ->
  ets:info(Eventos, size).

%% Recorre el segmento completo en orden, sin materializar listas grandes.
-spec plegar(fun((map(), term()) -> term()), term(), segmento()) -> term().
plegar(Fun, Acc0, #{eventos := Eventos}) ->
  ets:foldl(
    fun({{_Ts, _Seq}, Ev}, Acc) -> Fun(Ev, Acc) end,
    Acc0,
    Eventos
  ).

%% Internos

elegir_indice(Filtros) ->
  case maps:find(dispositivo, Filtros) of
    {ok, Disp} when Disp =/= undefined -> {dispositivo, Disp};
    _ ->
      case maps:find(edificio, Filtros) of
        {ok, Edificio} when Edificio =/= undefined -> {edificio, Edificio};
        _ -> none
      end
  end.

recorrer_eventos(#{eventos := Eventos}, Desde, Hasta, Filtros, MaxSeq, Acc) ->
  Clave = ets:next(Eventos, {Desde, -1}),
  bucle_eventos(Eventos, Clave, Hasta, Filtros, MaxSeq, Acc).

bucle_eventos(_Eventos, '$end_of_table', _Hasta, _Filtros, _MaxSeq, Acc) ->
  lists:reverse(Acc);
bucle_eventos(_Eventos, {Ts, _Seq}, Hasta, _Filtros, _MaxSeq, Acc) when Ts > Hasta ->
  lists:reverse(Acc);
bucle_eventos(Eventos, Clave, Hasta, Filtros, MaxSeq, Acc) ->
  [{Clave, Ev}] = ets:lookup(Eventos, Clave),
  Acc2 = agregar_si_cumple(Ev, Filtros, MaxSeq, Acc),
  bucle_eventos(Eventos, ets:next(Eventos, Clave), Hasta, Filtros, MaxSeq, Acc2).

recorrer_indice(#{indices := Indices, eventos := Eventos}, Tipo, Valor, Desde, Hasta,
    Filtros, MaxSeq, Acc) ->
  Clave = ets:next(Indices, {Tipo, Valor, Desde, -1}),
  bucle_indice(Indices, Eventos, Clave, Tipo, Valor, Hasta, Filtros, MaxSeq, Acc).

bucle_indice(_Indices, _Eventos, '$end_of_table', _Tipo, _Valor, _Hasta, _Filtros,
    _MaxSeq, Acc) ->
  lists:reverse(Acc);
bucle_indice(_Indices, _Eventos, {Tipo, Valor, _Ts, _Seq}, TipoEsperado, ValorEsperado,
    _Hasta, _Filtros, _MaxSeq, Acc)
    when Tipo =/= TipoEsperado; Valor =/= ValorEsperado ->
  %% El indice ordena por tipo y valor: al cambiar de grupo ya no hay mas
  %% eventos del filtro pedido.
  lists:reverse(Acc);
bucle_indice(_Indices, _Eventos, {_Tipo, _Valor, Ts, _Seq}, _TipoEsperado,
    _ValorEsperado, Hasta, _Filtros, _MaxSeq, Acc) when Ts > Hasta ->
  lists:reverse(Acc);
bucle_indice(Indices, Eventos, {_Tipo, _Valor, Ts, Seq} = Clave, TipoEsperado,
    ValorEsperado, Hasta, Filtros, MaxSeq, Acc) ->
  case ets:lookup(Eventos, {Ts, Seq}) of
    [{_K, Ev}] ->
      Acc2 = agregar_si_cumple(Ev, Filtros, MaxSeq, Acc),
      bucle_indice(Indices, Eventos, ets:next(Indices, Clave), TipoEsperado,
        ValorEsperado, Hasta, Filtros, MaxSeq, Acc2);
    [] ->
      bucle_indice(Indices, Eventos, ets:next(Indices, Clave), TipoEsperado,
        ValorEsperado, Hasta, Filtros, MaxSeq, Acc)
  end.

agregar_si_cumple(Ev, Filtros, MaxSeq, Acc) ->
  case cumple(Ev, Filtros, MaxSeq) of
    true -> [Ev | Acc];
    false -> Acc
  end.

cumple(Ev, Filtros, MaxSeq) ->
  maps:get(seq, Ev) =< MaxSeq
    andalso coincide(edificio, maps:get(edificio, Ev), Filtros)
    andalso coincide(dispositivo, maps:get(dispositivo_id, Ev), Filtros)
    andalso coincide(tipo, maps:get(tipo_evento, Ev), Filtros)
    andalso coincide(persona, maps:get(persona, Ev, undefined), Filtros).

coincide(Clave, Valor, Filtros) ->
  case maps:find(Clave, Filtros) of
    {ok, Esperado} when Esperado =/= undefined -> Valor =:= Esperado;
    _ -> true
  end.
