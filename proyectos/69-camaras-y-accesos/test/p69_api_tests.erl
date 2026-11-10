-module(p69_api_tests).
-include_lib("eunit/include/eunit.hrl").

iniciar() ->
  Dir = p69_test_util:dir(),
  p69_test_util:config(datos_dir, Dir),
  p69_test_util:config(segmento_segundos, 3600),
  p69_test_util:config(retencion_dias, 0),
  p69_test_util:config(puerto, 0),
  p69_test_util:config(num_aceptores, 5),
  {ok, _} = application:ensure_all_started(inets),
  {ok, Pid} = p69_camaras_y_accesos_sup:start_link(),
  #{dir => Dir, pid => Pid, puerto => p69_http:puerto()}.

detener(#{dir := Dir, pid := Pid}) ->
  unlink(Pid),
  exit(Pid, shutdown),
  _ = application:stop(inets),
  p69_test_util:limpiar(Dir).

api_test_() ->
  {setup, fun iniciar/0, fun detener/1, fun(Ctx) ->
    [
      fun() -> salud_y_estaticos(Ctx) end,
      fun() -> alta_busqueda_y_dispositivos(Ctx) end,
      fun() -> validacion_y_paginacion(Ctx) end,
      fun() -> verificacion_integridad(Ctx) end
    ]
  end}.

salud_y_estaticos(Ctx) ->
  {200, Salud} = get(Ctx, "/api/salud"),
  ?assertEqual(<<"ok">>, maps:get(<<"estado">>, decodificar(Salud))),
  {200, Index} = get(Ctx, "/"),
  ?assertNotEqual(nomatch, binary:match(Index, <<"API activa">>)),
  {200, Metrics} = get(Ctx, "/metrics"),
  ?assertNotEqual(nomatch, binary:match(Metrics, <<"p69_eventos_total">>)).

alta_busqueda_y_dispositivos(Ctx) ->
  T = p69_test_util:base_ts(),
  Evento = #{
    dispositivo_id => <<"api-cam-1">>,
    tipo_dispositivo => <<"camara">>,
    edificio => <<"API">>,
    tipo_evento => <<"movimiento">>,
    persona => <<"ana">>,
    ts_evento => T,
    ts_recepcion => T
  },
  {201, Respuesta} = post(Ctx, "/api/eventos", Evento),
  #{<<"evento">> := Ev} = decodificar(Respuesta),
  ?assertEqual(<<"api-cam-1">>, maps:get(<<"dispositivo_id">>, Ev)),
  Ruta = io_lib:format("/api/eventos?desde=~p&hasta=~p&edificio=API",
    [T, T + 1000000]),
  {200, ListaBin} = get(Ctx, lists:flatten(Ruta)),
  Lista = decodificar(ListaBin),
  ?assertEqual(1, maps:get(<<"total">>, Lista)),
  esperar_dispositivo(<<"api-cam-1">>, 50),
  {200, DevsBin} = get(Ctx, "/api/dispositivos?edificio=API"),
  Devs = decodificar(DevsBin),
  ?assertEqual(1, maps:get(<<"total">>, Devs)),
  {200, DetalleBin} = get(Ctx, "/api/dispositivos/api-cam-1?edificio=API"),
  Detalle = decodificar(DetalleBin),
  ?assertEqual(<<"camara">>, maps:get(<<"tipo">>, Detalle)),
  {200, AlertasBin} = get(Ctx, "/api/alertas"),
  ?assert(is_map(decodificar(AlertasBin))).

validacion_y_paginacion(Ctx) ->
  {400, _} = post(Ctx, "/api/eventos", #{tipo_evento => <<"x">>}),
  T = p69_test_util:base_ts() + 100000,
  [post(Ctx, "/api/eventos", #{
    dispositivo_id => <<"api-p-1">>,
    tipo_dispositivo => <<"puerta">>,
    edificio => <<"PAG">>,
    tipo_evento => <<"tarjeta_leida">>,
    ts_evento => T + N,
    ts_recepcion => T + N
   }) || N <- [0, 1000000, 2000000]],
  Ruta = lists:flatten(io_lib:format(
    "/api/eventos?desde=~p&hasta=~p&edificio=PAG&limite=2&offset=0",
    [T, T + 3000000])),
  {200, Bin} = get(Ctx, Ruta),
  Pagina = decodificar(Bin),
  ?assertEqual(3, maps:get(<<"total">>, Pagina)),
  ?assertEqual(2, length(maps:get(<<"eventos">>, Pagina))).

verificacion_integridad(Ctx) ->
  {200, Bin} = get(Ctx, "/api/bitacora/verificar"),
  Resp = decodificar(Bin),
  ?assertEqual(<<"ok">>, maps:get(<<"integridad">>, Resp)).

esperar_dispositivo(_Id, 0) ->
  error(dispositivo_no_creado);
esperar_dispositivo(Id, N) ->
  Devs = p69_sitios:dispositivos(),
  case lists:any(fun(D) -> maps:get(id, D) =:= Id end, Devs) of
    true -> ok;
    false ->
      timer:sleep(20),
      esperar_dispositivo(Id, N - 1)
  end.

get(#{puerto := Puerto}, Ruta) ->
  Url = lists:flatten(io_lib:format("http://127.0.0.1:~p~s", [Puerto, Ruta])),
  {ok, {{_, Status, _}, _Headers, Cuerpo}} =
    httpc:request(get, {Url, []}, [{timeout, 10000}], [{body_format, binary}]),
  {Status, Cuerpo}.

post(#{puerto := Puerto}, Ruta, Termino) ->
  Url = lists:flatten(io_lib:format("http://127.0.0.1:~p~s", [Puerto, Ruta])),
  Cuerpo = iolist_to_binary(json:encode(Termino)),
  {ok, {{_, Status, _}, _Headers, Respuesta}} = httpc:request(
    post,
    {Url, [], "application/json", Cuerpo},
    [{timeout, 10000}],
    [{body_format, binary}]
  ),
  {Status, Respuesta}.

decodificar(Bin) ->
  json:decode(iolist_to_binary(Bin)).
