-module(p69_almacen_tests).
-include_lib("eunit/include/eunit.hrl").

ev(Seq, Ts, Edificio, Disp) ->
  #{
    seq => Seq,
    ts_corregido => Ts,
    edificio => Edificio,
    dispositivo_id => Disp,
    tipo_evento => <<"movimiento">>,
    persona => undefined
  }.

busqueda_ordenada_y_tardia_test() ->
  Seg = p69_almacen:crear(),
  ok = p69_almacen:insertar(Seg, ev(1, 100, <<"A">>, <<"d1">>)),
  ok = p69_almacen:insertar(Seg, ev(2, 300, <<"A">>, <<"d1">>)),
  %% Evento tardio: se inserta despues pero con ts menor.
  ok = p69_almacen:insertar(Seg, ev(3, 200, <<"B">>, <<"d2">>)),
  Resultado = p69_almacen:buscar(Seg, 100, 300, #{}, 3),
  ?assertEqual([1, 3, 2], [maps:get(seq, E) || E <- Resultado]),
  ?assertEqual(3, p69_almacen:contar(Seg)),
  p69_almacen:borrar(Seg).

filtros_e_indices_test() ->
  Seg = p69_almacen:crear(),
  ok = p69_almacen:insertar(Seg, ev(1, 100, <<"A">>, <<"d1">>)),
  ok = p69_almacen:insertar(Seg, ev(2, 200, <<"B">>, <<"d2">>)),
  ok = p69_almacen:insertar(Seg, ev(3, 300, <<"A">>, <<"d2">>)),
  SoloA = p69_almacen:buscar(Seg, 0, 400, #{edificio => <<"A">>}, 3),
  ?assertEqual([1, 3], [maps:get(seq, E) || E <- SoloA]),
  SoloD2 = p69_almacen:buscar(Seg, 0, 400, #{dispositivo => <<"d2">>}, 3),
  ?assertEqual([2, 3], [maps:get(seq, E) || E <- SoloD2]),
  HastaSeq2 = p69_almacen:buscar(Seg, 0, 400, #{}, 2),
  ?assertEqual([1, 2], [maps:get(seq, E) || E <- HastaSeq2]),
  Rango = p69_almacen:buscar(Seg, 150, 250, #{}, 3),
  ?assertEqual([2], [maps:get(seq, E) || E <- Rango]),
  Total = p69_almacen:plegar(fun(_E, N) -> N + 1 end, 0, Seg),
  ?assertEqual(3, Total),
  p69_almacen:borrar(Seg).

vacio_test() ->
  Seg = p69_almacen:crear(),
  ?assertEqual([], p69_almacen:buscar(Seg, 0, 100, #{}, 10)),
  p69_almacen:borrar(Seg).
