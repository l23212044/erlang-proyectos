%% Utilidades compartidas por los handlers HTTP: respuestas JSON, lectura de
%% cuerpo, conversion de eventos/dispositivos y parseo de query string.
-module(p69_api).

-export([
  json/3,
  error/4,
  sobrecarga/1,
  evento/1,
  dispositivo/1,
  leer_json/1,
  qs/1,
  q/3,
  filtros/1,
  ts/2,
  iso/1,
  a_bin/1,
  clave_texto/1
]).

-spec json(non_neg_integer(), term(), cowboy_req:req()) -> {ok, cowboy_req:req(), term()}.
json(Status, Termino, Req) ->
  Req2 = cowboy_req:reply(
    Status,
    #{<<"content-type">> => <<"application/json; charset=utf-8">>},
    json:encode(Termino),
    Req
  ),
  {ok, Req2, none}.

-spec error(non_neg_integer(), binary(), binary(), cowboy_req:req()) ->
  {ok, cowboy_req:req(), term()}.
error(Status, Codigo, Mensaje, Req) ->
  json(Status, #{error => #{codigo => Codigo, mensaje => Mensaje}}, Req).

-spec sobrecarga(cowboy_req:req()) -> {ok, cowboy_req:req(), term()}.
sobrecarga(Req) ->
  Req2 = cowboy_req:reply(
    503,
    #{
      <<"content-type">> => <<"application/json; charset=utf-8">>,
      <<"retry-after">> => <<"1">>
    },
    json:encode(#{error => #{
      codigo => <<"sobrecarga">>,
      mensaje => <<"cola de ingesta llena; reintente en 1 segundo">>
    }}),
    Req
  ),
  {ok, Req2, none}.

%% Lee y decodifica el cuerpo completo. Devuelve el req actualizado.
-spec leer_json(cowboy_req:req()) ->
  {ok, term(), cowboy_req:req()} | {error, term(), cowboy_req:req()}.
leer_json(Req0) ->
  leer_json(Req0, []).

leer_json(Req0, Acc) ->
  case cowboy_req:read_body(Req0, #{length => 1048576, period => 5000}) of
    {ok, Datos, Req} ->
      decodificar(iolist_to_binary(lists:reverse([Datos | Acc])), Req);
    {more, Datos, Req} ->
      leer_json(Req, [Datos | Acc])
  end.

decodificar(Bin, Req) when byte_size(Bin) =:= 0 ->
  {error, cuerpo_vacio, Req};
decodificar(Bin, Req) ->
  try {ok, json:decode(Bin), Req}
  catch _:_ -> {error, json_invalido, Req}
  end.

-spec qs(cowboy_req:req()) -> map().
qs(Req) ->
  maps:from_list(cowboy_req:parse_qs(Req)).

-spec q(map(), binary(), binary() | undefined) -> binary() | undefined.
q(Query, Nombre, Default) ->
  maps:get(Nombre, Query, Default).

-spec filtros(map()) -> map().
filtros(Query) ->
  Filtros0 = #{
    edificio => q(Query, <<"edificio">>, undefined),
    dispositivo => case q(Query, <<"camara">>, undefined) of
      undefined -> q(Query, <<"dispositivo">>, undefined);
      Camara -> Camara
    end,
    tipo => q(Query, <<"tipo">>, undefined),
    persona => q(Query, <<"persona">>, undefined)
  },
  maps:filter(fun(_K, V) -> V =/= undefined end, Filtros0).

%% Convierte el parametro de tiempo a microsegundos. Lanza {error, Motivo}
%% mediante throw para que el handler responda 400.
-spec ts(map(), binary()) -> integer() | undefined.
ts(Query, Nombre) ->
  case q(Query, Nombre, undefined) of
    undefined -> undefined;
    Bin ->
      try p69_evento:ts_a_micros(Bin)
      catch throw:{error, Motivo} -> throw({error, {parametro_invalido, Nombre, Motivo}})
      end
  end.

-spec iso(integer()) -> binary() | null.
iso(Micros) when is_integer(Micros) ->
  try list_to_binary(calendar:system_time_to_rfc3339(Micros, [
    {unit, microsecond}, {offset, "Z"}
  ]))
  catch _:_ -> null
  end;
iso(_) -> null.

-spec evento(map()) -> map().
evento(Ev) ->
  #{
    <<"seq">> => maps:get(seq, Ev),
    <<"dispositivo_id">> => maps:get(dispositivo_id, Ev),
    <<"tipo_dispositivo">> => a_bin(maps:get(tipo_dispositivo, Ev)),
    <<"edificio">> => maps:get(edificio, Ev),
    <<"tipo_evento">> => maps:get(tipo_evento, Ev),
    <<"persona">> => persona(maps:get(persona, Ev, undefined)),
    <<"ts_evento">> => maps:get(ts_evento, Ev),
    <<"ts_evento_iso">> => iso(maps:get(ts_evento, Ev)),
    <<"ts_corregido">> => maps:get(ts_corregido, Ev),
    <<"ts_corregido_iso">> => iso(maps:get(ts_corregido, Ev)),
    <<"ts_recepcion">> => maps:get(ts_recepcion, Ev),
    <<"ts_recepcion_iso">> => iso(maps:get(ts_recepcion, Ev)),
    <<"offset_reloj">> => maps:get(offset_reloj, Ev, 0),
    <<"desfasado">> => maps:get(desfasado, Ev, false),
    <<"hash_prev">> => hex(maps:get(hash_prev, Ev, <<>>)),
    <<"hash">> => hex(maps:get(hash, Ev, <<>>))
  }.

-spec dispositivo(map()) -> map().
dispositivo(Dev) ->
  #{
    <<"id">> => maps:get(id, Dev),
    <<"tipo">> => a_bin(maps:get(tipo, Dev)),
    <<"edificio">> => maps:get(edificio, Dev),
    <<"estado">> => a_bin(maps:get(estado, Dev)),
    <<"ultimo_latido">> => maps:get(ultimo_latido, Dev),
    <<"ultimo_latido_iso">> => iso(maps:get(ultimo_latido, Dev)),
    <<"offset_segundos">> => maps:get(offset_segundos, Dev, 0),
    <<"desfasado">> => maps:get(desfasado, Dev, false),
    <<"contadores">> => maps:get(contadores, Dev, #{}),
    <<"recientes">> => [evento(Ev) || Ev <- maps:get(recientes, Dev, [])]
  }.

-spec a_bin(term()) -> binary().
a_bin(B) when is_binary(B) -> B;
a_bin(A) when is_atom(A) -> atom_to_binary(A, utf8);
a_bin(I) when is_integer(I) -> integer_to_binary(I);
a_bin(Otro) -> iolist_to_binary(io_lib:format("~p", [Otro])).

-spec clave_texto(term()) -> binary().
clave_texto(A) when is_atom(A) -> atom_to_binary(A, utf8);
clave_texto(B) when is_binary(B) -> B;
clave_texto(Otro) -> iolist_to_binary(io_lib:format("~p", [Otro])).

persona(undefined) -> null;
persona(P) -> P.

hex(Bin) -> binary:encode_hex(Bin).
