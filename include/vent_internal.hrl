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
