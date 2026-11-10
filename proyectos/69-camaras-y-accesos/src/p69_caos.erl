%% Prueba de caos reproducible: carga masiva, consulta concurrente, muerte de
%% dispositivo, sitio, retencion, consulta y bitacora, y retencion con una
%% consulta en curso. Imprime resultados medidos en Markdown; no inventa cifras.
-module(p69_caos).

-export([ejecutar/1, cli/1]).

%% Ejecuta el escenario y devuelve las filas medidas.
-spec ejecutar(map()) -> {ok, map()}.
ejecutar(Opciones) ->
  Eventos = entero(Opciones, eventos, 1000000),
  Semilla = entero(Opciones, semilla, 11),
  {MsCarga, {ok, Hist}} = medir(fun() ->
    p69_simulador:historico(#{
      eventos => Eventos,
      horas => 2,
      dias_atras => 0,
      lote => 5000,
      semilla => Semilla
    })
  end),
  Estado0 = p69_bitacora:estado(),
  Presentes0 = eventos_presentes(),
  FilaCarga = fila(<<"Carga base">>,
    <<"eventos aceptados y seq monotona">>,
    iolist_to_binary(io_lib:format("seq=~p presentes=~p", [
      maps:get(seq, Estado0), Presentes0
    ])),
    iolist_to_binary(io_lib:format("~p ms (~.1f ev/s)", [
      MsCarga, Eventos * 1000 / max(1, MsCarga)
    ]))),

  {FilaConsulta, Durante} = consulta_durante_ingesta(Semilla),

  FilaDispositivo = matar_dispositivo(),
  FilaSitio = matar_sitio(),
  FilaRetencion = matar_retencion(),
  FilaConsultaMuerta = matar_consulta(),

  {FilaBitacora, EstadoBitacora} = matar_bitacora(),
  {FilaRetencionPin, VerificacionFinal} = retencion_con_pin(),

  Filas = [
    FilaCarga, FilaConsulta, FilaDispositivo, FilaSitio,
    FilaRetencion, FilaConsultaMuerta, FilaBitacora,
    FilaRetencionPin,
    fila(<<"Verificacion final">>,
      <<"cadena integra despues de retencion">>,
      compacto(VerificacionFinal),
      <<"-">>)
  ],
  {ok, #{
    filas => Filas,
    historico => Hist,
    durante => Durante,
    estado_bitacora => EstadoBitacora,
    verificacion_final => VerificacionFinal
  }}.

consulta_durante_ingesta(Semilla) ->
  Hasta = ahora(),
  Desde = Hasta - 2 * 3600 * 1000000,
  Filtros = #{edificio => <<"B">>},
  {UsInactiva, ok} = medir_us(fun() ->
    {ok, _} = p69_consulta:buscar(Desde, Hasta, Filtros, 30000),
    ok
  end),
  SeqInicio = maps:get(seq, p69_bitacora:estado()),
  Padre = self(),
  {Pid, Ref} = spawn_monitor(fun() ->
    Resultado = p69_simulador:historico(#{
      eventos => 300000,
      horas => 2,
      dias_atras => 0,
      lote => 5000,
      semilla => Semilla + 1
    }),
    Padre ! {carga_terminada, self(), Resultado}
  end),
  %% Espera a que la ingesta haya empezado de verdad antes de medir.
  {ok, _} = esperar_hasta(fun() ->
    case maps:get(seq, p69_bitacora:estado()) >= SeqInicio + 5000 of
      true -> {ok, ok};
      false -> error
    end
  end, 30000),
  {Muestras, Vivo} = bucle_consultas(Desde, Filtros, Pid, 20, []),
  Latencias = [Us || {Us, _Durante} <- Muestras],
  Durante = length([ok || {_Us, true} <- Muestras]),
  Carga = receive
    {carga_terminada, Pid, Resultado} -> Resultado;
    {'DOWN', Ref, process, Pid, Motivo} -> {error, Motivo}
  end,
  Estado = p69_bitacora:estado(),
  Promedio = lists:sum(Latencias) / max(1, length(Latencias)),
  MsIngesta = case Carga of
    {ok, Datos} -> maps:get(duracion_ms, Datos);
    _ -> 0
  end,
  Fila = fila(<<"Consulta durante la ingesta">>,
    <<"la consulta responde mientras la ingesta sigue">>,
    iolist_to_binary(io_lib:format(
      "~p consultas (~p durante la ingesta); loader vivo al final=~p; seq final=~p",
      [length(Latencias), Durante, Vivo, maps:get(seq, Estado)])),
    iolist_to_binary(io_lib:format(
      "inactiva=~p us; durante prom=~.1f us; ingesta=~p ms",
      [UsInactiva, Promedio, MsIngesta]))),
  {Fila, #{latencias_us => Latencias, durante => Durante, promedio_us => Promedio,
           carga => Carga, vivo_al_terminar => Vivo}}.

