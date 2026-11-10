%% Simulador del escenario del problema: 100 puertas y 200 camaras, tasa
%% promedio configurable, picos, datos historicos, un reloj 4 minutos atrasado,
%% eventos tardios y dispositivos que pasan a offline. Genera eventos y los
%% entrega a la bitacora real (no usa atajos ni tablas paralelas).
-module(p69_simulador).

-export([
  dispositivos/0,
  historico/1,
  carga/1,
  escenario/1,
  esperar/1,
  detener/0,
  detener/1,
  cli/1
]).

-define(NOMBRE, p69_simulador_live).
-define(RELOJ_ATRASADO_MICROS, 240000000).
-define(DISP_RELOJ_ATRASADO, <<"camara-017">>).

%% 100 puertas + 200 camaras repartidas en 10 edificios (A..J).
-spec dispositivos() -> [map()].
dispositivos() ->
  Puertas = [dispositivo(<<"puerta">>, N, puerta) || N <- lists:seq(1, 100)],
  Camaras = [dispositivo(<<"camara">>, N, camara) || N <- lists:seq(1, 200)],
  Puertas ++ Camaras.

%% Carga historica sincronica. Opciones: eventos, horas, dias_atras, lote,
%% semilla. Por defecto carga ~1.08 millones de eventos de las ultimas 2 horas
%% de hace 29 dias (dentro de la retencion de 30 dias).
-spec historico(map()) -> {ok, map()}.
historico(Opciones) ->
  Total = entero(Opciones, eventos, 1080000),
  Horas = entero(Opciones, horas, 2),
  Dias = entero(Opciones, dias_atras, 29),
  Lote = entero(Opciones, lote, 2000),
  Semilla = entero(Opciones, semilla, 1),
  Hasta = ahora() - Dias * 86400 * 1000000,
  Desde = Hasta - Horas * 3600 * 1000000,
  Paso = max(1, (Hasta - Desde) div max(1, Total)),
  Dispositivos = list_to_tuple(dispositivos()),
  Desfases = desfases(),
  {DuracionUs, Resumen} = timer:tc(fun() ->
    cargar_historico(0, Total, Lote, Desde, Paso, Dispositivos, Desfases, Semilla, 0)
  end),
  Resultado = Resumen#{
    desde => Desde,
    hasta => Hasta,
    duracion_ms => DuracionUs div 1000
  },
  logger:info("carga historica terminada", Resultado),
  {ok, Resultado}.

%% Arranca el flujo en vivo en un proceso aparte y devuelve su pid.
%% Opciones: duracion_s, tasa, pico, pico_cada_s, pico_duracion_s, tick_ms,
%% semilla, offline_desde_s, offline_hasta_s.
-spec carga(map()) -> {ok, pid()}.
carga(Opciones) ->
  case whereis(?NOMBRE) of
    undefined -> ok;
    _ -> erlang:error(simulador_ya_en_marcha)
  end,
  Padre = self(),
  Pid = spawn(fun() -> vivir(Opciones, Padre) end),
  {ok, Pid}.

-spec esperar(pid()) -> map().
esperar(Pid) ->
  Ref = erlang:monitor(process, Pid),
  receive
    {p69_simulador_fin, Pid, Resumen} ->
      erlang:demonitor(Ref, [flush]),
      Resumen;
    {'DOWN', Ref, process, Pid, Motivo} ->
      erlang:error({simulador_fallo, Motivo})
  after 600000 ->
    erlang:demonitor(Ref, [flush]),
    exit(Pid, kill),
    erlang:error(simulador_timeout)
  end.

-spec detener() -> ok.
detener() ->
  case whereis(?NOMBRE) of
    undefined -> ok;
    Pid -> detener(Pid)
  end.

-spec detener(pid()) -> ok.
detener(Pid) ->
  Pid ! detener,
  ok.

