%% Nucleo de la bitacora: dueno estable de las tablas ETS, del WAL y de la
%% cadena de hashes. La ingesta se confirma solo despues de escribir y
%% sincronizar el WAL (persistencia previa al ACK). Al reiniciar se reconstruye
%% el estado desde el WAL y se respetan los checkpoints de retencion.
-module(p69_bitacora).
-behaviour(gen_server).

-export([
  start_link/0,
  ingresar/1,
  ingresar_lote/1,
  buscar/3,
  abrir_consulta/2,
  cerrar_consulta/1,
  verificar/0,
  retener/1,
  baja_segmento/1,
  info_segmentos/0,
  estado/0,
  offset_dispositivo/1
]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TAB_SEQ, p69_bitacora_seq).
-define(TAB_HASH, p69_bitacora_hash).
-define(TAB_CP, p69_bitacora_checkpoints).

-record(estado, {
  dir,
  wal,
  segundos,
  umbral_reloj,
  max_muestras,
  umbral_429,
  segmentos = #{},
  seq = 0,
  last_hash = <<>>,
  relojes = #{},
  pines = #{},
  pin_counts = #{},
  cp_seq = 0,
  last_cp_hash = <<>>,
  tid_seq,
  tid_hash,
  tid_cp
}).

%% API

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec ingresar(map()) -> {ok, map()} | {error, term()}.
ingresar(EventoCrudo) ->
  gen_server:call(?MODULE, {ingresar, EventoCrudo}, 15000).

-spec ingresar_lote([map()]) -> {ok, [map()]} | {error, term()}.
ingresar_lote(Eventos) when is_list(Eventos) ->
  gen_server:call(?MODULE, {ingresar_lote, Eventos}, 60000).

%% Consulta por rango. La lectura de ETS ocurre en el proceso llamante (por
%% ejemplo un worker de p69_consultas_sup) para no bloquear la ingesta.
-spec buscar(integer(), integer(), map()) -> {ok, [map()]} | {error, term()}.
buscar(Desde, Hasta, Filtros) when Desde =< Hasta ->
  case abrir_consulta(Desde, Hasta) of
    {ok, {Ref, Segmentos, MaxSeq}} ->
      try
        Resultado = lists:append([
          p69_almacen:buscar(Almacen, Desde, Hasta, Filtros, MaxSeq)
         || {_Id, Almacen} <- Segmentos
        ]),
        {ok, Resultado}
      after
        _ = cerrar_consulta(Ref)
      end;
    {error, _} = Error ->
      Error
  end;
buscar(_Desde, _Hasta, _Filtros) ->
  {error, rango_invalido}.

-spec abrir_consulta(integer(), integer()) ->
  {ok, {reference(), [{integer(), map()}], non_neg_integer()}} | {error, term()}.
abrir_consulta(Desde, Hasta) when Desde =< Hasta ->
  gen_server:call(?MODULE, {abrir_consulta, Desde, Hasta}, 15000);
abrir_consulta(_Desde, _Hasta) ->
  {error, rango_invalido}.

-spec cerrar_consulta(reference()) -> ok.
cerrar_consulta(Ref) ->
  gen_server:call(?MODULE, {cerrar_consulta, Ref}, 15000).

-spec verificar() -> {ok, map()} | {error, map()}.
verificar() ->
  case gen_server:call(?MODULE, snapshot_verificacion, 30000) of
    {ok, MaxSeq, Cps, TidHash, TidSeq} ->
      Filas = recolectar_filas(TidHash, TidSeq, MaxSeq),
      p69_cadena:verificar(Filas, Cps);
    Error ->
      Error
  end.

-spec retener(integer()) -> {ok, [term()]} | {error, term()}.
retener(CorteTs) ->
  gen_server:call(?MODULE, {retener, CorteTs}, 120000).

-spec baja_segmento(integer()) -> ok | {error, term()}.
baja_segmento(SegId) ->
  gen_server:call(?MODULE, {baja_segmento, SegId}, 120000).

-spec info_segmentos() -> [map()].
info_segmentos() ->
  gen_server:call(?MODULE, info_segmentos, 15000).

