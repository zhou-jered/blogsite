---
title: Spring Cloud Stream Note (1)
date: 2018-05-19 10:49:16
tags:
	- Spring
	- Spring Cloud
	- Note
---


- Application Model
- Binder abstraction
- persistent publish-subscribe support
- Consumer Group support
- Partitioning support
- Pluggable Binder API

## Application Model
一个SpringCloudStream app没有和特定的消息中间件绑定起来，app和MQ是通过autowire的Input和Output Channel抽象来交互的，Channel与外部的broker交互是通过和MQ相关的Biner Api来完成的。
![Model of Application](/images/springcloudstream/SCSt-with-binder.png)

## Binder Abstraction
SpringCloudStream 提供了 Kafka 和 RabbitMQ 的Binder实现，`TestSupportBinder`可以用来测试，也可以实现自己的Binder。

SpringCloudStream会在classpath中自己探测和选择Binder，所以你可以通过同样的代码来访问不同的MQ，只需要提供不同的Binder就可以了，甚至可以用多个Binder，然后在runtimer来切换Binder来实现同时访问不同的MQ。

## Persistent Publish-subscribe Support
Push Model
pass

## Consumer Groups
和Kafka的consumer group一样。springcloudstream在自己的抽象层上实现来consumer group逻辑，在一个group内，一条消息只能发送给其中一个consumer。
可以通过配置`spring.cloud.steram.bindings.<channelName>.group来配置consumer group。

## Durability
是说一旦订阅topic，Binder会存储订阅关系，一旦订阅关系建立，Binder就会接收消息，即使所有的app都stopped。

记住给你的application 标记consumer Group，这样可以避免重复收到消息。

## Partition Support
SpringCloudStream 支持应用之间多个实例的data partition。并提供了对于不同MQ的统一风格的partition抽象。就是Kafka中的partition的概念。


# 编程模型
`@EnableBinding` 开启springcloudstream 功能。
`@Input`  和 `@Output` 声明channel
```java
public interface Barista {
	@Input
	SubscribableChannel orders();

	@Output
	MessageChannel hotDrinks();
	
	@Output
	MessageChannel coldDrinks();
}
```

然后
```
@EnableBinding(Barista.class)
public class Application {
	...
}
```
然后在程序中通过autowrie来使用这些组件。


## Producing and Consuming Message
可以这样写一个转换器，消费消息之后，立马写入另外一个MQ
```java
@EnableBinding(Processor.class)
public class TransformProcessor {
	@Transformer(inputChannel = Process.INPUT, outputChannel = Processor.OUTPUT)
	public object transform(String message) {
		return message.toUpperCase();
	}
}
```

> 注意当你使用来@StreamListener 的时候，你使用的是订阅发布的消息模式，所有被@StreamListener 注解的方法拿到的是消息的不同copy，每个都是一个单独的consumer group。然而，如果在@Aggregator， @Transformer， @ServiceActivator 中使用共享的bindable channel，这些方法之久就是一个竞争的关系，相当于在同一个consumer group中。

### 关于ErrorChannel的支持
pass

### 使用@StreamListener 的自动类型处理功能
提供了一个简单的模型来处理inbound 消息，特别是设计到类型处理的时候，能提供更多便利的功能。

SpringCloudStream提供了消息类型转换机制，然后将消息转换后的类型分派给被@StreamListener注解的方法，比如
```java
@EnableBinding(Sink.class)
public class VoteHandler {
	@autowired
	VotingService votingService;

	@StreamListener(Sink.INPUT)
	public void handle(Vote vote) {
		vitingService.record(vote);
	}
}
```

### 使用@StreamListener 来分派消息到多个方法
从1.2开始，SpringCloudStream支持分派消息到多个@StreamListener注解的方法，前提条件是方法注册了inputChannel。
为了使用基于条件的消息分派，方法必须满足一下条件
- 不能返回值
- 一次只能处理一条消息（Reactive API不支持）
`condition`可以通过在注解中的condition属性来执行，支持spEL语法，每条消息会判断一次。所有满足条件的方法都会在同一线程里面被调用。

下面这个例子演示怎么根据消息header不同的type值，分配到不同的方法中去处理
```java
@EnableBinding(Sink.class)
@EnableAutoConfiguration
public class TestPojoWithAnnoatatedArgements {
	
	@StreamListener(target = Sink.INPUT, condition = "headers['type' == 'foo']")
	public void receiveFoo(@Payload FooPojo fooPojo) {
		//handler msg 
	}

	@StreamListener(target = Sink.INPUT, condition = "headers ['type'] === 'bar'")
	public void receiveBar(@Payload BarPojo barPojo) {
		//handle msg
	}
}
```
