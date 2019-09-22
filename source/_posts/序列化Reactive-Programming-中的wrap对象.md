---
title: 序列化 Reactive Programming 中的 Mono 对象
date: 2019-03-26 11:40:43
tags:
	- Cache
	- Reactive Programming
---

## 前言
前几天改造程序，Spring boot的项目，升级到Spring boot 2，全链路 reactive 改造。项目使用了Spring data redis 做cache，会缓存几个service layer的方法返回值。由于 reactive 改造需要方法的返回对象类型，将方法的返回值类型用 Mono wrap 一下，所以方法的返回对象就变成了Mono。
问题来了，Mono 没有实现 java.io.Serializable 接口，导致缓存序列化失败。改造遇阻。

## 解决方案

Spring 里面的 CacheManager 支持自定义的 Serializer ？先来试一下能不能把 Mono 序列化成Json。
```java
static void main(String[] args) {
        Mono<String> mono = Mono.just("Hello Mono");
        String seriaStr = JSON.toJSONString(mono);
        System.out.println("Serialized String: " + seriaStr);
        Mono<String> deserObj = JSON.toJavaObject(JSON.parseObject(seriaStr), Mono.class);
        System.out.println("Deserialized String: " + deserObj);
    }
    ```

得到输出：
```
Serialized String: {"scanAvailable":true}
Deserialized String: null
```

Oops，看来不好使。不过虽然自己简单定义 Serializer 的方法不行，不过这个思路还是对的，起因是 CacheManager 只支持实现 Serializable 的类，CacheManager 还支持用户自己定义一些缓存行为。

首先 RedisCacheManager 里面有两个主要的成员变量：
```java
private final RedisCacheWriter cacheWriter;
private final RedisCacheConfiguration defaultCacheConfig;
```

其中 cacheWrite 负责对redis的读写操作，支持无锁读写，由于我之前遇到过 redis 缓存锁不释放从而造成线上服务集体hang住的问题我觉得这个特性还是很不错的。

```java
public interface RedisCacheWriter {

	static RedisCacheWriter nonLockingRedisCacheWriter(RedisConnectionFactory connectionFactory) {
		return new DefaultRedisCacheWriter(connectionFactory);
	}

	static RedisCacheWriter lockingRedisCacheWriter(RedisConnectionFactory connectionFactory) {
		return new DefaultRedisCacheWriter(connectionFactory, Duration.ofMillis(50));
	}

```

好了，序列化相关的不在 writer 这里，在 RedisCacheConfiguration 里面。

看看相关的成员变量

```java
public class RedisCacheConfiguration {

	private final SerializationPair<String> keySerializationPair;
	private final SerializationPair<Object> valueSerializationPair;

	private final ConversionService conversionService;

```

除此之外呢，看看 CacheManager 和 RedisCache 这两个类：

```java
public interface CacheManager {


	@Nullable
	Cache getCache(String name);

	Collection<String> getCacheNames();

}
```

RedisCahe
![](/img/misc/RedisCache.png)

然后 RedisCache 保存了 RedisCacheConfiguration 的实例，RedisCache 作为实际的缓存数据操作类，对缓存的操作调用链如下：

SerializationPair.write() -------> RedisElementWriter.write() --->  RedisSerializer.serialize()

可以看到最后的序列化操作是由 RedisSerializer 来完成的，RedisSerializer 是一个接口，框架提供了几种实现（字符串，json，xml，jdk）。默认使用的是 jdk 序列化实现 JdkSerializationRedisSerializer。好了，我们就改造这个吧。

假设让 jdk 来序列化一个 字符串 Java 对象的话，得到的大概长这个样子

> \xac\xed\x00\x05t\x00\x0cHello world

下面开始改造，改造的思路呢就是将 Mono unwrap 之后得到的对象交给原来的 Serializer 去做序列化，但是要注意2点
- 可能 unwrapper 之后的对象仍然是 Mono 对象
- 序列化之后会丢失 wrap 信息，deserialize 之后会出错。

