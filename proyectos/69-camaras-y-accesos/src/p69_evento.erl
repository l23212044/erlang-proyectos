%% Logica pura del evento: normalizacion, timestamps, cadena de hashes y
%% correccion de reloj. No conoce procesos ni ETS, lo que la hace facil de probar.
-module(p69_evento).

-export([
  normalizar/1,
  ts_a_micros/1,
  preparar/5,
  canonico/1,
  hash/2,
  verificar_hash/1,
  estimar_offset/1,
  desfasado/2,
  mediana/1
]).

-export_type([evento/0, tipo_dispositivo/0]).

-type tipo_dispositivo() :: puerta | camara.
-type evento() :: #{
  seq := non_neg_integer(),
  dispositivo_id := binary(),
  tipo_dispositivo := tipo_dispositivo(),
  edificio := binary(),
  tipo_evento := binary(),
  persona := binary() | undefined,
  ts_evento := integer(),
  ts_corregido := integer(),
  ts_recepcion := integer(),
  offset_reloj := integer(),
  desfasado := boolean(),
  hash_prev := binary(),
  hash := binary()
}.

%% Normaliza una entrada externa (mapa con llaves atom o binario) y valida
%% los campos minimos. Devuelve el evento aun sin seq/hash.
-spec normalizar(map()) -> {ok, map()} | {error, term()}.
normalizar(Map) when is_map(Map) ->
  try
    Disp = a_binario(obtener([dispositivo_id, <<"dispositivo_id">>], Map)),
    TipoDisp = tipo_dispositivo(obtener([tipo_dispositivo, <<"tipo_dispositivo">>], Map)),
    Edificio = a_binario(obtener([edificio, <<"edificio">>], Map)),
    TipoEvento = a_binario(obtener([tipo_evento, <<"tipo_evento">>], Map)),
    Persona = persona(obtener([persona, <<"persona">>], Map, undefined)),
    TsEvento = ts_a_micros(obtener([ts_evento, <<"ts_evento">>, ts, <<"ts">>], Map)),
    TsRecepcion = ts_a_micros(
      obtener([ts_recepcion, <<"ts_recepcion">>], Map, erlang:system_time(microsecond))
    ),
    validar_texto(dispositivo_id, Disp),
    validar_texto(edificio, Edificio),
    validar_texto(tipo_evento, TipoEvento),
    {ok, #{
      dispositivo_id => Disp,
      tipo_dispositivo => TipoDisp,
      edificio => Edificio,
      tipo_evento => TipoEvento,
      persona => Persona,
      ts_evento => TsEvento,
      ts_recepcion => TsRecepcion
    }}
  catch
    throw:{error, Motivo} -> {error, Motivo};
    error:Razon -> {error, {entrada_invalida, Razon}}
  end;
normalizar(Otro) ->
  {error, {entrada_invalida, Otro}}.

%% Acepta epoch en segundos, milisegundos o microsegundos, o ISO-8601.
-spec ts_a_micros(integer() | binary() | list()) -> integer().
ts_a_micros(Ts) when is_integer(Ts) ->
  normalizar_escala(Ts);
ts_a_micros(Ts) when is_binary(Ts); is_list(Ts) ->
  Bin = a_binario(Ts),
  case es_entero(Bin) of
    {true, Entero} ->
      normalizar_escala(Entero);
    false ->
      try calendar:rfc3339_to_system_time(binary_to_list(Bin), [{unit, microsecond}])
      catch
        _:_ -> throw({error, {ts_invalido, Bin}})
      end
  end;
ts_a_micros(Otro) ->
  throw({error, {ts_invalido, Otro}}).

normalizar_escala(Ts) when Ts < 100000000000 -> Ts * 1000000;
normalizar_escala(Ts) when Ts < 100000000000000 -> Ts * 1000;
normalizar_escala(Ts) -> Ts.

%% Construye la version final del evento con seq, correccion de reloj y hashes.
-spec preparar(map(), non_neg_integer(), binary(), integer(), boolean()) -> evento().
preparar(Evento0, Seq, HashPrev, Offset, Desfasado) ->
  TsCorregido = maps:get(ts_evento, Evento0) + Offset,
  Evento1 = Evento0#{
    seq => Seq,
    ts_corregido => TsCorregido,
    offset_reloj => Offset,
    desfasado => Desfasado,
    hash_prev => HashPrev
  },
  Evento1#{hash => hash(HashPrev, Evento1)}.

