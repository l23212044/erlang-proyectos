%% Logica pura del evento: normalizacion, timestamps, reloj y cadena SHA-256.
%% No conoce HTTP ni almacenamiento.
:- module(p69_evento, [
  normalizar/2,
  ts_a_micros/2,
  preparar/6,
  canonico/2,
  hash/3,
  verificar_hash/1,
  estimar_offset/2,
  desfasado/3,
  mediana/2
]).

:- use_module(library(crypto)).
:- use_module(p69_util).

%% normalizar(+DictCrudo, -Evento)
normalizar(Raw, Ev) :-
  is_dict(Raw), !,
  texto_requerido(Raw, dispositivo_id, Disp),
  campo_requerido(Raw, tipo_dispositivo, TipoValor),
  tipo_dispositivo(TipoValor, TipoDisp),
  texto_requerido(Raw, edificio, Edificio),
  texto_requerido(Raw, tipo_evento, TipoEvento),
  campo_opcional(Raw, persona, null, PersonaValor),
  persona(PersonaValor, Persona),
  campo_requerido_ts(Raw, TsValor),
  ts_a_micros(TsValor, TsEvento),
  ts_recepcion(Raw, TsRecepcion),
  Ev = evento{
    dispositivo_id: Disp,
    tipo_dispositivo: TipoDisp,
    edificio: Edificio,
    tipo_evento: TipoEvento,
    persona: Persona,
    ts_evento: TsEvento,
    ts_recepcion: TsRecepcion
  }.
normalizar(Otro, _) :-
  throw(error(entrada_invalida(Otro), _)).

campo_requerido_ts(Raw, Valor) :-
  ( get_dict(ts_evento, Raw, V) -> Valor = V
  ; get_dict(ts, Raw, V2) -> Valor = V2
  ; throw(error(campo_requerido(ts_evento), _))
  ).

ts_recepcion(Raw, Micros) :-
  ( get_dict(ts_recepcion, Raw, V) ->
      ts_a_micros(V, Micros)
  ; p69_util:now_micros(Micros)
  ).

campo_requerido(Raw, Nombre, Valor) :-
  ( get_dict(Nombre, Raw, V) -> Valor = V
  ; throw(error(campo_requerido(Nombre), _))
  ).

campo_opcional(Raw, Nombre, Default, Valor) :-
  ( get_dict(Nombre, Raw, V) -> Valor = V ; Valor = Default ).

texto_requerido(Raw, Nombre, Texto) :-
  campo_requerido(Raw, Nombre, Valor),
  texto(Valor, Texto),
  ( Texto == "" -> throw(error(campo_vacio(Nombre), _)) ; true ).

texto(Valor, Texto) :-
  ( string(Valor) -> Texto = Valor
  ; atom(Valor) -> atom_string(Valor, Texto)
  ; integer(Valor) -> number_string(Valor, Texto)
  ; throw(error(valor_no_textual(Valor), _))
  ).

tipo_dispositivo(Valor, puerta) :-
  ( Valor == "puerta" ; Valor == puerta ), !.
tipo_dispositivo(Valor, camara) :-
  ( Valor == "camara" ; Valor == camara ), !.
tipo_dispositivo(Valor, _) :-
  throw(error(tipo_dispositivo_invalido(Valor), _)).

persona(null, null) :- !.
persona(undefined, null) :- !.
persona("", null) :- !.
persona(Valor, Texto) :-
  texto(Valor, Texto).

ts_a_micros(Ts, Micros) :-
  ( integer(Ts) ->
      normalizar_escala(Ts, Micros)
  ; float(Ts) ->
      normalizar_escala_float(Ts, Micros)
  ; string(Ts) ->
      ts_texto(Ts, Micros)
  ; atom(Ts) ->
      atom_string(Ts, Cadena), ts_texto(Cadena, Micros)
  ; throw(error(ts_invalido(Ts), _))
  ).

normalizar_escala(Ts, Micros) :-
  ( Ts < 100000000000 -> Micros is Ts * 1000000
  ; Ts < 100000000000000 -> Micros is Ts * 1000
  ; Micros = Ts
  ).

normalizar_escala_float(Ts, Micros) :-
  ( abs(Ts) < 100000000000 -> Micros is round(Ts * 1000000)
  ; abs(Ts) < 100000000000000 -> Micros is round(Ts * 1000)
  ; Micros is round(Ts)
  ).

ts_texto(Cadena, Micros) :-
  ( catch(number_string(Numero, Cadena), _, fail) ->
      ts_a_micros(Numero, Micros)
  ; catch(parse_time(Cadena, Stamp), _, fail) ->
      Micros is round(Stamp * 1000000)
  ; throw(error(ts_invalido(Cadena), _))
  ).

preparar(Ev0, Seq, HashPrev, Offset, Desfasado, Ev) :-
  TsCorregido is Ev0.ts_evento + Offset,
  Ev1 = Ev0.put(_{
    seq: Seq,
    ts_corregido: TsCorregido,
    offset_reloj: Offset,
    desfasado: Desfasado,
    hash_prev: HashPrev
  }),
  hash(HashPrev, Ev1, Hash),
  Ev = Ev1.put(hash, Hash).

%% Bytes exactos que usa Erlang: prefijo hex crudo + canonico con hash_prev crudo.
canonico(Ev, Bytes) :-
  valor_persona(Ev.persona, Persona),
  ( Ev.desfasado == true -> Desf = true ; Desf = false ),
  format(string(Prefijo),
    'seq=~w|disp=~w|tdisp=~w|edif=~w|tevento=~w|persona=~w|tse=~w|tsc=~w|tsr=~w|offset=~w|desf=~w|prev=',
    [Ev.seq, Ev.dispositivo_id, Ev.tipo_dispositivo, Ev.edificio,
     Ev.tipo_evento, Persona, Ev.ts_evento, Ev.ts_corregido,
     Ev.ts_recepcion, Ev.offset_reloj, Desf]),
  text_bytes(Prefijo, PrefijoBytes),
  hex_a_bytes(Ev.hash_prev, PrevBytes),
  append(PrefijoBytes, PrevBytes, Bytes).

valor_persona(null, "-") :- !.
valor_persona(undefined, "-") :- !.
valor_persona(Valor, Valor).

hash(HashPrev, Ev, HashHex) :-
  canonico(Ev, CanonBytes),
  hex_a_bytes(HashPrev, PrevBytes),
  append(PrevBytes, CanonBytes, Datos),
  string_codes(DatosTexto, Datos),
  crypto_data_hash(DatosTexto, HashAtom, [algorithm(sha256), encoding(octet)]),
  atom_string(HashAtom, HashMin),
  string_upper(HashMin, HashHex).

verificar_hash(Ev) :-
  hash(Ev.hash_prev, Ev, Calculado),
  Calculado == Ev.hash.

estimar_offset([], 0).
estimar_offset(Deltas, Offset) :-
  mediana(Deltas, Offset).

mediana([], 0).
mediana(Lista, Mediana) :-
  msort(Lista, Ordenada),
  length(Ordenada, N),
  Mitad is N div 2,
  Indice is Mitad + 1,
  ( N rem 2 =:= 1 ->
      nth1(Indice, Ordenada, Mediana)
  ; nth1(Mitad, Ordenada, A),
    nth1(Indice, Ordenada, B),
    Mediana is (A + B) div 2
  ).

desfasado(Offset, Umbral, true) :- abs(Offset) > Umbral, !.
desfasado(_, _, false).
