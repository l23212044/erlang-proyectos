%% Supervisor raiz de los sitios (edificios). Cada sitio es un supervisor
%% dinamico que a su vez contiene los dispositivos.
-module(p69_sitios_sup).
-behaviour(supervisor).

-export([start_link/0, iniciar_sitio/1]).
-export([init/1]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec iniciar_sitio(binary()) -> {ok, pid()} | {error, term()}.
iniciar_sitio(Edificio) ->
  Spec = #{
    id => {p69_sitio_sup, Edificio},
    start => {p69_sitio_sup, start_link, [Edificio]},
    restart => permanent,
    shutdown => infinity,
    type => supervisor,
    modules => [p69_sitio_sup]
  },
  supervisor:start_child(?MODULE, Spec).

init([]) ->
  {ok, {#{strategy => one_for_one, intensity => 50, period => 30}, []}}.
