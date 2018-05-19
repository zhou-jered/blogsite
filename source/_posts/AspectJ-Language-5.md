---
title: AspectJ Language 5 thisJoinPoint
date: 2018-04-15 17:55:49
tags:
	- AspectJ
	- AOP
	- Note
---

# thisJoinPoint
AspectJ 提供了一个特殊的变量*thisJoinPoint*，给advice提供了关于当前连接点的一些反射信息。这个变量只能在advice的上下文中使用，就像this只能在非静态方法中使用一样。在advice中，*thisJoinPoint*是一个*org.aaspectj.lang.JoinPoint*类型的对象。

一个比较简单的方法是直接的打印出来，*thisJoinPoint* 有一个 *toString()*方法。
```java
aspect TraceNonStaticMethods {
	before(Point p): target(p) && call(* *(..)) {
		System.out.println("entering " + thisJoinPoint + " in " + p)
	}
}
```

*thisJoinPoint*包含许多关于反射，继承和签名信息，能访问静态的信息，也能访问动态的信息，比如获取当前连接点的参数：
```java
thisJoinPoint.getArgs()
```

另外，它还有一个包含当前连接点所有的静态信息的对象，比如对应的行号和静态签名：
```java
thisJoinPoint.getStaticPart()
```
如果你需要当前连接点的静态信息，你就可以访问通过一个特殊的变量*thisJoinPointStaticPart*来直接访问。使用这个变量可以避免在runtime创建thisJoinPoint的开销。下面的代码解释来这两个变量的关系：
```java
thisJoinPointStaticPart == thisJoinPoint.getStaticPart()
thisJoinPoint.getKind() == thisJoinPointStaticPart.getKind()
thisJoinPoint.getSignature() == thisJoinPointStaticPart.getSignature()
thisJoinPoint.getSourceLocation() == thisJoinPointStaticPart.getSourceLocation()
```

一个在反射上更加灵活的变量是*thisEnclosingJoinPointStaticPart*。和thisJoinPoint类似，只包含连接点的静态信息，但是包含的不是当前的连接点信息，而是内含的连接点信息。比如，如果可能的话，下面的代码可以打印正在调用的source location
```java
before() : executon (* *(..)) {
	System.err.println(thisEnclosingJoinPointStaticPart.getSourceLocation())
}
```


