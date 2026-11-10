%% Arranque y supervision del listener HTTP/WebSocket de cowboy.
%% Las rutas de la API y los estaticos de priv/www se declaran aqui.
-module(p69_http).
-behaviour(gen_server).

-export([start_link/0, puerto/0, rutas/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(LISTENER, p69_http_listener).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec puerto() -> inet:port_number().
puerto() ->
  ranch:get_port(?LISTENER).

-spec rutas() -> list().
rutas() ->
  [
    {"/", cowboy_static, {priv_file, p69_camaras_y_accesos, <<"www/index.html">>}},
    {"/api/eventos", p69_api_eventos, []},
    {"/api/dispositivos", p69_api_dispositivos, []},
    {"/api/dispositivos/:id", p69_api_dispositivos, []},
    {"/api/alertas", p69_api_alertas, []},
    {"/api/bitacora/verificar", p69_api_verificar, []},
    {"/api/salud", p69_api_salud, []},
    {"/metrics", p69_api_metrics, []},
    {"/ws/eventos", p69_ws, []},
    {"/[...]", cowboy_static, {priv_dir, p69_camaras_y_accesos, <<"www">>}}
  ].

init([]) ->
  case application:ensure_all_started(cowboy) of
    {ok, _} ->
      iniciar_listener();
    {error, Motivo} ->
      {stop, {cowboy_no_arranca, Motivo}}
  end.

handle_call(_Msg, _From, Estado) ->
  {reply, {error, no_soportado}, Estado}.

handle_cast(_Msg, Estado) ->
  {noreply, Estado}.

handle_info({'DOWN', _Mon, process, _Pid, _Motivo}, Estado) ->
  %% ranch reinicia el listener; si no lo hizo, lo levantamos de nuevo.
  case iniciar_listener() of
    {ok, Estado2} -> {noreply, Estado2};
    {stop, Motivo} -> {stop, Motivo, Estado}
  end;
handle_info(_Info, Estado) ->
  {noreply, Estado}.

terminate(_Motivo, _Estado) ->
  _ = cowboy:stop_listener(?LISTENER),
  ok.

iniciar_listener() ->
  Ip = p69_config:get(interfaz, {0, 0, 0, 0}),
  Port = p69_config:get(puerto, 8080),
  Acceptors = p69_config:get(num_aceptores, 50),
  Dispatch = cowboy_router:compile([{'_', rutas()}]),
  TransOpts = #{
    socket_opts => [{ip, Ip}, {port, Port}],
    num_acceptors => Acceptors
  },
  ProtoOpts = #{
    env => #{dispatch => Dispatch},
    idle_timeout => 60000,
    max_keepalive => 1000
  },
  case cowboy:start_clear(?LISTENER, TransOpts, ProtoOpts) of
    {ok, Pid} ->
      Mon = erlang:monitor(process, Pid),
      logger:info("listener HTTP iniciado", #{
        puerto => Port, interfaz => Ip, aceptores => Acceptors
      }),
      {ok, #{listener => Pid, monitor => Mon}};
    {error, {already_started, Pid}} ->
      Mon = erlang:monitor(process, Pid),
      {ok, #{listener => Pid, monitor => Mon}};
    {error, Motivo} ->
      {stop, {listener_no_arranca, Motivo}}
  end.
