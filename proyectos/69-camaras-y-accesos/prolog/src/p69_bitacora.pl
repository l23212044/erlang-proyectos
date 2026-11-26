%% Nucleo de la bitacora en SWI-Prolog. Un hilo dueno del estado serializa la
%% ingesta y las consultas. El WAL se escribe antes de confirmar el ACK.
:- module(p69_bitacora, [
  start_link/0,
  ingresar/2,
  ingresar_lote/2,
  buscar/4,
  verificar/1,
  retener/2,
  estado/1,
  dispositivos/1,
  dispositivo/3,
  eventos_desde/4,
  metricas/1
]).

:- use_module(library(rbtrees)).
:- use_module(library(lists)).
:- use_module(p69_util).
:- use_module(p69_evento).
:- use_module(p69_almacen, [insertar/3, buscar/6, plegar/4, quitar_antes/4, seqs_antes/3]).
:- use_module(p69_cadena).
:- use_module(p69_reloj, [agregar/6, offset/2, desfasado/2, muestras/2]).
:- use_module(p69_sitios, [actualizar/4, listar/4, estado_calculado/4]).
:- use_module(p69_wal, [abrir/2, agregar/2, agregar_lote/2]).
:- use_module(p69_config).
:- use_module(p69_pub, [publicar/1]).

:- dynamic bitacora_thread/1.

start_link :-
  thread_create(iniciar, Id, [detached(true)]),
  assertz(bitacora_thread(Id)),
  esperar_bitacora(200).

esperar_bitacora(0) :- !, throw(error(bitacora_no_inicia, _)).
esperar_bitacora(N) :-
  ( catch(llamar(ping, 100, pong), _, fail) -> true
  ; sleep(0.05), N1 is N - 1, esperar_bitacora(N1)
  ).

iniciar :-
  estado_inicial(E0),
  recuperar(E0, E1),
  loop(E1).

estado_inicial(E) :-
  p69_config:get(datos_dir, Dir),
  p69_config:get(segmento_segundos, Segundos),
  p69_config:get(umbral_reloj_seg, UmbralSeg),
  p69_config:get(reloj_max_muestras, MaxMuestras),
  p69_wal:abrir(Dir, Wal),
  p69_almacen:nuevo(Almacen),
  rb_empty(Ledger),
  rb_empty(PorSeq),
  p69_sitios:nuevo(Sitios),
  p69_util:now_micros(Ahora),
  metricas_nuevas(Metricas),
  E = bitacora{
    dir: Dir,
    wal: Wal,
    segundos: Segundos,
    umbral_reloj: UmbralSeg * 1000000,
    max_muestras: MaxMuestras,
    seq: 0,
    last_hash: "",
    almacen: Almacen,
    ledger: Ledger,
    por_seq: PorSeq,
    sitios: Sitios,
    checkpoints: [],
    cp_seq: 0,
    last_cp_hash: "",
    relojes: #{},
    recientes: [],
    metricas: Metricas,
    inicio: Ahora
  }.

metricas_nuevas(metricas{
  eventos_ingresados: 0,
  ingesta_aceptada: 0,
  ingesta_rechazada: 0,
  alertas_reloj: 0,
  consultas: 0,
  consulta_latencia_total_us: 0,
  por_dispositivo: #{},
  por_tipo: #{}
}).

loop(E) :-
  thread_get_message(Mensaje),
  ( Mensaje = {From, Peticion} ->
      ( catch(manejar(Peticion, E, Reply, E2), Error,
          ( Reply = {error, Error}, E2 = E )) ->
          thread_send_message(From, Reply),
          loop(E2)
      ; thread_send_message(From, {error, fallo_interno}),
        loop(E)
      )
  ; loop(E)
  ).

llamar(Peticion, Timeout, Respuesta) :-
  ( bitacora_thread(Id) -> true ; throw(error(bitacora_no_disponible, _)) ),
  message_queue_create(Q),
  catch(thread_send_message(Id, {Q, Peticion}), _, throw(error(bitacora_no_disponible, _))),
  catch(thread_get_message(Q, Respuesta, [timeout(Timeout)]),
    error(timeout, _), Respuesta = {error, timeout}),
  message_queue_destroy(Q).

