%%%-------------------------------------------------------------------
%% @doc vent subsciber supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(vent_subscriber_sup).

-behaviour(supervisor).

-include("vent_internal.hrl").

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

-spec start_link() -> {ok, pid()}.
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
-spec init([]) -> {ok, {supervisor:sup_flags(),
                                 [supervisor:child_spec()]}}.
init([]) ->
    HostOpts = vent_helper:get_host_opts(),
    {ok, {sup_flags(), subscriber_spec(HostOpts)}}.

%%====================================================================
%% Internal functions
%%====================================================================

-spec sup_flags() -> supervisor:sup_flags().
sup_flags() ->
    #{strategy => one_for_one}.

-spec subscriber_spec(host_opts()) -> [supervisor:child_spec()].
subscriber_spec(HostOpts) ->
    Subscribers = vent_helper:required_opt(subscribers),
    Workers = [begin
                   {Opts, NWorkers} = opts(Subscriber),
                   %% TODO: make a uniqueness constraint on ID, where
                   %% |Subscribers| > 1
                   SeqIds = lists:seq(1, NWorkers),
                   [subscriber(SeqId, HostOpts, Opts) || SeqId <- SeqIds]
               end || Subscriber <- Subscribers],
    lists:flatten(Workers).

-spec subscriber(pos_integer(),
                 host_opts(),
                 vent_subscriber:opts()) -> supervisor:child_spec().
subscriber(SeqId, HostOpts, Opts) ->
    ID = {vent_subscriber, SeqId},
    #{id => ID,
      start => {vent_subscriber, start_link, [HostOpts, Opts#{id => ID}]}}.

-spec opts(term()) -> {vent_subcriber:opts(), pos_integer()}.
opts({vent_subscriber, Conf}) ->
    Defaults = #{handler => vent_debug_handler,
                 n_workers => 1,
                 prefetch_count => 2,
                 message_ttl => 300000},
    Props = maps:from_list(Conf),
    NWorkers = proplists:get_value(n_workers, Conf, 1),
    {maps:merge(Defaults, Props), NWorkers}.
