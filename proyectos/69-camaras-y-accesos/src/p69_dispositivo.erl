%% Un gen_server por puerta o camara. Mantiene estado propio: ultimo latido,
%% offset de reloj, contadores y eventos recientes. Si se cae, el supervisor
%% del sitio lo reinicia; el estado importante (eventos) ya vive en la bitacora.
-module(p69_dispositivo).
-behaviour(gen_server).

-export([start_link/3, estado/1, heartbeat/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(MAX_RECIENTES, 20).

start_link(Edificio, DispId, Tipo) ->
  gen_server:start_link(?MODULE, {Edificio, DispId, Tipo}, []).

-spec estado(pid()) -> map().
estado(Pid) ->
  gen_server:call(Pid, estado, 5000).

-spec heartbeat(pid()) -> ok.
heartbeat(Pid) ->
  gen_server:cast(Pid, heartbeat).

init({Edificio, DispId, Tipo}) ->
  {ok, #{
    edificio => Edificio,
    id => DispId,
    tipo => Tipo,
    ultimo_latido => erlang:system_time(microsecond),
    offset => 0,
    desfasado => false,
    estado => ok,
    contadores => #{},
    recientes => []
  }}.

handle_call(estado, _From, Estado) ->
  {reply, con_estado_calculado(Estado), Estado};
handle_call(_Msg, _From, Estado) ->
  {reply, {error, no_soportado}, Estado}.

handle_cast({evento, Ev}, Estado) ->
  TipoEvento = maps:get(tipo_evento, Ev),
  Desfasado = maps:get(desfasado, Ev, false),
  NuevoEstado = estado_por_evento(TipoEvento, Desfasado),
  Contadores = maps:update_with(TipoEvento, fun(N) -> N + 1 end, 1, maps:get(contadores, Estado)),
  Recientes = lists:sublist([Ev | maps:get(recientes, Estado)], ?MAX_RECIENTES),
  {noreply, Estado#{
    ultimo_latido => maps:get(ts_recepcion, Ev),
    offset => maps:get(offset_reloj, Ev, 0),
    desfasado => Desfasado,
    estado => NuevoEstado,
    contadores => Contadores,
    recientes => Recientes
  }};
handle_cast(heartbeat, Estado) ->
  {noreply, Estado#{ultimo_latido => erlang:system_time(microsecond)}};
handle_cast(_Msg, Estado) ->
  {noreply, Estado}.

handle_info(_Info, Estado) ->
  {noreply, Estado}.

estado_por_evento(<<"offline">>, _Desfasado) -> falla;
estado_por_evento(<<"alarma">>, _Desfasado) -> alerta;
estado_por_evento(_Tipo, true) -> alerta;
estado_por_evento(_Tipo, false) -> ok.

con_estado_calculado(Estado) ->
  Timeout = p69_config:get(dispositivo_timeout_seg, 120) * 1000000,
  Ahora = erlang:system_time(microsecond),
  EstadoFinal = case Ahora - maps:get(ultimo_latido, Estado) > Timeout of
    true -> maps:put(estado, falla, Estado);
    false -> Estado
  end,
  EstadoFinal#{
    offset_segundos => maps:get(offset, EstadoFinal) / 1000000
  }.
