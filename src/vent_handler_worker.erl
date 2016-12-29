-module(vent_handler_worker).

%% API
-export([simple_processor/1, process/2, terminate/2]).

-include("vent_internal.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-type handler_response() :: ok |
                            {requeue, term()} |
                            {requeue, number(), term()} |
                            {drop, term()} |
                            {error, Reason :: term()}.
-type message() :: #amqp_msg{}.
-type timed_message() :: #{msg => message(),
                           processing_start => monotonic_tstamp()}.

-export_type([handler_response/0]).

-record(state, { handler_state :: term(),
                 handler :: module() }).

-type state() :: #state{}.

-spec simple_processor(Handler :: module()) -> ok.
simple_processor(Handler) ->
    {ok, HState} = init(Handler),
    loop(#state{handler = Handler, handler_state = HState}).

-spec process(pid(), Msg :: timed_message()) -> {pid(), {'process',
                                                         handler_response()}}.
process(Pid, Msg) ->
    Pid ! {self(), {process, Msg}}.

-spec terminate(pid(), Reason :: term()) -> {'terminate', _}.
terminate(Pid, Reason) ->
    Pid ! {terminate, Reason}.

%% TODO configure a timeout so processing is not indefinite
loop(State) ->
    receive
        {From, {process, Message}} ->
            {Response, State1} = handle(Message, State),
            From ! {process, Message, Response},

            case Response of
                {error, Reason} ->
                    exit(self(), Reason);
                _ ->
                    loop(State1)
            end;
        {terminate, Reason} ->
            terminate_handler(State, Reason);
        {'EXIT', _Parent, Reason} ->
            terminate_handler(State, Reason)
    end.

%%
%% Internal functions
%%

-spec init(Handler :: module()) -> {ok, state()}.
init(Handler) when is_atom(Handler) ->
    vent_handler:init(Handler).

-spec handle(timed_message(), state()) -> {handler_response(), state()}.
handle(Message, #state{handler = Handler, handler_state = HState} = State) ->
    try handle(Handler, Message, HState) of
        {ok, HState1} ->
            State1 = State#state{handler_state = HState1},
            {ok, State1};
        {requeue, Reason, HState1} ->
            lager:error("Handler asked to requeue message: ~p~n", [Reason]),
            State1 = State#state{handler_state = HState1},
            {{requeue, Reason}, State1};
        {requeue, Timeout, Reason, HState1} when Timeout > 0 ->
            State1 = State#state{handler_state = HState1},
            {{requeue, Timeout, Reason}, State1};
        {drop, Reason, HState1} ->
            State1 = State#state{handler_state = HState1},
            {{drop, Reason}, State1}
    catch
        ErrorType:Reason ->
            Stack = erlang:get_stacktrace(),
            lager:error("Error in message handler execution: ~p~n",
                        [{ErrorType, Reason, Stack}]),
            {{error, Reason}, HState}
    end.

-spec handle(module(), timed_message(), term()) -> term().
handle(Handler, Message, HState) ->
    Payload = decode_payload(Message),
    vent_handler:handle(Handler, Payload, HState).

-spec decode_payload(timed_message()) -> number() | binary() | maps:map() |
                                         [maps:map()].
decode_payload(#{msg := {#'basic.deliver'{},
                         #amqp_msg{payload = Payload}}}) ->
    %% TODO: for now we just assume it is always a valid json.
    try jsone:decode(Payload)
    catch
        ErrorType:Reason ->
            Stack = erlang:get_stacktrace(),
            lager:error("Error in json decoding: ~p~n",
                        [{ErrorType, Reason, Stack}]),
            throw({ErrorType, Reason})
    end.

-spec terminate_handler(state(), Reason :: term()) -> ok.
terminate_handler(#state{handler = Handler, handler_state = HState}, Reason) ->
    lager:info("Handler worker terminating due to reason: ~p", [Reason]),
    vent_handler:terminate(Handler, HState).
