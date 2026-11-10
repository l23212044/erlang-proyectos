%% Estimacion de desfase de reloj por dispositivo con mediana de las ultimas
%% muestras. Es logica pura: el proceso que la usa decide cuando persistirla.
-module(p69_reloj).

-export([nuevo/0, agregar/4, offset/1, desfasado/1, muestras/1]).
-export_type([estado/0]).

-type estado() :: #{
  deltas := [integer()],
  offset := integer(),
  desfasado := boolean()
}.

-spec nuevo() -> estado().
nuevo() ->
  #{deltas => [], offset => 0, desfasado => false}.

-spec agregar(estado(), integer(), integer(), map()) -> estado().
agregar(Estado, TsEvento, TsRecepcion, Opts) ->
  MaxMuestras = maps:get(max_muestras, Opts, 15),
  Umbral = maps:get(umbral_reloj_micros, Opts, 60000000),
  Delta = TsRecepcion - TsEvento,
  Recortados = lists:sublist([Delta | muestras(Estado)], MaxMuestras),
  Offset = p69_evento:estimar_offset(Recortados),
  #{
    deltas => Recortados,
    offset => Offset,
    desfasado => p69_evento:desfasado(Offset, Umbral)
  }.

-spec offset(estado()) -> integer().
offset(Estado) -> maps:get(offset, Estado).

-spec desfasado(estado()) -> boolean().
desfasado(Estado) -> maps:get(desfasado, Estado).

-spec muestras(estado()) -> [integer()].
muestras(Estado) -> maps:get(deltas, Estado).
