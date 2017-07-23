---
title: HTML5 WebSocket 如何与代理服务器交互【Translation】
date: 2017-07-23 19:55:15
tags:
	- Translation
	- Websocket
---

这篇文章是infoQ上[How HTML5 Web Socket Interact With Proxy Servers](https://www.infoq.com/articles/Web-Sockets-Proxy-Servers) 的翻译。
没事干干老本行，直译出来的东西好像看着也比较蛋疼，就意译好了。

随着近些年越来越多的服务器使用websocket，出现了许多关于html5 websocket如何处理服务器代理，防火墙，负载均衡路由的问题，服务器代理会自动的断开websocket的连接吗？html5 websocket会比Comet（这是个啥？）更好的处理防火墙和服务器代理的问题吗？同时在客户端与服务端实时数据传输websocket是最好的办法吗？在这篇文章中，我将会解释html5 websocket如何和服务器代理，防火墙，负载均衡路由交互。另外，我将会解释Kaazing WebSocket Gateway和它对websocket的模拟能添加一个额外的值。

## 关于html5 websocket和服务器代理
让我们从名字解释开始，到底什么是html5 websocket 和服务器代理

### html5 Web Sockets
Html5 Web Sockets 规范定义了 *Web Sockets API*，网页可以使用*Web Socket protocol* 与服务器进行全双工通信。它介绍了在网络上一个socket连接上如何操作WebSocket接口和全双工的通信channel。相比过去的使用polling和long polling来解决实时数据传输的解决方案, html5 WebSocket提供了一个通过网络的尽可能底层的socket连接，其结果就是降低了大量的没必要的网络传输和延时，而且前者为了模拟全双工通信，还要同时维护两条http连接。

为了使用html5 websocket来从一个web客户端连接到远程服务器，你需要创建一个WebSocket 实例并且提供远程服务器的URL，具体的定义是使用 ws:// 或者 wss:// scheme 来指定一个websocket 或者经过加密之后的websocket，相应的，一个websocket的连接是通过http协议过程的握手阶段的Upgrade操作来完成的，upgrade之后的websocket体层使用的tcp连接与http协议握手阶段的连接是同一个。

### 服务器代理
服务器代理就是在客户端和真正的服务器之间的中间人。服务器代理一般用来做内容缓存，网络连接性（？？？），安全，和企业内容过滤。经典的用法是代理一般设置在内网和公网之间，服务器代理可以控制流量或者关闭一个长时间打开的连接。服务器代理和需要长时间连接的应用之间的问题是显而易见的，http服务器代理，是为了文档传输而设计的---会选择关闭长连接，因为服务器代理会认为服务器此时没有响应。这种主动关闭连接的行为在长时间连接比如websocket的时候就会成为一个问题。而且，服务器代理会缓存没经过加密的服务器响应内容，这回导致在http响应流不可预测的延时。

### html5 Web Socket 和服务器代理
让我们来看看html5 websocket 如何与服务器代理协同工作，websocket连接使用标准的http端口（80或者443）。因此，html5 websocket不需要安装的新的硬件设施（？？？）或者打开新的端口。如果在客户端和服务器之间没有第三方介入的话，websocket连接能够很容易的就建立起来，然而，在现实环境中，许多流量是经过了中间件路由之后的。

话说一图胜千言，下图展示了经过简化后的客户使用浏览器来访问一个基于tcp的全双工websocket的拓扑图。一些企业客户端位于企业内网中，被企业防火墙所保护起来，通过统一的对外防火墙来访问外部网络，一部分客户端直接位于公共网络上，可以直接访问服务器，在这两种枪框下，客户端请求也许被完全透明的的被服务器代理路由到真正的服务器或者下一集的服务器代理。
![](https://cdn.infoq.com/statics_s2_20170718-0237/resource/articles/Web-Sockets-Proxy-Servers/en/resources/websockets1.png)

和普通的使用请求／响应模式的http请求不一样，websocket连接能够保持长时间打开，服务器代理也许能够很好的处理这一情况，也可能完全懵逼。

### WebSocket Upgrade
html5 websocket 使用http的upgrade机制来升级到uwebsocket协议，html5 websocket针对http进行兼容性设计，所以能够和http共同使用80或者443端口，为了使用websocket协议，客户端和服务器在开始的握手阶段进行协议升级协商操作，如下图所示，一旦建立，websocket数据帧就能够在客户端和服务端同时的发送。

Client to Server
```html
GET /demo HTTP/1.1
Upgrade: WebSocket
Connect: Upgrade
Host: example.com
Origin: http://example.com
WebSocket-Protocol: sample
```

Server to Client
```html
HTTP/1.1 101 Web Socket Protocol Handshake
Upgrade: WebSocket
Connect: Upgrade
WebSocket-Origin: http://example.com
WebSocket-Location: ws://example.com
WebSocket-Protocol: sample
```
*为经加密的websocket连接*

websocket本身是意识不到服务度代理或者防火墙的存在的，它只是定义来websocket升级握手和传输的数据帧格式，让我们来看看在两种服务器代理的为经加密的websocket情况。

### 未经加密的websocket连接和显式的服务器代理
如果浏览器配置成使用显式的使用代理模式的话，它首先会在建立websocket连接的时候发送HTTP CONNECT方法到代理服务器，比如，为了使用ws://   scheme连接到example.com，浏览器发送发送HTTP CONNECT方法到示例2中的代理服务器
```html
CONNECT example.com:80 HTTP/1.1
Host: example.com
```
当代理服务器允许CONNECT方法的时候，当握手成功的时候，websocket连接就会建立，websocket的流量就能够通过服务器代理发送出去。
（译者注：我想这应该是客户端使用的代理服务器的情况，显然，服务器并不知道这个代理的存在，就是说，如果客户端使用代理的情况下，如果想要与服务端建立websocket，首先要发送CONNECT到代理服务器去）

### 未经加密的websocket连接与完全透明的服务器代理
在客户端发送数据经过一个它感知不到的服务器代理的情况下，连接可能会断开，因为客户端没有首先发送一个CONNECT。当一个服务器代理转发请求到服务器的时候，它会删除部分头部信息，包括表示协议升级的Connection头部，这会导致握手失败。

当然也不是所有的服务器代理都不会转发关于握手的http头部信息，在握手阶段可以完成，但是问题会出在第一个websocket数据帧发送的时候，因为websocket的数据不跟平常的http数据一样，服务地代理此时可能会抛出一个异常信息。除非服务器代理明确的被配置用来作为websocket的服务器代理。

## Hop-By-Hop Upgrade



