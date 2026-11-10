%% Write-ahead log propio: archivo append-only con registros enmarcados
%% (longitud de 32 bits + term_to_binary). Se sincroniza antes de confirmar
%% la ingesta. Al recuperar se ignora una cola truncada por un corte de luz.
-module(p69_wal).

-export([abrir/1, cerrar/1, agregar/2, agregar_lote/2, sincronizar/1, recuperar/1]).

-export_type([wal/0]).

-type wal() :: #{fd := file:io_device(), ruta := file:filename_all()}.

-spec abrir(file:filename_all()) -> {ok, wal()} | {error, term()}.
abrir(Dir) ->
  ok = filelib:ensure_dir(filename:join(Dir, "bitacora.wal")),
  Ruta = filename:join(Dir, "bitacora.wal"),
  case file:open(Ruta, [append, raw, binary]) of
    {ok, Fd} -> {ok, #{fd => Fd, ruta => Ruta}};
    {error, Motivo} -> {error, {wal_no_abre, Ruta, Motivo}}
  end.

-spec cerrar(wal()) -> ok.
cerrar(#{fd := Fd}) ->
  _ = file:close(Fd),
  ok.

-spec agregar(wal(), term()) -> ok | {error, term()}.
agregar(Wal, Termino) ->
  agregar_lote(Wal, [Termino]).

-spec agregar_lote(wal(), [term()]) -> ok | {error, term()}.
agregar_lote(#{fd := Fd}, Terminos) ->
  Datos = [enmarcar(T) || T <- Terminos],
  case file:write(Fd, Datos) of
    ok -> ok;
    {error, Motivo} -> {error, {wal_escritura, Motivo}}
  end.

-spec sincronizar(wal()) -> ok | {error, term()}.
sincronizar(#{fd := Fd}) ->
  case file:sync(Fd) of
    ok -> ok;
    {error, Motivo} -> {error, {wal_sync, Motivo}}
  end.

-spec recuperar(file:filename_all()) -> {ok, [term()]} | {error, term()}.
recuperar(Dir) ->
  Ruta = filename:join(Dir, "bitacora.wal"),
  case file:read_file(Ruta) of
    {ok, Bin} -> {ok, desenmarcar(Bin, [])};
    {error, enoent} -> {ok, []};
    {error, Motivo} -> {error, {wal_lectura, Ruta, Motivo}}
  end.

enmarcar(Termino) ->
  Bin = term_to_binary(Termino),
  <<(byte_size(Bin)):32/unsigned-big, Bin/binary>>.

desenmarcar(<<>>, Acc) ->
  lists:reverse(Acc);
desenmarcar(<<Longitud:32/unsigned-big, Resto/binary>>, Acc) ->
  case Resto of
    <<Bin:Longitud/binary, Siguiente/binary>> ->
      case term_seguro(Bin) of
        {ok, Termino} -> desenmarcar(Siguiente, [Termino | Acc]);
        {error, _} -> lists:reverse(Acc)
      end;
    _ ->
      %% Registro incompleto al final: se descarta.
      lists:reverse(Acc)
  end;
desenmarcar(_Basura, Acc) ->
  lists:reverse(Acc).

term_seguro(Bin) ->
  try {ok, binary_to_term(Bin)}
  catch _:_ -> {error, termino_corrupto}
  end.
