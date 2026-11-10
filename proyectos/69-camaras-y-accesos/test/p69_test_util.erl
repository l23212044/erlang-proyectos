%% Utilidades compartidas por las pruebas eunit.
-module(p69_test_util).

-export([dir/0, limpiar/1, base_ts/0, ev/5, ev/6, config/2]).

dir() ->
  Dir = filename:join(
    "/tmp",
    "p69_test_" ++ integer_to_list(erlang:unique_integer([positive, monotonic]))
  ),
  ok = filelib:ensure_dir(filename:join(Dir, "x")),
  Dir.

limpiar(Dir) ->
  _ = file:del_dir_r(Dir),
  ok.

base_ts() ->
  1700000000 * 1000000.

config(Key, Valor) ->
  application:set_env(p69_camaras_y_accesos, Key, Valor).

ev(Disp, Edificio, TipoDisp, TipoEvento, Ts) ->
  ev(Disp, Edificio, TipoDisp, TipoEvento, Ts, Ts).

ev(Disp, Edificio, TipoDisp, TipoEvento, Ts, TsRecepcion) ->
  #{
    dispositivo_id => Disp,
    tipo_dispositivo => TipoDisp,
    edificio => Edificio,
    tipo_evento => TipoEvento,
    ts_evento => Ts,
    ts_recepcion => TsRecepcion
  }.
