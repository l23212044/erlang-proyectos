%% Handler de /metrics en formato Prometheus (texto). Incluye eventos por
%% dispositivo y tipo, estado de dispositivos, cola de ingesta, latencia de
%% consultas y tamano de segmentos.
-module(p69_api_metrics).

-export([init/2]).

init(Req0, State) ->
  case cowboy_req:method(Req0) of
    <<"GET">> ->
      Cuerpo = iolist_to_binary(lineas(recolectar())),
      Req = cowboy_req:reply(
        200,
        #{<<"content-type">> => <<"text/plain; version=0.0.4; charset=utf-8">>},
        Cuerpo,
        Req0
      ),
      {ok, Req, State};
    _ ->
      {ok, Req, _} = p69_api:error(405, <<"metodo_no_permitido">>,
        <<"use GET">>, Req0),
      {ok, Req, State}
  end.

recolectar() ->
  Metricas = p69_metricas:snapshot(),
  Estado = p69_bitacora:estado(),
  Segmentos = p69_bitacora:info_segmentos(),
  Dispositivos = p69_sitios:dispositivos(),
  #{
    metricas => Metricas,
    estado => Estado,
    segmentos => Segmentos,
    dispositivos => Dispositivos
  }.

lineas(Datos) ->
  M = maps:get(metricas, Datos),
  E = maps:get(estado, Datos),
  Segs = maps:get(segmentos, Datos),
  Devs = maps:get(dispositivos, Datos),
  Consultas = valor(M, consultas),
  LatenciaTotal = valor(M, consulta_latencia_total_us),
  LatenciaProm = case Consultas of
    0 -> 0;
    _ -> LatenciaTotal div Consultas
  end,
  [
    "# HELP p69_eventos_total Eventos aceptados desde el arranque\n",
    "# TYPE p69_eventos_total counter\n",
    linea("p69_eventos_total", valor(M, eventos_ingresados)),
    "# HELP p69_ingesta_rechazada_total Eventos rechazados (validacion o sobrecarga)\n",
    "# TYPE p69_ingesta_rechazada_total counter\n",
    linea("p69_ingesta_rechazada_total", valor(M, ingesta_rechazada)),
    "# HELP p69_alertas_reloj_total Eventos marcados con reloj desfasado\n",
    "# TYPE p69_alertas_reloj_total counter\n",
    linea("p69_alertas_reloj_total", valor(M, alertas_reloj)),
    "# HELP p69_consultas_total Consultas de rango ejecutadas\n",
    "# TYPE p69_consultas_total counter\n",
    linea("p69_consultas_total", Consultas),
    "# HELP p69_consulta_latencia_promedio_us Latencia promedio de consultas\n",
    "# TYPE p69_consulta_latencia_promedio_us gauge\n",
    linea("p69_consulta_latencia_promedio_us", LatenciaProm),
    "# HELP p69_cola_ingesta Mensajes pendientes en la bitacora\n",
    "# TYPE p69_cola_ingesta gauge\n",
    linea("p69_cola_ingesta", maps:get(cola_ingesta, E, 0)),
    "# HELP p69_segmentos Segmentos temporales activos\n",
    "# TYPE p69_segmentos gauge\n",
    linea("p69_segmentos", length(Segs)),
    "# HELP p69_segmentos_eventos Eventos en segmentos activos\n",
    "# TYPE p69_segmentos_eventos gauge\n",
    linea("p69_segmentos_eventos", suma([maps:get(eventos, S) || S <- Segs])),
    "# HELP p69_segmentos_memoria_bytes Memoria ETS de los segmentos\n",
    "# TYPE p69_segmentos_memoria_bytes gauge\n",
    linea("p69_segmentos_memoria_bytes", suma([maps:get(memoria_bytes, S) || S <- Segs])),
    "# HELP p69_dispositivos_total Dispositivos conocidos\n",
    "# TYPE p69_dispositivos_total gauge\n",
    linea("p69_dispositivos_total", length(Devs)),
    "# HELP p69_camaras_offline Camaras en estado falla\n",
    "# TYPE p69_camaras_offline gauge\n",
    linea("p69_camaras_offline", contar(Devs, camara, falla)),
    "# HELP p69_puertas_offline Puertas en estado falla\n",
    "# TYPE p69_puertas_offline gauge\n",
    linea("p69_puertas_offline", contar(Devs, puerta, falla)),
    "# HELP p69_dispositivos_alerta Dispositivos en alerta\n",
    "# TYPE p69_dispositivos_alerta gauge\n",
    linea("p69_dispositivos_alerta", contar_estado(Devs, alerta)),
    eventos_por_dispositivo(M),
    eventos_por_tipo(M)
  ].

valor(Map, Clave) ->
  maps:get(Clave, Map, 0).

linea(Nombre, Valor) ->
  [Nombre, " ", integer_to_binary(Valor), "\n"].

suma(Lista) -> lists:sum(Lista).

contar(Devs, Tipo, Estado) ->
  length([
    D || D <- Devs,
         maps:get(tipo, D) =:= Tipo,
         maps:get(estado, D) =:= Estado
  ]).

contar_estado(Devs, Estado) ->
  length([D || D <- Devs, maps:get(estado, D) =:= Estado]).

eventos_por_dispositivo(M) ->
  Casos = [
    {Disp, N}
   || {{eventos_dispositivo, Disp}, N} <- maps:to_list(M)
  ],
  [
    [<<"p69_eventos_dispositivo{dispositivo=\"">>, escapar(Disp), <<"\"} ">>,
     integer_to_binary(N), "\n"]
   || {Disp, N} <- Casos
  ].

eventos_por_tipo(M) ->
  Casos = [
    {Tipo, N}
   || {{eventos_tipo, Tipo}, N} <- maps:to_list(M)
  ],
  [
    [<<"p69_eventos_tipo{tipo=\"">>, escapar(Tipo), <<"\"} ">>,
     integer_to_binary(N), "\n"]
   || {Tipo, N} <- Casos
  ].

escapar(Bin) when is_binary(Bin) ->
  binary:replace(binary:replace(Bin, <<"\\">>, <<"\\\\">>, [global]),
    <<"\"">>, <<"\\\"">>, [global]);
escapar(Otro) ->
  escapar(p69_api:a_bin(Otro)).
