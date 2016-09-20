-type gen_server_startlink_ret() :: {ok, pid()}
                                  | ignore
                                  | {error, {already_started, pid()}}
                                  | {error, any()}.

-type millis() :: non_neg_integer().

-type host_opts() :: #{host => string(),
                       port => pos_integer(),
                       virtual_host => binary(),
                       username => binary(),
                       password => binary()}.

-type connection() :: pid().

-type channel() :: pid().

%% `monotonic_time()` can be safely used to measure intervals.
-type monotonic_time() :: integer().

%% This could actually be any subtype of erlang:time_unit(),
%% but to minimize amount of work (conversions...) we lock
%% on nano_seconds.
-type timeunit() :: nano_seconds.

-type monotonic_tstamp() :: {monotonic_time(), timeunit()}.
