%%%-------------------------------------------------------------------
%% @doc vent publisher supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(vent_publisher_sup).

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
    {ok, {sup_flags(), publisher_spec(HostOpts)}}.

%%====================================================================
%% Internal functions
%%====================================================================

-spec sup_flags() -> supervisor:sup_flags().
sup_flags() ->
    #{strategy => one_for_one}.

-spec publisher_spec(host_opts()) -> [supervisor:child_spec()].
%% TODO allow for multiple publishers, registered by name
publisher_spec(HostOpts) ->
    Opts = opts(),
    [ publisher(HostOpts, Opts) ].

-spec publisher(host_opts(),
                vent_publisher:opts()) -> supervisor:child_spec().
publisher(HostOpts, Opts) ->
    ID = vent_publisher,
    #{id => ID,
      start => {vent_publisher, start_link, [HostOpts, Opts#{id => ID}]}}.

-spec opts() -> vent_publisher:opts().
opts() ->
    #{chunk_size => vent_helper:opt(publish_chunk_size, 20)}.
