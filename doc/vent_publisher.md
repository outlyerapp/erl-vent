

# Module vent_publisher #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

__Behaviours:__ [`gen_server`](gen_server.md).

<a name="types"></a>

## Data Types ##




### <a name="type-message">message()</a> ###


<pre><code>
message() = #amqp_msg{}
</code></pre>




### <a name="type-opts">opts()</a> ###


<pre><code>
opts() = #{id =&gt; term(), chunk_size =&gt; pos_integer(), exchange =&gt; binary()}
</code></pre>




### <a name="type-state">state()</a> ###


<pre><code>
state() = #state{}
</code></pre>




### <a name="type-topic">topic()</a> ###


<pre><code>
topic() = binary()
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#code_change-3">code_change/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_call-3">handle_call/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_cast-2">handle_cast/2</a></td><td></td></tr><tr><td valign="top"><a href="#handle_info-2">handle_info/2</a></td><td></td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td></td></tr><tr><td valign="top"><a href="#publish-2">publish/2</a></td><td></td></tr><tr><td valign="top"><a href="#start_link-2">start_link/2</a></td><td></td></tr><tr><td valign="top"><a href="#terminate-2">terminate/2</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="code_change-3"></a>

### code_change/3 ###

<pre><code>
code_change(OldVsn::any(), State::<a href="#type-state">state()</a>, Extra::any()) -&gt; {ok, <a href="#type-state">state()</a>}
</code></pre>
<br />

<a name="handle_call-3"></a>

### handle_call/3 ###

<pre><code>
handle_call(Request::any(), From::any(), State::<a href="#type-state">state()</a>) -&gt; {reply, ok, <a href="#type-state">state()</a>}
</code></pre>
<br />

<a name="handle_cast-2"></a>

### handle_cast/2 ###

<pre><code>
handle_cast(Msg::{publish, <a href="#type-topic">topic()</a>, [<a href="#type-message">message()</a>]}, State::<a href="#type-state">state()</a>) -&gt; {noreply, <a href="#type-state">state()</a>}
</code></pre>
<br />

<a name="handle_info-2"></a>

### handle_info/2 ###

<pre><code>
handle_info(Down::any(), State::<a href="#type-state">state()</a>) -&gt; {noreply, <a href="#type-state">state()</a>} | {noreply, <a href="#type-state">state()</a>, <a href="#type-millis">millis()</a>} | {stop, any(), <a href="#type-state">state()</a>}
</code></pre>
<br />

<a name="init-1"></a>

### init/1 ###

<pre><code>
init(X1::{<a href="#type-host_opts">host_opts()</a>, <a href="#type-opts">opts()</a>}) -&gt; {ok, <a href="#type-state">state()</a>}
</code></pre>
<br />

<a name="publish-2"></a>

### publish/2 ###

<pre><code>
publish(Topic::<a href="#type-topic">topic()</a>, Payload::binary()) -&gt; ok
</code></pre>
<br />

<a name="start_link-2"></a>

### start_link/2 ###

<pre><code>
start_link(HostOpts::<a href="#type-host_opts">host_opts()</a>, Opts::<a href="#type-opts">opts()</a>) -&gt; <a href="#type-gen_server_startlink_ret">gen_server_startlink_ret()</a>
</code></pre>
<br />

<a name="terminate-2"></a>

### terminate/2 ###

<pre><code>
terminate(Reason::any(), State::any()) -&gt; ok
</code></pre>
<br />

