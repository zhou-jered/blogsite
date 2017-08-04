---
title: WebScoket in OpenResty
date: 2017-08-04 22:15:34
tags:
	- Note
	- Websocket
	- OpenResty
---

OpenResty 的websocket模块是自带的官方模块，[Github地址](https://github.com/openresty/lua-resty-websocket)
用法和一些详细的资料都可以从这个地址顺藤摸瓜的找到。

ws的建立过程首先需要http协议来进行协议转换，在第一个请求中，需要以下的头部信息
```HTML
Connection: Upgrade
Upgrade: websocket
sec-websocket-key: x3JJHMbDL1EzLkh9GBhXDw==
sec-websocket-version: 13
sec-websocket-protocol: chat
```

Connection 和Upgrade 字段用来告诉服务器协议需要升级，在[RFC6455](https://tools.ietf.org/html/rfc6455)中对sec-websocket-key的描述是
> The request MUST include a header field with the name
>        |Sec-WebSocket-Key|.  The value of this header field MUST be a
>        nonce consisting of a randomly selected 16-byte value that has
>        been base64-encoded (see Section 4 of [RFC4648]).  The nonce
>        MUST be selected randomly for each connection.
sec-websocket-key 是一段base64编码的随机16字节的字符串
通过查阅rfc文档
sec-websocket-version 只能是13
sec-websocket-protocol 不是必须的，用于websocket只是定义了一种数据传输方式，并没有定义具体数据传输格式或者协议，所以这个字段可以用来告诉服务器使用的数据传输子协议（subprotocol）。

当服务器返回以下信息的时候，websocket连接就建立完成了，接下来就可以在条连接上使用websocket发送数据了
```html
HTTP/1.1 101 Switching Protocols
 Connection: upgrade
 Upgrade: websocket
 Sec-WebSocket-Accept: KBWfLwqhdE5yXMWa4+MFBXBIxxg=
```
sec-websocket-accept 的值是由客户端提交的sec-websocket-key值加上一个GUID（258EAFA5-E914-47DA-95CA-C5AB0DC85B11），然后经过sha1后在经过base64编码而来。这个字段可以让客户端确认服务器是有理解websocket协议的。

和spring提供websocket功能比起来，openresty 提供的功能就比较少了，也没有提供一个传输数据的子协议。
openresty既能写ws的服务端逻辑也能写ws的客户端，后面会使用到的应该是使用openresty 来编写应用的测试用例，开发也比较方便。

to be continue...
