-module(p69_camaras_y_accesos_tests).
-include_lib("eunit/include/eunit.hrl").

arbol_de_supervision_test_() ->
  {setup,
   fun() ->
     Dir = p69_test_util:dir(),
     p69_test_util:config(datos_dir, Dir),
     p69_test_util:config(retencion_dias, 0),
     p69_test_util:config(puerto, 0),
     p69_test_util:config(num_aceptores, 5),
     {ok, Pid} = p69_camaras_y_accesos_sup:start_link(),
     #{dir => Dir, pid => Pid}
   end,
   fun(#{dir := Dir, pid := Pid}) ->
     unlink(Pid),
     exit(Pid, shutdown),
     p69_test_util:limpiar(Dir)
   end,
   fun(_Ctx) ->
     [?_assertEqual(pong, p69_camaras_y_accesos_server:ping()),
      ?_assert(is_map(p69_camaras_y_accesos_server:state())),
      ?_assert(is_map(p69_bitacora:estado()))]
   end}.
