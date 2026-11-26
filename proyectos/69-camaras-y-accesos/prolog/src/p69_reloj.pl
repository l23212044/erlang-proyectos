%% Estimacion de desfase de reloj por dispositivo con mediana de las ultimas
%% muestras. Logica pura; la bitacora decide cuando guardarla.
:- module(p69_reloj, [
  nuevo/1,
  agregar/6,
  offset/2,
  desfasado/2,
  muestras/2
]).

nuevo(reloj{deltas: [], offset: 0, desfasado: false}).

agregar(Reloj0, TsEvento, TsRecepcion, MaxMuestras, Umbral, Reloj) :-
  Delta is TsRecepcion - TsEvento,
  get_dict(deltas, Reloj0, Deltas0),
  ( length(Deltas0, Largo), Largo >= MaxMuestras ->
      tomar(MaxMuestras, Deltas0, Previas)
  ; Previas = Deltas0
  ),
  Deltas = [Delta | Previas],
  p69_evento:estimar_offset(Deltas, Offset),
  p69_evento:desfasado(Offset, Umbral, Desfasado),
  Reloj = reloj{deltas: Deltas, offset: Offset, desfasado: Desfasado}.

offset(Reloj, Offset) :- get_dict(offset, Reloj, Offset).
desfasado(Reloj, Desfasado) :- get_dict(desfasado, Reloj, Desfasado).
muestras(Reloj, Deltas) :- get_dict(deltas, Reloj, Deltas).

tomar(0, _, []) :- !.
tomar(_, [], []) :- !.
tomar(N, [X | Resto], [X | Tomados]) :-
  N1 is N - 1,
  tomar(N1, Resto, Tomados).