-spec estado() -> map().
estado() ->
  gen_server:call(?MODULE, estado, 15000).

-spec offset_dispositivo(binary()) -> {ok, integer(), boolean()} | {error, no_encontrado}.
offset_dispositivo(Disp) ->
  gen_server:call(?MODULE, {offset_dispositivo, Disp}, 15000).

%% Callbacks

init([]) ->
  Dir = p69_config:get(datos_dir, "data"),
  Segundos = p69_config:get(segmento_segundos, 86400),
  UmbralReloj = p69_config:get(umbral_reloj_seg, 60) * 1000000,
  MaxMuestras = p69_config:get(reloj_max_muestras, 15),
  Umbral429 = p69_config:get(ingesta_umbral_429, 80000),
  case p69_wal:abrir(Dir) of
    {ok, Wal} ->
      TidSeq = ets:new(?TAB_SEQ, [ordered_set, protected, {read_concurrency, true}]),
      TidHash = ets:new(?TAB_HASH, [ordered_set, protected, {read_concurrency, true}]),
      TidCp = ets:new(?TAB_CP, [ordered_set, protected, {read_concurrency, true}]),
      Estado0 = #estado{
        dir = Dir,
        wal = Wal,
        segundos = Segundos,
        umbral_reloj = UmbralReloj,
        max_muestras = MaxMuestras,
        umbral_429 = Umbral429,
        tid_seq = TidSeq,
        tid_hash = TidHash,
        tid_cp = TidCp
      },
      Estado1 = recuperar(Estado0),
      logger:info("bitacora iniciada", #{
        dir => Dir, seq => Estado1#estado.seq, segmentos => map_size(Estado1#estado.segmentos)
      }),
      {ok, Estado1};
    {error, Motivo} ->
      {stop, Motivo}
  end.

handle_call({ingresar, EventoCrudo}, _From, Estado) ->
  case sobrecargada(Estado) of
    true ->
      metricas(inc, [ingesta_rechazada]),
      {reply, {error, sobrecarga}, Estado};
    false ->
      case do_ingresar([EventoCrudo], Estado) of
        {ok, [Ev], Estado2} ->
          notificar(Ev),
          {reply, {ok, Ev}, Estado2};
        {error, Motivo} ->
          metricas(inc, [ingesta_rechazada]),
          {reply, {error, Motivo}, Estado}
      end
  end;
handle_call({ingresar_lote, Eventos}, _From, Estado) ->
  case sobrecargada(Estado) of
    true ->
      metricas(inc, [ingesta_rechazada]),
      {reply, {error, sobrecarga}, Estado};
    false ->
      case do_ingresar(Eventos, Estado) of
        {ok, Evs, Estado2} ->
          lists:foreach(fun notificar/1, Evs),
          {reply, {ok, Evs}, Estado2};
        {error, Motivo} ->
          metricas(inc, [ingesta_rechazada]),
          {reply, {error, Motivo}, Estado}
      end
  end;