%% API publica

ingresar(Evento, Respuesta) :-
  llamar({ingresar, Evento}, 30000, Respuesta).

ingresar_lote(Eventos, Respuesta) :-
  llamar({ingresar_lote, Eventos}, 120000, Respuesta).

buscar(Desde, Hasta, Filtros, Respuesta) :-
  llamar({buscar, Desde, Hasta, Filtros}, 60000, Respuesta).

verificar(Respuesta) :-
  llamar(verificar, 60000, Respuesta).

retener(Corte, Respuesta) :-
  llamar({retener, Corte}, 120000, Respuesta).

estado(Respuesta) :-
  llamar(estado, 30000, Respuesta).

dispositivos(Respuesta) :-
  llamar(dispositivos, 30000, Respuesta).

dispositivo(Edificio, Id, Respuesta) :-
  llamar({dispositivo, Edificio, Id}, 30000, Respuesta).

eventos_desde(Ultimo, Max, Eventos, Nuevo) :-
  llamar({eventos_desde, Ultimo, Max}, 30000, {ok, Eventos, Nuevo}).

metricas(Respuesta) :-
  llamar(metricas, 30000, Respuesta).

%% Manejo de peticiones

manejar(ping, E, pong, E).
manejar({ingresar, Crudo}, E0, Reply, E) :-
  ( procesar_ingesta([Crudo], E0, Resultado, E1) ->
      ( Resultado = {ok, [Ev]} -> Reply = {ok, Ev} ; Reply = Resultado ),
      E = E1
  ; Reply = {error, ingesta_fallida}, E = E0
  ).
manejar({ingresar_lote, Lista}, E0, Reply, E) :-
  procesar_ingesta(Lista, E0, Reply, E).
manejar({buscar, Desde, Hasta, Filtros}, E0, Reply, E) :-
  ( Desde =< Hasta ->
      p69_util:now_micros(T0),
      p69_almacen:buscar(E0.almacen, Desde, Hasta, Filtros, E0.seq, Eventos),
      p69_util:now_micros(T1),
      Duracion is T1 - T0,
      inc(E0.metricas, consultas, M1),
      inc(M1, consulta_latencia_total_us, Duracion, Metricas),
      E = E0.put(metricas, Metricas),
      Reply = {ok, Eventos}
  ; Reply = {error, rango_invalido}, E = E0
  ).
manejar(verificar, E, Reply, E) :-
  p69_cadena:verificar(E.ledger, E.por_seq, E.checkpoints, Resultado),
  ( Resultado = ok(Resumen) -> Reply = {ok, Resumen}
  ; Resultado = error(Detalle) -> Reply = {error, Detalle}
  ).
manejar(estado, E, Reply, E) :-
  ahora(Ahora),
  timeout_dispositivo(Timeout),
  p69_sitios:listar(E.sitios, Ahora, Timeout, Devs),
  segmentos_activos(E, Segmentos),
  length(Devs, NDevs),
  conteo_dict(E.relojes, NRelojes),
  Reply = {ok, #{
    seq: E.seq,
    ultimo_hash: E.last_hash,
    cp_seq: E.cp_seq,
    segmentos: Segmentos,
    pines: 0,
    relojes: NRelojes,
    cola_ingesta: 0,
    dispositivos: NDevs
  }}.
manejar(dispositivos, E, Reply, E) :-
  ahora(Ahora),
  timeout_dispositivo(Timeout),
  p69_sitios:listar(E.sitios, Ahora, Timeout, Devs),
  Reply = {ok, Devs}.
manejar({dispositivo, Edificio, Id}, E, Reply, E) :-
  ( p69_sitios:buscar(E.sitios, Edificio, Id, Dev0) ->
      ahora(Ahora),
      timeout_dispositivo(Timeout),
      p69_sitios:estado_calculado(Dev0, Ahora, Timeout, Dev),
      Reply = {ok, Dev}
  ; Reply = {error, no_encontrado}
  ).
manejar({eventos_desde, Ultimo, Max}, E, Reply, E) :-
  nuevos_recientes(E.recientes, Ultimo, Max, Eventos, Nuevo),
  Reply = {ok, Eventos, Nuevo}.
