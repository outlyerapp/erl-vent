-module(vent_handler_worker).
-behaviour(gen_server).

%% API
-export([start_link/1, process/2]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-include("vent_internal.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-type handler_response() :: ok |
                            {requeue, term()} |
                            {requeue, number(), term()} |
                            {drop, term()}.

-type message() :: #amqp_msg{}.
-type timed_message() :: #{msg => message(),
                           processing_start => monotonic_tstamp()}.

-record(state, {handler :: module(),
                handler_state :: term()}).

-type state() :: #state{}.

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link(term()) -> gen_server_startlink_ret().
start_link(Args) ->
    gen_server:start_link(?MODULE, Args, []).

-spec process(pid(), Msg :: timed_message()) -> handler_response().
process(Pid, Msg) ->
    gen_server:call(Pid, {process, Msg}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

-spec init([module()]) -> {ok, state()}.
init([Handler]) ->
    {ok, HandlerState} = vent_handler:init(Handler),
    {ok, #state{ handler = Handler,
                 handler_state = HandlerState }}.

-spec handle_call(any(), any(), state()) -> {reply, ok, state()}.
handle_call({process, Msg}, _From, State) ->
    {Reply, State} = call_handler(Msg, State),
    {reply, Reply, State};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

-spec handle_cast(any(), state()) -> {noreply, state()}.
handle_cast(_Msg, State) ->
    {noreply, State}.

-spec handle_info(any(), state()) -> {noreply, state()} |
                                     {stop, any(), state()}.
handle_info(_Info, State) ->
    {noreply, State}.

-spec terminate(any(), any()) -> ok.
terminate(_Reason, #state{ handler = Handler,
                           handler_state = HState}) ->
    catch vent_handler:terminate(Handler, HState),
    ok.

-spec code_change(any(), state(), any()) -> {ok, state()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec call_handler(timed_message(), state()) -> {handler_response(), state()}.
call_handler(#{msg := {#'basic.deliver'{},
                       #amqp_msg{payload = Payload}}},
             #state{handler = Handler,
                    handler_state = HState} = State) ->
    DecodedPayload = jsone:decode(Payload),
    case vent_handler:handle(Handler, DecodedPayload, HState) of
        {ok, HState1} ->
            {ok, State#state{handler_state = HState1}};
        {requeue, Reason, HState1} ->
            lager:error("Handler asked to requeue message: ~p~n", [Reason]),
            {{requeue, Reason}, State#state{handler_state = HState1}};
        {requeue, Timeout, Reason, HState1} when Timeout > 0 ->
            {{requeue, Timeout, Reason}, State#state{handler_state = HState1}};
        {drop, Reason, HState1} ->
            {{drop, Reason}, State#state{handler_state = HState1}}
    end.
