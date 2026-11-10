%% Arbol de supervision raiz.
%% Estrategia rest_for_one: si la bitacora cae, se reinician tambien los
%% procesos que dependen de ella (sitios, consultas, retencion). La bitacora
%% es la duena de las ETS y del WAL; al reiniciar reconstruye su estado desde
%% el WAL, por eso los clientes nunca son duenos de las tablas.
-module(p69_camaras_y_accesos_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
  Children = [
    #{
      id => p69_metricas,
      start => {p69_metricas, start_link, []},
      restart => permanent,
      shutdown => 5000,
      type => worker
    },
    #{
      id => p69_bitacora,
      start => {p69_bitacora, start_link, []},
      restart => permanent,
      shutdown => 15000,
      type => worker
    },
    #{
      id => p69_eventos_pub,
      start => {p69_eventos_pub, start_link, []},
      restart => permanent,
      shutdown => 5000,
      type => worker
    },
    #{
      id => p69_sitios_sup,
      start => {p69_sitios_sup, start_link, []},
      restart => permanent,
      shutdown => infinity,
      type => supervisor
    },
    #{
      id => p69_sitios,
      start => {p69_sitios, start_link, []},
      restart => permanent,
      shutdown => 5000,
      type => worker
    },
    #{
      id => p69_consultas_sup,
      start => {p69_consultas_sup, start_link, []},
      restart => permanent,
      shutdown => infinity,
      type => supervisor
    },
    #{
      id => p69_retencion,
      start => {p69_retencion, start_link, []},
      restart => permanent,
      shutdown => 5000,
      type => worker
    },
    #{
      id => p69_http,
      start => {p69_http, start_link, []},
      restart => permanent,
      shutdown => 10000,
      type => worker
    },
    #{
      id => p69_camaras_y_accesos_server,
      start => {p69_camaras_y_accesos_server, start_link, []},
      restart => permanent,
      shutdown => 5000,
      type => worker
    }
  ],
  {ok, {#{strategy => rest_for_one, intensity => 10, period => 60}, Children}}.
