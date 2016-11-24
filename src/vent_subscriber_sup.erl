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
                   Opts = opts(Subscriber),
                   subscribers(HostOpts, Opts)
               end || Subscriber <- Subscribers],
    lists:flatten(Workers).

-spec subscribers(host_opts(),
                  vent_subscriber:opts()) -> [supervisor:child_spec()].
subscribers(HostOpts, Opts = #{handler   := Handler,
                               n_workers := NWorkers}) ->
    [begin
         ID = {Handler, SeqId},
         #{id => ID,
           start => {vent_subscriber, start_link, [HostOpts, Opts#{id => ID}]}}
     end || SeqId <- lists:seq(1, NWorkers)].

-spec opts(term()) -> vent_subcriber:opts().
opts({vent_subscriber, Conf}) ->
    Defaults = #{handler => vent_debug_handler,
                 n_workers => 1,
                 prefetch_count => 2},
    Props = maps:from_list(Conf),
    maps:merge(Defaults, Props).