manejar(metricas, E, Reply, E) :-
  Reply = {ok, E.metricas}.
manejar({retener, Corte}, E0, Reply, E) :-
  ( retener_ahora(Corte, E0, Resultado, E1) ->
      Reply = Resultado, E = E1
  ; Reply = {error, retencion_fallida}, E = E0
  ).
manejar(_, E, {error, no_soportado}, E).

procesar_ingesta([], E, {error, lote_vacio}, E) :- !.
procesar_ingesta(Crudos, E0, Resultado, E) :-
  catch(normalizar_todos(Crudos, 1, Norm0), Error, Norm0 = error(Error)),
  ( Norm0 = error(ErrorNorm) ->
      Resultado = {error, ErrorNorm}, E = E0
  ; Norm0 = Norm,
    corte_retencion(Corte),
    ( tiene_fuera_retencion(Norm, Corte) ->
        Resultado = {error, fuera_de_retencion}, E = E0
    ; preparar_todos(Norm, E0, Preparados, Relojes, _Seq, _Hash),
      maplist(registro_evento, Preparados, Registros),
      ( catch(p69_wal:agregar_lote(E0.wal, Registros), _, fail) ->
          insertar_todos(Preparados, E0, E1),
          E = E1.put(relojes, Relojes),
          Resultado = {ok, Preparados}
      ; Resultado = {error, wal_escritura}, E = E0
      )
    )
  ).

normalizar_todos([], _N, []).
normalizar_todos([Crudo | Resto], N, [Ev | Evs]) :-
  catch(p69_evento:normalizar(Crudo, Ev), Error,
    throw(error(evento_invalido(N, Error), _))),
  N1 is N + 1,
  normalizar_todos(Resto, N1, Evs).

tiene_fuera_retencion([], _Corte) :- fail.
tiene_fuera_retencion([Ev | _], Corte) :- Ev.ts_evento < Corte, !.
tiene_fuera_retencion([_ | Resto], Corte) :- tiene_fuera_retencion(Resto, Corte).

corte_retencion(Corte) :-
  p69_config:get(retencion_dias, Dias),
  ( Dias =:= 0 -> Corte = 0
  ; ahora(T), Corte is T - Dias * 86400 * 1000000
  ).

preparar_todos(Evs, E, Preparados, Relojes, Seq, Hash) :-
  preparar_todos_(Evs, E.seq, E.last_hash, E.relojes, E.max_muestras,
    E.umbral_reloj, Preparados, Relojes, Seq, Hash).

preparar_todos_([], Seq, Hash, Relojes, _Max, _Umbral, [], Relojes, Seq, Hash).
preparar_todos_([Ev0 | Resto], Seq0, Hash0, Relojes0, Max, Umbral,
    [Ev | Evs], Relojes, Seq, Hash) :-
  Seq1 is Seq0 + 1,
  Disp = Ev0.dispositivo_id,
  p69_util:texto_atom(Disp, DispKey),
  ( get_dict(DispKey, Relojes0, Reloj0) -> true ; p69_reloj:nuevo(Reloj0) ),
  p69_reloj:agregar(Reloj0, Ev0.ts_evento, Ev0.ts_recepcion,
    Max, Umbral, Reloj1),
  p69_reloj:offset(Reloj1, Offset),
  p69_reloj:desfasado(Reloj1, Desfasado),
  p69_evento:preparar(Ev0, Seq1, Hash0, Offset, Desfasado, Ev),
  put_dict(DispKey, Relojes0, Reloj1, Relojes1),
  preparar_todos_(Resto, Seq1, Ev.hash, Relojes1, Max, Umbral,
    Evs, Relojes, Seq, Hash).

