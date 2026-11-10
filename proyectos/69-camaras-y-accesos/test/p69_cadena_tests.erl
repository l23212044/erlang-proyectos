-module(p69_cadena_tests).
-include_lib("eunit/include/eunit.hrl").

filas_validas() ->
  Ts = p69_test_util:base_ts(),
  {ok, E1} = p69_evento:normalizar(p69_test_util:ev(<<"d1">>, <<"A">>, camara, <<"mov">>, Ts)),
  Ev1 = p69_evento:preparar(E1, 1, <<>>, 0, false),
  {ok, E2} = p69_evento:normalizar(p69_test_util:ev(<<"d2">>, <<"A">>, puerta, <<"abierta">>, Ts + 1)),
  Ev2 = p69_evento:preparar(E2, 2, maps:get(hash, Ev1), 0, false),
  [
    {1, Ev1, maps:get(hash, Ev1), maps:get(hash_prev, Ev1)},
    {2, Ev2, maps:get(hash, Ev2), maps:get(hash_prev, Ev2)}
  ].

verificar_cadena_ok_test() ->
  {ok, Resumen} = p69_cadena:verificar(filas_validas(), []),
  ?assertEqual(2, maps:get(eventos, Resumen)),
  ?assertEqual(0, maps:get(eliminados, Resumen)).

detecta_evento_alterado_test() ->
  [F1, {2, Ev2, H2, P2}] = filas_validas(),
  Ev2Alterado = Ev2#{tipo_evento => <<"manipulado">>},
  {error, Motivo} = p69_cadena:verificar([F1, {2, Ev2Alterado, H2, P2}], []),
  ?assertEqual(evento_alterado, maps:get(motivo, Motivo)).

detecta_eslabon_roto_test() ->
  [F1, {2, Ev2, H2, _P2}] = filas_validas(),
  {error, Motivo} = p69_cadena:verificar([F1, {2, Ev2, H2, <<"otro">>}], []),
  ?assertEqual(eslabon_roto, maps:get(motivo, Motivo)).

evento_eliminado_conserva_eslabon_test() ->
  [F1, {2, _Ev2, H2, P2}] = filas_validas(),
  {ok, Resumen} = p69_cadena:verificar([F1, {2, undefined, H2, P2}], []),
  ?assertEqual(1, maps:get(eventos, Resumen)),
  ?assertEqual(1, maps:get(eliminados, Resumen)).

checkpoints_ok_test() ->
  {Cp1, Cp2} = checkpoints(),
  ?assertEqual(ok, p69_cadena:verificar_checkpoints([Cp1, Cp2])).

detecta_checkpoint_alterado_test() ->
  {Cp1, Cp2} = checkpoints(),
  Cp2Alterado = Cp2#{eventos => 999},
  ?assertMatch({error, #{motivo := checkpoint_alterado}},
    p69_cadena:verificar_checkpoints([Cp1, Cp2Alterado])).

checkpoints() ->
  Cp1Base = #{
    cp_seq => 1, tipo => baja_segmento, segmento => 1,
    primer_seq => 1, ultimo_seq => 2, eventos => 2,
    hash_ultimo_evento => <<"h">>, hash_prev => <<>>, ts => 1
  },
  Cp1 = Cp1Base#{hash => p69_cadena:hash_checkpoint(<<>>, Cp1Base)},
  Cp2Base = #{
    cp_seq => 2, tipo => baja_segmento, segmento => 2,
    primer_seq => 3, ultimo_seq => 4, eventos => 2,
    hash_ultimo_evento => <<"h2">>, hash_prev => maps:get(hash, Cp1), ts => 2
  },
  Cp2 = Cp2Base#{hash => p69_cadena:hash_checkpoint(maps:get(hash, Cp1), Cp2Base)},
  {Cp1, Cp2}.
