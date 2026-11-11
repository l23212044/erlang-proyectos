%% Handler de /api/salud: estado del sistema y de la bitacora.
-module(p69_api_salud).

-export([init/2]).

init(Req0, State) ->
  case cowboy_req:method(Req0) of
    <<"GET">> ->
      {UptimeMs, _} = erlang:statistics(wall_clock),
      Vsn = case application:get_key(p69_camaras_y_accesos, vsn) of
        {ok, V} -> list_to_binary(V);
        _ -> <<"desconocida">>
      end,
      {ok, Req, _} = p69_api:json(200, #{
        estado => <<"ok">>,
        version => Vsn,
        otp => list_to_binary(erlang:system_info(otp_release)),
        uptime_seg => UptimeMs div 1000,
        procesos => erlang:system_info(process_count),
        memoria_total => erlang:memory(total),
        bitacora => clave(p69_bitacora:estado()),
        metricas => metricas_json(p69_metricas:snapshot())
      }, Req0),
      {ok, Req, State};
    _ ->
      {ok, Req, _} = p69_api:error(405, <<"metodo_no_permitido">>,
        <<"use GET">>, Req0),
      {ok, Req, State}
  end.

metricas_json(Map) ->
  maps:from_list([
    {p69_api:clave_texto(K), V} || {K, V} <- maps:to_list(Map)
  ]).

clave(Map) ->
  maps:from_list([
    {p69_api:clave_texto(K), valor(K, V)} || {K, V} <- maps:to_list(Map)
  ]).

%% El hash interno es binario crudo (32 bytes) y no siempre es UTF-8 valido.
%% La API lo expone en hexadecimal igual que los eventos.
valor(ultimo_hash, V) when is_binary(V) -> binary:encode_hex(V);
valor(_K, V) -> V.
