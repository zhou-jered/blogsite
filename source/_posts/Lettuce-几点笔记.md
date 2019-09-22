---
title: Lettuce 几点笔记
date: 2019-03-21 11:45:31
tags:
	- Note
	- Redis
	- Lettuce
---

Lettuce 是Java 异步时代的redis client。

## 构建client url
```
RedisURI.create("redis://localhost/");
RedisURI.Builder.redis("localhost", 6379).auth("password").database(1).build();
new RedisURI("localhost", 6379, 60, TimeUnit.SECONDS);
```

Uri Syntax
```
Redis Standalone

redis :// [: password@] host [: port] [/ database][? [timeout=timeout[d|h|m|s|ms|us|ns]] [&_database=database_]]

Redis Standalone (SSL)

rediss :// [: password@] host [: port] [/ database][? [timeout=timeout[d|h|m|s|ms|us|ns]] [&_database=database_]]

Redis Standalone (Unix Domain Sockets)

redis-socket :// path [?[timeout=timeout[d|h|m|s|ms|us|ns]][&_database=database_]]

Redis Sentinel

redis-sentinel :// [: password@] host1[: port1] [, host2[: port2]] [, hostN[: portN]] [/ database][?[timeout=timeout[d|h|m|s|ms|us|ns]] [&_sentinelMasterId=sentinelMasterId_] [&_database=database_]]
```

### 使用client 步骤
1. 使用redis uri 创建一个RedisClient
2. 从client 获取一个connection
3. 从connection 获取 RedisCommand Api 接口
4. 关闭connection
5. 关闭client

```
RedisClient client = RedisClient.create("redis://localhost");          

StatefulRedisConnection<String, String> connection = client.connect(); 

RedisCommands<String, String> commands = connection.sync();            

String value = commands.get("foo");                                    

...

connection.close();                                                    

client.shutdown();                  
```

## 异步API
Lettuce 使用Netty 来实现网络的异步操作API。

connection 可以用来做长连接使用，会自动reconnect，re-execute