%% Escenario completo: historico + flujo en vivo + estado + verificacion.
-spec escenario(map()) -> {ok, map()}.
escenario(Opciones) ->
  {ok, Historico} = historico(Opciones),
  {ok, Pid} = carga(Opciones),
  Carga = esperar(Pid),
  Estado = p69_bitacora:estado(),
  Verificacion = p69_bitacora:verificar(),
  {ok, #{
    historico => Historico,
    carga => Carga,
    estado => Estado,
    verificacion => Verificacion
  }}.

%% CLI para scripts/simular.sh. Modos: historico | carga | completo.
-spec cli([string()]) -> ok.
cli(Argumentos) ->
  Opciones = leer_argumentos(Argumentos, #{}),
  Modo = atomo(Opciones, modo, completo),
  Iniciada = iniciar_app(Opciones),
  Resultado = case Modo of
    historico ->
      historico(Opciones);
    carga ->
      {ok, Pid} = carga(Opciones),
      {ok, esperar(Pid)};
    completo ->
      escenario(Opciones);
    Otro ->
      erlang:error({modo_invalido, Otro})
  end,
  io:format("~p~n", [Resultado]),
  detener_app(Iniciada),
  case Iniciada of
    true -> init:stop();
    false -> ok
  end,
  ok.

%% Internos de generacion

cargar_historico(Total, Total, _Lote, _Desde, _Paso, _Dispositivos, _Desfases,
    _Semilla, _Rand) ->
  #{eventos => Total};
cargar_historico(Indice, Total, Lote, Desde, Paso, Dispositivos, Desfases,
    Semilla, Rand0) ->
  N = min(Lote, Total - Indice),
  Rand1 = case Rand0 of
    0 -> rand:seed_s(exsss, {Semilla, Semilla + 1, Semilla + 2});
    _ -> Rand0
  end,
  {Eventos, Rand2} = generar_historico(N, Indice, Desde, Paso, Dispositivos,
    Desfases, Rand1, []),
  case p69_bitacora:ingresar_lote(Eventos) of
    {ok, _} -> ok;
    {error, Motivo} -> erlang:error({ingesta_fallida, Motivo})
  end,
  Fin = Indice + N,
  avisar_progreso(Indice, Fin),
  cargar_historico(Fin, Total, Lote, Desde, Paso, Dispositivos, Desfases,
    Semilla, Rand2).

generar_historico(0, _Indice, _Desde, _Paso, _Dispositivos, _Desfases, Rand, Acc) ->
  {lists:reverse(Acc), Rand};
generar_historico(N, Indice, Desde, Paso, Dispositivos, Desfases, Rand0, Acc) ->
  {Pos, R1} = rand:uniform_s(tuple_size(Dispositivos), Rand0),
  Dev = element(Pos, Dispositivos),
  {Jitter, R2} = rand:uniform_s(Paso, R1),
  TsRecepcion = Desde + Indice * Paso + Jitter,
  {Evento, R3} = construir_evento(Dev, TsRecepcion, Desfases, R2),
  generar_historico(N - 1, Indice + 1, Desde, Paso, Dispositivos, Desfases,
    R3, [Evento | Acc]).

construir_evento(Dev, TsRecepcion, Desfases, Rand0) ->
  Id = maps:get(id, Dev),
  {Retraso, Rand1} = retraso_reloj(Id, Desfases, Rand0),
  Tipo = maps:get(tipo, Dev),
  {TipoEvento, Rand2} = elegir_tipo(Tipo, Rand1),
  {Persona, Rand3} = elegir_persona(Tipo, TipoEvento, Rand2),
  {#{
    dispositivo_id => Id,
    tipo_dispositivo => Tipo,
    edificio => maps:get(edificio, Dev),
    tipo_evento => TipoEvento,
    persona => Persona,
    ts_evento => TsRecepcion - Retraso,
    ts_recepcion => TsRecepcion
  }, Rand3}.

