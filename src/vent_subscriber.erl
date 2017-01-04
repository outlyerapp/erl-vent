-module(vent_subscriber).
-behaviour(gen_server).

%% API
-export([start_link/2]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-export_type([opts/0]).

-include("vent_internal.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

%% TODO: move These to configuration
-define(INITIAL_BACKOFF, 200). %% milliseconds
-define(MAX_BACKOFF, timer:minutes(2)).
-define(QUEUE_WEIGHT, <<"10">>).

-define(METRIC_IN, {vent_subscriber, in}).
-define(METRIC_ACK, {vent_subscriber, ack}).
-define(METRIC_ERROR, {vent_subscriber, error}).
-define(METRIC_PROCESSING_TIME, {vent_subscriber, processing_time}).

-type opts() :: #{id => term(),
                  name => string(),
                  exchange => binary(),
                  error_exchange => binary(),
                  dead_letter_exchange => binary(),
                  error_routing_key => binary(),
                  pool => atom(),
                  n_workers => pos_integer(),
                  n_overflow => pos_integer(),
                  prefetch_count => pos_integer(),
                  queue => binary(),
                  message_ttl => millis()}.

-type rabbit_params_proplist() :: [{atom(), any()}].
-type monitor_down() :: {'DOWN', reference(), process, pid(), any()}.
-type message() :: #amqp_msg{}.
-type timed_message() :: #{msg => message(),
                           processing_start => monotonic_tstamp()}.

-record(state, {id :: term(),
                host_opts :: host_opts(),
                opts :: opts(),
                conn :: connection(),
                channel :: channel(),
                consumer_tag :: binary(),
                error_exchange :: binary(),
                error_routing_key :: binary()}).

-type state() :: #state{}.

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link(host_opts(), opts()) -> gen_server_startlink_ret().
start_link(HostOpts, Opts) ->
    gen_server:start_link(?MODULE, {HostOpts, Opts}, []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

-spec init({host_opts(), opts()}) -> {ok, state()}.
init({HostOpts, #{id := ID,
                  error_exchange := EE,
                  error_routing_key := ERK} = Opts}) ->
    register_subscriber_metrics(),
    %% TODO: gen_server:cast should work
    self() ! {subscribe, ?INITIAL_BACKOFF, ?MAX_BACKOFF},
    {ok, #state{id = ID,
                host_opts = HostOpts,
                opts = Opts,
                error_exchange = EE,
                error_routing_key = ERK}}.

-spec handle_call(any(), any(), state()) -> {reply, ok, state()}.
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

-spec handle_cast(any(), state()) -> {noreply, state()}.
handle_cast(_Msg, State) ->
    {noreply, State}.

-spec handle_info(Msg, state()) -> Result when
      Msg :: {subscribe, millis(), millis()}
           | monitor_down()
           | message(),
      Result :: {noreply, state()}
              | {stop, any(), state()}.

handle_info({subscribe, Backoff, MaxBackoff}, #state{host_opts = HostOpts,
                                                     opts = Opts} = State) ->
    %% TODO: We can use external ETS table to keep backoff state to have nice
    %% exponential backoff strategy.
    timer:sleep(backoff:rand_increment(Backoff, MaxBackoff)),

    ok = configure(HostOpts, Opts),
    {ok, State1} = subscribe(State),
    {noreply, State1};
