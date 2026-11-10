%% Registro de sitios y dispositivos. Traduce un evento en el proceso del
%% dispositivo correspondiente, creando el sitio y el dispositivo la primera
%% vez. La cache evita preguntar al supervisor en cada evento.
-module(p69_sitios).
-behaviour(gen_server).

-export([start_link/0, notificar/1, dispositivos/0, dispositivo/2, sitios/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec notificar(map()) -> ok.
notificar(Ev) ->
  gen_server:cast(?MODULE, {evento, Ev}).

-spec dispositivos() -> [map()].
dispositivos() ->
  gen_server:call(?MODULE, dispositivos, 15000).

-spec dispositivo(binary(), binary()) -> {ok, map()} | {error, no_encontrado}.
dispositivo(Edificio, DispId) ->
  gen_server:call(?MODULE, {dispositivo, Edificio, DispId}, 15000).

-spec sitios() -> [binary()].
sitios() ->
  gen_server:call(?MODULE, sitios, 15000).

init([]) ->
  {ok, #{sitios => #{}, dispositivos => #{}}}.

handle_call(dispositivos, _From, Estado) ->
  Lista = lists:append([
    dispositivos_de_sitio(SitePid)
   || {_Edificio, SitePid} <- maps:to_list(maps:get(sitios, Estado)),
      is_process_alive(SitePid)
  ]),
  {reply, Lista, Estado};
handle_call({dispositivo, Edificio, DispId}, _From, Estado) ->
  case maps:find(Edificio, maps:get(sitios, Estado)) of
    error ->
      {reply, {error, no_encontrado}, Estado};
    {ok, SitePid} ->
      case is_process_alive(SitePid) of
        false ->
          Sitios2 = maps:remove(Edificio, maps:get(sitios, Estado)),
          {reply, {error, no_encontrado}, Estado#{sitios => Sitios2}};
        true ->
          case buscar_hijo(SitePid, DispId) of
            {ok, Pid} -> {reply, {ok, p69_dispositivo:estado(Pid)}, Estado};
            error -> {reply, {error, no_encontrado}, Estado}
          end
      end
  end;
handle_call(sitios, _From, Estado) ->
  {reply, maps:keys(maps:get(sitios, Estado)), Estado};
handle_call(_Msg, _From, Estado) ->
  {reply, {error, no_soportado}, Estado}.

handle_cast({evento, Ev}, Estado) ->
  Edificio = maps:get(edificio, Ev),
  DispId = maps:get(dispositivo_id, Ev),
  Tipo = maps:get(tipo_dispositivo, Ev),
  {Pid, Estado2} = asegurar_dispositivo(Edificio, DispId, Tipo, Estado),
  case Pid of
    undefined -> ok;
    _ -> gen_server:cast(Pid, {evento, Ev})
  end,
  {noreply, Estado2};
handle_cast(_Msg, Estado) ->
  {noreply, Estado}.

handle_info(_Info, Estado) ->
  {noreply, Estado}.

%% Internos

asegurar_dispositivo(Edificio, DispId, Tipo, Estado) ->
  Clave = {Edificio, DispId},
  Dispositivos = maps:get(dispositivos, Estado),
  case maps:find(Clave, Dispositivos) of
    {ok, Pid} ->
      case is_process_alive(Pid) of
        true -> {Pid, Estado};
        false -> iniciar_o_buscar(Edificio, DispId, Tipo, Estado)
      end;
    error ->
      iniciar_o_buscar(Edificio, DispId, Tipo, Estado)
  end.

iniciar_o_buscar(Edificio, DispId, Tipo, Estado) ->
  {SitePid, Estado2} = asegurar_sitio(Edificio, Estado),
  case SitePid of
    undefined ->
      {undefined, Estado2};
    _ ->
      case buscar_hijo(SitePid, DispId) of
        {ok, Pid} ->
          {Pid, guardar_dispositivo(Edificio, DispId, Pid, Estado2)};
        error ->
          case p69_sitio_sup:iniciar_dispositivo(SitePid, DispId, Edificio, Tipo) of
            {ok, Pid} ->
              {Pid, guardar_dispositivo(Edificio, DispId, Pid, Estado2)};
            {error, {already_started, Pid}} ->
              {Pid, guardar_dispositivo(Edificio, DispId, Pid, Estado2)};
            {error, Motivo} ->
              logger:warning("no se pudo iniciar dispositivo ~p: ~p", [DispId, Motivo]),
              {undefined, Estado2}
          end
      end
  end.

asegurar_sitio(Edificio, Estado) ->
  Sitios = maps:get(sitios, Estado),
  case maps:find(Edificio, Sitios) of
    {ok, Pid} ->
      %% La cache puede apuntar a un sitio que murio y ya fue reiniciado por
      %% p69_sitios_sup. Si no se comprueba, los eventos de ese edificio se
      %% pierden silenciosamente.
      case is_process_alive(Pid) of
        true -> {Pid, Estado};
        false -> iniciar_sitio(Edificio, maps:remove(Edificio, Sitios), Estado)
      end;
    error ->
      iniciar_sitio(Edificio, Sitios, Estado)
  end.

iniciar_sitio(Edificio, Sitios, Estado) ->
  case p69_sitios_sup:iniciar_sitio(Edificio) of
    {ok, Pid} ->
      {Pid, Estado#{sitios => maps:put(Edificio, Pid, Sitios)}};
    {error, {already_started, Pid}} ->
      {Pid, Estado#{sitios => maps:put(Edificio, Pid, Sitios)}};
    {error, Motivo} ->
      logger:warning("no se pudo iniciar sitio ~p: ~p", [Edificio, Motivo]),
      {undefined, Estado}
  end.

guardar_dispositivo(Edificio, DispId, Pid, Estado) ->
  Estado#{dispositivos => maps:put({Edificio, DispId}, Pid, maps:get(dispositivos, Estado))}.

buscar_hijo(SitePid, DispId) ->
  case lists:keyfind(DispId, 1, supervisor:which_children(SitePid)) of
    {DispId, Pid, _Tipo, _Modulos} when is_pid(Pid) -> {ok, Pid};
    _ -> error
  end.

dispositivos_de_sitio(SitePid) ->
  [
    p69_dispositivo:estado(Pid)
   || {_Id, Pid, _Tipo, _Modulos} <- supervisor:which_children(SitePid),
      is_pid(Pid)
  ].
