%% Publicador minimo para WebSocket: un hilo reparte eventos a las colas de los
%% clientes conectados. No guarda estado de dominio ni bloquea a la bitacora.
:- module(p69_pub, [
  iniciar/0,
  publicar/1,
  suscribir/1,
  desuscribir/1
]).

:- use_module(library(lists)).

:- dynamic pub_thread/1.

iniciar :-
  ( pub_thread(Id),
    catch(thread_property(Id, status(_)), _, fail) ->
      true
  ; retractall(pub_thread(_)),
    thread_create(loop, Nuevo, [detached(true)]),
    assertz(pub_thread(Nuevo))
  ).

publicar(Evento) :-
  ( pub_thread(Id) ->
      catch(thread_send_message(Id, {publicar, Evento}), _, true)
  ; true
  ).

suscribir(Cola) :-
  ( pub_thread(Id) ->
      catch(thread_send_message(Id, {suscribir, Cola}), _, true)
  ; true
  ).

desuscribir(Cola) :-
  ( pub_thread(Id) ->
      catch(thread_send_message(Id, {desuscribir, Cola}), _, true)
  ; true
  ).

loop :-
  loop([]).

loop(Subs0) :-
  thread_get_message(Mensaje),
  ( Mensaje = {suscribir, Cola} ->
      ( memberchk(Cola, Subs0) -> Subs = Subs0 ; Subs = [Cola | Subs0] )
  ; Mensaje = {desuscribir, Cola} ->
      delete(Subs0, Cola, Subs)
  ; Mensaje = {publicar, Evento} ->
      repartir(Subs0, Evento),
      Subs = Subs0
  ; Subs = Subs0
  ),
  loop(Subs).

repartir([], _Evento).
repartir([Cola | Resto], Evento) :-
  catch(thread_send_message(Cola, {evento, Evento}), _, true),
  repartir(Resto, Evento).
