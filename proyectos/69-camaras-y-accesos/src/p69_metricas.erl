%% Contadores y medidores en ETS. El proceso es dueno de la tabla; los demas
%% procesos solo escriben contadores con update_counter (operacion atomica).
-module(p69_metricas).
-behaviour(gen_server).

-export([start_link/0, inc/1, inc/2, set/2, snapshot/0, reset/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(TAB, p69_metricas_tab).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec inc(term()) -> ok.
inc(Key) -> inc(Key, 1).

-spec inc(term(), integer()) -> ok.
inc(Key, N) ->
  _ = ets:update_counter(?TAB, Key, N, {Key, 0}),
  ok.

-spec set(term(), integer()) -> ok.
set(Key, Valor) ->
  true = ets:insert(?TAB, {Key, Valor}),
  ok.

-spec snapshot() -> map().
snapshot() ->
  maps:from_list(ets:tab2list(?TAB)).

-spec reset() -> ok.
reset() ->
  gen_server:call(?MODULE, reset).

init([]) ->
  ?TAB = ets:new(?TAB, [named_table, public, set, {write_concurrency, true}]),
  {ok, #{}}.

handle_call(reset, _From, State) ->
  true = ets:delete_all_objects(?TAB),
  {reply, ok, State};
handle_call(_Msg, _From, State) ->
  {reply, {error, no_soportado}, State}.

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.
