%% Handler de /api/alertas: dispositivos en alerta o falla.
-module(p69_api_alertas).

-export([init/2]).

init(Req0, State) ->
  case cowboy_req:method(Req0) of
    <<"GET">> ->
      Alertas = [
        D
       || D <- p69_sitios:dispositivos(),
          maps:get(estado, D) =:= alerta orelse maps:get(estado, D) =:= falla
      ],
      {ok, Req, _} = p69_api:json(200, #{
        total => length(Alertas),
        alertas => [p69_api:dispositivo(D) || D <- Alertas]
      }, Req0),
      {ok, Req, State};
    _ ->
      {ok, Req, _} = p69_api:error(405, <<"metodo_no_permitido">>,
        <<"use GET">>, Req0),
      {ok, Req, State}
  end.
