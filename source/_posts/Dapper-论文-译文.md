---
title: Dapper 论文笔记
date: 2018-06-02 10:36:36
tags:
	- Dapper
	- Paper
	- Translation
---

Dapper 是google的分布式系统调用链追踪系统。具有低消耗，对应用透明，扩展性好等优点。Dapper可以帮助开发者分析并理解分布式系统中的各个服务的行为表现。
这个系统Google没有开源出来，但是开源社区有自己的实现zipkin。Spring Cloud 进一步继承和增强了相关功能，推出了Spring Cloud Sleuth 和 Spring Cloud Zipkin。

# 追踪系统的实现模型
在论文中，描述了两种追踪系统的模型，基于黑盒（black box）的追踪数据收集和基于注解（annotation-based，可以理解为程序侵入式）的数据收集。
尽管黑盒模式的数据收集具有更高的移植性，但是数据项的可扩展性明显不足。Google发现，只要通过instrment 部分基础库，比如gRpc，就可以收集到大部分的
trace数据。

# Dapper 追踪模型
Dapper 的trace 模型分为 `trees`, `spans`, `annotations`。
在Dapper 的追踪树（tree）中，树节点（node）是工作的基本单位，称之为`spans`。树节点的父节点也是一个span，父节点叫做自节点的`parent span`。
在实际应用中，一个span就是一个日志（log）记录，这个日志带有响应的work的开始和结束的时间戳（timestamp）。
![](/images/dapperspan.png)

# Dapper Instrument point(插桩点)
由于应用透明非侵入式设计，但是又要有足够的追踪数据来满足分析需求，所以需要对一部分基础库代码进行改造。
- 当一个线程进入追踪链路的时候，Dapper 将trace 上下文（content）附加到ThreadLocal中，trace context足够小，附加的代价也能比较小，通常是
traceID 和 spanID

- 当计算需要defered或者异步执行的时候， Dapper就将上线问注入到callback里面

- 改造gRpc。由于gRpc在Google内部使用是在太过于普遍了，改造gRpc就变得十分有用。

# Dapper Annotation
程序员自己往追踪信息流中写入自定义的追踪信息，便于日后的分析。但是不能写入超过配置上限的信息大小，这是为了保持追踪系统的轻量化和对系统性能的影响的可控性。

# Trace Collection
追踪数据首先写在自己的本地的log文件中，然后再被Dapper服务拉取，最后放入到BigTable 中一个Cell里面。一个Trace占一行，一个Span占一列，完美！

# Dapper runtime 库
Dapper 中最核心的代码就是对基本的Rpc 调用，线程和控制流代码的插桩代码，这些代码包括span的创建，取样和log到本地磁盘。除了保持轻量化以外，还必须保持足够的健壮，你不能因为别人include了你的代码就导致别人的的程序crash了，这样会被打的。你的代码在别人的程序里面运行，debug也不容易，要做好自测。


# 读后感
通篇读下来，感觉也没啥特别有用的信息，就是Dapper大体上的一个流程，最感兴趣的如何做到对应用低负载的部分也没有说，这篇文章最有用的部分就是介绍了两个概念，trace和span。paper很大部分都是在介绍自己的工作和成果，技术细节上涉及的不多，就这样吧，最后一句话总结一下这片论文就是
> 通过对基础通信库的改造来对app进行通信调用profile，通过TraceId 来做链路管理

作为全链路监控的一个基础组件，dapper只是提供了底层的数据和链路追踪能力，想要做好全链路监控的话，感觉只有这个的话还是不够，结合我司的情况来看，我司虽然有提供了traceId，但是也只是作为一个查询日志时的key来用的，还没有发挥traceId 的全部威力。在平时值班的时候，系统响应慢了，有用户反馈的话，才去开始定位问题，查日志，grep一波，效率还是有点慢，问题发现处在十分被动的状态。如果全链路平台搭建起来的话，问题能够被主动发现，及时高效定位。效率提升上来的话，就有其他精力去干别的事去了。

