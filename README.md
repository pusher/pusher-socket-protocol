# Pusher Protocol

Describes the JSON based protocol used by clients to communicate with Pusher, mainly over a WebSocket connection.
{: .intro}

<ul class="toc">
  <li><a href="#websocket-connection">WebSocket connection</a>
    <ul>
      <li><a href="#websocket-messages">WebSocket data messages</a></li>
      <li><a href="#ping-pong">Ping and pong messages</a></li>
      <li><a href="#connection-closure">Connection closure</a></li>
    </ul>
  </li>
  <li><a href="#events">Events</a>
    <ul>
      <li><a href="#connection-events">Connection events</a></li>
      <li><a href="#system-events">System events</a></li>
      <li><a href="#subscription-events">Subscription events</a></li>
      <li><a href="#channel-events">Channel events</a></li>
      <li><a href="#presence-channel-events">Presence channel events</a></li>
      <li><a href="#channel-client-events">Triggering channel events from the client</a></li>
    </ul>
  </li>
  <li><a href="#client-library-considerations">Client Library Considerations</a>
    <ul>
      <li><a href="#class-structure">Class Structure</a></li>
      <li><a href="#client-only-events">Client Only Events</a></li>
    </ul>
  </li>
  <li><a href="#error-codes">Error codes</a></li>
  <li><a href="#changelog">CHANGELOG</a></li>
</ul>

Changes to this protocol are handled by incrementing an integer version number. The current protocol, version 7, is documented here. Currently protocol 4 and later are supported by Pusher, however clients are encouraged to keep up to date with changes.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in RFC 2119.

----

## WebSocket connection
{: id="websocket-connection"}

Clients should make a WebSocket connection to

    [scheme]://ws.pusherapp.com:[port]/app/[key]

* **scheme**
  * `ws` - for a normal WebSocket connection
  * `wss` - for a secure WebSocket connection
* **port**
  * Default WebSocket ports: 80 (ws) or 443 (wss)
  * For Silverlight clients ports 4502 (ws) and 4503 (wss) may be used.
* **key**
  * The app key for the application connecting to Pusher

The following query parameters should be supplied:

  * **protocol** [integer]
    * The protocol version to use. If this is not supplied the protocol version to use is inferred from the version parameter (to support old javascript clients which relied on this behaviour). Failing that protocol 1 is used (this behaviour is deprecated and will in future be replaced by a 4008 error code)
  * **client** [string]
    * Identifies the client which is connecting. This string should be of the form `platform-library` - for example the iOS library identifies itself as `iOS-libPusher`.
  * **version** [string]
    * The version of the library which is connecting, for example `1.9.3`.

For example

    ws://ws.pusherapp.com:80/app/APP_KEY?client=js&version=<%= APP_CONFIG[:current_js_version] %>&protocol=5

### WebSocket data messages
{: id="websocket-messages"}

Data is sent bidirectionally over a WebSocket as text data containing UTF8 encoded JSON.

**Note**: Binary WebSocket frames are not supported.

Every JSON message contains a single **event** and has an `event` property which is known as the event name. See <a href="#events">events</a> below for a description of the event types.

### Ping and pong messages
{: id="ping-pong"}

If the WebSocket connection supports ping & pong (i.e. advertises itself as draft 01 or above), Pusher will send ping messages to the client in order to verify that it is active.

