%% WebSocket /ws/eventos. El hilo de la conexion atiende ping/close; un hilo
%% emisor independiente manda eventos y resumenes sin bloquear la recepcion.
:- module(p69_ws, [
  handler/1
]).

:- use_module(library(http/websocket)).
:- use_module(library(http/json)).
:- use_module(p69_json).
:- use_module(p69_pub).

handler(Request) :-
  http_upgrade_to_websocket(conectar, [], Request).

conectar(WebSocket) :-
  message_queue_create(Q),
  p69_pub:suscribir(Q),
  catch((p69_json:resumen(Resumen0), enviar(WebSocket, Resumen0)), _, true),
  thread_create(emisor(WebSocket, Q), Emisor, [detached(true)]),
  ws_loop(WebSocket),
  limpiar(Q, Emisor).

ws_loop(WebSocket) :-
  catch(ws_receive(WebSocket, Mensaje), _, fail),
  ( Mensaje.opcode == close ->
      true
  ; Mensaje.opcode == text, Mensaje.data == "ping" ->
      catch(ws_send(WebSocket, text("pong")), _, true),
      ws_loop(WebSocket)
  ; ws_loop(WebSocket)
  ).

emisor(WebSocket, Q) :-
  catch(thread_get_message(Q, Mensaje, [timeout(5)]), error(timeout, _), Mensaje = timeout),
  ( Mensaje == fin ->
      true
  ; Mensaje == timeout ->
      ( catch(p69_json:resumen(Resumen), _, fail) ->
          catch(enviar(WebSocket, Resumen), _, true)
      ; true
      ),
      emisor(WebSocket, Q)
  ; Mensaje = {evento, Ev} ->
      ( catch(p69_json:evento(Ev, Evento), _, fail) ->
          catch(enviar(WebSocket, _{tipo: "evento", evento: Evento}), _, true)
      ; true
      ),
      emisor(WebSocket, Q)
  ; emisor(WebSocket, Q)
  ).

enviar(WebSocket, Dict) :-
  with_output_to(string(Texto), json_write_dict(current_output, Dict, [])),
  ws_send(WebSocket, text(Texto)).


limpiar(Q, Emisor) :-
  p69_pub:desuscribir(Q),
  catch(thread_send_message(Q, fin), _, true),
  catch(thread_join(Emisor, _), _, true),
  catch(message_queue_destroy(Q), _, true).
