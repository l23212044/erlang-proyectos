%% Utilidades compartidas: tiempo, bytes y hexadecimal.
:- module(p69_util, [
  now_micros/1,
  text_bytes/2,
  hex_a_bytes/2,
  bytes_a_hex/2,
  iso8601/2,
  pad_zero/3,
  atom_or_string/2,
  string_value/2,
  texto_atom/2
]).

:- use_module(library(utf8)).

now_micros(Micros) :-
  get_time(Segundos),
  Micros is round(Segundos * 1000000).

%% Convierte un texto Prolog (string o atomo) a bytes UTF-8.
text_bytes(Texto, Bytes) :-
  string_value(Texto, Cadena),
  string_codes(Cadena, Codigos),
  phrase(utf8_codes(Codigos), Bytes).

string_value(Valor, Cadena) :-
  ( string(Valor) -> Cadena = Valor
  ; atom(Valor) -> atom_string(Valor, Cadena)
  ; number(Valor) -> number_string(Valor, Cadena)
  ; throw(error(valor_no_textual(Valor), _))
  ).

texto_atom(Valor, Atom) :-
  string_value(Valor, Cadena),
  atom_string(Atom, Cadena).

atom_or_string(Valor, Atom) :-
  ( atom(Valor) -> Atom = Valor
  ; string(Valor) -> atom_string(Atom, Valor)
  ; throw(error(valor_no_textual(Valor), _))
  ).

hex_a_bytes(Hex, Bytes) :-
  string_value(Hex, Cadena),
  string_codes(Cadena, Codigos),
  hex_pares(Codigos, Bytes).

hex_pares([], []).
hex_pares([A, B | Resto], [Valor | Valores]) :-
  hex_digito(A, Alto),
  hex_digito(B, Bajo),
  Valor is Alto * 16 + Bajo,
  hex_pares(Resto, Valores).
hex_pares(_, _) :-
  throw(error(hex_invalido, _)).

hex_digito(C, V) :-
  C >= 0'0, C =< 0'9, !, V is C - 0'0.
hex_digito(C, V) :-
  C >= 0'a, C =< 0'f, !, V is 10 + C - 0'a.
hex_digito(C, V) :-
  C >= 0'A, C =< 0'F, !, V is 10 + C - 0'A.

bytes_a_hex(Bytes, Hex) :-
  maplist(byte_hex, Bytes, Partes),
  atomics_to_string(Partes, Hex).

byte_hex(Byte, Texto) :-
  Alto is Byte >> 4,
  Bajo is Byte /\ 15,
  hex_char(Alto, C1),
  hex_char(Bajo, C2),
  string_codes(Texto, [C1, C2]).

hex_char(N, C) :- N < 10, !, C is 0'0 + N.
hex_char(N, C) :- C is 0'A + N - 10.

%% ISO-8601 en UTC con microsegundos, igual que la API Erlang.
iso8601(Micros, Texto) :-
  Segundos is Micros div 1000000,
  Fraccion is Micros mod 1000000,
  stamp_date_time(Segundos, Fecha, 'UTC'),
  format_time(string(Base), '%Y-%m-%dT%H:%M:%S', Fecha),
  pad_zero(Fraccion, 6, FraccionTexto),
  atomic_list_concat([Base, '.', FraccionTexto, 'Z'], Texto).

pad_zero(Numero, Ancho, Texto) :-
  number_string(Numero, Crudo),
  string_length(Crudo, Largo),
  Faltan is max(0, Ancho - Largo),
  length(Ceros, Faltan),
  maplist([X]>>(X = 0'0), Ceros),
  string_codes(CerosTexto, Ceros),
  string_concat(CerosTexto, Crudo, Texto).
