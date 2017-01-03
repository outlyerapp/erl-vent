%%%-------------------------------------------------------------------
%% @doc vent subsciber supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(vent_subscriber_sup).

-behaviour(supervisor).

-include("vent_internal.hrl").

%% API
-export([start_link/4]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

-spec start_link(SupName :: atom(),
                 PoolName :: atom(),
                 host_opts(),
                 vent_subscriber:opts()) -> {ok, pid()}.
start_link(SupName, PoolName, HostOpts, Opts) ->
    supervisor:start_link({local, SupName}, ?MODULE,
                          {PoolName, HostOpts, Opts}).

%%====================================================================
%% Supervisor callbacks
%%====================================================================
%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
-spec init({PoolName :: atom(), host_opts(), vent_subscriber:opts()}) ->
    {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init({PoolName, HostOpts, Opts}) ->
    Specs = subscriber_specs(PoolName, HostOpts, Opts),
    {ok, {sup_flags(), Specs}}.

%%====================================================================
%% Internal functions
%%====================================================================

-spec sup_flags() -> supervisor:sup_flags().
sup_flags() ->
    #{strategy => one_for_one}.

-spec subscriber_specs(PoolName :: atom(),
                       host_opts(),
                       vent_subscriber:opts()) -> [supervisor:child_spec()].
subscriber_specs(PoolName, HostOpts, Opts = #{name      := Name,
                                              n_workers := NWorkers}) ->
    [begin
         ID = {Name, SeqId},
         Opts1 = Opts#{id => ID, pool => PoolName},
         #{id => ID,
           start => {vent_subscriber, start_link, [HostOpts, Opts1]}}
     end || SeqId <- lists:seq(1, NWorkers)].
