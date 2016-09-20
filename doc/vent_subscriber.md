

# Module vent_subscriber #
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




### <a name="type-monitor_down">monitor_down()</a> ###


<pre><code>
monitor_down() = {'DOWN', reference(), process, pid(), any()}
</code></pre>




### <a name="type-opts">opts()</a> ###


<pre><code>
opts() = #{id =&gt; term(), handler =&gt; module(), exchange =&gt; binary(), error_exchange =&gt; binary(), dead_letter_exchange =&gt; binary(), error_routing_key =&gt; binary(), n_workers =&gt; pos_integer(), prefetch_count =&gt; pos_integer(), queue =&gt; binary(), message_ttl =&gt; <a href="#type-millis">millis()</a>}
</code></pre>




### <a name="type-state">state()</a> ###


<pre><code>
state() = #state{}
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#code_change-3">code_change/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_call-3">handle_call/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_cast-2">handle_cast/2</a></td><td></td></tr><tr><td valign="top"><a href="#handle_info-2">handle_info/2</a></td><td></td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td></td></tr><tr><td valign="top"><a href="#start_link-2">start_link/2</a></td><td></td></tr><tr><td valign="top"><a href="#terminate-2">terminate/2</a></td><td></td></tr></table>


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
handle_cast(Msg::any(), State::<a href="#type-state">state()</a>) -&gt; {noreply, <a href="#type-state">state()</a>}
</code></pre>
<br />

<a name="handle_info-2"></a>

### handle_info/2 ###

<pre><code>
handle_info(Msg, State::<a href="#type-state">state()</a>) -&gt; Result
</code></pre>

<ul class="definitions"><li><code>Msg = {subscribe, <a href="#type-millis">millis()</a>, <a href="#type-millis">millis()</a>} | <a href="#type-monitor_down">monitor_down()</a> | <a href="#type-message">message()</a></code></li><li><code>Result = {noreply, <a href="#type-state">state()</a>} | {stop, any(), <a href="#type-state">state()</a>}</code></li></ul>

<a name="init-1"></a>

### init/1 ###

<pre><code>
init(X1::{<a href="#type-host_opts">host_opts()</a>, <a href="#type-opts">opts()</a>}) -&gt; {ok, <a href="#type-state">state()</a>}
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