handle_info({requeue, Message, Reason},
             #state{channel = Ch} = State) ->
    lager:error("Handler asked to requeue message: ~p~n", [Reason]),
    reject(Ch, true, Message),
    {noreply, State};
handle_info({'DOWN', _MRef, process, _Pid, _Info} = Down, State) ->
    lager:error("broker down: ~p", [Down]),
    {stop, {broker_down, Down}, State};

handle_info(Info, State) ->
    case handle_message(Info, State) of
        false ->
            unhandled_message(Info, State),
            {noreply, State};
        {ok, State1} ->
            {noreply, State1}
    end.

-spec terminate(any(), any()) -> ok.
terminate(_Reason, #state{conn = Conn}) ->
    catch amqp_connection:close(Conn),
    ok.

-spec code_change(any(), state(), any()) -> {ok, state()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec handle_message(message(), state()) -> {ok, state()} | false.
handle_message(#'basic.consume_ok'{consumer_tag = Tag},
               #state{consumer_tag = Tag} = State) ->
    {ok, State};
handle_message({#'basic.deliver'{consumer_tag = Tag}, #amqp_msg{}} = Message,
               #state{consumer_tag = Tag} = State) ->
    T0 = get_monotonic_tstamp(nano_seconds),
    folsom_metrics:notify({?METRIC_IN, {inc, 1}}),
    State1 = call_handler(#{msg => Message, processing_start => T0}, State),
    {ok, State1};
handle_message(_, _State) ->
    false.

-spec unhandled_message(message(), state()) -> ok.
unhandled_message(Msg, _State) ->
    lager:warning("unhandled message: ~p", [Msg]),
    ok.

-spec configure(host_opts(), opts()) -> ok.
configure(HostOpts, #{error_exchange := ErrorExchange} = Opts) ->
    {ok, Conn} = start_rabbitmq(HostOpts),
    {ok, Ch} = amqp_connection:open_channel(Conn),
    declare_work_exchanges(Ch, Opts),
    declare_exchange(Ch, ErrorExchange, <<"direct">>),
    declare_work_queues(Ch, Opts),
    bind_queues(Ch, Opts),
    amqp_connection:close(Conn),
    ok.

-spec subscribe(state()) -> {ok, state()}.
subscribe(#state{host_opts = HostOpts,
                 opts = #{id := {_, SeqId},
                          n_workers := NWorkers,
                          queue := Prefix,
                          prefetch_count := PrefCount}} = State) ->
    {ok, Conn} = start_rabbitmq(HostOpts),
    %% TODO: maybe it will be just easier to link and die when channel proc dies
    erlang:monitor(process, Conn),
    {ok, Ch} = amqp_connection:open_channel(Conn),
    erlang:monitor(process, Ch),
    qos(Ch, PrefCount),
    Queue = queue_name(Prefix, SeqId - 1, NWorkers),
    {ok, Tag} = subscribe(Ch, Queue),
    lager:info("subscribed: ~s tag: ~s", [Queue, Tag]),
    {ok, State#state{conn = Conn, channel = Ch, consumer_tag = Tag}}.

-spec call_handler(timed_message(), state()) -> state().
call_handler(Message,
             #state{opts = Opts, channel = Ch} = State) ->
    #{pool := Pool} = Opts,
    WorkerFun = fun(Worker) ->
                        try
                            vent_handler_worker:process(Worker, Message)
                        catch
                            ErrorType:Reason ->
                                Stack = erlang:get_stacktrace(),
                                {error, ErrorType, Reason, Stack}
                        end
                end,
    try poolboy:transaction(Pool, WorkerFun) of
        ok ->
            ack(Ch, Message),
            State;
        {requeue, Reason} ->
            reject(Ch, true, Message),
            lager:error("Handler asked to requeue message: ~p~n", [Reason]),
            State;
        {requeue, Timeout, Reason} when Timeout > 0 ->
            erlang:send_after(Timeout, self(), {requeue, Message, Reason}),
            State;
        {drop, Reason} ->
            error(Ch, Message, Reason, State),
            State;
        {error, ErrorType, Reason, Stack} ->
            lager:error("Error in message handler execution: ~p~n",
                        [{ErrorType, Reason, Stack}]),
            error(Ch, Message, Reason, State),
            State
    catch
        ErrorType:Reason ->
            Stack = erlang:get_stacktrace(),
            lager:error("Error in vent subscriber: ~p~n",
                        [{ErrorType, Reason, Stack}]),
            error(Ch, Message, {ErrorType, Reason, Stack}, State),
            throw({ErrorType, Reason})
    end.

-spec ack(channel(), timed_message()) -> ok.
ack(Ch, #{msg := {#'basic.deliver'{delivery_tag = Tag}, _},
          processing_start := T0}) ->

    folsom_metrics:notify({?METRIC_ACK, {inc, 1}}),
    folsom_metrics:notify({?METRIC_PROCESSING_TIME, elapsed_time(T0)}),
    amqp_channel:cast(Ch, #'basic.ack'{delivery_tag = Tag}).

-spec reject(channel(), boolean(), timed_message()) -> ok.
reject(Ch, Requeue, #{msg := {#'basic.deliver'{delivery_tag = Tag}, _},
                      processing_start := T0}) ->
    folsom_metrics:notify({?METRIC_ERROR, {inc, 1}}),
    folsom_metrics:notify({?METRIC_PROCESSING_TIME, elapsed_time(T0)}),
    amqp_channel:cast(Ch, #'basic.reject'{delivery_tag = Tag,
                                          requeue = Requeue}).

-spec error(channel(), timed_message(), term(), state()) -> ok.
error(Ch, Message, Error, #state{error_exchange = ErrorExchange,
                                 error_routing_key = ErrorRoutingKey}) ->
    %% TODO: it would be nice to have also stacktrace in error message
    Type = #'basic.publish'{exchange = ErrorExchange,
                            routing_key = ErrorRoutingKey},
    Payload = iolist_to_binary(io_lib:format("~p: ~p", [Error, Message])),
    Msg = #'amqp_msg'{payload = Payload},
    amqp_channel:cast(Ch, Type, Msg),
    reject(Ch, false, Message),
    ok.

-spec validate_params(Params, AllowedFields) -> ok when
      Params :: rabbit_params_proplist(),
      AllowedFields :: [atom()].
validate_params(Params, AllowedFields) ->
    case proplists:get_keys(Params) -- AllowedFields of
        [] -> ok;
        _UnknownFields ->
            erlang:error(unknown_amqp_params, [Params, AllowedFields])
    end.

populate_record(Record, Fields, Properties) ->
    [Type | DefaultValues] = tuple_to_list(Record),
    Defaults = lists:zip(Fields, DefaultValues),
    Values = [ proplists:get_value(Name, Properties, Def)
               || {Name, Def} <- Defaults ],
    list_to_tuple([Type | Values]).

declare_work_exchanges(Ch, #{n_workers := 1, exchange := Exchange}) ->
    declare_exchange(Ch, Exchange, <<"topic">>);
declare_work_exchanges(Ch, #{n_workers := N,
                             exchange := Exchange,
                             routing_key := RKey}) when N > 1 ->
    declare_exchange(Ch, Exchange, <<"topic">>),
    HashingExchange = hashing_exchange_name(Exchange),
    declare_exchange(Ch, HashingExchange, <<"x-consistent-hash">>),
    %% TODO: # is a wildcard; should we be more specific?
    bind_exchange(Ch, Exchange, HashingExchange, RKey).

declare_exchange(Ch, Exchange, Type) ->
    Ex = #'exchange.declare'{exchange = Exchange,
                             type = Type,
                             durable = true},
    #'exchange.declare_ok'{} = amqp_channel:call(Ch, Ex).

hashing_exchange_name(Prefix) ->
    Name = atom_to_list(node()),
    SName = string:sub_word(Name, 1, $@),
    NamePart = list_to_binary(SName),
    <<Prefix/bytes, ":", NamePart/bytes, ":splitter">>.

bind_exchange(Ch, Source, Dest, RoutingKey) ->
    B = #'exchange.bind'{source = Source,
                         destination = Dest,
                         routing_key = RoutingKey},
    #'exchange.bind_ok'{} = amqp_channel:call(Ch, B).

declare_work_queues(Ch, #{n_workers := N} = Opts) ->
    #{queue := Queue} = Opts,
    [ declare_queue(Ch, queue_name(Queue, I, N), queue_arguments(Opts))
      || I <- lists:seq(0, N-1) ].

declare_queue(Ch, Queue, Arguments) ->
    Q = #'queue.declare'{queue = Queue,
                         durable = true,
                         arguments = Arguments},
    #'queue.declare_ok'{} = amqp_channel:call(Ch, Q).

queue_name(Prefix, _SeqNo, 1) ->
    Prefix;
queue_name(Prefix, SeqNo, _NWorkers) ->
    <<Prefix/bytes, "-p", (integer_to_binary(SeqNo))/bytes>>.

queue_arguments(#{dead_letter_exchange := DLExchange,
                  message_ttl := Ttl}) ->
    [{<<"x-message-ttl">>, long, Ttl},
     {<<"x-dead-letter-exchange">>, longstr, DLExchange}];
queue_arguments(#{dead_letter_exchange := DLExchange}) ->
    [{<<"x-dead-letter-exchange">>, longstr, DLExchange}].

bind_queues(Ch, #{n_workers := N} = Opts) ->
    #{exchange := Prefix,
      queue    := Queue} = Opts,
    Exchange = case N of
                   1 -> Prefix;
                   _ -> hashing_exchange_name(Prefix)
               end,
    [ bind_queue(Ch, Exchange,
                 queue_name(Queue, I, N),
                 routing_key(Opts))
      || I <- lists:seq(0, N-1) ].

bind_queue(Ch, Exchange, Queue, RoutingKey) ->
    B = #'queue.bind'{queue = Queue,
                      exchange = Exchange,
                      routing_key = RoutingKey},
    #'queue.bind_ok'{} = amqp_channel:call(Ch, B).

routing_key(#{n_workers := 1, routing_key := RKey}) ->
    RKey;
routing_key(_) ->
    ?QUEUE_WEIGHT.

qos(Ch, PrefetchCount) ->
    Q = #'basic.qos'{prefetch_count = PrefetchCount},
    #'basic.qos_ok'{} = amqp_channel:call(Ch, Q).

subscribe(Ch, Queue) ->
    C = #'basic.consume'{queue = Queue},
    Resp = #'basic.consume_ok'{} = amqp_channel:subscribe(Ch, C, self()),
    {ok, Resp#'basic.consume_ok'.consumer_tag}.

params(Params) ->
    Fields = record_info(fields, amqp_params_network),
    validate_params(Params, Fields),
    populate_record(#amqp_params_network{}, Fields, Params).

%%--------------------------------------------------------------------
%% @doc Starts a new rabbitMQ connection with parameters extracted
%% from the worker opts.
%% @end
%%--------------------------------------------------------------------
-spec start_rabbitmq(host_opts()) -> {ok, pid()}.
start_rabbitmq(RabbitOpts) ->
    amqp_connection:start(params(maps:to_list(RabbitOpts))).

register_subscriber_metrics() ->
    folsom_metrics:new_counter(?METRIC_IN),
    folsom_metrics:new_counter(?METRIC_ACK),
    folsom_metrics:new_counter(?METRIC_ERROR),
    folsom_metrics:new_histogram(?METRIC_PROCESSING_TIME, slide, 60).

-spec get_monotonic_tstamp(timeunit()) -> monotonic_tstamp().
get_monotonic_tstamp(nano_seconds) ->
    {erlang:monotonic_time(nano_seconds), nano_seconds}.

-spec elapsed_time(monotonic_tstamp()) -> float().
elapsed_time({T0, nano_seconds}) ->
    {T1, nano_seconds} = get_monotonic_tstamp(nano_seconds),
    time_difference(T0, T1, nano_seconds).

time_difference(T0, T1, nano_seconds) ->
    NanosToMillisDiv = 1000000,
    (T1 - T0) / NanosToMillisDiv.
