-module(vent_handler).

-export([init/1, handle/3, terminate/2]).

-type state() :: term().

-callback init() ->
    {ok, state()}.
-callback handle(term(), state()) ->
    {ok, state()} |
    {requeue, term(), state()} |
    {drop, term(), state()}.
-callback terminate(state()) ->
    ok.

%%--------------------------------------------------------------------
%% @doc Initialize subscription handler.
%% @end
%%--------------------------------------------------------------------
-spec init(module()) -> {ok, state()}.
init(Mod) ->
    _ = code:ensure_loaded(Mod),
    case erlang:function_exported(Mod, init, 0) of
        false ->
            {error, badarg};
        true ->
            Mod:init()
    end.

%%--------------------------------------------------------------------
%% @doc Handle message
%%
%% The implementation can respond with one of 3 messages:
%% * {ok, State} - Processing is done and we should move on
%% * {requeue, Reason, State} - With that response handler is
%%   communicating that it couldn't process it right now, but that
%%   situation could change in feature, so message should be re tried
%%   later. This usually happens if other systems are down and can't
%%   be reached, but may become available in feature.
%% * {requeue, TTL, Reason, State} -> If the message is not acknowledged
%%   within a finite period of time, it is automatically rejected and placed
%%   back onto the queue.
%% * {drop, Reason, State} - Handler should respond with drop only if
%%   it can't do anything with message and it wont change in feature.
%%   In this case message is moved to error queue and never re-tried.
%%   Usually you get those responses with ill-formatted messages.
%%
%% @end
%%--------------------------------------------------------------------
-spec handle(module(), term(), state()) ->
                    {ok, state()} |
                    {requeue, term(), state()} |
                    {requeue, number(), term(), state()} |
                    {drop, term(), state()}.
handle(Mod, Msg, State) ->
    case erlang:function_exported(Mod, handle, 2) of
        false ->
            {error, badarg};
        true ->
            Mod:handle(Msg, State)
    end.

%%--------------------------------------------------------------------
%% @doc Stops a subscription handler.
%% @end
%%--------------------------------------------------------------------
-spec terminate(module(), state()) -> ok.
terminate(Mod, State) ->
    case erlang:function_exported(Mod, terminate, 1) of
        false ->
            {error, badarg};
        true ->
            Mod:terminate(State)
    end.
