

# Module vent_handler #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

__This module defines the `vent_handler` behaviour.__<br /> Required callback functions: `init/0`, `handle/2`, `terminate/1`.

<a name="types"></a>

## Data Types ##




### <a name="type-state">state()</a> ###


<pre><code>
state() = term()
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#handle-3">handle/3</a></td><td>Handle message.</td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td>Initialize subscription handler.</td></tr><tr><td valign="top"><a href="#terminate-2">terminate/2</a></td><td>Stops a pusher.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="handle-3"></a>

### handle/3 ###

<pre><code>
handle(Mod::module(), Msg::term(), State::<a href="#type-state">state()</a>) -&gt; {ok, <a href="#type-state">state()</a>} | {requeue, term(), <a href="#type-state">state()</a>} | {drop, term(), <a href="#type-state">state()</a>}
</code></pre>
<br />

Handle message

The implementation can respond with one of 3 messages:
* {ok, State} - Processing is done and we should move on
* {requeue, Reason, State} - With that response handler is
communicating that it couldn't process it right now, but that
situation could change in feature, so message should be re tried
later. This usually happens if other systems are down and can't
be reached, but may become available in feature.
* {drop, Reason, State} - Handler should respond with drop only if
it can't do anything with message and it wont change in feature.
In this case message is moved to error queue and never re-tried.
Usually you get those responses with ill-formatted messages.

<a name="init-1"></a>

### init/1 ###

<pre><code>
init(Mod::module()) -&gt; {ok, <a href="#type-state">state()</a>}
</code></pre>
<br />

Initialize subscription handler.

<a name="terminate-2"></a>

### terminate/2 ###

<pre><code>
terminate(Mod::module(), State::<a href="#type-state">state()</a>) -&gt; ok
</code></pre>
<br />

Stops a pusher.

