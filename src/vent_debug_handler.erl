-module(vent_debug_handler).
-behaviour(vent_handler).

-export([init/0, handle/2, terminate/1]).

%%====================================================================
%% API functions
%%====================================================================

-spec init() -> {ok, undefined}.
init() ->
    {ok, undefined}.

-spec terminate(undefined) -> ok.
terminate(_S) ->
    ok.

-spec handle(term(), undefined) -> {ok, undefined}.
handle(Msg, _S) ->
    lager:info("Received message: ~p", [Msg]),
    {ok, undefined}.
