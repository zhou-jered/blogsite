---
title: AspectJ-Language-3-Advice
date: 2018-04-13 18:06:58
tags:
	- AspectJ
	- AOP
	- Note
---

# Advice
Advice定义在程序执行过程中的特点的时间点运行的片段。这些点能够通过匿名或者具名的切点来指定。
Eg：
```java
pointcut setter(Point p1, int newval): target(p1) ** args(newval) 
				(call(void setX(int)) ||
				 call(void setY(int)));
before(Point p1, int newval): setter(p1, newval) {
		System.out.println("p1: " + p1 + ", newval : "+newval)
}
```

下面这个和上面的一模一样，只不过是匿名的：
```Java
before(Point p1, int newval) : target(p1) && args(newval) 
		(call(void setX(int)) ||
		 call(void setY(int)));
```

下面是一些advice类型的例子：
*before* advice在连接点运行之前运行
```Java
before(Point p, int x): target(p) && args(x) call(void setX(int)) {
	if (!p.assertX(x)) return ;
}
```

*after* advice 在连接点运行之后运行，不管连接点是正常结束还是抛出异常结束。
```Java
after(Point p, int x): target(p) && args(x) && call(void setX(int)) {
	if (p.assertX(x)) throw new PostConditionViolation();
}
```


*after returning* advice 只能有匿名的形式，而且在方法正常返回之后，能够访问返回值。
```Java 
after(Point p) returning(int x): target(p) && call(int getX()) {
	System.out.println("Returning int value: " + x );
}
```

*after throwing* advice 也只能有匿名的形式，在方法抛出异常之后执行，抛出的异常也能够在advice里面访问。
```Java
after() throwing(Exception e): target(Point) && call(void setX(int)) {
	System.out.println(e);
}
```

*around* advice 比较屌，能够捕获切点的执行，在advice里面调用特定的方法 *proceed*来调用原来的方法。
```Aspect
void around(Point p, int x) : target(p) && args(x) &&
			call(void setX(int)) {
	if (p.assertX(x) proceed(p,x);
	p.releaseResources();
}
```