针对第二点，需要一个辅助类：

```java
public static class MyMonoIdentifier implements Serializable {
        final Object val;

        public MyMonoIdentifier(Object val) {
            this.val = val;
        }
    }

```

用这个类来标志里面的对象是 Mono wrapped 对象。到这里就可以上真正的改造代码了

```java
public class MonoSerializer implements Serializer<Object> {

    Serializer<Object> delegatedSerializer = new DefaultSerializer();

    @Override
    public void serialize(Object object, OutputStream outputStream) throws IOException {
        Object serObj = null;
        try {
            serObj = unwrapMono(object);
        } catch (ExecutionException e) {
            throw new IOException(e);
        } catch (InterruptedException e) {
            throw new IOException(e);
        }
        delegatedSerializer.serialize(serObj, outputStream);
    }

    private Object unwrapMono(Object obj) throws ExecutionException, InterruptedException {
        if(obj instanceof  Mono) {
            Mono monoObj = (Mono)obj;
            Object resultObj = monoObj.toFuture().get();
            Object identifiedObj = new MyMonoIdentifier(resultObj);
            return identifiedObj;
        } else {
            return obj;
        }
    }

}


public class MonoDeserializer implements Deserializer<Object> {

    Deserializer<Object> delegatedDeserializer = new DefaultDeserializer();

    @Override
    public Object deserialize(InputStream inputStream) throws IOException {
        Object obj = delegatedDeserializer.deserialize(inputStream);
        return wrapperMono(obj);
    }

    private Object wrapperMono (Object obj) {
        if(obj instanceof MonoSerializer.MyMonoIdentifier) {
            MonoSerializer.MyMonoIdentifier myMoNoIdentfierWrapper = (MonoSerializer.MyMonoIdentifier)obj;
            Object mono = wrapperMono(myMoNoIdentfierWrapper.getVal());
            return Mono.just(mono);
        } else {
            return obj;
        }
    }
}

```

然后将自定义的 Serializer 和 Deserializer 添加进去就OK了。

```java

 @Bean
public CacheManager cacheManager(RedisConnectionFactory redisConnectionFactory) {
    SerializingConverter serializingConverter = new SerializingConverter(new MonoSerializer());
	DeserializingConverter deserializingConverter = new DeserializingConverter(new MonoDeserializer());
	RedisSerializer<Object> redisSerializer = new JdkSerializationRedisSerializer(serializingConverter, deserializingConverter);
	RedisCacheConfiguration redisCacheConfiguration = RedisCacheConfiguration.defaultCacheConfig()
	    .serializeValuesWith(RedisSerializationContext.SerializationPair.fromSerializer(redisSerializer));
	CacheManager cacheManager = RedisCacheManager.builder(redisConnectionFactory)
	    .cacheDefaults(redisCacheConfiguration)
	    .build();
	return cacheManager;
}
```

到此为止，Mono 已经可以成功序列化了，序列化之后的样子大概这样
> \xac\xed\x00\x05sr\x00)me.xxx.yyy.zzzMyMonoIdentifier\x84x\x8c\xd1
\xff\x9c\bK\x02\x00\x01L\x00\x03valt\x00\x12
Ljava/lang/Object;xpt\x00\x10Hello World

可以看到，类名 MyMonoIdentifier 也被序列化进去了，所以为了节省空间，类型可以取短一点 xd。

## 总结


可以看到有一行代码： ` Object resultObj = monoObj.toFuture().get(); `  这行代码，同步阻塞等待异步操作的结果，使得整个服务不是完全异步的，这个在性能上会部分损耗，不过就实际情况而言，还是可以接受的 trade off。完美的解决方案应该是对于缓存的操作也是异步的。这个可以后续来搞搞。
另外在 Reactive 中，还有一个对象 `Flux` 也可以作为方法的返回值。这个代码如果在生产环境使用的话，还需要兼容Flux对象。
