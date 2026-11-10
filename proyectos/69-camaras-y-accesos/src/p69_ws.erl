%% WebSocket /ws/eventos: envia cada evento nuevo y un resumen periodico del
%% estado de dispositivos para reflejar cambios (offline, alerta, desfase).
-module(p69_ws).

-export([init/2, websocket_init/1, websocket_handle/2, websocket_info/2, terminate/3]).

-define(INTERVALO_RESUMEN_MS, 5000).

init(Req0, State) ->
  ok = p69_eventos_pub:suscribir(self()),
  {cowboy_websocket, Req0, State}.

websocket_init(State) ->
  _ = erlang:send_after(?INTERVALO_RESUMEN_MS, self(), resumen),
  {reply, {text, codificar(resumen())}, State}.

websocket_handle({text, <<"ping">>}, State) ->
  {reply, {text, <<"pong">>}, State};
websocket_handle({text, _Bin}, State) ->
  {ok, State};
websocket_handle(_Frame, State) ->
  {ok, State}.

websocket_info({evento, Ev}, State) ->
  Mensaje = #{tipo => <<"evento">>, evento => p69_api:evento(Ev)},
  {reply, {text, codificar(Mensaje)}, State};
websocket_info(resumen, State) ->
  _ = erlang:send_after(?INTERVALO_RESUMEN_MS, self(), resumen),
  {reply, {text, codificar(resumen())}, State};
websocket_info(_Info, State) ->
  {ok, State}.

terminate(_Motivo, _Req, _State) ->
  p69_eventos_pub:desuscribir(self()),
  ok.

resumen() ->
  Devs = p69_sitios:dispositivos(),
  Estado = p69_bitacora:estado(),
  #{
    tipo => <<"resumen">>,
    ts => p69_api:iso(erlang:system_time(microsecond)),
    seq => maps:get(seq, Estado),
    cola_ingesta => maps:get(cola_ingesta, Estado, 0),
    dispositivos => length(Devs),
    camaras_offline => contar(Devs, camara, falla),
    puertas_offline => contar(Devs, puerta, falla),
    en_alerta => length([D || D <- Devs, maps:get(estado, D) =:= alerta])
  }.

contar(Devs, Tipo, Estado) ->
  length([
    D || D <- Devs,
         maps:get(tipo, D) =:= Tipo,
         maps:get(estado, D) =:= Estado
  ]).

codificar(Termino) ->
  iolist_to_binary(json:encode(Termino)).