%% Serializacion determinista para hashear. No se usa term_to_binary de mapas
%% porque el orden de las llaves no es parte del contrato.
-spec canonico(map()) -> binary().
canonico(Evento) ->
  iolist_to_binary([
    "seq=", entero(maps:get(seq, Evento)),
    "|disp=", bin(maps:get(dispositivo_id, Evento)),
    "|tdisp=", atom_to_binary(maps:get(tipo_dispositivo, Evento), utf8),
    "|edif=", bin(maps:get(edificio, Evento)),
    "|tevento=", bin(maps:get(tipo_evento, Evento)),
    "|persona=", bin(maps:get(persona, Evento, undefined)),
    "|tse=", entero(maps:get(ts_evento, Evento)),
    "|tsc=", entero(maps:get(ts_corregido, Evento)),
    "|tsr=", entero(maps:get(ts_recepcion, Evento)),
    "|offset=", entero(maps:get(offset_reloj, Evento)),
    "|desf=", atom_to_binary(maps:get(desfasado, Evento), utf8),
    "|prev=", bin(maps:get(hash_prev, Evento))
  ]).

-spec hash(binary(), map()) -> binary().
hash(HashPrev, Evento) when is_binary(HashPrev) ->
  crypto:hash(sha256, <<HashPrev/binary, (canonico(Evento))/binary>>).

-spec verificar_hash(map()) -> boolean().
verificar_hash(Evento) ->
  Prev = maps:get(hash_prev, Evento),
  maps:get(hash, Evento) =:= hash(Prev, Evento).

%% Mediana de (ts_recepcion - ts_evento). Robusta ante valores atipicos de red.
-spec estimar_offset([integer()]) -> integer().
estimar_offset([]) -> 0;
estimar_offset(Deltas) -> mediana(Deltas).

-spec mediana([integer()]) -> integer().
mediana([]) -> 0;
mediana(Lista) ->
  Ordenada = lists:sort(Lista),
  N = length(Ordenada),
  Mitad = N div 2,
  case N rem 2 of
    1 -> lists:nth(Mitad + 1, Ordenada);
    0 -> (lists:nth(Mitad, Ordenada) + lists:nth(Mitad + 1, Ordenada)) div 2
  end.

-spec desfasado(integer(), non_neg_integer()) -> boolean().
desfasado(Offset, Umbral) -> abs(Offset) > Umbral.

%% Internos

obtener(Llaves, Map) ->
  case obtener(Llaves, Map, '$sin_valor') of
    '$sin_valor' -> throw({error, {campo_requerido, hd(Llaves)}});
    Valor -> Valor
  end.

obtener([], _Map, Default) -> Default;
obtener([Llave | Resto], Map, Default) ->
  case maps:find(Llave, Map) of
    {ok, Valor} when Valor =/= undefined -> Valor;
    _ -> obtener(Resto, Map, Default)
  end.

tipo_dispositivo(puerta) -> puerta;
tipo_dispositivo(camara) -> camara;
tipo_dispositivo(<<"puerta">>) -> puerta;
tipo_dispositivo(<<"camara">>) -> camara;
tipo_dispositivo("puerta") -> puerta;
tipo_dispositivo("camara") -> camara;
tipo_dispositivo(Otro) -> throw({error, {tipo_dispositivo_invalido, Otro}}).

persona(undefined) -> undefined;
persona(null) -> undefined;
persona(<<"">>) -> undefined;
persona(P) -> a_binario(P).

validar_texto(_Campo, <<>>) -> throw({error, {campo_vacio, _Campo}});
validar_texto(_Campo, _Valor) -> ok.

a_binario(B) when is_binary(B) -> B;
a_binario(A) when is_atom(A) -> atom_to_binary(A, utf8);
a_binario(L) when is_list(L) -> unicode:characters_to_binary(L);
a_binario(I) when is_integer(I) -> integer_to_binary(I);
a_binario(Otro) -> throw({error, {valor_no_textual, Otro}}).

es_entero(Bin) ->
  try {true, binary_to_integer(Bin)}
  catch _:_ -> false
  end.

entero(I) -> integer_to_binary(I).
bin(undefined) -> <<"-">>;
bin(B) when is_binary(B) -> B.
