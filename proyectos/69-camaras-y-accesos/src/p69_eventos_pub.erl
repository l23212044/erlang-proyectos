%% Pub/sub minimo para el WebSocket: los procesos interesados se suscriben y
%% reciben cada evento nuevo. Los suscriptores muertos se eliminan con monitor.
-module(p69_eventos_pub).
-behaviour(gen_server).

-export([start_link/0, suscribir/1, desuscribir/1, publicar/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec suscribir(pid()) -> ok.
suscribir(Pid) ->
  gen_server:call(?MODULE, {suscribir, Pid}, 5000).

-spec desuscribir(pid()) -> ok.
desuscribir(Pid) ->
  gen_server:cast(?MODULE, {desuscribir, Pid}).

-spec publicar(map()) -> ok.
publicar(Evento) ->
  gen_server:cast(?MODULE, {publicar, Evento}).

init([]) ->
  {ok, #{suscriptores => #{}}}.

handle_call({suscribir, Pid}, _From, Estado) ->
  Suscriptores = maps:get(suscriptores, Estado),
  case maps:is_key(Pid, Suscriptores) of
    true ->
      {reply, ok, Estado};
    false ->
      Mon = erlang:monitor(process, Pid),
      Info = #{mon => Mon, aviso => false},
      {reply, ok, Estado#{suscriptores => maps:put(Pid, Info, Suscriptores)}}
  end;
handle_call(_Msg, _From, Estado) ->
  {reply, {error, no_soportado}, Estado}.

handle_cast({desuscribir, Pid}, Estado) ->
  {noreply, quitar(Pid, Estado)};
handle_cast({publicar, Evento}, Estado0) ->
  Max = p69_config:get(mensajes_pendientes_max, 10000),
  Suscriptores = maps:map(
    fun(Pid, Info) -> publicar_a(Pid, Info, Evento, Max) end,
    maps:get(suscriptores, Estado0)
  ),
  {noreply, Estado0#{suscriptores => Suscriptores}};
handle_cast(_Msg, Estado) ->
  {noreply, Estado}.

handle_info({'DOWN', _Mon, process, Pid, _Motivo}, Estado) ->
  {noreply, quitar(Pid, Estado)};
handle_info(_Info, Estado) ->
  {noreply, Estado}.

%% Si un suscriptor acumula mas mensajes de los permitidos se le omite el
%% evento y se avisa una sola vez hasta que se recupere.
publicar_a(Pid, #{mon := _Mon, aviso := Avisado} = Info, Evento, Max) ->
  case pendientes(Pid) of
    N when N > Max ->
      case Avisado of
        true -> ok;
        false -> logger:warning("suscriptor lento, evento omitido",
          #{pid => Pid, pendientes => N, max => Max})
      end,
      Info#{aviso => true};
    _N ->
      Pid ! {evento, Evento},
      Info#{aviso => false}
  end.

pendientes(Pid) ->
  case erlang:process_info(Pid, message_queue_len) of
    {message_queue_len, N} -> N;
    undefined -> 0
  end.

quitar(Pid, Estado) ->
  Suscriptores = maps:get(suscriptores, Estado),
  case maps:take(Pid, Suscriptores) of
    {#{mon := Mon}, Resto} ->
      erlang:demonitor(Mon, [flush]),
      Estado#{suscriptores => Resto};
    error ->
      Estado
  end.