bucle_consultas(_Desde, _Filtros, Pid, 0, Acc) ->
  {lists:reverse(Acc), is_process_alive(Pid)};
bucle_consultas(Desde, Filtros, Pid, N, Acc) ->
  VivoAntes = is_process_alive(Pid),
  {Us, {ok, _}} = medir_us(fun() ->
    p69_consulta:buscar(Desde, ahora(), Filtros, 30000)
  end),
  bucle_consultas(Desde, Filtros, Pid, N - 1, [{Us, VivoAntes} | Acc]).

matar_dispositivo() ->
  case elegir_dispositivo() of
    {ok, Edificio, DispId, Pid, SitePid} ->
      {Ms, Nuevo} = medir(fun() ->
        exit(Pid, kill),
        esperar_hasta(fun() -> dispositivo_vivo(SitePid, DispId) end, 10000)
      end),
      case Nuevo of
        {ok, NuevoPid} when is_pid(NuevoPid), NuevoPid =/= Pid ->
          ok = ingresar_actual(Edificio, DispId),
          _ = esperar_hasta(fun() -> dispositivo_actual(Edificio, DispId) end, 5000),
          fila(<<"Matar un dispositivo">>,
            <<"el supervisor del sitio lo reinicia y sigue aceptando eventos">>,
            iolist_to_binary(io_lib:format("nuevo pid ~p; evento posterior ok",
              [NuevoPid])),
            iolist_to_binary(io_lib:format("~p ms", [Ms])));
        Otro ->
          fila(<<"Matar un dispositivo">>,
            <<"el supervisor del sitio lo reinicia">>,
            iolist_to_binary(io_lib:format("resultado inesperado: ~p", [Otro])),
            iolist_to_binary(io_lib:format("~p ms", [Ms])))
      end;
    {error, Motivo} ->
      fila(<<"Matar un dispositivo">>, <<"reinicio">>,
        iolist_to_binary(io_lib:format("sin dispositivo: ~p", [Motivo])), <<"-">>)
  end.

matar_sitio() ->
  case elegir_sitio() of
    {ok, Edificio, SitePid, DispId} ->
      {Ms, Nuevo} = medir(fun() ->
        exit(SitePid, kill),
        esperar_hasta(fun() -> sitio_vivo(Edificio, SitePid) end, 10000)
      end),
      case Nuevo of
        {ok, NuevoPid} ->
          ok = ingresar_actual(Edificio, DispId),
          _ = esperar_hasta(fun() -> dispositivo_actual(Edificio, DispId) end, 5000),
          fila(<<"Matar un sitio_sup">>,
            <<"se reinicia el sitio y se recrean sus dispositivos">>,
            iolist_to_binary(io_lib:format("nuevo sitio ~p; evento posterior ok",
              [NuevoPid])),
            iolist_to_binary(io_lib:format("~p ms", [Ms])));
        Otro ->
          fila(<<"Matar un sitio_sup">>, <<"se reinicia el sitio">>,
            iolist_to_binary(io_lib:format("resultado inesperado: ~p", [Otro])),
            iolist_to_binary(io_lib:format("~p ms", [Ms])))
      end;
    {error, Motivo} ->
      fila(<<"Matar un sitio_sup">>, <<"reinicio">>,
        iolist_to_binary(io_lib:format("sin sitio: ~p", [Motivo])), <<"-">>)
  end.

matar_retencion() ->
  Pid = whereis(p69_retencion),
  {Ms, Nuevo} = medir(fun() ->
    exit(Pid, kill),
    esperar_hasta(fun() ->
      case whereis(p69_retencion) of
        undefined -> error;
        Pid -> error;
        P -> {ok, P}
      end
    end, 10000)
  end),
  fila(<<"Matar p69_retencion">>, <<"el supervisor lo reinicia">>,
    iolist_to_binary(io_lib:format("reinicio=~s", [compacto(Nuevo)])),
    iolist_to_binary(io_lib:format("~p ms", [Ms]))).

