%% API REST, UI estatica y router HTTP de la version Prolog.
:- module(p69_http, [
  iniciar/0,
  detener/0,
  router/1
]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_json)).
:- use_module(library(uri)).
:- use_module(library(lists)).
:- use_module(p69_util).
:- use_module(p69_config).
:- use_module(p69_json, [evento/2, resumen/1, error/3]).
:- use_module(p69_bitacora, [estado/1, ingresar/2, ingresar_lote/2, buscar/4]).
:- use_module(p69_ws).

:- dynamic inicio_http/1.

iniciar :-
  p69_config:get(puerto, Puerto),
  p69_config:get(num_aceptores, Aceptores),
  p69_util:now_micros(Ahora),
  assertz(inicio_http(Ahora)),
  http_server(router, [port(Puerto), workers(Aceptores)]).

detener :-
  p69_config:get(puerto, Puerto),
  catch(http_stop_server(Puerto, []), _, true).

router(Request) :-
  memberchk(request_uri(URI), Request),
  uri_components(URI, Partes),
  uri_data(path, Partes, Path),
  ( uri_data(search, Partes, Consulta), Consulta \== '' ->
      uri_query_components(Consulta, Busqueda)
  ; Busqueda = []
  ),
  Request1 = [request_path(Path), search(Busqueda) | Request],
  ( Path == '/' -> estatico(Request1)
  ; Path == "/api/salud" -> salud(Request1)
  ; Path == "/api/eventos" -> eventos(Request1)
  ; Path == "/api/dispositivos" -> dispositivos(Request1)
  ; Path == "/api/alertas" -> alertas(Request1)
  ; Path == "/api/bitacora/verificar" -> verificar(Request1)
  ; Path == "/metrics" -> metricas(Request1)
  ; Path == "/ws/eventos" -> p69_ws:handler(Request1)
  ; atom_concat('/api/dispositivos/', Id, Path) -> dispositivo(Id, Request1)
  ; estatico(Request1)
  ).

%% Salud

salud(Request) :-
  ( metodo(Request, get) ->
      p69_bitacora:estado({ok, E}),
      p69_bitacora:metricas({ok, M}),
      p69_util:now_micros(Ahora),
      ( inicio_http(Inicio) -> UptimeMs is (Ahora - Inicio) div 1000 ; UptimeMs = 0 ),
      responder_json(200, #{
        estado: "ok",
        version: "swi-prolog",
        otp: "SWI-Prolog",
        uptime_seg: UptimeMs,
        procesos: 1,
        memoria_total: 0,
        bitacora: E,
        metricas: M
      })
  ; responder_error(405, "metodo_no_permitido", "use GET")
  ).

%% Eventos: alta y consulta

eventos(Request) :-
  ( metodo(Request, get) -> eventos_get(Request)
  ; metodo(Request, post) -> eventos_post(Request)
  ; responder_error(405, "metodo_no_permitido", "use GET o POST")
  ).

eventos_post(Request) :-
  ( catch(http_read_json_dict(Request, Cuerpo), _, fail) ->
      ( is_list(Cuerpo) ->
          alta_lote(Cuerpo)
      ; get_dict(eventos, Cuerpo, Lista), is_list(Lista) ->
          alta_lote(Lista)
      ; get_dict(evento, Cuerpo, Evento), is_dict(Evento) ->
          alta_uno(Evento)
      ; is_dict(Cuerpo) ->
          alta_uno(Cuerpo)
      ; responder_error(400, "formato_invalido",
          "se esperaba un evento, un arreglo o {eventos: []}")
      )
  ; responder_error(400, "cuerpo_invalido", "cuerpo JSON invalido")
  ).

