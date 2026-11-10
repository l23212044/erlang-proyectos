-module(p69_evento_tests).
-include_lib("eunit/include/eunit.hrl").

normalizar_valido_test() ->
  Ts = p69_test_util:base_ts(),
  {ok, Ev} = p69_evento:normalizar(p69_test_util:ev(<<"cam-1">>, <<"A">>, camara, <<"movimiento">>, Ts)),
  ?assertEqual(<<"cam-1">>, maps:get(dispositivo_id, Ev)),
  ?assertEqual(camara, maps:get(tipo_dispositivo, Ev)),
  ?assertEqual(Ts, maps:get(ts_evento, Ev)),
  ?assertEqual(undefined, maps:get(persona, Ev)).

normalizar_iso8601_test() ->
  {ok, Ev} = p69_evento:normalizar(#{
    <<"dispositivo_id">> => <<"puerta-1">>,
    <<"tipo_dispositivo">> => <<"puerta">>,
    <<"edificio">> => <<"B">>,
    <<"tipo_evento">> => <<"tarjeta_leida">>,
    <<"ts_evento">> => <<"2026-11-09T10:00:00Z">>
  }),
  ?assertEqual(puerta, maps:get(tipo_dispositivo, Ev)),
  ?assert(is_integer(maps:get(ts_evento, Ev))).

normalizar_invalido_test() ->
  ?assertMatch({error, {campo_requerido, _}},
    p69_evento:normalizar(#{tipo_dispositivo => camara})),
  ?assertMatch({error, {tipo_dispositivo_invalido, _}},
    p69_evento:normalizar(p69_test_util:ev(<<"x">>, <<"A">>, sensor, <<"x">>, 1))).

escala_timestamps_test() ->
  ?assertEqual(1700000000000000, p69_evento:ts_a_micros(1700000000)),
  ?assertEqual(1700000000000000, p69_evento:ts_a_micros(1700000000000)),
  ?assertEqual(1700000000000000, p69_evento:ts_a_micros(1700000000000000)),
  ?assertEqual(1700000000000000, p69_evento:ts_a_micros(<<"1700000000">>)).

cadena_hashes_test() ->
  Ts = p69_test_util:base_ts(),
  {ok, E1} = p69_evento:normalizar(p69_test_util:ev(<<"d1">>, <<"A">>, camara, <<"movimiento">>, Ts)),
  Ev1 = p69_evento:preparar(E1, 1, <<>>, 0, false),
  {ok, E2} = p69_evento:normalizar(p69_test_util:ev(<<"d2">>, <<"A">>, puerta, <<"abierta">>, Ts + 1)),
  Ev2 = p69_evento:preparar(E2, 2, maps:get(hash, Ev1), 0, false),
  ?assert(p69_evento:verificar_hash(Ev1)),
  ?assert(p69_evento:verificar_hash(Ev2)),
  ?assertEqual(maps:get(hash_prev, Ev2), maps:get(hash, Ev1)).

mediana_y_offset_test() ->
  ?assertEqual(3, p69_evento:mediana([1, 2, 3, 10, 100])),
  ?assertEqual(2, p69_evento:mediana([1, 2, 3, 4])),
  ?assertEqual(240000000, p69_evento:estimar_offset([239000000, 241000000, 240000000])),
  ?assert(p69_evento:desfasado(240000000, 60000000)),
  ?assertNot(p69_evento:desfasado(1000000, 60000000)).

reloj_estado_test() ->
  R0 = p69_reloj:nuevo(),
  R1 = p69_reloj:agregar(R0, 1000000, 241000000,
    #{max_muestras => 5, umbral_reloj_micros => 60000000}),
  ?assertEqual(240000000, p69_reloj:offset(R1)),
  ?assert(p69_reloj:desfasado(R1)),
  ?assertEqual(1, length(p69_reloj:muestras(R1))).