matar_consulta() ->
  Desde = ahora() - 2 * 3600 * 1000000,
  Hasta = ahora(),
  Padre = self(),
  {Wrapper, Ref} = spawn_monitor(fun() ->
    Resultado = p69_consulta:buscar(Desde, Hasta, #{}, 60000),
    Padre ! {consulta_terminada, self(), Resultado}
  end),
  {Ms, Encontrada} = medir(fun() ->
    esperar_hasta(fun() -> primer_hijo(p69_consultas_sup) end, 2000)
  end),
  Resultado = case Encontrada of
    {ok, Pid} ->
      exit(Pid, kill),
      receive
        {consulta_terminada, Wrapper, R} -> R;
        {'DOWN', Ref, process, Wrapper, Motivo} -> {error, Motivo}
      after 10000 -> timeout
      end;
    error ->
      receive
        {consulta_terminada, Wrapper, R} -> R;
        {'DOWN', Ref, process, Wrapper, Motivo} -> {error, Motivo}
      after 10000 -> timeout
      end
  end,
  fila(<<"Matar un proceso de consulta">>,
    <<"el llamador recibe error y la bitacora sigue viva">>,
    iolist_to_binary(io_lib:format("consulta=~p", [Resultado])),
    iolist_to_binary(io_lib:format("captura=~p; ~p ms", [Encontrada, Ms]))).

matar_bitacora() ->
  Antes = p69_bitacora:estado(),
  PresentesAntes = eventos_presentes(),
  PidViejo = whereis(p69_bitacora),
  {Ms, _Nuevo} = medir(fun() ->
    exit(PidViejo, kill),
    esperar_hasta(fun() -> bitacora_lista(PidViejo) end, 120000)
  end),
  Despues = p69_bitacora:estado(),
  PresentesDespues = eventos_presentes(),
  {MsVerif, Verificacion} = medir(fun() -> p69_bitacora:verificar() end),
  Dependientes = [
    {p69_http, whereis(p69_http)},
    {p69_sitios, whereis(p69_sitios)},
    {p69_retencion, whereis(p69_retencion)},
    {p69_eventos_pub, whereis(p69_eventos_pub)}
  ],
  Fila = fila(<<"Matar la bitacora (duena de ETS/WAL)">>,
    <<"recupera el WAL, conserva seq y la verificacion queda ok">>,
    iolist_to_binary(io_lib:format(
      "seq ~p -> ~p; presentes ~p -> ~p; verif=~s",
      [maps:get(seq, Antes), maps:get(seq, Despues),
       PresentesAntes, PresentesDespues, compacto(Verificacion)])),
    iolist_to_binary(io_lib:format(
      "recuperacion=~p ms; verificacion=~p ms; dependientes=~s",
      [Ms, MsVerif, compacto(Dependientes)]))),
  {Fila, Despues}.

retencion_con_pin() ->
  {ok, _} = p69_simulador:historico(#{
    eventos => 2000,
    horas => 1,
    dias_atras => 2,
    lote => 500,
    semilla => 99
  }),
  Corte = ahora() - 86400 * 1000000,
  Segmentos = p69_bitacora:info_segmentos(),
  Antiguos = [S || S <- Segmentos, maps:get(hasta, S) < Corte],
  case Antiguos of
    [] ->
      {fila(<<"Retencion con consulta en curso">>,
        <<"no borra el segmento en uso">>,
        <<"no se encontro segmento antiguo">>, <<"-">>), sin_verificar};
    [Seg | _] ->
      Id = maps:get(id, Seg),
      Desde = maps:get(desde, Seg),
      Hasta = maps:get(hasta, Seg),
      {ok, {Ref, _, _}} = p69_bitacora:abrir_consulta(Desde, Hasta),
      {Ms1, {ok, R1}} = medir(fun() -> p69_bitacora:retener(Corte) end),
      EnUso = lists:keyfind(Id, 1, R1),
      Sigue = lists:any(fun(S) -> maps:get(id, S) =:= Id end,
        p69_bitacora:info_segmentos()),
      ok = p69_bitacora:cerrar_consulta(Ref),
      {Ms2, {ok, R2}} = medir(fun() -> p69_bitacora:retener(Corte) end),
      Borrado = lists:keyfind(Id, 1, R2),
      YaNo = not lists:any(fun(S) -> maps:get(id, S) =:= Id end,
        p69_bitacora:info_segmentos()),
      Verificacion = p69_bitacora:verificar(),
      Fila = fila(<<"Retencion con consulta en curso">>,
        <<"en_uso durante el pin, borrado al cerrar, cadena sigue ok">>,
        iolist_to_binary(io_lib:format(
          "con pin=~p sigue=~p; sin pin=~p borrado=~p; verif=~s",
          [EnUso, Sigue, Borrado, YaNo, compacto(Verificacion)])),
        iolist_to_binary(io_lib:format("~p ms + ~p ms", [Ms1, Ms2]))),
      {Fila, Verificacion}
  end.

