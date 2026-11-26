%% Configuracion del backend Prolog. Los valores por defecto se pueden
%% sobreescribir con un archivo config.pl en el directorio de trabajo.
:- module(p69_config, [get/2, cargar/1]).

:- dynamic config/2.

get(Clave, Valor) :-
  ( config(Clave, V) -> Valor = V ; default(Clave, Valor) ).

cargar(Archivo) :-
  ( exists_file(Archivo) ->
      consult(Archivo)
  ; true
  ).

default(puerto, 8090).
default(interfaz, '0.0.0.0').
default(num_aceptores, 16).
default(datos_dir, 'data').
default(web_dir, 'web').
default(retencion_dias, 30).
default(retencion_intervalo_seg, 3600).
default(segmento_segundos, 86400).
default(ingesta_umbral_429, 80000).
default(umbral_reloj_seg, 60).
default(reloj_max_muestras, 15).
default(dispositivo_timeout_seg, 120).
