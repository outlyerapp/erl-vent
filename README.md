vent
=====

[![Hex pm](http://img.shields.io/hexpm/v/vent.svg?style=flat)](https://hex.pm/packages/vent)

An application that simplifies writing RabbitMQ producers and consumers.

Typically, a client workflow is as follows:
 
- Establish a connection to a broker
- Create a new channel within the open connection
- Execute AMQP commands with a channel such as sending and receiving messages, creating exchanges and queue or defining routing rules between exchanges and queues
- When no longer required, close the channel and the connection

Vent encapsulates this workflow and delegates the consumer specific-logic to a custom `handler` behaviour.

## Configuration

RabbitMQ configuration:

    {host, "localhost"},                                # defaults to 'localhost'
    {port, 5672},                                       # defaults to 5672
    {username, "user"},                                 # optional
    {password, "pass"},                                 # optional
    {virtual_host, <<"prod">>},                         # required
    {publish_exchange, <<"publish_exchange">>}          # required

## Publishers

Only one topic exchange message flow is currently supported.  Also, it is not
possible to configure multiple publishers at present.  The serialization format
is assumed to be JSON.

Publisher configuration:

    {publish_exchange, <<"publish_exchange">>}          # required
    {publish_chunk_size, 20}                            # defaults to 20

## Subscribers

A subscriber `handler` should be created for every subscription.  The behaviour
consists of the following callbacks:

    callback init() ->
       {ok, state()}.
    callback handle(term(), state()) ->
       {ok, state()} |
       {requeue, term(), state()} |
       {drop, term(), state()}.
    callback terminate(state()) ->
       ok.

An inert `vent_debug_handler` is already provided that will log every message
that it consumes.

Every subscription should be configured together with its handler:

    {n_workers, 1},                                     # defaults to 5
    {prefetch_count, 2},                                # defaults to 2
    {exchange, <<"exchange">>},                         # required
    {dead_letter_exchange, <<"dl_exchange">>},          # required
    {error_exchange, <<"errors">>},                     # required
    {error_routing_key, <<"error_routing_key">>},       # required
    {queue, <<"vent:queue">>},                          # required
    {message_ttl, 300000},                              # defaults to 300000
    {handler, vent_debug_handler}]                      # defaults to vent_debug_handler

Note that more than one subscriber may be registered.

     {subscribers,
         [{vent_subscriber, ...config for 1st subscriber},
          {vent_subscriber, ...config for 2nd subscriber}]}

## Build

```bash
$ rebar3 compile
```

In order to run tests...{to do}

## Release
```
$ rebar3 release
```
