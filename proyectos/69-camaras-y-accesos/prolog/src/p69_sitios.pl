%% Estado agregado de dispositivos (puertas y camaras). En esta version no hay
%% un proceso por dispositivo: la bitacora actualiza un mapa puro y la API lo
%% consulta. Conserva la forma que espera la UI.
:- module(p69_sitios, [
  nuevo/1,
  actualizar/4,
  listar/4,
  buscar/4,
  estado_calculado/4
]).

:- use_module(p69_util).

nuevo(#{dispositivos: #{}}).

actualizar(Estado0, Ev, Ahora, Estado) :-
  get_dict(dispositivos, Estado0, Mapa0),
  Edificio = Ev.edificio,
  Id = Ev.dispositivo_id,
  clave_dispositivo(Edificio, Id, Clave),
  ( get_dict(Clave, Mapa0, Dev0) -> true
  ; Dev0 = dispositivo{
      id: Id,
      tipo: Ev.tipo_dispositivo,
      edificio: Edificio,
      estado: ok,
      ultimo_latido: Ahora,
      offset: 0,
      desfasado: false,
      contadores: #{},
      recientes: []
    }
  ),
  estado_por_evento(Ev, NuevoEstado),
  get_dict(contadores, Dev0, Contadores0),
  map_update(Contadores0, Ev.tipo_evento, 1, Contadores),
  get_dict(recientes, Dev0, Recientes0),
  tomar(20, [Ev | Recientes0], Recientes),
  Dev = Dev0.put(_{
    tipo: Ev.tipo_dispositivo,
    edificio: Edificio,
    ultimo_latido: Ev.ts_recepcion,
    offset: Ev.offset_reloj,
    desfasado: Ev.desfasado,
    estado: NuevoEstado,
    contadores: Contadores,
    recientes: Recientes
  }),
  put_dict(Clave, Mapa0, Dev, Mapa),
  Estado = Estado0.put(dispositivos, Mapa).

estado_por_evento(Ev, falla) :- Ev.tipo_evento == "offline", !.
estado_por_evento(Ev, alerta) :- Ev.tipo_evento == "alarma", !.
estado_por_evento(Ev, alerta) :- Ev.desfasado == true, !.
estado_por_evento(_, ok).

listar(Estado, Ahora, Timeout, Lista) :-
  get_dict(dispositivos, Estado, Mapa),
  dict_pairs(Mapa, _, Pares),
  maplist([_K-D0, D]>>estado_calculado(D0, Ahora, Timeout, D), Pares, Lista).

buscar(Estado, Edificio, Id, Dev) :-
  get_dict(dispositivos, Estado, Mapa),
  clave_dispositivo(Edificio, Id, Clave),
  ( get_dict(Clave, Mapa, Dev0) -> Dev = Dev0 ; fail ).

estado_calculado(Dev0, Ahora, Timeout, Dev) :-
  get_dict(ultimo_latido, Dev0, Ultimo),
  get_dict(offset, Dev0, Offset),
  OffsetSeg is Offset / 1000000,
  ( Ahora - Ultimo > Timeout ->
      Dev1 = Dev0.put(estado, falla)
  ; Dev1 = Dev0
  ),
  Dev = Dev1.put(offset_segundos, OffsetSeg).

tomar(0, _, []) :- !.
tomar(_, [], []) :- !.
tomar(N, [X | Resto], [X | Tomados]) :-
  N1 is N - 1,
  tomar(N1, Resto, Tomados).

map_update(Mapa0, Clave0, Delta, Mapa) :-
  p69_util:texto_atom(Clave0, Clave),
  ( get_dict(Clave, Mapa0, Actual) -> Nuevo is Actual + Delta ; Nuevo = Delta ),
  put_dict(Clave, Mapa0, Nuevo, Mapa).

clave_dispositivo(Edificio, Id, Clave) :-
  format(atom(Clave), '~w|~w', [Edificio, Id]).