In protocol versions 5 and above, when using an old version of the WebSocket protocol, Pusher will send `pusher:ping` event (see [events](#events)) to the client. The client should respond with a `pusher:pong` event.

#### Detecting that the connection is alive

Both Pusher and clients require a mechanism for establishing that the connection is alive.

The basic design pattern is described in the [ZeroMQ Wiki](http://www.zeromq.org/deleted:topics:heartbeating) and is symmetric for the client and Pusher.

Essentially any messages received from the other party are considered to mean that the connection is alive. In the absence of any messages either party may check that the other side is responding by sending a ping message, to which the other party should respond with a pong.

In recent WebSocket drafts ping & pong are supported as part of the protocol. Unfortunately this was not the case in earlier drafts, and unfortunately it is still not possible to trigger sending a ping, or binding to a pong from JavaScript using the [W3C API](http://dev.w3.org/html5/websockets/#ping-and-pong-frames). For both these reasons, Pusher supports both protocol level ping-pong, and an emulated one. This means that Pusher will respond to a WebSocket protocol ping message with a pong message, and also it will respond to a `pusher:ping` event with a `pusher:pong` event (both have empty data).

#### Recommendations for client libraries

If the WebSocket draft supports protocol level ping-pong, then on receipt of a ping message, the client MUST respond with a pong message.

If the client does not support protocol level pings and advertises (on connect) that it implements a protocol version >= 5 then the client MUST respond to a `pusher:ping` event with a `pusher:pong` event.

Clients SHOULD send a ping to Pusher when the connection has been inactive for some time in order to check that the connection is alive. They MUST then wait some time for receipt of a pong message before closing the connection / reconnecting. Clients SHOULD send a protocol ping if supported (sending a `pusher:ping` event will also work).

Clients MAY use platform specific APIs to trigger a ping check at an appropriate time (for example when network conditions change).

The precise timeouts before sending a ping and how long to wait for a pong MAY be configurable by the user of the library, but sensible defaults SHOULD be specified. The recommended values are:

* Activity timeout before sending ping: 120s
* Time to wait for pong response before closing: 30s

If the client supports protocol version 7, the server will send an `activity_timeout` value in the data hash of the `pusher:connection_established` event (see <a href="#connection-events">Connection Events</a>). The client SHOULD set the timeout before sending a ping to be the minimum of the value it has chosen though configuration and the value supplied by the server.

The following example code is taken from the `pusher-js` library. This function is called whenever a message is received

    function resetActivityCheck() {
      if (self._activityTimer) { clearTimeout(self._activityTimer); }
      // Send ping after inactivity
      self._activityTimer = setTimeout(function() {
        self.send_event('pusher:ping', {})
        // Wait for pong response
        self._activityTimer = setTimeout(function() {
          self.socket.close();
        }, (self.options.pong_timeout || Pusher.pong_timeout))
      }, (self.options.activity_timeout || Pusher.activity_timeout))
    }

### Connection closure

Clients may close the WebSocket connection at any time.

The Pusher server may choose to close the WebSocket connection, in which case a close code and reason will be sent.

Clients SHOULD support the following 3 ranges

**4000-4099**: The connection SHOULD NOT be re-established unchanged.

**4100-4199**: The connection SHOULD be re-established after backing off. The back-off time SHOULD be at least 1 second in duration and MAY be exponential in nature on consecutive failures.

**4200-4299**: The connection SHOULD be re-established immediately.

Clients MAY handle specific close codes in particular way, but this is generally not necessary. See [error codes](#error-codes) below for a list of errors.

**Old WebSocket drafts**: If the underlying WebSocket does not support close codes then a `pusher:error` event will be sent with an appropriate code before the WebSocket connection is closed (see [below](#system-events)).
{: class="alert alert-info"}

**Legacy protocols**: When using protocol versions < 6, a `pusher:error` event is also sent before the connection is closed (regardless of the WebSocket draft).
{: class="alert alert-info"}

----

## Events
{: id="events"}

Every message on a Pusher WebSocket connection is packaged as an 'event', whether it is user-generated, or if it is a message from the system. There is always an event name that can be used to determine what should happen to the payload.
{: class="intro"}

Every event must contain an `event` property containing the event name.

In the docs below "(Pusher -> Client)" indicates that this event is sent from the Pusher server to to client, and similarly vice versa.

### Double encoding

All events received and sent by clients can contain a `data` field. While all `pusher:`-prefixed events contain only JSON-serializable hashes, it is possible for publishers to trigger messages containing arbitrarily-encoded data. In order to keep the protocol consistent, Pusher tries to send the `data` field as a string. In case of `pusher:` events data has to be JSON-serialized first. For example, Pusher will send:

    {
      "event": "pusher:connection_established",
      "data": "{\"socket_id\":\"123.456\"}"
    }

instead of:

    {
      "event": "pusher:connection_established",
      "data": {"socket_id": "123.456"}
    }


### Connection events
{: id="connection-events"}

##### `pusher:connection_established` (Pusher -> Client)

When the client has connected to the Pusher service a `pusher:connection_established` event is triggered. Once this event has been triggered subscriptions can be made to Pusher using the WebSocket connection.

    {
      "event": "pusher:connection_established",
      "data": String
    }

Where the `data` field is a JSON-encoded hash of following format:

    {
      "socket_id": String
      "activity_timeout": Number
    }

* data.socket_id (String)
  * A unique identifier for the connected client
* data.activity_timeout (Number) (Protocol 7 and above)
  * The number of seconds of server inactivity after which the client should initiate a ping message

Within the client libraries the connection is normally established when the constructor is called.

<div class="code">
    <code data-lang="js">
      var pusher = new Pusher('APP_KEY');
    </code>
</div>

![Connection and connection event](/images/docs/connect.png)

### System Events
{: id="system-events"}

#### `pusher:error` (Pusher -> Client)

When an error occurs a `pusher:error` event will be triggered. An error may be sent from Pusher in response to invalid authentication, an invalid command, etc.

**Old WebSocket drafts**: Some errors result in the WebSocket connection being closed by Pusher. If the WebSocket connection does not support close codes then a `pusher:error` event will be sent with an appropriate code before the WebSocket connection is closed.
{: class="alert alert-info"}

    {
      "event": "pusher:error",
      "data": {
        "message": String,
        "code": Integer
      }
    }

* data.message (String)
  * A textual description of the error
* data.code (Integer) - optional
  * A code that identifies the error that has occurred. See <a href="#error-codes">error codes</a> below.

### Subscription Events
{: id="subscription-events"}

#### `pusher:subscribe`  (Client -> Pusher)
{: id="pusher-subscribe"}

The `pusher:subscribe` event is generated on the client and sent to Pusher when a subscription is made. For more information on channel names see the [channels documentation](http://pusher.com/docs/client_api_guide/client_channels).

    {
      "event": "pusher:subscribe",
      "data": String
    }

Where the `data` field is a JSON-encoded hash of following format:

    {
      "channel": String,
      "auth": String,
      "channel_data": Object
    }

* data.channel (String)
  * The name of the channel that is being subscribed to.
* data.auth (String) [optional]
  * If the channel is a presence or private channel then the subscription needs to be authenticated. The authentication signature should be provided on this property if required. The value will be generated on the application server. For more information see [authentication signatures](/docs/auth_signatures).
* data.channel_data (Object) [optional]
  * This property should be populated with additional information about the channel if the channel is a presence channel. The JSON for the `channel_data` will be generated on the application server and should simply be assigned to this property within the client library. The format of the object is as follows:

##### Example JSON

    {
      "event": "pusher:subscribe",
      "data": "{
        \"channel\": \"presence-example-channel\",
        \"auth\": \"<APP_KEY>:<server_generated_signature>\",
        \"channel_data\" :{
          \"user_id\": \"<unique_user_id>\",
          \"user_info\" :{
            \"name\": \"Phil Leggetter\",
            \"twitter\": \"@leggetter\",
            \"blogUrl\":\"http://blog.pusher.com\"
          }
        }
      }"
    }

For more information see [authenticating users](/docs/authenticating_users).

From the API users point of view the subscription is made the moment that the `subscribe` method is called. However, the actual moment within the client library that a `pusher:subscribe` event is triggered depends on the type of channel that is being subscribed to.

<div class="code">
    <code data-lang="js">
var pusher = new Pusher('APP_KEY');
var channel = pusher.subscribe('public-channel');
    </code>
</div>

##### Public channel subscription

Since no authentication must take place when subscribing to a public channel the `pusher:subscribe` event can be sent from the client to Pusher as soon as the call to `subscribe` is made.

![Subscribing to a public channel](/images/docs/subscribe.png)

##### Private and Presence channel subscription

Private and Presence channels require authentication so an additional call needs to be made to the application server hosting the web application in order to make sure the current user can subscribe to the given channel.

![Subscribing to a private channel](http://www.websequencediagrams.com/cgi-bin/cdraw?lz=cGFydGljaXBhbnQgIkFQSSBVc2VyIiBhcyBBVQoADw5wcCBTZXJ2ABcIUwARDkNsaWVudCBMaWJyYXJ5AD0FQ0wANA5QdXNoAFYHUAoKQVUtPkNMOiBwABEFLnN1YnNjcmliZSgncHJpdmF0ZS1jaGFubmVsJykKQ0wtPkFTOi8AJgYvYXV0aC8_XG4AGgdfbmFtZT0AJw8mXG5zb2NrZXRfaWQ9PAACCT4KQVMtAHQFPGF1dGggcmVzcG9uc2U-AF8FUDp7XG4iZXZlbnQiOiIAgRQGOgCBEQkiLFxuImRhdGEiACIFAIEYByI6IgCBIg8AIwVrZXkiOiAiPHNpZ25hdHVyZT4AOgUAgSsIAEEGIDxkYXRhPn1cbn0K&s=napkin)
<!-- Edit: http://www.websequencediagrams.com/?lz=cGFydGljaXBhbnQgIkFQSSBVc2VyIiBhcyBBVQoADw5wcCBTZXJ2ABcIUwARDkNsaWVudCBMaWJyYXJ5AD0FQ0wANA5QdXNoAFYHUAoKQVUtPkNMOiBwABEFLnN1YnNjcmliZSgncHJpdmF0ZS1jaGFubmVsJykKQ0wtPkFTOi8AJgYvYXV0aC8_XG4AGgdfbmFtZT0AJw8mXG5zb2NrZXRfaWQ9PAACCT4KQVMtAHQFPGF1dGggcmVzcG9uc2U-AF8FUDp7XG4iZXZlbnQiOiIAgRQGOgCBEQkiLFxuImRhdGEiACIFAIEYByI6IgCBIg8AIwVrZXkiOiAiPHNpZ25hdHVyZT4AOgUAgSsIAEEGIDxkYXRhPn1cbn0K&s=napkin -->

For more information on authentication of channels see the [Authenticating Users docs](/docs/authenticating_users).

#### `pusher:unsubscribe` (Client -> Pusher)

The `pusher:unsubscribe` event is generated on the client and sent to Pusher when a client wishes to unsubscribe from a channel.

    {
      "event": "pusher:unsubscribe",
      "data" : String
    }

Where the `data` field is a JSON-encoded hash of following format:

    {
      "channel": String
    }

* data.channel (String)
  * The name of the channel to be unsubscribed from.

Unsubscribing works in the same way as subscribing to a channel with the only difference being that the event name is `pusher:unsubscribe`.

<div class="code">
    <code data-lang="js">
var pusher = new Pusher('APP_KEY');
var channel = pusher.subscribe('public-channel');

// ...

pusher.unsubscribe('my-channel');
    </code>
</div>

![Unsubscribing](/images/docs/unsubscribe.png)

### Channel Events (Pusher -> Client)
{: id="channel-events"}

Channel events are associated with a single channel.

    {
      "event": String,
      "channel": String,
      "data": String
    }

* event (String)
  * The name of the event
* channel (String)
  * The name of the channel that the event is associated with e.g. `test-channel`
* data (String)
  * The data associated with the event. It is strongly recommended that this be a JSON-serialized hash (e.g. `{"hello":"world", "foo": {"bar": 1000}}`), although it is possible to send any type of payload, for example a simple string.

*Note: The following code shows how to receive an event and not how to trigger one*

<div class="code">
    <code data-lang="js">
var pusher = new Pusher('APP_KEY');
var channel = pusher.subscribe('my-channel');
channel.bind('my-event', function(data){
  // handle event
});
    </code>
</div>

![Receiving events](/images/docs/receive-events.png)

### Presence Channel Events
{: id="presence-channel-events"}

Some events are related only to presence channels.

#### pusher_internal:subscription_succeeded (Pusher -> Client)

The `pusher_internal:subscription_succeeded` event is sent when a subscription to a presence channel is successful.

    {
      "event": "pusher_internal:subscription_succeeded",
      "channel": "presence-example-channel",
      "data": String
    }

Where the `data` field is a JSON-encoded hash of following format:

    {
      "presence": {
        "ids": Array,
        "hash": Hash,
        "count": Integer
      }
    }

* channel (String)
  * The presence channel name
* data.presence.ids (Array)
  * An array of unique user identifiers who are subscribe to the channel.
* data.presence.hash (Hash)
  * A hash of user IDs to object literals containing information about that user.
* data.presence.count (Integer)
  * The number of users subscribed to the presence channel

##### Example JSON

    {
      "event": "pusher_internal:subscription_succeeded",
      "channel": "presence-example-channel",
      "data": "{
        \"presence\": {
        \"ids\": [\"11814b369700141b222a3f3791cec2d9\",\"71dd6a29da2a4833336d2a964becf820\"],
        \"hash\": {
          \"11814b369700141b222a3f3791cec2d9\": {
            \"name\":\"Phil Leggetter\",
            \"twitter\": \"@leggetter\"
          },
          \"71dd6a29da2a4833336d2a964becf820\": {
            \"name\":\"Max Williams\",
            \"twitter\": \"@maxthelion\"
          }
        },
        \"count\": 2
      }"
    }

#### pusher_internal:member_added (Pusher -> Client)

When a user subscribes to a presence channel the `pusher_internal:member_added` is triggered on the from Pusher. The different event name is used to differentiate a public event from an internal one.

    {
      "event": "pusher_internal:member_added",
      "channel": "presence-example-channel",
      "data": String
    }

Where the `data` field is a JSON-encoded hash of following format:

    {
      "user_id": String,
      "user_info": Object
    }

* channel (String)
  * The presence channel name
* data.user_id (String)
  * The ID of a user who has just subscribed to the presence channel.
* data.user_info (Object)
  * An object containing information about that user who has just subscribed to the channel. The contents of the `user_info` property depends on what the application server replied with when the presence channel was authenticated.

##### Example JSON

    {
      "event": "pusher_internal:member_added",
      "channel": "presence-example-channel",
      "data": "{
        \"user_id\": \"11814b369700141b222a3f3791cec2d9\",
        \"user_info\": {
          \"name\": \"Phil Leggetter\",
          \"twitter\": \"@leggetter\",
          \"blogUrl\": \"http://blog.pusher.com\"
        }
      }"
    }

