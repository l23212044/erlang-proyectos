%% Almacen en memoria de un segmento temporal. Usa tres rbtrees: tiempo,
%% edificio y dispositivo. Las claves incluyen ts y seq para ser unicas.
:- module(p69_almacen, [
  nuevo/1,
  insertar/3,
  buscar/6,
  contar/2,
  memoria/2,
  plegar/4,
  quitar_antes/4,
  seqs_antes/3
]).

:- use_module(library(rbtrees)).

nuevo(almacen{tiempo: T, edificio: E, dispositivo: D}) :-
  rb_empty(T), rb_empty(E), rb_empty(D).

insertar(Almacen0, Ev, Almacen) :-
  Ts = Ev.ts_corregido,
  Seq = Ev.seq,
  rb_insert(Almacen0.tiempo, {Ts, Seq}, Ev, T1),
  rb_insert(Almacen0.edificio, {Ev.edificio, Ts, Seq}, Seq, E1),
  rb_insert(Almacen0.dispositivo, {Ev.dispositivo_id, Ts, Seq}, Seq, D1),
  Almacen = Almacen0.put(_{tiempo: T1, edificio: E1, dispositivo: D1}).

buscar(Almacen, Desde, Hasta, Filtros, MaxSeq, Evs) :-
  rb_visit(Almacen.tiempo, Filas),
  include_filas(Filas, Desde, Hasta, Filtros, MaxSeq, Evs).

include_filas([], _Desde, _Hasta, _Filtros, _MaxSeq, []).
include_filas([{Ts, Seq}-Ev | Resto], Desde, Hasta, Filtros, MaxSeq, Evs) :-
  ( Ts >= Desde, Ts =< Hasta, Seq =< MaxSeq, cumple(Ev, Filtros) ->
      Evs = [Ev | Evs1],
      include_filas(Resto, Desde, Hasta, Filtros, MaxSeq, Evs1)
  ; include_filas(Resto, Desde, Hasta, Filtros, MaxSeq, Evs)
  ).

cumple(Ev, Filtros) :-
  coincide(edificio, Ev.edificio, Filtros),
  coincide(dispositivo, Ev.dispositivo_id, Filtros),
  coincide(tipo, Ev.tipo_evento, Filtros),
  coincide(persona, Ev.persona, Filtros).

coincide(Clave, Valor, Filtros) :-
  ( get_dict(Clave, Filtros, Esperado) ->
      ( Esperado == undefined -> true ; Valor == Esperado )
  ; true
  ).

contar(Almacen, N) :-
  rb_size(Almacen.tiempo, N).

%% Aproximacion: se reporta como bytes de memoria del segmento.
memoria(Almacen, Bytes) :-
  rb_size(Almacen.tiempo, N),
  Bytes is N * 200.

plegar(Almacen, Fun, Acc0, Acc) :-
  rb_visit(Almacen.tiempo, Filas),
  plegar_filas(Filas, Fun, Acc0, Acc).

plegar_filas([], _Fun, Acc, Acc).
plegar_filas([_K-Ev | Resto], Fun, Acc0, Acc) :-
  call(Fun, Ev, Acc0, Acc1),
  plegar_filas(Resto, Fun, Acc1, Acc).

seqs_antes(Almacen, Corte, Seqs) :-
  rb_visit(Almacen.tiempo, Filas),
  seqs_filas(Filas, Corte, [], Seqs).

seqs_filas([], _Corte, Acc, Seqs) :- reverse(Acc, Seqs).
seqs_filas([{Ts, Seq}-_Ev | Resto], Corte, Acc, Seqs) :-
  ( Ts < Corte ->
      seqs_filas(Resto, Corte, [Seq | Acc], Seqs)
  ; seqs_filas(Resto, Corte, Acc, Seqs)
  ).

%% Quita del segmento los eventos anteriores a CorteTs. Devuelve el nuevo
%% almacen y cuantos eventos se quitaron. El libro de hashes no se toca.
quitar_antes(Almacen, CorteTs, Nuevo, Eliminados) :-
  nuevo(Vacio),
  rb_visit(Almacen.tiempo, Filas),
  quitar_filas(Filas, CorteTs, Vacio, Nuevo, 0, Eliminados).

quitar_filas([], _Corte, Vacio, Vacio, N, N).
quitar_filas([{Ts, _Seq}-Ev | Resto], Corte, Acc0, Nuevo, N0, N) :-
  ( Ts < Corte ->
      N1 is N0 + 1,
      quitar_filas(Resto, Corte, Acc0, Nuevo, N1, N)
  ; insertar(Acc0, Ev, Acc1),
    quitar_filas(Resto, Corte, Acc1, Nuevo, N0, N)
  ).
