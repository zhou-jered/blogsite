---
title: AspectJ Language-1-概览
date: 2018-04-11 20:55:16
tags:
	- AOP
	- AspectJ
	- Note
---

#Example
An example aspect definition in AspectJ:
```Aspect
aspect FaultHandler {
	private boolean Server.disabled = false;
	
	private void reportFault() {
		System.out.println("Failure! Please fix it");
	}

	public static void fixServer(Server s ) {
		s.disabled = false;
	}

	pointcut services(Server s): target(s) && call(public * *(..));

	before(Server s): services(s) {
		if (s.disabled) throw new DisabledException();
	}

	after(Server S) throwing (FaultException e): services(s) {
		s.disabled = true;
	}
}
```

上面这个FaultHandler 包含一个Server的inter-type 域，两个方法reportFault和 fixServer，一个切点定义，和两个advice。
通常来说，上面这个例子包含了在aspect定义中能包含的东西，程序定义的实体类，方法和域，切点和advice。

#Pointcuts
切点。
AspectJ中切点可以有名字。通过切点去定义需要连接点（join point，需要切片的地方）。定义的连接点可以是方法、构造器的调用，异常的catch或者是field的读操作或者写操作。
> pointcut services(Server s): target(s) && call(public **(..))

上面定义了一个切点，名字叫做service，选取的连接点是Server实例对象的public方法。由于提供了方法的调用对象，这个对象其实是作为advice的context存在的，可以在advice中访问这个被调用的对象。

这个切点的主要思想就是处理在公有方法上触发的错误。

通过定义参数的形式来暴露切面的上下文信息，这个例子里面定义的是Server，target(s) 表示发生在Server实例对象上的调用，&& 表示逻辑上的与关系，call后面是方法签名，* 表示通配符，两个*表示通配返回值和方法名，方法参数也通配，唯一的限定就是public，合起来就是发生在Server实例对象上的public方法。

通过切点定义可以选择任意多的方法，但是只能选择几种类型的连接点，下面是可选择类型的不完全列表：
- 方法调用
- 方法执行
- 异常handling
- 实例化
- 构造器执行
- 成员变量的访问

具体信息在文章的后面会提到。