%% Auxiliares de procesos

elegir_dispositivo() ->
  case elegir_sitio() of
    {ok, Edificio, SitePid, DispId} ->
      case dispositivo_vivo(SitePid, DispId) of
        {ok, Pid} -> {ok, Edificio, DispId, Pid, SitePid};
        error -> {error, sin_dispositivo}
      end;
    Error -> Error
  end.

elegir_sitio() ->
  Sitios = [S || S <- supervisor:which_children(p69_sitios_sup),
                 element(1, S) =/= undefined],
  elegir_sitio_con_hijo(Sitios).

elegir_sitio_con_hijo([]) ->
  {error, sin_sitios};
elegir_sitio_con_hijo([{{p69_sitio_sup, Edificio}, Pid, supervisor, _} | Resto])
    when is_pid(Pid) ->
  case primer_hijo_pid(Pid) of
    {ok, DispId} -> {ok, Edificio, Pid, DispId};
    error -> elegir_sitio_con_hijo(Resto)
  end;
elegir_sitio_con_hijo([_ | Resto]) ->
  elegir_sitio_con_hijo(Resto).

primer_hijo_pid(SitePid) ->
  case [Id || {Id, Pid, worker, _} <- supervisor:which_children(SitePid),
              is_pid(Pid)] of
    [Id | _] -> {ok, Id};
    [] -> error
  end.

dispositivo_vivo(SitePid, DispId) ->
  case lists:keyfind(DispId, 1, supervisor:which_children(SitePid)) of
    {DispId, Pid, _Tipo, _Modulos} when is_pid(Pid) ->
      case is_process_alive(Pid) of
        true -> {ok, Pid};
        false -> error
      end;
    _ -> error
  end.

dispositivo_actual(Edificio, DispId) ->
  case p69_sitios:dispositivo(Edificio, DispId) of
    {ok, _} -> {ok, ok};
    {error, _} -> error
  end.

sitio_vivo(Edificio, PidViejo) ->
  case buscar_sitio(Edificio) of
    {ok, Pid} when Pid =/= PidViejo -> {ok, Pid};
    _ -> error
  end.

buscar_sitio(Edificio) ->
  case lists:keyfind({p69_sitio_sup, Edificio}, 1,
      supervisor:which_children(p69_sitios_sup)) of
    {{p69_sitio_sup, Edificio}, Pid, supervisor, _} when is_pid(Pid) -> {ok, Pid};
    _ -> error
  end.

primer_hijo(Sup) ->
  case [Pid || {_Id, Pid, worker, _} <- supervisor:which_children(Sup),
               is_pid(Pid)] of
    [Pid | _] -> {ok, Pid};
    [] -> error
  end.

bitacora_lista(PidViejo) ->
  case whereis(p69_bitacora) of
    undefined -> error;
    PidViejo -> error;
    _ ->
      try p69_bitacora:estado() of
        _ -> {ok, whereis(p69_bitacora)}
      catch
        exit:{noproc, _} -> error;
        exit:{timeout, _} -> error
      end
  end.

esperar_hasta(Fun, TimeoutMs) ->
  Fin = erlang:monotonic_time(millisecond) + TimeoutMs,
  esperar_bucle(Fun, Fin).

esperar_bucle(Fun, Fin) ->
  case Fun() of
    {ok, Valor} -> {ok, Valor};
    error ->
      case erlang:monotonic_time(millisecond) >= Fin of
        true -> {error, timeout};
        false ->
          timer:sleep(5),
          esperar_bucle(Fun, Fin)
      end
  end.

ingresar_actual(Edificio, DispId) ->
  Ts = ahora(),
  case p69_bitacora:ingresar(#{
    dispositivo_id => DispId,
    tipo_dispositivo => tipo_por_id(DispId),
    edificio => Edificio,
    tipo_evento => <<"online">>,
    ts_evento => Ts,
    ts_recepcion => Ts
  }) of
    {ok, _} -> ok;
    {error, Motivo} -> erlang:error({ingesta_fallo, Motivo})
  end.

tipo_por_id(<<"puerta", _/binary>>) -> puerta;
tipo_por_id(_) -> camara.

eventos_presentes() ->
  lists:sum([maps:get(eventos, S) || S <- p69_bitacora:info_segmentos()]).

%% Formato y utilidades

fila(Escenario, Esperado, Ocurrio, Medicion) ->
  #{escenario => Escenario, esperado => Esperado,
    ocurrio => Ocurrio, medicion => Medicion}.