handle_call({abrir_consulta, Desde, Hasta}, _From, Estado) ->
  {Ref, Segmentos, Estado2} = registrar_pines(Desde, Hasta, Estado),
  {reply, {ok, {Ref, Segmentos, Estado2#estado.seq}}, Estado2};
handle_call({cerrar_consulta, Ref}, _From, Estado) ->
  {reply, ok, liberar_pines(Ref, Estado)};
handle_call(snapshot_verificacion, _From, Estado) ->
  Cps = [Cp || {_N, Cp} <- ets:tab2list(Estado#estado.tid_cp)],
  {reply,
    {ok, Estado#estado.seq, Cps, Estado#estado.tid_hash, Estado#estado.tid_seq},
    Estado};
handle_call({retener, CorteTs}, _From, Estado) ->
  {Resultados, Estado2} = retener_segmentos(CorteTs, Estado),
  {reply, {ok, Resultados}, Estado2};
handle_call({baja_segmento, SegId}, _From, Estado) ->
  case bajar_segmento(SegId, Estado) of
    {ok, Estado2} -> {reply, ok, Estado2};
    {error, Motivo} -> {reply, {error, Motivo}, Estado}
  end;
handle_call(info_segmentos, _From, Estado) ->
  Info = [
    #{
      id => Id,
      desde => maps:get(desde, Meta),
      hasta => maps:get(hasta, Meta),
      eventos => p69_almacen:contar(maps:get(almacen, Meta)),
      pines => maps:get(Id, Estado#estado.pin_counts, 0)
    }
   || {Id, Meta} <- lists:sort(maps:to_list(Estado#estado.segmentos))
  ],
  {reply, Info, Estado};
handle_call(estado, _From, Estado) ->
  {reply, #{
    seq => Estado#estado.seq,
    ultimo_hash => Estado#estado.last_hash,
    cp_seq => Estado#estado.cp_seq,
    segmentos => map_size(Estado#estado.segmentos),
    pines => map_size(Estado#estado.pines),
    relojes => maps:size(Estado#estado.relojes)
  }, Estado};
handle_call({offset_dispositivo, Disp}, _From, Estado) ->
  case maps:find(Disp, Estado#estado.relojes) of
    {ok, Reloj} ->
      {reply, {ok, p69_reloj:offset(Reloj), p69_reloj:desfasado(Reloj)}, Estado};
    error ->
      {reply, {error, no_encontrado}, Estado}
  end;
handle_call(_Msg, _From, Estado) ->
  {reply, {error, no_soportado}, Estado}.

handle_cast(_Msg, Estado) ->
  {noreply, Estado}.

handle_info(_Info, Estado) ->
  {noreply, Estado}.

terminate(_Motivo, Estado) ->
  _ = p69_wal:cerrar(Estado#estado.wal),
  ok.

%% Ingesta

do_ingresar(Eventos, Estado) ->
  case normalizar_todos(Eventos) of
    {ok, Normalizados} ->
      caso_retencion(Normalizados, Estado);
    {error, Motivo} ->
      {error, Motivo}
  end.

normalizar_todos(Eventos) ->
  normalizar_todos(Eventos, 1, []).

normalizar_todos([], _N, Acc) ->
  {ok, lists:reverse(Acc)};
normalizar_todos([Crudo | Resto], N, Acc) ->
  case p69_evento:normalizar(Crudo) of
    {ok, Ev} -> normalizar_todos(Resto, N + 1, [Ev | Acc]);
    {error, Motivo} -> {error, {evento_invalido, N, Motivo}}
  end.

caso_retencion(Normalizados, Estado) ->
  Corte = corte_retencion(Estado),
  case [Ev || Ev <- Normalizados, maps:get(ts_evento, Ev) < Corte] of
    [] ->
      prefijar_y_guardar(Normalizados, Estado);
    _ ->
      {error, fuera_de_retencion}
  end.

prefijar_y_guardar(Normalizados, Estado) ->
  {Preparados, Estado2} = lists:mapfoldl(fun preparar_uno/2, Estado, Normalizados),
  Registros = [#{tipo => evento, evento => Ev} || Ev <- Preparados],
  case p69_wal:agregar_lote(Estado2#estado.wal, Registros) of
    ok ->
      case p69_wal:sincronizar(Estado2#estado.wal) of
        ok ->
          Estado3 = lists:foldl(fun insertar_en_memoria/2, Estado2, Preparados),
          metricas(inc, [ingesta_aceptada]),
          metricas(inc, [eventos_ingresados, length(Preparados)]),
          {ok, Preparados, Estado3};
        {error, Motivo} ->
          {error, Motivo}
      end;
    {error, Motivo} ->
      {error, Motivo}
  end.

preparar_uno(Ev0, Estado) ->
  Disp = maps:get(dispositivo_id, Ev0),
  TsEvento = maps:get(ts_evento, Ev0),
  TsRecepcion = maps:get(ts_recepcion, Ev0),
  Reloj0 = maps:get(Disp, Estado#estado.relojes, p69_reloj:nuevo()),
  Reloj1 = p69_reloj:agregar(Reloj0, TsEvento, TsRecepcion, #{
    max_muestras => Estado#estado.max_muestras,
    umbral_reloj_micros => Estado#estado.umbral_reloj
  }),
  Offset = p69_reloj:offset(Reloj1),
  Desfasado = p69_reloj:desfasado(Reloj1),
  Seq = Estado#estado.seq + 1,
  Ev = p69_evento:preparar(Ev0, Seq, Estado#estado.last_hash, Offset, Desfasado),
  Estado2 = Estado#estado{
    seq = Seq,
    last_hash = maps:get(hash, Ev),
    relojes = maps:put(Disp, Reloj1, Estado#estado.relojes)
  },
  case Desfasado of
    true -> metricas(inc, [alertas_reloj]);
    false -> ok
  end,
  {Ev, Estado2}.

insertar_en_memoria(Ev, Estado) ->
  Ts = maps:get(ts_corregido, Ev),
  Seq = maps:get(seq, Ev),
  SegId = segmento_de(Ts, Estado#estado.segundos),
  Estado2 = asegurar_segmento(SegId, Estado),
  Meta = maps:get(SegId, Estado2#estado.segmentos),
  ok = p69_almacen:insertar(maps:get(almacen, Meta), Ev),
  true = ets:insert(Estado2#estado.tid_seq, {Seq, Ev}),
  true = ets:insert(Estado2#estado.tid_hash, {Seq, #{
    hash => maps:get(hash, Ev), hash_prev => maps:get(hash_prev, Ev)
  }}),
  Estado2.

corte_retencion(#estado{segundos = _Segundos}) ->
  Dias = p69_config:get(retencion_dias, 30),
  case Dias of
    0 -> 0;
    _ -> ahora() - Dias * 86400 * 1000000
  end.

%% Segmentos y consultas

segmento_de(Ts, Segundos) ->
  Ts div (Segundos * 1000000).

asegurar_segmento(SegId, Estado) ->
  case maps:is_key(SegId, Estado#estado.segmentos) of
    true ->
      Estado;
    false ->
      Segundos = Estado#estado.segundos,
      Desde = SegId * Segundos * 1000000,
      Hasta = Desde + Segundos * 1000000 - 1,
      Almacen = p69_almacen:crear(),
      Meta = #{almacen => Almacen, desde => Desde, hasta => Hasta},
      Estado#estado{segmentos = maps:put(SegId, Meta, Estado#estado.segmentos)}
  end.

registrar_pines(Desde, Hasta, Estado) ->
  Segundos = Estado#estado.segundos,
  Ids = lists:seq(
    segmento_de(Desde, Segundos),
    segmento_de(Hasta, Segundos)
  ),
  Existentes = [{Id, maps:get(almacen, Meta)}
    || Id <- Ids, {ok, Meta} <- [maps:find(Id, Estado#estado.segmentos)]],
  Ref = make_ref(),
  Counts = lists:foldl(
    fun({Id, _}, Acc) -> maps:update_with(Id, fun(N) -> N + 1 end, 1, Acc) end,
    Estado#estado.pin_counts,
    Existentes
  ),
  Estado2 = Estado#estado{
    pines = maps:put(Ref, [Id || {Id, _} <- Existentes], Estado#estado.pines),
    pin_counts = Counts
  },
  {Ref, Existentes, Estado2}.

liberar_pines(Ref, Estado) ->
  case maps:take(Ref, Estado#estado.pines) of
    error ->
      Estado;
    {Ids, Pines2} ->
      Counts = lists:foldl(
        fun(Id, Acc) ->
          case maps:find(Id, Acc) of
            {ok, 1} -> maps:remove(Id, Acc);
            {ok, N} -> maps:put(Id, N - 1, Acc);
            error -> Acc
          end
        end,
        Estado#estado.pin_counts,
        Ids
      ),
      Estado#estado{pines = Pines2, pin_counts = Counts}
  end.

%% Retencion

retener_segmentos(CorteTs, Estado) ->
  Expirados = [Id || {Id, Meta} <- maps:to_list(Estado#estado.segmentos),
                     maps:get(hasta, Meta) < CorteTs],
  lists:foldl(
    fun(Id, {Acc, Est}) ->
      case bajar_segmento(Id, Est) of
        {ok, Est2} -> {[{Id, ok} | Acc], Est2};
        {error, Motivo} -> {[{Id, Motivo} | Acc], Est}
      end
    end,
    {[], Estado},
    lists:sort(Expirados)
  ).

bajar_segmento(SegId, Estado) ->
  case maps:find(SegId, Estado#estado.segmentos) of
    error ->
      {error, no_existe};
    {ok, _Meta} ->
      case maps:get(SegId, Estado#estado.pin_counts, 0) of
        N when N > 0 ->
          {error, en_uso};
        _ ->
          bajar_segmento_ahora(SegId, Estado)
      end
  end.

bajar_segmento_ahora(SegId, Estado) ->
  Meta = maps:get(SegId, Estado#estado.segmentos),
  Almacen = maps:get(almacen, Meta),
  {Count, MinSeq, MaxSeq} = p69_almacen:plegar(
    fun(Ev, {C, Min, Max}) ->
      Seq = maps:get(seq, Ev),
      true = ets:delete(Estado#estado.tid_seq, Seq),
      {C + 1, min(Min, Seq), max(Max, Seq)}
    end,
    {0, 999999999999, 0},
    Almacen
  ),
  CpSeq = Estado#estado.cp_seq + 1,
  CpBase = #{
    cp_seq => CpSeq,
    tipo => baja_segmento,
    segmento => SegId,
    primer_seq => MinSeq,
    ultimo_seq => MaxSeq,
    eventos => Count,
    hash_ultimo_evento => Estado#estado.last_hash,
    hash_prev => Estado#estado.last_cp_hash,
    ts => ahora()
  },
  Hash = p69_cadena:hash_checkpoint(Estado#estado.last_cp_hash, CpBase),
  Cp = CpBase#{hash => Hash},
  case p69_wal:agregar(Estado#estado.wal, #{tipo => checkpoint, checkpoint => Cp}) of
    ok ->
      case p69_wal:sincronizar(Estado#estado.wal) of
        ok ->
          true = ets:insert(Estado#estado.tid_cp, {CpSeq, Cp}),
          ok = p69_almacen:borrar(Almacen),
          Segmentos2 = maps:remove(SegId, Estado#estado.segmentos),
          Pines2 = maps:remove(SegId, Estado#estado.pin_counts),
          metricas(inc, [retencion_segmentos, {retencion_eventos, Count}]),
          logger:info("segmento eliminado por retencion", #{
            segmento => SegId, eventos => Count
          }),
          {ok, Estado#estado{
            segmentos = Segmentos2,
            pin_counts = Pines2,
            cp_seq = CpSeq,
            last_cp_hash = Hash
          }};
        {error, Motivo} ->
          {error, Motivo}
      end;
    {error, Motivo} ->
      {error, Motivo}
  end.

%% Recuperacion desde WAL

recuperar(Estado0) ->
  case p69_wal:recuperar(Estado0#estado.dir) of
    {ok, Terminos} ->
      {Estado1, Eliminados} = lists:foldl(fun recuperar_termino/2, {Estado0, []}, Terminos),
      lists:foldl(fun eliminar_segmento_recuperado/2, Estado1, lists:usort(Eliminados));
    {error, Motivo} ->
      logger:warning("no se pudo leer el WAL: ~p", [Motivo]),
      Estado0
  end.

recuperar_termino(#{tipo := evento, evento := Ev}, {Estado, Eliminados}) ->
  {insertar_recuperado(Ev, Estado), Eliminados};
recuperar_termino(#{tipo := checkpoint, checkpoint := Cp}, {Estado, Eliminados}) ->
  {registrar_cp_recuperado(Cp, Estado), [maps:get(segmento, Cp) | Eliminados]};
recuperar_termino(_Otro, Acc) ->
  Acc.

insertar_recuperado(Ev, Estado) ->
  Ts = maps:get(ts_corregido, Ev),
  Seq = maps:get(seq, Ev),
  SegId = segmento_de(Ts, Estado#estado.segundos),
  Estado2 = asegurar_segmento(SegId, Estado),
  Meta = maps:get(SegId, Estado2#estado.segmentos),
  ok = p69_almacen:insertar(maps:get(almacen, Meta), Ev),
  true = ets:insert(Estado2#estado.tid_seq, {Seq, Ev}),
  true = ets:insert(Estado2#estado.tid_hash, {Seq, #{
    hash => maps:get(hash, Ev), hash_prev => maps:get(hash_prev, Ev)
  }}),
  Estado3 =
    case Seq > Estado2#estado.seq of
      true -> Estado2#estado{seq = Seq, last_hash = maps:get(hash, Ev)};
      false -> Estado2
    end,
  actualizar_reloj_recuperado(Ev, Estado3).

actualizar_reloj_recuperado(Ev, Estado) ->
  Disp = maps:get(dispositivo_id, Ev),
  Reloj0 = maps:get(Disp, Estado#estado.relojes, p69_reloj:nuevo()),
  Reloj1 = p69_reloj:agregar(
    Reloj0,
    maps:get(ts_evento, Ev),
    maps:get(ts_recepcion, Ev),
    #{max_muestras => Estado#estado.max_muestras,
      umbral_reloj_micros => Estado#estado.umbral_reloj}
  ),
  Estado#estado{relojes = maps:put(Disp, Reloj1, Estado#estado.relojes)}.

registrar_cp_recuperado(Cp, Estado) ->
  CpSeq = maps:get(cp_seq, Cp),
  true = ets:insert(Estado#estado.tid_cp, {CpSeq, Cp}),
  case CpSeq > Estado#estado.cp_seq of
    true -> Estado#estado{cp_seq = CpSeq, last_cp_hash = maps:get(hash, Cp)};
    false -> Estado
  end.

eliminar_segmento_recuperado(SegId, Estado) ->
  case maps:find(SegId, Estado#estado.segmentos) of
    error ->
      Estado;
    {ok, Meta} ->
      Almacen = maps:get(almacen, Meta),
      _ = p69_almacen:plegar(
        fun(Ev, Acc) ->
          true = ets:delete(Estado#estado.tid_seq, maps:get(seq, Ev)),
          Acc
        end,
        ok,
        Almacen
      ),
      ok = p69_almacen:borrar(Almacen),
      Estado#estado{
        segmentos = maps:remove(SegId, Estado#estado.segmentos),
        pin_counts = maps:remove(SegId, Estado#estado.pin_counts)
      }
  end.

%% Verificacion

recolectar_filas(TidHash, TidSeq, MaxSeq) ->
  recolectar_filas(TidHash, TidSeq, ets:first(TidHash), MaxSeq, []).

recolectar_filas(_TidHash, _TidSeq, '$end_of_table', _MaxSeq, Acc) ->
  lists:reverse(Acc);
recolectar_filas(_TidHash, _TidSeq, Seq, MaxSeq, Acc) when Seq > MaxSeq ->
  _ = Seq,
  lists:reverse(Acc);
recolectar_filas(TidHash, TidSeq, Seq, MaxSeq, Acc) ->
  [{Seq, Meta}] = ets:lookup(TidHash, Seq),
  Evento = case ets:lookup(TidSeq, Seq) of
    [{Seq, Ev}] -> Ev;
    [] -> undefined
  end,
  Fila = {Seq, Evento, maps:get(hash, Meta), maps:get(hash_prev, Meta)},
  recolectar_filas(TidHash, TidSeq, ets:next(TidHash, Seq), MaxSeq, [Fila | Acc]).

%% Auxiliares

sobrecargada(#estado{umbral_429 = Umbral}) ->
  case erlang:process_info(self(), message_queue_len) of
    {message_queue_len, N} -> N > Umbral;
    undefined -> false
  end.

notificar(Ev) ->
  case whereis(p69_sitios) of
    undefined -> ok;
    _ -> p69_sitios:notificar(Ev)
  end.

metricas(Fun, Args) ->
  case whereis(p69_metricas) of
    undefined -> ok;
    _ -> apply(p69_metricas, Fun, Args)
  end.

ahora() ->
  erlang:system_time(microsecond).
