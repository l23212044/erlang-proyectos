%% Arranque de la version Prolog: configuracion, bitacora, publicador y HTTP.
:- module(p69_app, [
  iniciar/0,
  detener/0
]).

:- use_module(p69_config).
:- use_module(p69_bitacora).
:- use_module(p69_pub).
:- use_module(p69_http).

iniciar :-
  p69_config:cargar('config.pl'),
  p69_config:get(datos_dir, Dir),
  ( exists_directory(Dir) -> true ; make_directory_paths(Dir, _) ),
  p69_bitacora:start_link,
  p69_pub:iniciar,
  p69_http:iniciar.

detener :-
  p69_http:detener,
  p69_simulador:detener_vivo.
