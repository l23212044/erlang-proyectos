%% Proceso periodico de retencion. Pide a la bitacora eliminar los segmentos
%% vencidos; la bitacora omite los segmentos con consultas activas (pines).
-module(p69_retencion).
-behaviour(gen_server).

-export([start_link/0, ejecutar/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec ejecutar() -> {ok, [term()]} | {error, term()}.
ejecutar() ->
  gen_server:call(?MODULE, ejecutar, 120000).

init([]) ->
  Intervalo = p69_config:get(retencion_intervalo_seg, 3600),
  _ = erlang:send_after(Intervalo * 1000, self(), tick),
  {ok, #{intervalo => Intervalo}}.

handle_call(ejecutar, _From, Estado) ->
  {reply, retener_ahora(), Estado};
handle_call(_Msg, _From, Estado) ->
  {reply, {error, no_soportado}, Estado}.

handle_cast(_Msg, Estado) ->
  {noreply, Estado}.

handle_info(tick, Estado) ->
  _ = retener_ahora(),
  _ = erlang:send_after(maps:get(intervalo, Estado) * 1000, self(), tick),
  {noreply, Estado};
handle_info(_Info, Estado) ->
  {noreply, Estado}.

retener_ahora() ->
  case p69_config:get(retencion_dias, 30) of
    0 ->
      {ok, []};
    Dias ->
      Corte = erlang:system_time(microsecond) - Dias * 86400 * 1000000,
      case p69_bitacora:retener(Corte) of
        {ok, Resultados} ->
          logger:info("retencion ejecutada", #{corte => Corte, segmentos => Resultados}),
          {ok, Resultados};
        {error, Motivo} ->
          {error, Motivo}
      end
  end.
