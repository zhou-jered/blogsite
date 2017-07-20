---
title: Websocket in Spring
date: 2017-07-20 20:43:07
tags:
	- Note
	- Websocket
	- Spring
---

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


