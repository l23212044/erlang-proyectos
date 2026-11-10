-module(p69_simulador_tests).
-include_lib("eunit/include/eunit.hrl").

iniciar() ->
  Dir = p69_test_util:dir(),
  p69_test_util:config(datos_dir, Dir),
  p69_test_util:config(retencion_dias, 0),
  p69_test_util:config(segmento_segundos, 3600),
  p69_test_util:config(puerto, 0),
  p69_test_util:config(num_aceptores, 5),
  {ok, Pid} = p69_camaras_y_accesos_sup:start_link(),
  #{dir => Dir, pid => Pid}.

detener(#{dir := Dir, pid := Pid}) ->
  unlink(Pid),
  exit(Pid, shutdown),
  p69_test_util:limpiar(Dir).

simulador_test_() ->
  {setup, fun iniciar/0, fun detener/1, fun(Ctx) ->
    [
      fun() -> dispositivos(Ctx) end,
      fun() -> historico(Ctx) end,
      fun() -> carga_en_vivo(Ctx) end,
      fun() -> recuperacion_de_sitio(Ctx) end
    ]
  end}.

dispositivos(_Ctx) ->
  Lista = p69_simulador:dispositivos(),
  ?assertEqual(300, length(Lista)),
  ?assertEqual(100, length([D || D <- Lista, maps:get(tipo, D) =:= puerta])),
  ?assertEqual(200, length([D || D <- Lista, maps:get(tipo, D) =:= camara])),
  Edificios = lists:usort([maps:get(edificio, D) || D <- Lista]),
  ?assertEqual(10, length(Edificios)).

historico(_Ctx) ->
  {ok, Resumen} = p69_simulador:historico(#{
    eventos => 300, horas => 1, dias_atras => 0, lote => 100, semilla => 5
  }),
  ?assertEqual(300, maps:get(eventos, Resumen)),
  Estado = p69_bitacora:estado(),
  ?assertEqual(300, maps:get(seq, Estado)),
  Presentes = lists:sum([maps:get(eventos, S)
    || S <- p69_bitacora:info_segmentos()]),
  ?assertEqual(300, Presentes).

carga_en_vivo(_Ctx) ->
  Antes = maps:get(seq, p69_bitacora:estado()),
  {ok, Pid} = p69_simulador:carga(#{
    duracion_s => 1,
    tasa => 20,
    pico => 0,
    semilla => 9,
    offline_desde_s => 100,
    offline_hasta_s => 200
  }),
  Resumen = p69_simulador:esperar(Pid),
  ?assert(maps:get(aceptados, Resumen) > 0),
  Despues = maps:get(seq, p69_bitacora:estado()),
  ?assert(Despues > Antes).

recuperacion_de_sitio(_Ctx) ->
  {Edificio, SitePid, DispId} = primer_sitio_con_hijo(),
  exit(SitePid, kill),
  ok = esperar_sitio(Edificio, SitePid, 200),
  Ts = erlang:system_time(microsecond),
  {ok, _} = p69_bitacora:ingresar(#{
    dispositivo_id => DispId,
    tipo_dispositivo => tipo(DispId),
    edificio => Edificio,
    tipo_evento => <<"online">>,
    ts_evento => Ts,
    ts_recepcion => Ts
  }),
  ok = esperar_dispositivo(Edificio, DispId, 200).

primer_sitio_con_hijo() ->
  Sitios = [S || S <- supervisor:which_children(p69_sitios_sup),
                 element(1, S) =/= undefined],
  primer_sitio_con_hijo(Sitios).

primer_sitio_con_hijo([]) ->
  error(sin_sitios);
primer_sitio_con_hijo([{{p69_sitio_sup, Edificio}, Pid, supervisor, _} | Resto])
    when is_pid(Pid) ->
  case [Id || {Id, P, worker, _} <- supervisor:which_children(Pid), is_pid(P)] of
    [DispId | _] -> {Edificio, Pid, DispId};
    [] -> primer_sitio_con_hijo(Resto)
  end;
primer_sitio_con_hijo([_ | Resto]) ->
  primer_sitio_con_hijo(Resto).

esperar_sitio(Edificio, Viejo, 0) ->
  error({sitio_no_reiniciado, Edificio, Viejo});
esperar_sitio(Edificio, Viejo, N) ->
  case lists:keyfind({p69_sitio_sup, Edificio}, 1,
      supervisor:which_children(p69_sitios_sup)) of
    {{p69_sitio_sup, Edificio}, Pid, supervisor, _} when is_pid(Pid), Pid =/= Viejo ->
      ok;
    _ ->
      timer:sleep(10),
      esperar_sitio(Edificio, Viejo, N - 1)
  end.

esperar_dispositivo(Edificio, DispId, 0) ->
  error({dispositivo_no_recreado, Edificio, DispId});
esperar_dispositivo(Edificio, DispId, N) ->
  case p69_sitios:dispositivo(Edificio, DispId) of
    {ok, _} -> ok;
    {error, _} ->
      timer:sleep(10),
      esperar_dispositivo(Edificio, DispId, N - 1)
  end.

tipo(<<"puerta", _/binary>>) -> puerta;
tipo(_) -> camara.