insertar_todos([], E, E).
insertar_todos([Ev | Resto], E0, E) :-
  p69_almacen:insertar(E0.almacen, Ev, Almacen),
  rb_insert(E0.por_seq, Ev.seq, Ev, PorSeq),
  Fila = #{hash: Ev.hash, hash_prev: Ev.hash_prev},
  rb_insert(E0.ledger, Ev.seq, Fila, Ledger),
  ahora(Ahora),
  p69_sitios:actualizar(E0.sitios, Ev, Ahora, Sitios),
  tomar(200, [Ev | E0.recientes], Recientes),
  inc(E0.metricas, eventos_ingresados, M0),
  inc(M0, ingesta_aceptada, M1),
  inc_por(M1, por_dispositivo, Ev.dispositivo_id, M2),
  inc_por(M2, por_tipo, Ev.tipo_evento, M3),
  ( Ev.desfasado == true -> inc(M3, alertas_reloj, M4) ; M4 = M3 ),
  E1 = E0.put(_{
    almacen: Almacen,
    por_seq: PorSeq,
    ledger: Ledger,
    sitios: Sitios,
    seq: Ev.seq,
    last_hash: Ev.hash,
    recientes: Recientes,
    metricas: M4
  }),
  insertar_todos(Resto, E1, E).

nuevos_recientes(Recientes, Ultimo, Max, Eventos, Nuevo) :-
  nuevos_rec(Recientes, Ultimo, Max, [], Acumulados),
  reverse(Acumulados, Eventos),
  ( Eventos = [] -> Nuevo = Ultimo
  ; last(Eventos, UltimoEv), Nuevo = UltimoEv.seq
  ).

nuevos_rec(_, _, 0, Acc, Acc) :- !.
nuevos_rec([], _, _, Acc, Acc).
nuevos_rec([Ev | Resto], Ultimo, Max, Acc, Eventos) :-
  ( Ev.seq > Ultimo ->
      Max1 is Max - 1,
      nuevos_rec(Resto, Ultimo, Max1, [Ev | Acc], Eventos)
  ; nuevos_rec(Resto, Ultimo, Max, Acc, Eventos)
  ).

%% Retencion

