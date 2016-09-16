vent
=====

An application that simplifies writing RabbitMQ producers and An application.

Typically, a client workflow is as follows:
 
- Establish a connection to a broker
- Create a new channel within the open connection
- Execute AMQP commands with a channel such as sending and receiving messages, creating exchanges and queue or defining routing rules between exchanges and queues
- When no longer required, close the channel and the connection

This workflow is common to many subscribers, and is contained within vent.
Vent delegates the consumer specific-logic to a custom `handler` behaviour.

## Publishers

## Subscribers

## Build

```bash
$ rebar3 compile
```

## Release
```
$ rebar3 release
```