medir(Fun) ->
  Inicio = erlang:monotonic_time(microsecond),
  Resultado = Fun(),
  Fin = erlang:monotonic_time(microsecond),
  {(Fin - Inicio) div 1000, Resultado}.

medir_us(Fun) ->
  Inicio = erlang:monotonic_time(microsecond),
  Resultado = Fun(),
  Fin = erlang:monotonic_time(microsecond),
  {Fin - Inicio, Resultado}.

compacto(Termino) ->
  iolist_to_binary(io_lib:format("~0p", [Termino])).

%% CLI: scripts/caos.sh --eventos N [--datos DIR] [--semilla N]
-spec cli([string()]) -> ok.
cli(Argumentos) ->
  Opciones = leer_argumentos(Argumentos, #{}),
  logger:set_primary_config(level, critical),
  Datos = maps:get(datos, Opciones,
    "/tmp/p69_caos_" ++ integer_to_list(os:system_time(second))),
  iniciar_app(Datos),
  {ok, Resultado} = ejecutar(Opciones),
  imprimir(Resultado, Opciones, Datos),
  _ = application:stop(p69_camaras_y_accesos),
  init:stop(),
  ok.

iniciar_app(Datos) ->
  _ = application:load(p69_camaras_y_accesos),
  application:set_env(p69_camaras_y_accesos, datos_dir, Datos),
  application:set_env(p69_camaras_y_accesos, puerto, 0),
  application:set_env(p69_camaras_y_accesos, num_aceptores, 5),
  application:set_env(p69_camaras_y_accesos, retencion_dias, 0),
  application:set_env(p69_camaras_y_accesos, segmento_segundos, 3600),
  application:set_env(p69_camaras_y_accesos, dispositivo_timeout_seg, 120),
  case application:ensure_all_started(p69_camaras_y_accesos) of
    {ok, _} -> ok;
    {error, Motivo} -> erlang:error({app_no_arranca, Motivo})
  end.

imprimir(Resultado, Opciones, Datos) ->
  Filas = maps:get(filas, Resultado),
  io:format("# Prueba de caos - resultados medidos~n~n"),
  io:format("Fecha: ~s~n", [fecha()]),
  io:format("Entorno: OTP ~s, ~p nucleos~n",
    [erlang:system_info(otp_release), erlang:system_info(logical_processors_available)]),
  io:format("Datos: ~s (eventos base=~p)~n",
    [Datos, entero(Opciones, eventos, 1000000)]),
  io:format("Comando: scripts/caos.sh --eventos ~p~n~n",
    [entero(Opciones, eventos, 1000000)]),
  io:format("| Escenario | Que se esperaba | Que ocurrio | Medicion |~n"),
  io:format("|---|---|---|---|~n"),
  [io:format("| ~s | ~s | ~s | ~s |~n",
    [maps:get(escenario, F), maps:get(esperado, F),
     maps:get(ocurrio, F), maps:get(medicion, F)]) || F <- Filas],
  io:format("~n## Lectura~n~n"),
  io:format("- Los numeros salen de esta ejecucion; no son estimaciones.~n"),
  io:format("- El detalle de la consulta concurrente quedo en: ~s~n",
    [compacto(maps:get(durante, Resultado))]),
  io:format("- Estado final de la bitacora: ~s~n",
    [compacto(maps:get(estado_bitacora, Resultado))]),
  io:format("- Verificacion final: ~s~n",
    [compacto(maps:get(verificacion_final, Resultado))]).

fecha() ->
  {{Y, M, D}, {H, Min, S}} = calendar:local_time(),
  io_lib:format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B",
    [Y, M, D, H, Min, S]).

entero(Mapa, Clave, Defecto) ->
  case maps:get(Clave, Mapa, Defecto) of
    V when is_integer(V) -> V;
    V when is_list(V) -> list_to_integer(V);
    V when is_binary(V) -> binary_to_integer(V)
  end.

leer_argumentos([], Acc) ->
  Acc;
leer_argumentos(["--" ++ Nombre, Valor | Resto], Acc) ->
  leer_argumentos(Resto, Acc#{list_to_atom([case C of $- -> $_; _ -> C end
    || C <- Nombre]) => Valor});
leer_argumentos(["--" ++ Nombre | Resto], Acc) ->
  leer_argumentos(Resto, Acc#{list_to_atom([case C of $- -> $_; _ -> C end
    || C <- Nombre]) => true});
leer_argumentos([_Ignorado | Resto], Acc) ->
  leer_argumentos(Resto, Acc).

ahora() ->
  erlang:system_time(microsecond).
