-module(vent_helper).

-export([get_host_opts/0, opt/2, required_opt/1]).

-include("vent_internal.hrl").

-spec get_host_opts() -> host_opts().
get_host_opts() ->
    Opts = [{host, opt(host, "localhost")},
            {port, opt(port, 5672)},
            {virtual_host, opt(virtual_host, <<"/">>)},
            {username, opt(username, undefined)},
            {password, opt(password, undefined)}],
    maps:from_list([{K, V} || {K, V} <- Opts, V =/= undefined]).

-spec opt(atom(), term()) -> term().
opt(Name, Default) ->
    application:get_env(vent, Name, Default).

-spec required_opt(atom()) -> term().
required_opt(Name) ->
    {ok, Val} = application:get_env(vent, Name),
    Val.