retraso_reloj(Id, Desfases, Rand0) ->
  case maps:get(Id, Desfases, 0) of
    0 ->
      {V, R1} = rand:uniform_s(1000, Rand0),
      case V =< 5 of
        true ->
          {Extra, R2} = rand:uniform_s(240000000, R1),
          {60000000 + Extra, R2};
        false ->
          {Jitter, R2} = rand:uniform_s(100000, R1),
          {Jitter, R2}
      end;
    Fijo ->
      {Fijo, Rand0}
  end.

elegir_tipo(puerta, Rand) ->
  case rand:uniform_s(100, Rand) of
    {V, R} when V =< 60 -> {<<"puerta_abierta">>, R};
    {V, R} when V =< 90 -> {<<"tarjeta_leida">>, R};
    {V, R} when V =< 96 -> {<<"alarma">>, R};
    {V, R} when V =< 98 -> {<<"offline">>, R};
    {_V, R} -> {<<"online">>, R}
  end;
elegir_tipo(camara, Rand) ->
  case rand:uniform_s(100, Rand) of
    {V, R} when V =< 90 -> {<<"movimiento">>, R};
    {V, R} when V =< 97 -> {<<"alarma">>, R};
    {V, R} when V =< 99 -> {<<"offline">>, R};
    {_V, R} -> {<<"online">>, R}
  end.

elegir_persona(puerta, TipoEvento, Rand)
    when TipoEvento =:= <<"puerta_abierta">>; TipoEvento =:= <<"tarjeta_leida">> ->
  case rand:uniform_s(100, Rand) of
    {V, R} when V =< 70 ->
      {N, R2} = rand:uniform_s(50, R),
      {iolist_to_binary(io_lib:format("persona-~2..0B", [N])), R2};
    {_V, R} ->
      {undefined, R}
  end;
elegir_persona(_Tipo, _TipoEvento, Rand) ->
  {undefined, Rand}.

%% Flujo en vivo

vivir(Opciones, Padre) ->
  case whereis(?NOMBRE) of
    undefined -> register(?NOMBRE, self());
    _ -> erlang:error(simulador_ya_en_marcha)
  end,
  Duracion = entero(Opciones, duracion_s, entero(Opciones, duracion, 30)),
  Tick = entero(Opciones, tick_ms, 100),
  Inicio = erlang:monotonic_time(millisecond),
  Estado0 = #{
    opciones => Opciones,
    inicio => Inicio,
    fin => Inicio + Duracion * 1000,
    tick_ms => Tick,
    tick_us => Tick * 1000,
    dispositivos => list_to_tuple(dispositivos()),
    desfases => desfases(),
    por_id => maps:from_list([{maps:get(id, D), D} || D <- dispositivos()]),
    rand => rand:seed_s(exsss, {
      entero(Opciones, semilla, 7),
      entero(Opciones, semilla, 7) + 1,
      entero(Opciones, semilla, 7) + 2
    }),
    fase_offline => pendiente,
    offline => #{},
    acumulado => 0.0,
    enviados => 0,
    aceptados => 0,
    rechazados => 0,
    inicio_real => ahora()
  },
  Resumen = bucle_vivo(Estado0),
  Padre ! {p69_simulador_fin, self(), Resumen},
  ok.

bucle_vivo(Estado) ->
  AhoraMs = erlang:monotonic_time(millisecond),
  case AhoraMs >= maps:get(fin, Estado) of
    true ->
      resumen(Estado);
    false ->
      receive
        detener -> resumen(Estado)
      after maps:get(tick_ms, Estado) ->
        Estado2 = tick(Estado),
        bucle_vivo(Estado2)
      end
  end.

tick(Estado0) ->
  T = (erlang:monotonic_time(millisecond) - maps:get(inicio, Estado0)) div 1000,
  {Control, Estado1} = gestionar_offline(T, Estado0),
  {ControlAceptados, Estado2} = ingresar(Control, Estado1),
  Tasa = tasa_en(T, maps:get(opciones, Estado2)),
  TickMs = maps:get(tick_ms, Estado2),
  Cuenta = Tasa * TickMs / 1000 + maps:get(acumulado, Estado2),
  N = trunc(Cuenta),
  Acumulado = Cuenta - N,
  {Eventos, Estado3} = generar_vivo(N, Estado2),
  {Aceptados, Estado4} = ingresar(Eventos, Estado3),
  Estado4#{
    acumulado => Acumulado,
    enviados => maps:get(enviados, Estado4) + length(Eventos) + length(Control),
    aceptados => maps:get(aceptados, Estado4) + Aceptados + ControlAceptados
  }.

