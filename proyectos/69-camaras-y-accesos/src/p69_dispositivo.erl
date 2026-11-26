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
  Offset = maps:get(offset_reloj, Ev, 0),
  NuevoEstado = estado_por_evento(TipoEvento, Desfasado, reloj_en_falla(Offset)),
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

estado_por_evento(<<"offline">>, _Desfasado, _FallaReloj) -> falla;
estado_por_evento(_Tipo, _Desfasado, true) -> falla;
estado_por_evento(<<"alarma">>, _Desfasado, false) -> alerta;
estado_por_evento(_Tipo, true, false) -> alerta;
estado_por_evento(_Tipo, false, false) -> ok.

reloj_en_falla(Offset) ->
  Umbral = p69_config:get(reloj_falla_seg, 300) * 1000000,
  abs(Offset) > Umbral.

con_estado_calculado(Estado) ->
  Alerta = p69_config:get(dispositivo_alerta_seg, 60) * 1000000,
  Falla = p69_config:get(dispositivo_falla_seg, 180) * 1000000,
  Ahora = erlang:system_time(microsecond),
  Silencio = Ahora - maps:get(ultimo_latido, Estado),
  EstadoFinal = estado_por_silencio(Silencio, Alerta, Falla, Estado),
  EstadoFinal#{
    offset_segundos => maps:get(offset, EstadoFinal) / 1000000
  }.

estado_por_silencio(Silencio, _Alerta, Falla, Estado) when Silencio > Falla ->
  maps:put(estado, falla, Estado);
estado_por_silencio(Silencio, Alerta, _Falla, Estado) when Silencio > Alerta ->
  maps:put(estado, alerta, Estado);
estado_por_silencio(_Silencio, _Alerta, _Falla, Estado) ->
  Estado.
