%%%-------------------------------------------------------------------
%% @doc vent top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(vent_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-include("vent_internal.hrl").

-define(SERVER, ?MODULE).
-define(SUP_TIMEOUT, 5000).

-define(CHILD(I, Type, Args), {I, {I, start_link, Args}, permanent,
                                        ?SUP_TIMEOUT, Type, [I]}).

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
-spec init([term()]) -> {ok, {supervisor:sup_flags(),
                              [supervisor:child_spec()]}}.
init([]) ->
    SubscriberPoolSpecs = subscriber_pool_specs(),
    PublisherSpec = ?CHILD(vent_publisher_sup, supervisor, []),
    {ok, {sup_flags(), [PublisherSpec | SubscriberPoolSpecs]}}.

%%====================================================================
%% Internal functions
%%====================================================================
-spec sup_flags() -> supervisor:sup_flags().
sup_flags() ->
    #{strategy => one_for_one}.

-spec subscriber_pool_specs() -> [supervisor:child_spec()].
subscriber_pool_specs() ->
    HostOpts = vent_helper:get_host_opts(),
    Subscribers = vent_helper:required_opt(subscribers),
    [subscriber_pool_spec(HostOpts, opts(S)) || S <- Subscribers].

-spec subscriber_pool_spec(host_opts(),
                           vent_subscriber:opts()) -> supervisor:child_spec().
subscriber_pool_spec(HostOpts, Opts) ->
    SupName = subscriber_pool_sup_name(Opts),
    {SupName, {vent_subscriber_pool_sup, start_link, [SupName, HostOpts, Opts]},
     transient, 5000, supervisor, [vent_subscriber_pool_sup]}.

-spec subscriber_pool_sup_name(vent_subscriber:opts()) -> atom().
subscriber_pool_sup_name(#{name := Name}) when is_list(Name) ->
    list_to_atom("vent_" ++ Name ++ "_pool_sup").

-spec opts(term()) -> vent_subcriber:opts().
opts({vent_subscriber, Conf}) ->
    Defaults = #{handler => vent_debug_handler,
                 n_workers => 1,
                 n_overflow => 1,
                 prefetch_count => 2},
    Props = maps:from_list(Conf),
    maps:merge(Defaults, Props).
