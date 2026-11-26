%% Verificacion de la cadena de eventos y de checkpoints de retencion.
:- module(p69_cadena, [
  hash_checkpoint/3,
  verificar/4,
  verificar_checkpoints/2,
  verificar_ledger/3
]).

:- use_module(library(crypto)).
:- use_module(library(rbtrees)).
:- use_module(p69_util).
:- use_module(p69_evento).

hash_checkpoint(HashPrev, Cp, HashHex) :-
  format(string(P1),
    'cp_seq=~w|tipo=~w|segmento=~w|primer_seq=~w|ultimo_seq=~w|eventos=~w|hash_ultimo=',
    [Cp.cp_seq, Cp.tipo, Cp.segmento, Cp.primer_seq, Cp.ultimo_seq, Cp.eventos]),
  text_bytes(P1, B1),
  hex_a_bytes(Cp.hash_ultimo_evento, B2),
  format(string(P3), '|ts=~w', [Cp.ts]),
  text_bytes(P3, B3),
  append([B1, B2, B3], CanonBytes),
  hex_a_bytes(HashPrev, PrevBytes),
  append(PrevBytes, CanonBytes, Datos),
  string_codes(DatosTexto, Datos),
  crypto_data_hash(DatosTexto, HashAtom, [algorithm(sha256), encoding(octet)]),
  atom_string(HashAtom, HashMin),
  string_upper(HashMin, HashHex).

verificar(Ledger, PorSeq, Cps, Resultado) :-
  verificar_checkpoints(Cps, ResultadoCp),
  verificar_ledger(Ledger, PorSeq, ResultadoEventos),
  ( ResultadoCp = ok(NCp), ResultadoEventos = ok(Resumen) ->
      Resultado = ok(Resumen.put(checkpoints, NCp))
  ; ResultadoCp = error(DetalleCp) ->
      Resultado = error(DetalleCp)
  ; ResultadoEventos = error(DetalleEv) ->
      Resultado = error(DetalleEv)
  ).

verificar_checkpoints([], ok(0)) :- !.
verificar_checkpoints(Cps, Resultado) :-
  msort(Cps, Ordenados),
  [Primero | Resto] = Ordenados,
  verificar_cp(Primero, Primero.hash_prev, Resto, 1, Resultado).

verificar_cp(_Cp, _Prev, [], N, ok(N)).
verificar_cp(Cp, Prev, [Siguiente | Cola], N, Resultado) :-
  hash_checkpoint(Prev, Cp, Calculado),
  ( Calculado == Cp.hash ->
      N1 is N + 1,
      verificar_cp(Siguiente, Cp.hash, Cola, N1, Resultado)
  ; Resultado = error(#{motivo: checkpoint_alterado, cp_seq: Cp.cp_seq})
  ).

verificar_ledger(Ledger, PorSeq, Resultado) :-
  rb_visit(Ledger, Filas),
  verificar_filas(Filas, PorSeq, 1, "", 0, 0, 0, Resultado).

verificar_filas([], _PorSeq, _SeqEsperado, _Prev, Presentes, Eliminados, Ultimo,
    ok(#{eventos: Presentes, eliminados: Eliminados, ultimo_seq: Ultimo})).
verificar_filas([Seq-Fila | Resto], PorSeq, SeqEsperado, Prev, Presentes, Eliminados,
    _Ultimo, Resultado) :-
  ( Seq =:= SeqEsperado ->
      ( Fila.hash_prev == Prev ->
          ( rb_lookup(Seq, Ev, PorSeq) ->
              ( p69_evento:verificar_hash(Ev), Ev.hash == Fila.hash ->
                  Presentes1 is Presentes + 1,
                  verificar_filas(Resto, PorSeq, Seq + 1, Fila.hash, Presentes1,
                    Eliminados, Seq, Resultado)
              ; Resultado = error(#{motivo: evento_alterado, seq: Seq})
              )
          ; Eliminados1 is Eliminados + 1,
            verificar_filas(Resto, PorSeq, Seq + 1, Fila.hash, Presentes,
              Eliminados1, Seq, Resultado)
          )
      ; Resultado = error(#{motivo: eslabon_roto, seq: Seq})
      )
  ; Resultado = error(#{motivo: secuencia_incompleta, esperado: SeqEsperado,
                        encontrado: Seq})
  ).
