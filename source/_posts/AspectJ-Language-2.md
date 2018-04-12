---
title: AspectJ-Language-2-连接点和切点
date: 2018-04-12 13:08:58
tags:
	- AspectJ
	- AOP
	- Notes
---

# Join Points and Pointcuts
连接点和切点

考虑下面的Java类
```Java
class Point {
	private int x, y;
	Point(int x, int y) { this.x = x; this.y = y; }

	void setX(int x) { this.x = x; }
	void setY(int y) { this.y = y; }

	int getX() { return x; }
	int getY() { return y; }
}
```

为了更直观的理解AspectJ 里面的连接点和切点，首先看一下这个方法

> void setX(int x) { this.x = x; }

上面这个代码的意思是，当带着一个int参数调用setX方法的时候，*this.x=x* 这句代码就会被执行。

上面的描述隐含的模式是：

> 当某件事发生的时候，某段过程就会执行

在面向对象编程中，语言能够决定很多类型的正在发生的事情，AspectJ就把这些事情叫做连接点（Join Point，这点解释超棒有没有？）。连接点包括方法调用，方法执行，对象实例化，构造器执行，成员变量引用等等。

切点选择连接点，比如切点
```Aspect
pointcut setter(): target(Point) && 
	(call(void setX(int) ||
	 call(void setY(int)));
```
会选择所有的在Point实例对象上对setX和setY方法的调用。
另一个例子：
```Aspect
pointcut ioHandler(): within(MyClass) && handler(IOException);
```
这个切点会选择类型IOException的异常在MyClass定义的代码内被handler的时候执行。（嗯？在不在一个方法里面？）

切点的定义包括左边部分和右边部分，以冒号*：*分割，左边部分是切点的名字和参数，右边部分就是切点本身。此处注意切点的定义。通过定义切点来选择连接点。