tasa_en(T, Opciones) ->
  Base = entero(Opciones, tasa, 150),
  Pico = entero(Opciones, pico, 0),
  Cada = entero(Opciones, pico_cada_s, 20),
  Dur = entero(Opciones, pico_duracion_s, 5),
  Retardo = entero(Opciones, pico_retardo_s, 10),
  case Pico > 0 andalso Cada > 0 andalso T >= Retardo of
    true ->
      case (T - Retardo) rem Cada < Dur of
        true -> Pico;
        false -> Base
      end;
    false ->
      Base
  end.

generar_vivo(0, Estado) ->
  {[], Estado};
generar_vivo(N, Estado0) ->
  generar_vivo(N, Estado0, []).

generar_vivo(0, Estado, Acc) ->
  {lists:reverse(Acc), Estado};
generar_vivo(N, Estado0, Acc) ->
  case elegir_dispositivo(Estado0, 10) of
    {ok, Dev, Estado1} ->
      Rand0 = maps:get(rand, Estado1),
      {Jitter, Rand1} = rand:uniform_s(maps:get(tick_us, Estado1), Rand0),
      TsRecepcion = ahora() - Jitter,
      {Evento, Rand2} = construir_evento(Dev, TsRecepcion,
        maps:get(desfases, Estado1), Rand1),
      generar_vivo(N - 1, Estado1#{rand => Rand2}, [Evento | Acc]);
    {error, _} ->
      {lists:reverse(Acc), Estado0}
  end.

elegir_dispositivo(_Estado, 0) ->
  {error, todos_offline};
elegir_dispositivo(Estado, Intentos) ->
  Dispositivos = maps:get(dispositivos, Estado),
  Rand0 = maps:get(rand, Estado),
  {Pos, Rand1} = rand:uniform_s(tuple_size(Dispositivos), Rand0),
  Dev = element(Pos, Dispositivos),
  case maps:is_key(maps:get(id, Dev), maps:get(offline, Estado)) of
    true -> elegir_dispositivo(Estado#{rand => Rand1}, Intentos - 1);
    false -> {ok, Dev, Estado#{rand => Rand1}}
  end.

gestionar_offline(T, Estado0) ->
  Opciones = maps:get(opciones, Estado0),
  Desde = entero(Opciones, offline_desde_s, 15),
  Hasta = entero(Opciones, offline_hasta_s, 30),
  Ids = ids_offline(Opciones),
  case maps:get(fase_offline, Estado0) of
    pendiente when T >= Desde ->
      Eventos = [evento_control(maps:get(Id, maps:get(por_id, Estado0)),
        <<"offline">>, ahora()) || Id <- Ids,
        maps:is_key(Id, maps:get(por_id, Estado0))],
      {Eventos, Estado0#{
        fase_offline => offline,
        offline => maps:from_list([{Id, true} || Id <- Ids])
      }};
    offline when T >= Hasta ->
      Eventos = [evento_control(maps:get(Id, maps:get(por_id, Estado0)),
        <<"online">>, ahora()) || Id <- Ids,
        maps:is_key(Id, maps:get(por_id, Estado0))],
      {Eventos, Estado0#{fase_offline => online, offline => #{}}};
    _ ->
      {[], Estado0}
  end.

ids_offline(Opciones) ->
  case maps:get(offline_ids, Opciones, undefined) of
    undefined -> [<<"puerta-002">>, <<"camara-005">>, <<"camara-011">>];
    Lista -> Lista
  end.

evento_control(Dev, TipoEvento, Ts) ->
  #{
    dispositivo_id => maps:get(id, Dev),
    tipo_dispositivo => maps:get(tipo, Dev),
    edificio => maps:get(edificio, Dev),
    tipo_evento => TipoEvento,
    persona => undefined,
    ts_evento => Ts,
    ts_recepcion => Ts
  }.

ingresar([], Estado) ->
  {0, Estado};
ingresar(Eventos, Estado) ->
  case p69_bitacora:ingresar_lote(Eventos) of
    {ok, _} -> {length(Eventos), Estado};
    {error, sobrecarga} ->
      {0, Estado#{rechazados => maps:get(rechazados, Estado) + length(Eventos)}}
  end.

resumen(Estado) ->
  Fin = ahora(),
  DuracionMs = max(1, (Fin - maps:get(inicio_real, Estado)) div 1000),
  Aceptados = maps:get(aceptados, Estado),
  #{
    duracion_ms => DuracionMs,
    enviados => maps:get(enviados, Estado),
    aceptados => Aceptados,
    rechazados => maps:get(rechazados, Estado),
    tasa_real => Aceptados * 1000 / DuracionMs
  }.

%% Desfases conocidos: una camara con el reloj 4 minutos atrasado.
desfases() ->
  #{?DISP_RELOJ_ATRASADO => ?RELOJ_ATRASADO_MICROS}.

avisar_progreso(Antes, Despues) ->
  case Antes div 100000 =:= Despues div 100000 of
    true -> ok;
    false -> logger:info("historico: ~p eventos", [Despues])
  end.

%% Utilitarios

dispositivo(Prefijo, N, Tipo) ->
  #{
    id => iolist_to_binary(io_lib:format("~s-~3..0B", [Prefijo, N])),
    tipo => Tipo,
    edificio => edificio(N)
  }.

edificio(N) ->
  list_to_binary([$A + ((N - 1) rem 10)]).

entero(Mapa, Clave, Defecto) ->
  case maps:get(Clave, Mapa, Defecto) of
    V when is_integer(V) -> V;
    V when is_list(V) -> list_to_integer(V);
    V when is_binary(V) -> binary_to_integer(V)
  end.

atomo(Mapa, Clave, Defecto) ->
  case maps:get(Clave, Mapa, Defecto) of
    V when is_atom(V) -> V;
    V when is_list(V) -> list_to_atom(V);
    V when is_binary(V) -> binary_to_atom(V, utf8)
  end.

leer_argumentos([], Acc) ->
  Acc;
leer_argumentos(["--" ++ Nombre, Valor | Resto], Acc) ->
  leer_argumentos(Resto, Acc#{clave_argumento(Nombre) => Valor});
leer_argumentos(["--" ++ Nombre | Resto], Acc) ->
  leer_argumentos(Resto, Acc#{clave_argumento(Nombre) => true});
leer_argumentos([_Ignorado | Resto], Acc) ->
  leer_argumentos(Resto, Acc).

clave_argumento(Nombre) ->
  list_to_atom([case C of $- -> $_; _ -> C end || C <- Nombre]).

iniciar_app(Opciones) ->
  case whereis(p69_bitacora) of
    undefined ->
      %% set_env exige la aplicacion cargada; si no, falla en silencio y el
      %% arranque usaria el puerto de sys.config (8080) aunque pidamos otro.
      _ = application:load(p69_camaras_y_accesos),
      application:set_env(p69_camaras_y_accesos, datos_dir,
        maps:get(datos, Opciones, "data")),
      application:set_env(p69_camaras_y_accesos, puerto, entero(Opciones, puerto, 0)),
      application:set_env(p69_camaras_y_accesos, retencion_dias,
        entero(Opciones, retencion, 30)),
      case application:ensure_all_started(p69_camaras_y_accesos) of
        {ok, _} -> true;
        {error, Motivo} -> erlang:error({app_no_arranca, Motivo})
      end;
    _ ->
      false
  end.

detener_app(true) ->
  _ = application:stop(p69_camaras_y_accesos),
  ok;
detener_app(false) ->
  ok.

ahora() ->
  erlang:system_time(microsecond).
