---
title: Websocket in Spring
date: 2017-07-20 20:43:07
tags:
	- Note
	- Websocket
	- Spring
---

此文是阅读spring文档[Spring-Websocker](https://docs.spring.io/spring/docs/current/spring-framework-reference/html/websocket.html)的笔记。

[RFC 6455](https://tools.ietf.org/html/rfc6455) 定义了一种让web应用可以在服务器和客户端之间全双工通信的协议Websocket.
websocket的建立需要http协议的帮助，websocket的握手建立连接阶段是使用http协议来完成的。粗略的来讲，在需要建立websocket连接的时候，客户端在第一个http请求的时候会将http请求头
``` 
Connection: Upgrade
Upgrade: websocket
```
然后服务端回复http状态码101表示协议转换，并告知客户端转换的后协议，此时就可以使用websocket协议来进行数据传输了。
具体的websocket协议过程将在另文描述，这篇文重点介绍怎么在spring中使用websocket。
Spring Framwork 4引入了`spring-websocket`模块，除了完整的 websocket支持意外，还兼容 [JSR-356](https://jcp.org/en/jsr/detail?id=356)。
* * *
由于并不是所有的浏览器都支持websocket，或者说你使用代理的话，有些代理会不支持Upgrade 协议，或者直接断开一个长时间的tcp连接。此时需要回退（> fallback）选项来模拟websocket api的操作，
spring基于[SockJs](https://github.com/sockjs/sockjs-protocol) 提供来完全透明的回退选项。

> [How HTML5 Web Scokets interact with Proxy Server](https://www.infoq.com/articles/Web-Sockets-Proxy-Servers)

* * *
## websocket 的Sub-Protocol
websocket 只是定义的数据传输的规范，并没有像http协议那样指定数据使用什么样的协议来传输，相比http协议而言，websocket显得更加底层一些。所以websocket规定了使用sub-protocol的情况，在客户端和服务器握手期间可以使用 `Sec-WebSocket-Protocol` 来协商sub-protocol，基于此，spring提供来 [STOMP](https://stomp.github.io/stomp-specification-1.2.html#Abstract)的支持。

### WebScoket API
创建和配置一个WebSocketHandler
```Java
	public class MyHandler extends TextWebScoketHandler {
		@Override
		public void handleTextMessage(WebSocketSession session, TextMessage message) {
			// ...
		}
	}
```

配置WebSocketHandler
``` Java
@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {
	
	@Override
	public void regiserWebSocketHandlers(WebScoketHandlerRegistry) {
		registry.addHandler(myHandler(), "/myHandler");
	}

	@Bean
	public WebScoketHandler myHandler() {
		return new MyHandler();
	}
}
```

## 自定义WebSocket  握手
最简单的自定义HTTP初始化握手请求的方法是使用 `HandshakeInterceptor`，它暴露了`before` 和  `after` 的接口，顾名思义，就是在握手前和握手后执行的动作，在实际应用中，我们使用`before`来验证用户的身份和权限，一个高级选项是的扩展`DefaultHandshakeHandler`，它执行默认的握手步骤，比如验证客户端origin，协商sub-protocol等等。

## 配置 WebScoket Engine
每个底层的ws引擎都暴露了控制运行时动作行为的属性，比如message buffer size，idle timeout等等
Tomcat的配置
```Java
@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfiguere {
	
	@Bean
	public ServletServerContainerFactoryBean createWebSocketContainer() {
		ServletServerContainerFactoryBean container  = new ServletServerContainerFactoryBean();
		container.setMaxTextMessageBufferSize(8192);
		container.setMaxBinaryMessageBufferSize(8192)
		return container;
	}
}
```

## 配置allow Origin
```Java
	@Override
	public void registerWebSocketHandlers(WebSockerHandlerRegistry registry) {
		registry.addHandler(myHandler(), "/myHandler").setAllowOrigins("http://mydomain.com");
	}
```

## Overview of SockJS
SockJS 提供了即使在浏览器不支持ws的情况下也能够不改变代码就能够使用ws api的支持。
SockJS 包含一下几个部分
> - SockJS Protocol
> - SockJS JavaScript client - 一个在浏览器使用的lib
> - SockJS 的服务器端的实现
> - spring framework 4.1 `spring-websocket` 同时提供了SockJS的Java client

sjs(SockJS) 为了支持大部分的浏览器工作，使用了不同的技术，WebSocket，HTTP Streanm 和 HTTP Long Polling，
在开始的时候，sjs会发送一个`GET /info`请求到服务器来决定使用什么技术，在大部分情况下，如果浏览器不支持websocket的话，就是使用HTTP Streaming，如果你的浏览器连HTTP Streaming都不支持的话，就只能使用Long Polling了，下面是一个真实的`GET /info `请求的服务器返回
```json
{"entropy":-1196826647,"origins":["*:*"],"cookie_needed":true,"websocket":true}
```
此时服务器是支持websocket的。

*所有的传输请求使用下面的URL格式*
```scheme
http://host:port/myApp/myEndpoint/{server-id}/{session-id}/{transport}
- {server-id} 在集群下用来路由请求，否则就没用
- {session-id} 与sjs的http请求相关联
- {transport} 指定传输类型，比如 “websocket” 和 “xhr-streaming”等等
```

sjs添加了最小的数据帧（纯翻译），比如服务器发送字符o（‘open’ 数据帧）来初始化，消息通过 `a["message1","message2"]` (json), 字符 h表示心跳帧， 如果在25秒内没有消息的话，字母c（close 帧）会发送来关闭session。

## 使用SockJS
可以通过java配置来使用SockJS
```Java
@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {
		@Overried
		public void registerWebSocketHandlers (WebSocketHandlerRegistry registry) {
			registry.addHandler(myHandler(), "/myHandler").withSockJS();
		}
}
```
### 心跳消息
SockJS 协议要求服务器发送心跳消息来避免代理认为连接被hung住了从而kill掉连接，Spring SockJS 有个`heartbeatTime` 选项，用来定义心跳频率，默认是25秒。除此之外，还能配置`TaskScheduler`来自己执行心跳任务

##SockJS  Client
在没有浏览器的情况下SockJS提供了客户端来满足访问ws协议的需求，比如两个服务器之间的通信，或者ws的并发测试。SockJS的Java客户端支持 `websocket`，`xhr-streaming`，`xhr-polling`的传输选项。
一下例子展示了一个SockJS客户端如何连接到远程endpoint
```Java
List<Transport> transports = new ArrayList<>(2);
transports.add(new WebSocketTransport(new StandardWebSocketClient()));
transports.add(new RrstTemplateXhrTransport());

SockJsClient sockJsClient = new SockJsClient(transports);
sockJsClient.doHandshake(new MyWebSocketHandler(), "ws://examples.com:8080/sockjs");
···

> 由于SockJS使用json来序列化消息，所以需要一个序列化库，默认使用的是Jackson 2，如果classpath中没有这个库的话，需要在SockJsClient 中配置SocksJsMessageCodec




##使用STOMP在ws上进行数据传输
> STOMP  simple text-oriented messaging protocol

参考HTTP，STOMP是一个基本数据帧的协议，数据帧结构如下
```yaml
COMMAND
header1: value1
header2: value2

Body^@
```
客户端可以发送 `SEND` 或者`SUBSCRIBE`来发送或者订阅一个主题，发送消息可以设置 **destination** 来指定发送给哪个主题topic，这样就可以实现一个简单的*发布-订阅*机制。
当使用Spring中的STOMP时，应用此时扮演的是一个Broker的角色，消息被发送给相应的`Controller` 或者到一个简单的内存实现的broker中，接下来发送给相应的topic订阅者，其实也可以配置spring配合外部的消息Broker一起工作，比如RabbitMQ，ActiveMQ。
下面是一个客户端发送订阅股票报价主题的请求
```yaml
SUBSCRIBE
id:sub-1
destination:/topic/price.stock.*

^@
```

下面是客户端发送一个股票交易请求给服务端，服务端可以通过`@MessageMapping`来确定哪个方法来接收该请求
```yaml
SEND
destination:/queue/trade
content-type:application/json
content-length:44

{"action":"BUY","ticker":"MMM","shares":44}^@
```
在STOMP中并没有详细的确定destination的意思，它可以是任何字符串，完全有服务器定义，在这里使用类似路径的字符串来确定destination。`"/topic/···"类似的路径一般用在发布订阅模式中的消息（one-to-many），
`"/queue"` 看着像是用来一对一的消息传输。

STOMP服务器也可以使用*MESSAGE*指令来广播消息给订阅者，下面是一个发布股票报价的消息结构
```yaml
MESSAGE
message-id:nxajjsj-12
subscription:sub-1
destination:/topic/price.stock.MMM

{"ticker":"MMM","price":129.45}^@
```
请注意，服务器不能擅自给客户端发消息，所以服务器发出的消息必须是客户端通过订阅来指定的，头部中的**subscription-id**必须和客户端上传的id一致。完整的STOMP协议内容可以[参考这里](https://stomp.github.io/stomp-specification-1.2.html)

---
以下是一个使用STOMP的例子，在这里例子里，destination以"/app"开头会被交给消息处理方法来处理，以"/topic" 或者"/queue"开头的会发送给消息broker，用来接下来发送给其他已经连接的clients。
```Java
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/portfolio").withSockJS();
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        config.setApplicationDestinationPrefixes("/app");
        config.enableSimpleBroker("/topic", "/queue");
    }

}
```

## 消息流
![](https://docs.spring.io/spring/docs/current/spring-framework-reference/html/images/message-flow-simple-broker.png)

如果使用外部消息Broker的话，消息流就是这样
![](https://docs.spring.io/spring/docs/current/spring-framework-reference/html/images/message-flow-broker-relay.png)

我们通常会编写一个Java方法来处理一个客户端请求，我们会在这个方法上加上注解`@MessageMapping`，我们称这个方法叫做消息处理注解方法，当这个方法有返回值的时候，这个返回值会被spring发送给`brokerChannel`，然后broker会将消息广播给客户端。其实可以在任何时候通过使用*message template*给客户端返回消息。
```Java
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/portfolio");
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.setApplicationDestinationPrefixes("/app");
        registry.enableSimpleBroker("/topic");
    }

}

@Controller
public class GreetingController {

    @MessageMapping("/greeting") {
    public String handle(String greeting) {
        return "[" + getTimestamp() + ": " + greeting;
    }

}
```
上面的代码是这样的工作的
1. ws客户端连接上"/portfolio" endpoint
2. 对"/topic/greeting"的订阅通过"clientInboundChannel" 发送给broker
3. 发送给"/app/greeting"的消息通过“clientInboundChannel”发送给`GreetingController`。controller添加当前时间后，将返回值当作一个消息通过‘brokerChannel’发送给"/topic/greeting".(经过转变之后成为destination，但是也通过`@SendTo`来改变这一行为)
4. broker然后广播该消息给订阅者

##注解消息处理
重点来了
可以使用`@MessageMapping`来注解一个方法，在确定destination的时候，写法类似"/foo","/foo/**"，也可以包含模版函数，比如"/foo/{id}"，然后使用注解`@DestinationVariable`在方法参数中获取参数值。
在被注解的方法中可以使用以下的参数：
> - `Message` 获取被处理过后的消息
> - `@Payload` 用来获取消息的Payload，这个参数被`org.springframework.messaging.converter.MessageConverter` 转换后得来，这个注解不是必要的，因为spring可以猜出来，同时还可以使用`@Validated`
> - `@Header` 用来获取消息头部信息，有必要的话使用`org.springframwwork.core.convert.converter.Converter` 
> - `@Headers` 用来获取所有头部信息，注解的对象必须是`java.util.Map`
> - `MessageHanders` 用来获取所有的消息头部，不想使用被注解的Map来获取的话，直接在方法里面写上这个参数就可以获取到了
> - `MessageHanderAccessor`, `SimpMessageHeaderAccessor`, `StomHeaderAccessor` 用acessor的形式来获取头部信息（多种姿势）。
> - `@DestinationVariable` 用来获取注解中的模版参数值
> - `java.security.Principal` 反映用户在http 握手阶段的登录的方法参数（不是太懂）

##发送消息
应用可以给`brokerChannel`发送消息，最简单的方法就是使用`SimpMessagingTemplate`
```Java
@Controller
public class GreetingController {
	
	private SimpMessageingTemplate template;
	
	@Autowired
	public GreetingController(SimpMessageingTempalte template) {
		this.template = template;
	}

	@RequestMapping(path="/greeting", method=POST)
	public void greet(String greeting) {
		String text = "[" + getTimestamp() + "]" + greeting;
	}
}
```
## Broker
内置的broker是将消息存储在内存中然后发送给订阅者的简单broker实现，能满足的需求比较有限，如果想要一个全功能的broker，可以配置使用外部的MQ 的Broker。
首先启动外部的MQ应用之后，配置外部MQ应用支持STOMP。实际上，`MessageHandler`扮演了一个转发者的角色，与外部MQ建立连接之后，将发送消息转发给MQ，然后接收MQ的消息推送。外部MQ带来的收益有程序的健壮性和可扩展的消息广播机制。

###连接外部MQ Broker
一个STOMP转发器维护一个底层的tcp连接，这个连接只是为了发送消息，而不是接收消息，可以配置这个连接的认证信息，比如STOMP数据帧的`login`和`passcode`头部域，配置属性值是`systemLogin`和`systemPassCode`，默认值是`guest/guest`。
同样的，STOMP为每个连接的客户端维护一个tcp连接，同样的也可以配置客户端的认证信息，配置属性是`clientLogin/clientPasscode`， 默认也是`guest/guest`。
STOMP转发器和外部MQ之间同样有心跳，默认10秒，如果连接丢失，会以5秒为间隔一直重试，直到连接成功为止。

> 可以创建一个实现了`ApplicationListener<BrokerAvailabilityEvent>`的spring bean来监听转发器与外部MQ的连接情况变化。

## User Destination
STOMP可以识别前缀为 `/user/`的desination为发送给特定用户的消息。

##监听 ApplicationContext 事件 和消息切片
许多 `ApplicationContext` 事件能够被实现了 spring的 `ApplicationListener`监听到
- `BrokerAvailablilityEvent` Broker 可用状态变化监听器，在任何发送消息的时候都应该准备好处理`MessageDeliveryException`
- `SessionConnectEvent` 当一个STOMP 连接建立的时候触发的事件，意味着一个新的客户端连接，事件信息包括session id， 用户信息和自定义的头部信息
- `SessionSubscribeEvent` 新的订阅事件
- `SessionUnsubscribeEvent` 新的退订事件
- `SessionDisconnectEvent` 当一个session结束的发生的事件，客户端或者服务器的行为都能触发这个事件（废话），在一些情况下，一个session会触发多次这个事件（why？）

> spring内消息转发器的连接断开后会自动重连，但是客户端的连接，断开后不会自动重新连接，需要自己实现重连逻辑

应用可以对任意消息进行进行拦截，通过在各自的message channel 上注册`ChannelInterceptor`来实现。
For Example
```Java
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig extends AbstractWebSocketMessageBrokerConfigurer {

  @Override
  public void configureClientInboundChannel(ChannelRegistration registration) {
    registration.setInterceptors(new MyChannelInterceptor());
  }
}
```

自定义的`ChannelInterceptor`可以通过继承`ChannelInterceptorAdapter`来实现，使用`StompHeaderAccessor`或者`SimpMessageHeaderAccessor`来获取关于消息的信息
```Java
public class MyChannelInterceptor extends ChannelInterceptorAdapter {
	
	@Override
	public Message<?> preSend(Message<?> message, MessageChannel channel) {
		StompHeaderAccessor accessor = StompHeaderAccessor.wrap(message);
		SompCommand command =  accessor.getStompCommand();
		// ...
		return message;
	}
}
```

## STOMP Client
Spring 提供了底层websocket和tcp的STOMP客户端client。
首先创建和配置一个`WebSocketStompClient`:
```Java
WebSocketClient webSocketClient = new StandardWebvSocketClient();
WebSocketStompCleint stompClient = new WebSocketStompClient(websocketClient);
stompClient.setMessageConverter(new StringMessageConverter());
stompClient.setTaksSchediler(taskscheduler); // for heartbeats
```
接下来创建一个连接并提供STOMP session处理器
```java
string url = "ws://127.0.0.1:8080/endpoint";
StompSessionHandler sessionHandler = new MyStompSessionHandler();
stompClient.connect(url, sessionHandler);
```
当session可用的时候，处理器就会被唤醒
```Java
public class MyStompSessionHandler extends StompSessionhandlerAdapter {
	@Override
	public void afterConnected(StompSession session, StompHeaders connectedHeaders) {
		// ...
	}
}
```
一旦session建立之后就可以发送消息了，使用`MessageConverter`来序列化消息
```Java
session.send("/topic/foo", "payload");
```
订阅
```Java
session.subscribe("/topic/foo", new StompFrameHandler(){
	@Override
	public Type getPayloadType(StompHeaders headers) {
		return Stirng.class;
	}

	@Override
	public void handleFrame(StompHeaders headers, Object payload) {
		// ...
	}
});
```
##WebSocket Scope
每个ws session都有一个map来存储相关的属性attibutes，这个map作为inbound的头部信息传入，可以在controller中访问相关的信息
```Java
@Controller
public class MyController {
	@MessageMapping("/action")
	public void handle(SimpMessageHeaderAccessor headerAccessor) {
		Map<String, Object> attrs = headerAccessor.getSessionAttributes();
		// ...
	}
}
```
同样也可以生命一个websocket scope的spring bean，这个豆子能够被注入到controller 和任何注册在`chlientInboundChannel`的 channel interceptor。这些通常是单例的而且存在时间比ws session要长，所以你需要使用在WebSocket scoped 的bean上使用范围代理模式（scope proxy mode）。

```Java
@Component
@Scope(scopeName = "websocket", proxyMode = ScopeProxyMode.TARGET_CLASS)
public class MyBean {
	@PostConstruct
	public void init() {
		// Invoded after dependencies injected
	}

	@PreDestroy
	public void destory () {
	}
}

@Controller
public class MyController {
	private final MyBean myBean;
	
	@Autowired
	public MyController(MyBean myBean) {
		this.myBean = myBean;
	}

	@MessageMapping("/action")	
	public void handle() {
		// this.myBean from the current websocket session
	}
}
```

## 配置和性能
todo

