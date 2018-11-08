---
title: Java ClassLoader 的并发加载
date: 2018-10-13 12:32:38
tags:
	- Java
	- Jvm
---

今天看jdk文档，有这么一段话
> 如果ClassLoader 不会严格的按照委托模式去加载类的话，这个类就需要支持并发加载，并且需要调用静态方法
```java
ClassLoader.registerAsParallelCapable
```

否则的话，加载类的时候有概率会有死锁问题发生。这是由于在加载类的执行过程中，具体就是`loadClass`方法的执行中会持有classLoadingLock。
也就是说，如果自己搞个ClassLoader，并且破坏了双亲委派模型的话，如果还是单线程加载类，加载类的时候就有死锁的风险。

