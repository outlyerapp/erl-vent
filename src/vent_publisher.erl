-module(vent_publisher).
-behaviour(gen_server).

%% API
-export([start_link/2, publish/2]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-include("vent_internal.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-define(SERVER, ?MODULE).
-define(METRIC_OUT, {vent_producer, out}).

-type opts() :: #{id => term(),
                  chunk_size => pos_integer(),
                  exchange => binary()}.
-type topic() :: binary().
-type message() :: #amqp_msg{}.

-record(state, {id :: term(),
                host_opts :: host_opts(),
                opts :: opts(),
                conn :: connection(),
                channel :: channel(),
                exchange :: binary()}).

-type state() :: #state{}.

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link(host_opts(), opts()) -> gen_server_startlink_ret().
start_link(HostOpts, Opts) ->
    gen_server:start_link(?MODULE, {HostOpts, Opts}, []).

-spec publish(topic(), binary()) -> ok.
publish(Topic, Payload) ->
    gen_server:cast(?SERVER, {publish, Topic, Payload}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

-spec init({host_opts(), opts()}) -> {ok, state()}.
init({HostOpts, #{id := ID,
                  exchange := Exchange} = Opts}) ->
    register_producer_metrics(),
    RParams = mk_params(maps:to_list(HostOpts)),
    {ok, Conn} = amqp_connection:start(RParams),
    {ok, Ch} = amqp_connection:open_channel(Conn),
    link(Conn),
    link(Ch),
    %% TODO: Make exchange properties configurable
    ExCommand = #'exchange.declare'{exchange = Exchange,
                                    type = <<"topic">>,
                                    durable = true},
    #'exchange.declare_ok'{} = amqp_channel:call(Ch, ExCommand),
    {ok, #state{id = ID,
                host_opts = HostOpts,
                opts = Opts,
                conn = Conn,
                channel = Ch,
                exchange = Exchange}}.

-spec handle_call(any(), any(), state()) -> {reply, ok, state()}.
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

-spec handle_cast({publish, topic(), [message()]},
                   state()) -> {noreply, state()}.
handle_cast({publish, Topic, Payload}, State) ->
    ok = publish(Topic, Payload, State),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

-spec handle_info(any(), state()) -> {noreply, state()} |
                                     {noreply, state(), millis()} |
                                     {stop, any(), state()}.
handle_info({'DOWN', _MRef, process, _Pid, _Info} = Down, State) ->
    lager:error("broker down: ~p", [Down]),
    {stop, {broker_down, Down}, State};

handle_info(_Info, State) ->
    {noreply, State}.

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

-spec publish(topic(), [message()], #state{}) -> ok.
publish(Topic, Messages,
        State = #state{opts = #{chunk_size := S}}) when length(Messages) > S ->
    {H, T} = lists:split(S, Messages),
    publish_chunk(Topic, H, State),
    publish(Topic, T, State);
publish(_Topic, [], _State) ->
    ok;
publish(Topic, Messages, State) ->
    publish_chunk(Topic, Messages, State).

-spec publish_chunk(topic(), [message()], #state{}) -> ok.
publish_chunk(Topic, Messages, #state{channel = Ch, exchange = Exchange}) ->
    %% TODO: remove assumption on JSON serialization
    Json = jsone:encode(Messages),
    lager:info("Publishing to ~p samples to ~p exchange",
                [length(Messages), Exchange]),
    Command = #'basic.publish'{exchange = Exchange,
                               routing_key = Topic},
    M = #'amqp_msg'{props = #'P_basic'{content_type = <<"application/json">>},
                    payload = Json},
    counter_histogram:inc(?METRIC_OUT),
    amqp_channel:cast(Ch, Command, M).

-spec mk_params([proplists:property()]) -> #amqp_params_network{}.
mk_params(Opts) ->
    mk_params(Opts, #amqp_params_network{}).

-spec mk_params([proplist:property()], #amqp_params_network{}) ->
                       #amqp_params_network{}.
mk_params([], Params) ->
    Params;
mk_params([{host, Host} | Rest], Params) ->
    mk_params(Rest, Params#amqp_params_network{host = Host});
mk_params([{port, Port} | Rest], Params) ->
    mk_params(Rest, Params#amqp_params_network{port = Port});
mk_params([{virtual_host, VHost} | Rest], Params) ->
    mk_params(Rest, Params#amqp_params_network{virtual_host = VHost});
mk_params([{username, undefined} | Rest], Params) ->
    mk_params(Rest, Params);
mk_params([{username, User} | Rest], Params) ->
    mk_params(Rest, Params#amqp_params_network{username = User});
mk_params([{password, undefined} | Rest], Params) ->
    mk_params(Rest, Params);
mk_params([{password, Pass} | Rest], Params) ->
    mk_params(Rest, Params#amqp_params_network{password = Pass}).

register_producer_metrics() ->
    counter_histogram:new(?METRIC_OUT),
    exporter_server:register([?METRIC_OUT]).
