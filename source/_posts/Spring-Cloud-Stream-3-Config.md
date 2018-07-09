---
title: Spring Cloud Stream 3 - Config
date: 2018-05-21 14:06:47
tags:
	- Note
	- Spring
	- Spring Cloud Stream
---
List Sping Cloud Stream的配置。
可以通过一些Spring支持的配置手段来配置绑定和binder行为。

## Spring Cloud Stream Properties
- spring.cloud.stream.instanceCount
	部署的app的实例数量，使用Kafka partition的时候必须设置
	默认为1
- spring.cloud.stream.instaceIndex
	实例索引，范围是0到instanceCount-1，使用Kafka partition的设置。

- spring.cloud.stream.dynamicDestinations
	能够动态设置的destination 列表。
	默认为空

- spring.cloud.stream.defaultBinder
	默认Binder

- spring.cloud.stream.overrideCloudConnectors
	当`cloud`profile激活的时候，而且Spring Cloud Connector可用的时候，决定是使用SpringCloudConnector提供的连接还是使用SpringCloudStream的连接。
	默认false


## Binding Properties
Binding properties通过 spring.cloud.stream.bindings.<channelName>.<property>=<value> 格式来支持。<channelName>是配置channel时的名称。
	可以用 spring.cloud.stream.default.<property>=<value> 来指定所有的channel的默认配置。
	还有一个可以配置默认行为的配置项：spring.cloud.stream.default.....  比如 `spring.cloud.stream.default.contentType=application/json`

- destination
	与中间件交互的目标（比如RabbitMq的exchange 或者 Kafka的topic）。如果channel是consumer，可以指定多个destination，用逗号隔开，如果没有指定，channelname就是destination。
- group
	consumer group，只在consumer应用
	默认null

- contentType
	contenttype
	默认null

- binder
	channel使用的binder，指定binder的名字。

## Consumer properties
这一小节介绍的配置项通过配置前缀 spring.cloud.stream.bindings.<channelName>.consumer 指定
默认配置前缀是 spring.cloud.stream.default.consumer.....

- concurrency
	consumer 的并发度
	默认1

- partitioned
	consumer是否接收从partitioned producer过来的数据
	默认false

- headerMode
	设置为`raw`的时候，禁用header解析，仅在消息中间件不支持消息头而且要求内置消息头的时候。
	默认 `embeddedHeaders`

- maxAttempts
	如果处理失败，重试处理的次数，设置为1禁用重试。
	默认3

- backOffInitialInterval
	重试的初始间隔时间，单位应该是毫秒
	默认1000

- backOffMaxinterval
	最大回退时间间隔
	默认10000

- backOffMultiplier
	backoff multiplier
	默认2.0（这是个啥？？？？）	

- instanceIndex
	前面有提到说使用Kafka Partition的时候要设置instanceIndex。这个属性可以针对consumer设置instanceIndex，从而影响消息的消费行为。
	如果设置为大于0的数，就会覆盖通过spring.cloud.stream.instanceIndex设置的值。
	默认01

- instanceCount
	同上面，也是覆盖通过spring.cloud.stream.instanceCount设置的值。
	默认-1 ， 这个配置项不生效。

## Producer Properties
通过配置前缀`spring.cloud.stream.bindings.<channelName>.producer` 来指定producer的配置。
	默认的配置项前缀 `spring.cloud.stream.default.producer`

- partitionKeyExpression
	一个SpEl 表达式来决定消息怎么partition，如果设置来，数据就会partition，而且此时partitionCount必须被设置。
	除此之外，partitionKeyExpression 和 partitionKeyExtractorClass 不能同时设置。
	默认null	

- partitionKeyExtractorClass
	是一个`PartitionKeyExtractorStrategy`的实现，用来决定数据的partition，参考上面一个设置的描述。
	默认null

- partitionSelectorClass
	一个`partitionSelectorStrategy`的实现，不能和`partitionSelectorExpression`同时设置。
	如果两个都没有设置，partition的选择会按照`hashCode(key)%partitionCount`来决定，可以通过上面的两项之一来决定。
	默认null

- partitionSelectorExpression
	一个SpEL表达式用来自定义partition选择，和`partitionSelectorClass`互斥。
	默认null

- partitionCount
	partitionCount, 在Kafka情形下，会被表达为一个hint，Kafka实际的partitionCount和配置的partitionCount会选择大的那个作为实际的count。
	默认1

- requiredGroups
	逗号隔开的group 列表，定义消息必须被发送到的group，即使在group创建之后启动的。（不是很懂，后面再看）

- headerMode
	header mode，设置为`raw`禁用消息头解析
	默认`embededHeaders`

- usenativeEncoding
	设置为true时，outbound的消息就会直接使用本地的lib编码，当这个配置使用的时候，解析消息就不会基于contentType的配置，consumer负责使用正确的decoder来解析消息。	
	默认 false

- errorChannelEnabled
	当被设置为true时，如果binder支持异步发送结果，发送失败记录就会发送给errorchannel。
	默认 false

## 使用动态的bound destination

当你的destination需要在runtime决定的时候，可以使用SpringCloudStream 的Bean `BinderAwareChannelResolver`。 
配置项`spring.cloud.stream.dynamicDestinations` 使用白名单机制来决定动态destination允许的枚举值。因为BinderAwareChannelResolver是一个Bean，所以使用的时候直接autowire就可以了。
```java
	@Autowired
	private BinderAwareChannelResolver resolver;

	private void sendMessage(String body, String target, Object contentType) {
		resolver.resolveDestination(target).send(MessageBuilder.createMessage(body,
				new MessageHeaders(Collections.singletonMap(MessageHeaders.CONTENT_TYPE, contentType))));
	}
```
