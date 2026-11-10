%% Supervisor de un edificio. Sus hijos son los gen_servers de dispositivos,
%% que se agregan dinamicamente cuando llega el primer evento de cada uno.
-module(p69_sitio_sup).
-behaviour(supervisor).

-export([start_link/1, iniciar_dispositivo/4]).
-export([init/1]).

start_link(Edificio) ->
  supervisor:start_link(?MODULE, [Edificio]).

-spec iniciar_dispositivo(pid(), binary(), binary(), puerta | camara) ->
  {ok, pid()} | {error, term()}.
iniciar_dispositivo(SupPid, DispId, Edificio, Tipo) ->
  Spec = #{
    id => DispId,
    start => {p69_dispositivo, start_link, [Edificio, DispId, Tipo]},
    restart => permanent,
    shutdown => 5000,
    type => worker,
    modules => [p69_dispositivo]
  },
  supervisor:start_child(SupPid, Spec).

init([_Edificio]) ->
  {ok, {#{strategy => one_for_one, intensity => 100, period => 10}, []}}.