alta_uno(Evento) :-
  p69_bitacora:ingresar(Evento, Respuesta),
  ( Respuesta = {ok, Ev} ->
      p69_json:evento(Ev, Json),
      responder_json(201, #{evento: Json})
  ; Respuesta = {error, Motivo} ->
      responder_ingesta(Motivo)
  ; responder_error(500, "ingesta_fallo", "respuesta inesperada")
  ).

alta_lote([]) :-
  responder_error(400, "lote_vacio", "el lote no contiene eventos").
alta_lote(Eventos) :-
  p69_bitacora:ingresar_lote(Eventos, Respuesta),
  ( Respuesta = {ok, Evs} ->
      maplist(p69_json:evento, Evs, Json),
      length(Json, N),
      responder_json(201, #{recibidos: N, eventos: Json})
  ; Respuesta = {error, Motivo} ->
      responder_ingesta(Motivo)
  ; responder_error(500, "ingesta_fallo", "respuesta inesperada")
  ).

responder_ingesta(Motivo) :-
  ( Motivo = fuera_de_retencion ->
      responder_error(400, "fuera_de_retencion",
        "el evento es mas antiguo que la retencion configurada")
  ; Motivo = {evento_invalido, N, Detalle} ->
      format(string(Mensaje), "evento ~w: ~w", [N, Detalle]),
      responder_error(400, "evento_invalido", Mensaje)
  ; format(string(Mensaje), "~w", [Motivo]),
      responder_error(500, "ingesta_fallo", Mensaje)
  ).

eventos_get(Request) :-
  catch(parametros_eventos(Request, P), _, fail),
  P = p{desde: Desde0, hasta: Hasta0, limite: Limite, offset: Offset,
        edificio: Edificio, dispositivo: Disp, tipo: Tipo, persona: Persona},
  p69_util:now_micros(Ahora),
  ( nonvar(Hasta0) -> Hasta = Hasta0 ; Hasta = Ahora ),
  ( nonvar(Desde0) -> Desde = Desde0 ; Desde is Hasta - 3600 * 1000000 ),
  ( Desde =< Hasta ->
      filtros_eventos(Edificio, Disp, Tipo, Persona, Filtros),
      p69_bitacora:buscar(Desde, Hasta, Filtros, Respuesta),
      ( Respuesta = {ok, Lista} ->
          length(Lista, Total),
          drop(Offset, Lista, Resto),
          take(Limite, Resto, Paginados),
          maplist(p69_json:evento, Paginados, Json),
          responder_json(200, #{
            total: Total,
            desde: Desde,
            desde_iso: iso_o_null(Desde),
            hasta: Hasta,
            hasta_iso: iso_o_null(Hasta),
            limite: Limite,
            offset: Offset,
            eventos: Json
          })
      ; responder_error(500, "consulta_fallo", "no fue posible consultar")
      )
  ; responder_error(400, "rango_invalido", "desde debe ser menor o igual que hasta")
  ).

parametros_eventos(Request, P) :-
  http_parameters(Request, [
    desde(Desde, [integer, optional(true)]),
    hasta(Hasta, [integer, optional(true)]),
    limite(Limite0, [integer, default(1000)]),
    offset(Offset0, [integer, default(0)]),
    edificio(Edificio, [string, optional(true)]),
    dispositivo(Dispositivo, [string, optional(true)]),
    camara(Camara, [string, optional(true)]),
    tipo(Tipo, [string, optional(true)]),
    persona(Persona, [string, optional(true)])
  ], []),
  Limite = Limite0,
  Offset = Offset0,
  elegir_dispositivo(Dispositivo, Camara, Disp),
  P = p{desde: Desde, hasta: Hasta, limite: Limite, offset: Offset,
        edificio: Edificio, dispositivo: Disp, tipo: Tipo, persona: Persona}.

elegir_dispositivo(Dispositivo, _Camara, Dispositivo) :- nonvar(Dispositivo), !.
elegir_dispositivo(_, Camara, Camara) :- nonvar(Camara), !.
elegir_dispositivo(_, _, _).

filtros_eventos(Edificio, Dispositivo, Tipo, Persona, Filtros) :-
  F0 = #{},
  ( nonvar(Edificio) -> put_dict(edificio, F0, Edificio, F1) ; F1 = F0 ),
  ( nonvar(Dispositivo) -> put_dict(dispositivo, F1, Dispositivo, F2) ; F2 = F1 ),
  ( nonvar(Tipo) -> put_dict(tipo, F2, Tipo, F3) ; F3 = F2 ),
  ( nonvar(Persona) -> put_dict(persona, F3, Persona, Filtros) ; Filtros = F3 ).

%% Dispositivos

dispositivos(Request) :-
  ( metodo(Request, get) ->
      http_parameters(Request, [
        edificio(Edificio, [string, optional(true)]),
        estado(Estado, [string, optional(true)])
      ], []),
      p69_bitacora:dispositivos({ok, Devs}),
      include(coincide_dispositivo(Edificio, Estado), Devs, Filtrados),
      maplist(p69_json:dispositivo, Filtrados, Json),
      length(Json, N),
      responder_json(200, #{total: N, dispositivos: Json})
  ; responder_error(405, "metodo_no_permitido", "use GET")
  ).

coincide_dispositivo(Edificio, Estado, Dev) :-
  ( var(Edificio) -> true ; Dev.edificio == Edificio ),
  ( var(Estado) -> true
  ; p69_util:texto_atom(Estado, EstadoAtom),
    Dev.estado == EstadoAtom
  ).

dispositivo(IdAtom, Request) :-
  ( metodo(Request, get) ->
      atom_string(IdAtom, Id),
      http_parameters(Request, [edificio(Edificio, [string, optional(true)])], []),
      p69_bitacora:dispositivos({ok, Devs}),
      ( buscar_dev(Id, Edificio, Devs, Dev) ->
          p69_json:dispositivo(Dev, Json),
          responder_json(200, Json)
      ; responder_error(404, "no_encontrado", "dispositivo no encontrado")
      )
  ; responder_error(405, "metodo_no_permitido", "use GET")
  ).

buscar_dev(Id, Edificio, [Dev | Resto], Encontrado) :-
  ( Dev.id == Id,
    ( var(Edificio) ; Dev.edificio == Edificio ) ->
      Encontrado = Dev
  ; buscar_dev(Id, Edificio, Resto, Encontrado)
  ).

%% Alertas

alertas(Request) :-
  ( metodo(Request, get) ->
      p69_bitacora:dispositivos({ok, Devs}),
      include(en_alerta, Devs, Alertas),
      maplist(p69_json:dispositivo, Alertas, Json),
      length(Json, N),
      responder_json(200, #{total: N, alertas: Json})
  ; responder_error(405, "metodo_no_permitido", "use GET")
  ).

en_alerta(Dev) :-
  ( Dev.estado == alerta ; Dev.estado == falla ).

%% Verificacion

verificar(Request) :-
  ( metodo(Request, get) ->
      p69_bitacora:verificar(Respuesta),
      ( Respuesta = {ok, Resumen} ->
          responder_json(200, #{integridad: "ok", resumen: Resumen})
      ; Respuesta = {error, Detalle} ->
          responder_json(409, #{integridad: "falla", detalle: Detalle})
      ; responder_error(500, "verificacion_fallo", "respuesta inesperada")
      )
  ; responder_error(405, "metodo_no_permitido", "use GET")
  ).

%% Metricas Prometheus basicas

metricas(Request) :-
  ( metodo(Request, get) ->
      p69_bitacora:metricas({ok, M}),
      p69_bitacora:estado({ok, E}),
      format('Status: 200~nContent-type: text/plain; charset=utf-8~n~n'),
      format('# HELP p69_eventos_total Eventos aceptados por la bitacora~n'),
      format('# TYPE p69_eventos_total counter~n'),
      format('p69_eventos_total ~w~n', [M.eventos_ingresados]),
      format('# HELP p69_ingesta_rechazada_total Eventos rechazados~n'),
      format('# TYPE p69_ingesta_rechazada_total counter~n'),
      format('p69_ingesta_rechazada_total ~w~n', [M.ingesta_rechazada]),
      format('# HELP p69_alertas_reloj_total Eventos con reloj desfasado~n'),
      format('# TYPE p69_alertas_reloj_total counter~n'),
      format('p69_alertas_reloj_total ~w~n', [M.alertas_reloj]),
      format('# HELP p69_bitacora_seq Ultima secuencia registrada~n'),
      format('# TYPE p69_bitacora_seq gauge~n'),
      format('p69_bitacora_seq ~w~n', [E.seq])
  ; responder_error(405, "metodo_no_permitido", "use GET")
  ).

%% Estaticos

estatico(Request) :-
  memberchk(request_path(Path), Request),
  ruta_relativa(Path, Rel),
  ( ruta_valida(Rel) ->
      web_abs(WebDir),
      atomic_list_concat([WebDir, Rel], '/', Full),
      ( exists_file(Full) ->
          http_reply_file(Full, [unsafe(true)], Request)
      ; responder_texto(404, "no encontrado")
      )
  ; responder_texto(400, "ruta invalida")
  ).

ruta_relativa('/', "index.html") :- !.
ruta_relativa(Path, Rel) :-
  atom_string(Path, Texto0),
  ( sub_string(Texto0, 0, 1, _, "/") ->
      sub_string(Texto0, 1, _, 0, Texto)
  ; Texto = Texto0
  ),
  ( sub_string(Texto, _, 1, 0, "/") ->
      string_concat(Texto, "index.html", Rel)
  ; Rel = Texto
  ).

ruta_valida(Rel) :-
  \+ sub_string(Rel, _, _, _, ".."),
  \+ sub_string(Rel, _, _, _, "\\").

web_abs(WebDir) :-
  p69_config:get(web_dir, Configurado),
  absolute_file_name(Configurado, WebDir,
    [file_type(directory), access(read), file_errors(fail)]).

%% Utilidades de respuesta y consulta

metodo(Request, Metodo) :-
  memberchk(method(Metodo), Request).

responder_json(Status, Dict) :-
  reply_json_dict(Dict, [status(Status)]).

responder_error(Status, Codigo, Mensaje) :-
  p69_json:error(Codigo, Mensaje, Dict),
  responder_json(Status, Dict).

responder_texto(Status, Texto) :-
  format('Status: ~d~nContent-type: text/plain; charset=utf-8~n~n~s', [Status, Texto]).

iso_o_null(Micros) :-
  catch(p69_util:iso8601(Micros, Texto), _, Texto = null).

drop(0, Lista, Lista) :- !.
drop(_, [], []) :- !.
drop(N, [_ | Resto], Lista) :-
  N1 is N - 1,
  drop(N1, Resto, Lista).

take(0, _, []) :- !.
take(_, [], []) :- !.
take(N, [X | Resto], [X | Tomados]) :-
  N1 is N - 1,
  take(N1, Resto, Tomados).
