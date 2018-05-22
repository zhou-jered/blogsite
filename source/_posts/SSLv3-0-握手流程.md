---
title: SSLv3.0 握手流程
date: 2018-05-18 13:40:22
tags:
	- Notes
	- SSL
	- Protocol
---
关于加密的参数和session状态是通过握手阶段来决定的，当server和client开始交互的时候，首先决定一个协议版本，选择加密算法（比较有意思的是可以选择加密算法为NULL），可选的互相认证，还有使用公钥加密来生成共享的密钥。握手阶段的工作总结如下：
- client发送Hello消息给server，server必须回复一个hello消息，hello消息包含一些attributes用来提供加密的功能。这些attributes包括：
	- 协议版本
	- Session ID
	- Cipher Suite
	- 压缩算法
	- server和client分别生成的随机字符串



