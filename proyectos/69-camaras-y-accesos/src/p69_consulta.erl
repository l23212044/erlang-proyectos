%% Worker de consulta por rango. Se arranca bajo p69_consultas_sup con
%% restart=temporary; abre un pin en la bitacora, lee los segmentos y libera
%% el pin al terminar, aunque la retencion corra en paralelo.
-module(p69_consulta).

-export([buscar/3, buscar/4, start_link/5]).

-define(TIMEOUT_DEFECTO, 30000).

-spec buscar(integer(), integer(), map()) -> {ok, [map()]} | {error, term()}.
buscar(Desde, Hasta, Filtros) ->
  buscar(Desde, Hasta, Filtros, ?TIMEOUT_DEFECTO).

-spec buscar(integer(), integer(), map(), timeout()) -> {ok, [map()]} | {error, term()}.
buscar(Desde, Hasta, Filtros, Timeout) ->
  Parent = self(),
  Ref = make_ref(),
  Spec = #{
    id => Ref,
    start => {?MODULE, start_link, [Parent, Ref, Desde, Hasta, Filtros]},
    restart => temporary,
    shutdown => 5000,
    type => worker,
    modules => [?MODULE]
  },
  case supervisor:start_child(p69_consultas_sup, Spec) of
    {ok, Pid} ->
      Mon = erlang:monitor(process, Pid),
      recibir(Pid, Mon, Ref, Timeout);
    {error, Motivo} ->
      {error, {consulta_no_iniciada, Motivo}}
  end.

-spec start_link(pid(), reference(), integer(), integer(), map()) -> {ok, pid()}.
start_link(Parent, Ref, Desde, Hasta, Filtros) ->
  Pid = spawn_link(fun() -> ejecutar(Parent, Ref, Desde, Hasta, Filtros) end),
  {ok, Pid}.

ejecutar(Parent, Ref, Desde, Hasta, Filtros) ->
  Resultado = p69_bitacora:buscar(Desde, Hasta, Filtros),
  Parent ! {Ref, Resultado}.

recibir(Pid, Mon, Ref, Timeout) ->
  receive
    {Ref, Resultado} ->
      erlang:demonitor(Mon, [flush]),
      Resultado;
    {'DOWN', Mon, process, Pid, Motivo} ->
      {error, {consulta_fallo, Motivo}}
  after Timeout ->
    erlang:demonitor(Mon, [flush]),
    exit(Pid, kill),
    {error, timeout}
  end.
