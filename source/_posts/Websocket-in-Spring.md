---
title: Websocket in Spring
date: 2017-07-20 20:43:07
tags:
	- Note
	- Websocket
	- Spring
---

[RFC 6455](https://tools.ietf.org/html/rfc6455) 定义了一种让web应用可以在服务器和客户端之间全双工通信的协议.
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


