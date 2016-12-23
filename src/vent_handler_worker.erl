-module(vent_handler_worker).
-behaviour(gen_server).

%% API
-export([start_link/1, process_msg/2]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-ignore_xref([start_link/2]).

-include("vent_internal.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-define(SERVER, ?MODULE).

-type handler_response() :: ok |
                            {requeue, term()} |
                            {requeue, number(), term()} |
                            {drop, term()}.

-type message() :: #amqp_msg{}.
-type timed_message() :: #{msg => message(),
                           processing_start => monotonic_tstamp()}.

-record(state, { handler :: module(),
                 handler_state :: term()}).

-type state() :: #state{}.

%%
%% API
%%

-spec start_link(term()) -> gen_server_startlink_ret().
start_link(Args) ->
    gen_server:start(?MODULE, Args, []).

-spec process_msg(pid(), Msg :: term()) -> {ok, handler_response()}.
process_msg(Pid, Msg) ->
    gen_server:call(Pid, {process, Msg}).

%%
%% gen_server callbacks
%%
-spec init(HandlerMod :: module()) -> {ok, state()}.
init(HandlerMod) ->
    {ok, HandlerState} = vent_handler:init(HandlerMod),
    {ok, #state{ handler = HandlerMod,
                 handler_state = HandlerState }}.


-spec handle_call(any(), any(), state()) -> {reply, ok, state()}.
handle_call({process, Msg}, _From, State) ->
    case handle(Msg, State) of
        {Response = {error, _Reason}, State1} ->
            {stop, error, Response, State1};
        {Response, State1} ->
            {reply, Response, State1}
    end.

-spec handle_cast(any(), state()) -> {noreply, state()}.
handle_cast(_Msg, State) ->
    {noreply, State}.

-spec handle_info(term(), state()) -> {noreply, state()} |
                                      {stop, any(), state()}.
handle_info(_Info, State) ->
    {noreply, State}.

-spec terminate(any(), any()) -> ok.
terminate(Reason, #state{handler = Handler, handler_state = HandlerState}) ->
    lager:info("Terminating vent handler: ~p due to: ~p", [Handler, Reason]),
    Handler:terminate(HandlerState),
    ok;
terminate(_Reason, _State) ->
    ok.

-spec code_change(any(), state(), any()) -> {ok, state()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%
%% Internal functions
%%

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
            erlang:send_after(Timeout, self(), {requeue, Message, Reason}),
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
