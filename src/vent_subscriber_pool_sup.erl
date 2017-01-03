%%%-------------------------------------------------------------------
%% @doc vent subscriber pool supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(vent_subscriber_pool_sup).

-behaviour(supervisor).

-include("vent_internal.hrl").

%% API
-export([start_link/3]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

-spec start_link(SupName :: atom(),
                 host_opts(),
                 vent_subscriber:opts()) -> {ok, pid()}.
start_link(SupName, HostOpts, Opts) ->
    supervisor:start_link({local, SupName}, ?MODULE, {HostOpts, Opts}).

%%====================================================================
%% Supervisor callbacks
%%====================================================================
%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
-spec init({host_opts(), vent_subscriber:opts()}) ->
    {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init({HostOpts, Opts}) ->
    PoolName = pool_name(Opts),
    PoolerSpec = pool_spec(Opts),
    SupName = subscriber_sup_name(Opts),
    SubscriberSupSpec = {SupName,
                         {vent_subscriber_sup, start_link,
                          [SupName, PoolName, HostOpts, Opts]},
                         transient, 5000, supervisor, [vent_subscriber_sup]},
    {ok, {sup_flags(), [SubscriberSupSpec, PoolerSpec]}}.

%%====================================================================
%% Internal functions
%%====================================================================

-spec sup_flags() -> supervisor:sup_flags().
sup_flags() ->
    {one_for_all, 5, 60}.

pool_spec(#{handler   := Handler,
            n_workers := NWorkers,
            n_overflow := NOverflow} = Opts) ->
    Name = pool_name(Opts),
    PoolArgs = [{name, {local, Name}},
                {worker_module, vent_handler_worker},
                {size, NWorkers},
                {max_overflow, NOverflow}],
    WorkerArgs = [Handler],
    poolboy:child_spec(Name, PoolArgs, WorkerArgs).

-spec pool_name(vent_subscriber:opts()) -> atom().
pool_name(#{name := Name}) when is_list(Name) ->
    list_to_atom("vent_" ++ Name ++ "_pool").

-spec subscriber_sup_name(vent_subscriber:opts()) -> atom().
subscriber_sup_name(#{name := Name}) when is_list(Name) ->
    list_to_atom("vent_" ++ Name ++ "_subscriber_sup").
