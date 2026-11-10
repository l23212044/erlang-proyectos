-module(p69_bitacora_tests).
-include_lib("eunit/include/eunit.hrl").

-define(SEG, 3600).

iniciar() ->
  Dir = p69_test_util:dir(),
  p69_test_util:config(datos_dir, Dir),
  p69_test_util:config(segmento_segundos, ?SEG),
  p69_test_util:config(retencion_dias, 0),
  p69_test_util:config(umbral_reloj_seg, 60),
  p69_test_util:config(reloj_max_muestras, 5),
  {ok, Pid} = p69_bitacora:start_link(),
  #{dir => Dir, pid => Pid}.

detener(#{dir := Dir}) ->
  case whereis(p69_bitacora) of
    undefined -> ok;
    Pid -> catch gen_server:stop(Pid)
  end,
  p69_test_util:limpiar(Dir).

ingesta_busqueda_test_() ->
  {setup, fun iniciar/0, fun detener/1, fun(_Ctx) ->
    T = p69_test_util:base_ts(),
    {ok, _} = p69_bitacora:ingresar(
      p69_test_util:ev(<<"cam-1">>, <<"A">>, camara, <<"movimiento">>, T)),
    {ok, _} = p69_bitacora:ingresar(
      p69_test_util:ev(<<"cam-1">>, <<"A">>, camara, <<"movimiento">>, T + 20 * 1000000)),
    {ok, _} = p69_bitacora:ingresar(
      p69_test_util:ev(<<"pue-1">>, <<"B">>, puerta, <<"puerta_abierta">>, T + 5 * 1000000)),
    {ok, Todos} = p69_bitacora:buscar(T, T + 30 * 1000000, #{}),
    [?_assertEqual([1, 3, 2], [maps:get(seq, E) || E <- Todos]),
     ?_assertEqual([1, 2], [maps:get(seq, E) || E <- elems(
        p69_bitacora:buscar(T, T + 30 * 1000000, #{edificio => <<"A">>}))]),
     ?_assertEqual([3], [maps:get(seq, E) || E <- elems(
        p69_bitacora:buscar(T, T + 30 * 1000000, #{dispositivo => <<"pue-1">>}))]),
     ?_assertEqual(T + 5 * 1000000, maps:get(ts_corregido, lists:nth(2, Todos)))]
  end}.

reloj_desfasado_test_() ->
  {setup, fun iniciar/0, fun detener/1, fun(_Ctx) ->
    Ahora = erlang:system_time(microsecond),
    Tardio = Ahora - 240 * 1000000,
    {ok, E1} = p69_bitacora:ingresar(
      p69_test_util:ev(<<"cam-r">>, <<"C">>, camara, <<"movimiento">>, Tardio, Ahora)),
    {ok, E2} = p69_bitacora:ingresar(
      p69_test_util:ev(<<"cam-r">>, <<"C">>, camara, <<"movimiento">>, Tardio + 1000000, Ahora)),
    {ok, E3} = p69_bitacora:ingresar(
      p69_test_util:ev(<<"cam-r">>, <<"C">>, camara, <<"movimiento">>, Tardio + 2000000, Ahora)),
    {ok, Offset, Desfasado} = p69_bitacora:offset_dispositivo(<<"cam-r">>),
    {ok, Encontrados} = p69_bitacora:buscar(Ahora - 1000000, Ahora + 1000000, #{}),
    [?_assertEqual(true, Desfasado),
     ?_assert(abs(Offset - 240 * 1000000) < 2000000),
     ?_assertEqual(true, maps:get(desfasado, E1)),
     ?_assertEqual(true, maps:get(desfasado, E2)),
     ?_assertEqual(true, maps:get(desfasado, E3)),
     ?_assertEqual([1, 2, 3], [maps:get(seq, E) || E <- Encontrados])]
  end}.

verificacion_y_recuperacion_test_() ->
  {setup, fun iniciar/0, fun detener/1, fun(Ctx) ->
    T = p69_test_util:base_ts(),
    [p69_bitacora:ingresar(p69_test_util:ev(
      uniforme_disp(N), <<"A">>, camara, <<"movimiento">>, T + N * 1000000))
     || N <- [1, 2, 3]],
    {ok, Antes} = p69_bitacora:verificar(),
    #{pid := Pid} = Ctx,
    ok = gen_server:stop(Pid),
    {ok, _Pid2} = p69_bitacora:start_link(),
    {ok, Recuperados} = p69_bitacora:buscar(T, T + 10 * 1000000, #{}),
    {ok, Despues} = p69_bitacora:verificar(),
    {ok, Cuarto} = p69_bitacora:ingresar(
      p69_test_util:ev(<<"cam-4">>, <<"A">>, camara, <<"movimiento">>, T + 4 * 1000000)),
    [?_assertEqual(3, maps:get(eventos, Antes)),
     ?_assertEqual(3, length(Recuperados)),
     ?_assertEqual(3, maps:get(eventos, Despues)),
     ?_assertEqual(4, maps:get(seq, Cuarto))]
  end}.

retencion_con_consulta_test_() ->
  {setup, fun iniciar/0, fun detener/1, fun(_Ctx) ->
    T = p69_test_util:base_ts(),
    {ok, _} = p69_bitacora:ingresar(
      p69_test_util:ev(<<"p1">>, <<"A">>, puerta, <<"puerta_abierta">>, T)),
    {ok, _} = p69_bitacora:ingresar(
      p69_test_util:ev(<<"p2">>, <<"A">>, puerta, <<"puerta_abierta">>, T + 1000000)),
    SegId = T div (?SEG * 1000000),
    {ok, {Ref, Segmentos, _Snap}} = p69_bitacora:abrir_consulta(T, T + ?SEG * 1000000),
    EnUso = p69_bitacora:baja_segmento(SegId),
    ok = p69_bitacora:cerrar_consulta(Ref),
    Baja = p69_bitacora:baja_segmento(SegId),
    {ok, Vacios} = p69_bitacora:buscar(T, T + ?SEG * 1000000, #{}),
    Info = p69_bitacora:info_segmentos(),
    {ok, Verificacion} = p69_bitacora:verificar(),
    [?_assertEqual({error, en_uso}, EnUso),
     ?_assertEqual(1, length(Segmentos)),
     ?_assertEqual(ok, Baja),
     ?_assertEqual([], Vacios),
     ?_assertEqual([], Info),
     ?_assertEqual(0, maps:get(eventos, Verificacion)),
     ?_assertEqual(2, maps:get(eliminados, Verificacion)),
     ?_assertEqual(1, maps:get(checkpoints, Verificacion))]
  end}.

uniforme_disp(N) ->
  iolist_to_binary(["cam-", integer_to_list(N)]).

elems({ok, Lista}) -> Lista.
