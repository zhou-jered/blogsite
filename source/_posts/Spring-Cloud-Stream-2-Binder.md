---
title: Spring Cloud Stream (2) - Binder
date: 2018-05-21 11:01:29
tags:
	- Note
	- Spring
	- Spring Cloud Stream
---

Binder 是Spring Cloud Stream 提供的对外部MQ 中间件交互的抽象层，Binder  的思想类似JDBC，提供了对应用来说统一的接口，和对于外部不同中间件不同实现的一套机制。这种机制叫做SPI（Service Provider Interface）。

## 消费者和生产者
任何往channel里面塞消息的组件都是producer，channel又可以通过不同Binder的实现往不同MQ的Broker 塞消息，当调用`bindProducer()`方法的时候，第一个参数目标broker的名字，第二个参数是本地channel实例，第三个是一些properties。

任何从channel中接收消息的组件都是consumer，同样的可以通过Binder和外部MQ产生交互，调用`bindConsumer`的时候，第一个参数是目标broker名字，第二个参数是逻辑consumer group的名字，也就是，这个group的抽象应该是springcloudstream层面上的，而不是MQ提供的group。app中的conusmer和producer在设计上就是不会和具体的MQ交互的，交互的对象都是SpringCloudStream提供的抽象对象。

## Binder SPI
Binder SPI 包含一些接口，一直可以直接用的工具类utils 和 一些为了连接外部中间件可插拔机制的发现策略。有点拗口的可插拔机制的发现策略指的应该是通过发现策略来决定使用哪个外部中间件的实现，这些实现是可插拔的，灵活使用。

Binder SPI的最主要的接口是连接外部输入输出的策略选择
```java
public interface Binder<T, C extends ConsumerProperties, P extends ProducerProperties> {
	Binding<T> bindConsumer(String name, String group, T inboundBindTarget, C consumerProperties);

	Binding<T> bindProducer(String name, T outboundBindTarget, P produceProperties);
}
```

一个典型的Binder实现是这样的：
- 实现`Binder`接口
- 创建一个实现`Binder`接口的类型的spring baen
- 在文件META-INF/spring.binders 包含一个或者多个的binder定义，比如
> kafka: org.springframework.cloud.stream.binder.kafka.config.KafkaBinderconfiguration

## Binder 检测
前面说了嘛，spring-cloud-stream在classpath里面自动检测binder的实现，找到哪个用哪个（嗯？对不对？是不是还有啥策略什么的，还是多个同时一起用，然后根据不同的INPUT，OUTPUT配置来使用不同的Binder？答案在下文）

### classpath 检测
默认情况下，SpringCloudSteam会使用SpringBoot的自动配置，如果classpath只有一个Binder实现，就只使用这个Binder。
```xml
<dependency>
  <groupId>org.springframework.cloud</groupId>
  <artifactId>spring-cloud-stream-binder-rabbit</artifactId>
</dependency>
```

### classpath有多个Binder实现的情况
当多个Binder实现存在的时候，由于Binder实现的META-INF/spring.binders文件中包含这样的配置
> rabbit: org.springframework.cloud.stream.binder.rabbit.config.RabbitServiceAutoConfiguration

可以看到，一个冒号分开Binder的名字和配置类，配置类实现了上文中要求的Binder接口。可以通过`spring.cloud.stream.defaultBinder`来配置默认的Binder，比如 `spring.cloud.stream.defaultBinder=rabbit`。还可以配置从kafka读，写入rabbit的property
```property
spring.cloud.stream.bindings.input.binder=kafka
spring.cloud.stream.bindings.output.binder=rabbit
```

### 连接多个系统
默认情况下，binders使用springboot的自动配置，所以classpath中发现的Binder只会创建一个instance。如果你想要使用同一个binder连接多个中间件的系统，可以通过指定多个binder配置来实现。每个binder使用不同的env设定。

> Note
> 如果你使用来显式的配置就会让默认配置失效，这时候就需要给所有的binder指定配置，使用SpringCloudStream的框架透明的创建了能够通过名字来引用的Binder，但是不会影响默认binder配置。为了达到这样的效果，将binder的配置项`defaultCandidate`设置为false，比如 `spring.cloud.stream.binders.<configurationName>.defaultCandidate=false`。这项配置指明了配置和默认配置是独立的配置流程。

下面的例子是配置一个可以连接两个RabbitMQ的binder
```yml
spring:
    cloud:
        stream:
	    bindings:
		input:
		    destination: foo
		    binder: rabbit1
		output:
		    destination: bar
		    binder: rabbit2
	    binders:
		rabbit1:
		    type: rabbit
		    environment:
			spring:
			    rabbitmq:
				host: <host1>
		rabbit2:
		    type: rabbit
		    environment:
			spring:rabbitmq:
				host: <host2>
```

## Binder 的配置项
下面的配置项都有前缀`spring.cloud.stream.binders.<configurationName>`

### type
	binder type，指定在classpath中检测到的binder，就是Binder实现的文件/META-INF/spring.binders中的 binder名字。
	默认的是和configuation name一样

### inheritEnvironment
	是否继承环境设置
	默认true

### environment
	binder配置的环境设置，当被配置的时候，binder的context就不是application context的child。这个特性允许binder组件和应用组件完全隔离开。
	默认为空

### defaultCandidate
	binder的配置是否被默认配置影响，这个配置可以允许配置集不影响默认配置流程
	默认为true


