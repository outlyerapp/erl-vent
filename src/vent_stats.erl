-module(vent_stats).

-export([processing_start/1,
         processing_time/1,
         stats_rate/0,
         stats_slow_rate/0]).

-export_type([monotonic_tstamp/0]).

%% TODO: switch to using folsom

%% `monotonic_time()` can be safely used to measure intervals.
-type monotonic_time() :: integer().
%% This could actually be any subtype of erlang:time_unit(),
%% but to minimize amount of work (conversions...) we lock
%% on nano_seconds.
-type unit() :: nano_seconds.
-type monotonic_tstamp() :: {monotonic_time(), unit()}.

-spec processing_start(unit()) -> monotonic_tstamp().
processing_start(nano_seconds) ->
    {erlang:monotonic_time(nano_seconds), nano_seconds}.

%% Call to post the stat sample - strictly for the side effect.
-spec processing_time(monotonic_tstamp()) -> ok.
processing_time({T0, nano_seconds}) ->
    T1 = erlang:monotonic_time(nano_seconds),
    statsderl:timing(<<"processing.time">>,
                     processing_delta(T0, T1, nano_seconds),
                     stats_rate()).

processing_delta(T0, T1, nano_seconds) ->
    NanosToMillisDiv = 1000000,
    (T1 - T0) / NanosToMillisDiv.

-spec stats_rate() -> number().
stats_rate() ->
    %% TODO: really need to change this when moving to separate package
    application:get_env(vent, rate, 1).

-spec stats_slow_rate() -> number().
stats_slow_rate() ->
    application:get_env(vent, slow_rate, 1).
