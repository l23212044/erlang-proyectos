%% Handler de /api/bitacora/verificar. Recalcula la cadena desde el libro de
%% hashes: detecta eventos alterados y eslabones rotos. Responde 409 si falla.
-module(p69_api_verificar).

-export([init/2]).

init(Req0, State) ->
  case cowboy_req:method(Req0) of
    <<"GET">> ->
      case p69_bitacora:verificar() of
        {ok, Resumen} ->
          {ok, Req, _} = p69_api:json(200, #{
            integridad => <<"ok">>,
            resumen => clave(Resumen)
          }, Req0),
          {ok, Req, State};
        {error, Detalle} ->
          {ok, Req, _} = p69_api:json(409, #{
            integridad => <<"falla">>,
            detalle => clave(Detalle)
          }, Req0),
          {ok, Req, State}
      end;
    _ ->
      {ok, Req, _} = p69_api:error(405, <<"metodo_no_permitido">>,
        <<"use GET">>, Req0),
      {ok, Req, State}
  end.

clave(Map) ->
  maps:from_list([
    {p69_api:clave_texto(K), V} || {K, V} <- maps:to_list(Map)
  ]).
