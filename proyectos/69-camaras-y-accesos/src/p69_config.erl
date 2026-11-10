%% Lectura centralizada de parametros de config/sys.config.
%% Evita numeros magicos repartidos por los modulos.
-module(p69_config).

-export([get/1, get/2]).

-spec get(atom()) -> term().
get(Key) ->
  get(Key, undefined).

-spec get(atom(), term()) -> term().
get(Key, Default) ->
  case application:get_env(p69_camaras_y_accesos, Key) of
    {ok, Valor} -> Valor;
    undefined -> Default
  end.
