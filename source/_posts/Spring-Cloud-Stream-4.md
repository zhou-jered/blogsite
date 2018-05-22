---
title: Spring Cloud Stream (4)
date: 2018-05-22 10:40:11
tags:
	- Spring
	- Spring Cloud Stream
	- Note
---

默认情况下（关于headerMode配置），Spring Cloud Stream会在header中带上`contentType`信息，对于不支持header的消息中间件，SpringCloudStream使用其他的机制带上header，比如将头部信息包装在消息的其他部分传输出去。

Spring Cloud Stream依赖下面的信息来处理消息
- 消息的`contentType`设置
- 被@StreamListener注解的方法的参数类型

此外，还可以在配置中声明消息的contentType，配置项spring.cloud.stream.bindings.<channelName>.content-type。
而且SpringCloudStream默认支持一些简单的转换操作，包括
- Json/Pojo  
- Json/org.springframework.tuple.Tuple
- Object/byte[]
- String/byte[]
- Object 到plain text，调用object的`toString()`

如果没有设置消息的contentType的话，消息就会被`Kryo`序列化框架序列化之后再发送出去。

## MIME types
content-type会被解析成media type，比如`application/json`, `text/plain; charset=UTF-8`。使用通用type `application/x-java-object` 在可以将数据转换为Java对象。添加type参数可以进一步转换为特定的对象`application/x-java-object;type=java.util.Map`。注意，转换为Spring的Tuple对象的type为`application/x-spring-tuple`。

## 实现自己的MessageConverter
套路和HttpMessageConverter 一样，这里的话，注册一个类型为`org.springframework.messaging.converter.MessageConverter`的自己实现的Bean就可以了，一般通过继承`org.springframework.messaging.converter.AbstractMessageConverter` 来实现这个bean。


