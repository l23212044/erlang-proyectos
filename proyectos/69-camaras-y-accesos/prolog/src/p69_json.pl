%% Conversion de terminos internos al contrato JSON que consume la UI.
:- module(p69_json, [
  evento/2,
  dispositivo/2,
  resumen/1,
  error/3
]).

:- use_module(library(lists)).
:- use_module(p69_util).

evento(Ev, D) :-
  persona_json(Ev.persona, Persona),
  iso_seguro(Ev.ts_evento, TsEventoIso),
  iso_seguro(Ev.ts_corregido, TsCorregidoIso),
  iso_seguro(Ev.ts_recepcion, TsRecepcionIso),
  texto_json(Ev.dispositivo_id, Disp),
  texto_json(Ev.tipo_dispositivo, TipoDisp),
  texto_json(Ev.edificio, Edificio),
  texto_json(Ev.tipo_evento, TipoEvento),
  D = #{
    seq: Ev.seq,
    dispositivo_id: Disp,
    tipo_dispositivo: TipoDisp,
    edificio: Edificio,
    tipo_evento: TipoEvento,
    persona: Persona,
    ts_evento: Ev.ts_evento,
    ts_evento_iso: TsEventoIso,
    ts_corregido: Ev.ts_corregido,
    ts_corregido_iso: TsCorregidoIso,
    ts_recepcion: Ev.ts_recepcion,
    ts_recepcion_iso: TsRecepcionIso,
    offset_reloj: Ev.offset_reloj,
    desfasado: Ev.desfasado,
    hash_prev: Ev.hash_prev,
    hash: Ev.hash
  }.

dispositivo(Dev, D) :-
  texto_json(Dev.id, Id),
  texto_json(Dev.tipo, Tipo),
  texto_json(Dev.edificio, Edificio),
  texto_json(Dev.estado, Estado),
  iso_seguro(Dev.ultimo_latido, UltimoIso),
  contadores_json(Dev.contadores, Contadores),
  maplist(evento, Dev.recientes, Recientes),
  D = #{
    id: Id,
    tipo: Tipo,
    edificio: Edificio,
    estado: Estado,
    ultimo_latido: Dev.ultimo_latido,
    ultimo_latido_iso: UltimoIso,
    offset_segundos: Dev.offset_segundos,
    desfasado: Dev.desfasado,
    contadores: Contadores,
    recientes: Recientes
  }.

resumen(D) :-
  ( catch(resumen_(D), _, resumen_vacio(D)) ).

resumen_(_{
  tipo: "resumen",
  ts: TsIso,
  seq: Seq,
  cola_ingesta: 0,
  dispositivos: NDevs,
  camaras_offline: CamarasOffline,
  puertas_offline: PuertasOffline,
  en_alerta: EnAlerta
}) :-
  p69_bitacora:estado({ok, E}),
  p69_bitacora:dispositivos({ok, Devs}),
  p69_util:now_micros(Ahora),
  iso_seguro(Ahora, TsIso),
  Seq = E.seq,
  length(Devs, NDevs),
  contar_estado(Devs, camara, falla, CamarasOffline),
  contar_estado(Devs, puerta, falla, PuertasOffline),
  contar_estado(Devs, todos, alerta, EnAlerta).

resumen_vacio(_{
  tipo: "resumen",
  ts: TsIso,
  seq: 0,
  cola_ingesta: 0,
  dispositivos: 0,
  camaras_offline: 0,
  puertas_offline: 0,
  en_alerta: 0
}) :-
  p69_util:now_micros(Ahora),
  iso_seguro(Ahora, TsIso).

error(Codigo, Mensaje, _{
  error: _{
    codigo: Codigo,
    mensaje: Mensaje
  }
}).

contar_estado(Devs, Tipo, Estado, N) :-
  include(coincide_tipo_estado(Tipo, Estado), Devs, Filtrados),
  length(Filtrados, N).

coincide_tipo_estado(todos, Estado, Dev) :-
  Dev.estado == Estado.
coincide_tipo_estado(Tipo, Estado, Dev) :-
  Dev.tipo == Tipo,
  Dev.estado == Estado.

contadores_json(Contadores0, Contadores) :-
  dict_pairs(Contadores0, _, Pares),
  maplist(contador_par, Pares, ParesJson),
  dict_pairs(Contadores, _, ParesJson).

contador_par(Clave0-Valor, Clave-Valor) :-
  p69_util:texto_atom(Clave0, Clave).

persona_json(null, null) :- !.
persona_json(undefined, null) :- !.
persona_json(Persona, Texto) :-
  p69_util:string_value(Persona, Texto).

texto_json(Valor, Texto) :-
  p69_util:string_value(Valor, Texto).

iso_seguro(Micros, Texto) :-
  catch(p69_util:iso8601(Micros, Texto), _, Texto = null).
