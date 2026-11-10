%% Supervisor de consultas efimeras. Cada consulta de rango corre en su propio
%% proceso temporal y no bloquea la ingesta ni otros procesos.
-module(p69_consultas_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
  {ok, {#{strategy => one_for_one, intensity => 100, period => 10}, []}}.
