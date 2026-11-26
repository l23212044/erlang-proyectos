%% WAL append-only en terminos Prolog. Cada registro es un termino seguido de
%% punto y salto de linea. SWI no expone fsync/1 en su libreria estandar; se
%% usa flush_output/1 y se documenta que la durabilidad es menor que en Erlang.
:- module(p69_wal, [
  abrir/2,
  cerrar/1,
  agregar/2,
  agregar_lote/2,
  sincronizar/1,
  recuperar/2,
  ruta/2
]).

ruta(Dir, Ruta) :-
  atomic_list_concat([Dir, '/bitacora.wal'], Ruta).

abrir(Dir, Handle) :-
  ruta(Dir, Ruta),
  file_directory_name(Ruta, Padre),
  ( exists_directory(Padre) -> true ; make_directory_paths(Padre, _) ),
  open(Ruta, append, Handle, [encoding(utf8)]).

cerrar(Handle) :-
  catch(close(Handle), _, true).

agregar(Handle, Termino) :-
  agregar_lote(Handle, [Termino]).

agregar_lote(Handle, Terminos) :-
  escribir_todos(Handle, Terminos),
  flush_output(Handle).

escribir_todos(_Handle, []).
escribir_todos(Handle, [Termino | Resto]) :-
  write_term(Handle, Termino, [quoted(true), fullstop(true)]),
  escribir_todos(Handle, Resto).

sincronizar(Handle) :-
  flush_output(Handle).

recuperar(Dir, Terminos) :-
  ruta(Dir, Ruta),
  ( exists_file(Ruta) ->
      open(Ruta, read, Handle, [encoding(utf8)]),
      leer_todos(Handle, [], Terminos),
      close(Handle)
  ; Terminos = []
  ).

leer_todos(Handle, Acc, Terminos) :-
  catch(read_term(Handle, T, [syntax_errors(fail)]), _, T = end_of_file),
  ( T == end_of_file ->
      reverse(Acc, Terminos)
  ; leer_todos(Handle, [T | Acc], Terminos)
  ).