For more about the `user_info` object literal see `user_info` in the [authenticating users](/docs/authenticating_users) section.

#### pusher_internal:member_removed (Pusher -> Client)

When a user unsubscribes from a presence channel by either actually unsubscribing or their WebSocket connection closing the `pusher_internal:member_removed` is triggered on the from Pusher. The different event name is used to differentiate a public event from an internal one.

    {
      "event": "pusher_internal:member_removed",
      "channel": "presence-example-channel",
      "data": String
    }

Where the `data` field is a JSON-encoded hash of following format:

    {
      "user_id": String
    }

* channel (String)
  * The presence channel name
* data.user_id (String)
  * The ID of a user who has just unsubscribed from the presence channel.

### Triggering Channel Client Events
{: id="channel-client-events"}

It is possible to trigger events from a client when the application that the client has connected to has had client events enabled, the event name must be prefixed with `client-` and the channel must be an authenticated channel (private or presence). For more information on this see the [Triggering Client Events docs](http://pusher.com/docs/client_api_guide/client_events#trigger-events).

    {
      "event": String,
      "channel": String
      "data": String/Object
    }

* event (String)
  * The name of the event which must be prefixed with `client-` to be accepted. For example, `client-event` or `client-something-updated`
* channel (String)
  * The channel for the event to be triggered on. To be accepted the channel must be either a private (`private-`) or a presence (`presence-`) channel.
* data (String/Object)
  * The data to be sent and associated with the event. It is strongly recommended that this be a hash of key/value pairs (`{"hello":"world", "foo": {"bar": 1000}}`) although it is possible to send any type of payload, for example a simple string.

<div class="code">
    <code data-lang="js">
var pusher = new Pusher('APP_KEY');
var channel = pusher.subscribe('private-channel');
var data = {"some": "data"};
channel.trigger("client-event", data);
    </code>
</div>

![Triggering a client event](http://www.websequencediagrams.com/cgi-bin/cdraw?lz=cGFydGljaXBhbnQgIkFQSSBVc2VyIiBhcyBBVQoAEA1DbGllbnQgTGlicmFyeQAeBUNMABUOUHVzaAA3B1AKCkFVLT5DTDogY2hhbm5lbC50cmlnZ2VyKCdjAEUFLWV2ZW50JyxcbiB7InNvbWUiOiJkYXRhfSkKQ0wtPlA6e1xuIgAfBSI6IgAnDCIsXG4iAE4HIiwgInByaXZhdGUtAAkKXG4ARQUiOgBMDSJ9XG59Cm5vdGUgcmlnaHQgb2YgUDogAIEvBiB0aGVuIFxuZGlzdHJpYnV0ZXMgdG9cbiBhbGwgb3RoZXJcbiBjb25uZWN0ZWQgAIE9BnMuCg&s=napkin)
<!-- edit: http://www.websequencediagrams.com/?lz=cGFydGljaXBhbnQgIkFQSSBVc2VyIiBhcyBBVQoAEA1DbGllbnQgTGlicmFyeQAeBUNMABUOUHVzaAA3B1AKCkFVLT5DTDogY2hhbm5lbC50cmlnZ2VyKCdjAEUFLWV2ZW50JyxcbiB7InNvbWUiOiJkYXRhfSkKQ0wtPlA6e1xuIgAfBSI6IgAnDCIsXG4iAE4HIiwgInByaXZhdGUtAAkKXG4ARQUiOgBMDSJ9XG59Cm5vdGUgcmlnaHQgb2YgUDogAIEvBiB0aGVuIFxuZGlzdHJpYnV0ZXMgdG9cbiBhbGwgb3RoZXJcbiBjb25uZWN0ZWQgAIE9BnMuCg&s=napkin -->

----

## Client Library Considerations
{: id="client-library-considerations"}

A client library does much more than just proxy information between Pusher and client. It adds functionality to make using Pusher even easier. It does things such as reconnection, provides information and feedback about the connection state, performs subscription management (keeps track of what channels have been subscribed to) and routes events to the correct event listeners.

### Class Structure
{: id="class-structure"}

We don't want to dictate the structure of code but it's definitely easier if the libraries across different technologies have a similar class structure. The following diagram shows the structure of the JavaScript client library:

<div style="margin:auto;text-align:center;">
  <img src="/images/docs/client-library-uml.png" alt="Client Library suggested class structure" />
</div>

The following sections explain the purpose of each class shown within the diagram, what they represent and their interaction with other classes.

#### EventEmitter

A number of classes inherit from the `EventEmitter` which makes it easy for events to be bound to and ensures that binding is performed in a consistent way between all classes.

#### Pusher

The `Pusher` class is the main class which is created when connecting to Pusher. It creates a connection object which then established the connection to Pusher.

#### Connection

The `Connection` class represents the connection to Pusher and abstracts away the underlying connection mechanism. The recommended approach for connection is to use a `WebSocket`. In the JavaScript implementation a Flash Socket connection is created when the web browser does not support WebSockets.

#### WebSocket

The diagram shows a `WebSocket` object which is the native object used to connect to Pusher.

#### Channel

A `Channel` represents a source of data from Pusher and a subscription. A `Pusher` instance can contain many Channels and thus have many subscriptions.

#### PrivateChannel

A `PrivateChannel` inherits from `Channel` and represents an authenticated subscription for channel data from Pusher.

#### PresenceChannel

A `PresenceChannel` represents and authenticated subscription and thus inherits from `PrivateChannel`. Additional presence-only events can be subscribed to on the `PresenceChannel` object that notify the library user of the members that are subscribed to the channel and when members are subscribe or unsubscribe from the channel.

### Client Only Events
{: id="client-only-events"}

Client Only Events are events that transition from the client library to the API user only. They are generated within the library to provide the developer with additional information about the state or actions that occurring within the library. In keeping with the event paradigm that we use in Pusher it is recommended that client libraries also use events when communicating change within the library with the library user.

#### Connection States

Understanding and having access to information about the connection status to Pusher is very important, especially when developing for applications to run on mobile devices where network connectivity might not be very reliable. For this reasons we've spent a lot of time thinking about how to manage this and how best to keep a developer informed about the connection state. We have implemented functionality for this within the JavaScript library and we recommend that other client libraries copy, or follow, this functionality very closely.

For more information see our [connection states documentation](/docs/connection_states).

#### pusher:subscription_succeeded

The `pusher:subscription_succeeded` event is triggered following the receipt of a `pusher_internal:subscription_succeeded` event. The different event name is used to differentiate a public event from an internal one.

    {
      "event": "pusher:subscription_succeeded",
      "members": Object
    }

* members (Object)
  * The members object contains information on the members that are subscribed to the presence channel.

The `members` object interface is as follows:

<div class="code">
    <code data-lang="js">
function Members() {};
/* For each member call the `iterator` function */
Members.prototype.each = function(iterator /* Function */) {};
Members.prototype.count = 0;
Members.prototype.get = function(userId){};
    </code>
</div>

*Note: The members object is structured in this way because in future versions the members may be accessed through **lazy loading** within the `each` function.*

For more information on the members object see the `pusher:subscription_succeeded` section of the [presence events docs](/docs/client_api_guide/client_presence_events).

----

## Error Codes

### 4000-4099

Indicates an error resulting in the connection being closed by Pusher, and that attempting to reconnect using the same parameters will not succeed.

* `4000`: Application only accepts SSL connections, reconnect using wss://

* `4001`: Application does not exist

* `4003`: Application disabled

* `4004`: Application is over connection quota

* `4005`: Path not found

* `4006`: Invalid version string format

* `4007`: Unsupported protocol version

* `4008`: No protocol version supplied

### 4100-4199

Indicates an error resulting in the connection being closed by Pusher, and that the client may reconnect after 1s or more.

* `4100`: Over capacity

### 4200-4299

Indicates an error resulting in the connection being closed by Pusher, and that the client may reconnect immediately.

* `4200`: Generic reconnect immediately
* `4201`: Pong reply not received: ping was sent to the client, but no reply was received - see [ping and pong messages](#ping-pong)
* `4202`: Closed after inactivity: Client has been inactive for a long time (currently 24 hours) and client does not support ping. Please upgrade to a newer WebSocket draft or implement version 5 or above of this protocol.

### 4300-4399

Any other type of error.

* `4301`: Client event rejected due to rate limit

----

## CHANGELOG
{: id="changelog"}

### Version 7 (2013-11)

The server now sends the activity timeout in the
`pusher:connection_established` event.

### Version 6 (2013-03)

When the server closes connections due to an error, a `pusher:error` event is only sent if and old WebSocket draft is in use which does not support close codes. Clients SHOULD therefore expose the close code and reason in some way to the developer.

### Version 5 (2012-01)

Pusher expects the client to respond to ping messages [[docs]](#ping-pong)

### Version 4 (2011-12)

Added a confirmation message after subscribing to public and private channels (already sent for presence channels)

### Version 3 (2011-02)

Significant change to presence events [[docs]](#presence-channel-events)

### Version 2

Renamed `connection_established` event to `pusher:connection_established`

### Version 1

Initial release