retener_ahora(Corte, E0, {ok, Resultado}, E) :-
  p69_almacen:seqs_antes(E0.almacen, Corte, Seqs0),
  msort(Seqs0, Seqs),
  ( Seqs = [] ->
      Resultado = [], E = E0
  ; p69_almacen:quitar_antes(E0.almacen, Corte, Almacen, _),
    borrar_seqs(Seqs, E0.por_seq, PorSeq),
    length(Seqs, Count),
    [Primero | _] = Seqs,
    last(Seqs, Ultimo),
    CpSeq is E0.cp_seq + 1,
    ahora(Ahora),
    Segmento is Corte div (E0.segundos * 1000000),
    CpBase = checkpoint{
      cp_seq: CpSeq,
      tipo: retencion,
      segmento: Segmento,
      primer_seq: Primero,
      ultimo_seq: Ultimo,
      eventos: Count,
      hash_ultimo_evento: E0.last_hash,
      hash_prev: E0.last_cp_hash,
      ts: Ahora,
      corte_ts: Corte,
      eliminados: Seqs
    },
    p69_cadena:hash_checkpoint(E0.last_cp_hash, CpBase, Hash),
    Cp = CpBase.put(hash, Hash),
    ( catch(p69_wal:agregar(E0.wal, #{tipo: checkpoint, checkpoint: Cp}), _, fail) ->
        inc(E0.metricas, retencion_eventos, Count, Metricas),
        E = E0.put(_{
          almacen: Almacen,
          por_seq: PorSeq,
          checkpoints: [Cp | E0.checkpoints],
          cp_seq: CpSeq,
          last_cp_hash: Hash,
          metricas: Metricas
        }),
        Resultado = [{retencion, ok}]
    ; fail
    )
  ).

borrar_seqs([], Arbol, Arbol).
borrar_seqs([Seq | Resto], Arbol0, Arbol) :-
  ( rb_delete(Arbol0, Seq, Arbol1) -> true ; Arbol1 = Arbol0 ),
  borrar_seqs(Resto, Arbol1, Arbol).

%% Recuperacion

recuperar(E0, E) :-
  p69_wal:recuperar(E0.dir, Terminos),
  recuperar_terminos(Terminos, E0, E).

recuperar_terminos([], E, E).
recuperar_terminos([Termino | Resto], E0, E) :-
  ( Termino = #{tipo: evento, evento: Ev} ->
      insertar_recuperado(Ev, E0, E1)
  ; Termino = #{tipo: checkpoint, checkpoint: Cp} ->
      aplicar_checkpoint(Cp, E0, E1)
  ; E1 = E0
  ),
  recuperar_terminos(Resto, E1, E).

insertar_recuperado(Ev, E0, E) :-
  p69_almacen:insertar(E0.almacen, Ev, Almacen),
  rb_insert(E0.por_seq, Ev.seq, Ev, PorSeq),
  Fila = #{hash: Ev.hash, hash_prev: Ev.hash_prev},
  rb_insert(E0.ledger, Ev.seq, Fila, Ledger),
  ahora(Ahora),
  p69_sitios:actualizar(E0.sitios, Ev, Ahora, Sitios),
  tomar(200, [Ev | E0.recientes], Recientes),
  Disp = Ev.dispositivo_id,
  p69_util:texto_atom(Disp, DispKey),
  ( get_dict(DispKey, E0.relojes, R0) -> true ; p69_reloj:nuevo(R0) ),
  p69_reloj:agregar(R0, Ev.ts_evento, Ev.ts_recepcion,
    E0.max_muestras, E0.umbral_reloj, R1),
  put_dict(DispKey, E0.relojes, R1, Relojes),
  ( Ev.seq > E0.seq ->
      Seq = Ev.seq, LastHash = Ev.hash
  ; Seq = E0.seq, LastHash = E0.last_hash
  ),
  E = E0.put(_{
    almacen: Almacen,
    por_seq: PorSeq,
    ledger: Ledger,
    sitios: Sitios,
    relojes: Relojes,
    recientes: Recientes,
    seq: Seq,
    last_hash: LastHash
  }).

aplicar_checkpoint(Cp, E0, E) :-
  ( get_dict(corte_ts, Cp, Corte) -> true ; Corte = 0 ),
  p69_almacen:quitar_antes(E0.almacen, Corte, Almacen, _),
  get_dict(eliminados, Cp, Seqs),
  borrar_seqs(Seqs, E0.por_seq, PorSeq),
  get_dict(cp_seq, Cp, CpSeq),
  get_dict(hash, Cp, Hash),
  ( CpSeq > E0.cp_seq ->
      LastCp = Hash, CpSeqFinal = CpSeq
  ; LastCp = E0.last_cp_hash, CpSeqFinal = E0.cp_seq
  ),
  get_dict(ultimo_seq, Cp, UltimoSeq),
  ( E0.seq =< UltimoSeq ->
      get_dict(hash_ultimo_evento, Cp, LastHash)
  ; LastHash = E0.last_hash
  ),
  E = E0.put(_{
    almacen: Almacen,
    por_seq: PorSeq,
    checkpoints: [Cp | E0.checkpoints],
    cp_seq: CpSeqFinal,
    last_cp_hash: LastCp,
    last_hash: LastHash
  }).

%% Auxiliares

segmentos_activos(E, Segmentos) :-
  rb_size(E.por_seq, N),
  ( N =:= 0 -> Segmentos = 0 ; Segmentos = 1 ).

timeout_dispositivo(Timeout) :-
  p69_config:get(dispositivo_timeout_seg, Seg),
  Timeout is Seg * 1000000.

conteo_dict(Dict, N) :-
  dict_pairs(Dict, _, Pares),
  length(Pares, N).

ahora(T) :- p69_util:now_micros(T).

inc(M, Clave, M2) :-
  inc(M, Clave, 1, M2).

inc(M, Clave, Delta, M2) :-
  ( get_dict(Clave, M, V) -> V1 is V + Delta ; V1 = Delta ),
  put_dict(Clave, M, V1, M2).

inc_por(M, Categoria, Clave0, M2) :-
  p69_util:texto_atom(Clave0, Clave),
  ( get_dict(Categoria, M, Sub0) -> true ; Sub0 = #{} ),
  ( get_dict(Clave, Sub0, V) -> V1 is V + 1 ; V1 = 1 ),
  put_dict(Clave, Sub0, V1, Sub),
  put_dict(Categoria, M, Sub, M2).

registro_evento(Ev, #{tipo: evento, evento: Ev}).

tomar(0, _, []) :- !.
tomar(_, [], []) :- !.
tomar(N, [X | Resto], [X | Tomados]) :-
  N1 is N - 1,
  tomar(N1, Resto, Tomados).
