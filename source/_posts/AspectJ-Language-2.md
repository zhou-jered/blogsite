---
title: AspectJ-Language 2 连接点和切点
date: 2018-04-12 13:08:58
tags:
	- AspectJ
	- AOP
	- Note
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

#切点示例

方法执行切点
> execution(void Point.setX(int))

方法调用切点
> call(void Point.setX(int))

执行异常handler
> handler(ArrayOutOfBoundsException)

当前正在执行的对象是某个类型SomeType
> this(SomeType)

当目标对象是某个类型SomeType
> target(SomeType)

当正在执行的代码属于某个类
> within(SomeClass)

当一个连接点属于 *Test*的无参方法*main*的调用控制流中
> cflow(call(void Test.main()))

另外，切点还可以通过逻辑运算来连接，or(||), and(&&) 和 not(!)。
还可以使用通配符*，因此
 
- execution(* *(. .))
- call(* set(..))

（1）任何方法的执行，忽略返回类型，方法名字和参数。（2）代表叫做set的方法执行，忽略返回类型，参数。如果有多个匹配的情况，所有的方法都会被选择。

基于类型的选择。
- execution(int *())
- call(* setY(long))
- call(* Point.setY(int))
- call(*.new(int,int))

（1）选择任何返回int的方法执行，（2）选择带有一个long类型参数的setY方法，（3）选择在Point上对setY方法的调用，当然还有一个int参数，（4）选择有两个int类型参数的构造器调用。

你也可以通过逻辑运算将切点结合起来，比如
- target(Point) && call(int *())
- call(* *(..)) && (within(Linen) || within(Point))
- within(*) ** execution (*.new(int))
- !this.(Point) && call(int *(..))

(1) 选择Point实例上对返回类型为int的无参方法的调用，（2）选择发生在Point或者Line上的任何调用，（3）选择任何参数一个int的构造器调用，（4）选择任何不在Point上的返回int的方法调用。

你也可以通过修饰符来选择方法和构造器，比如
- call(public * *(..))
- execution(!static * * (..))
- execution(public !static * *(..))

（1）选择任何public方法，（2）选择所有的非静态方法，（3）选择所有的公有非静态方法。

切点也可以处理接口。比如，有接口
```Java
interface MyInterface { .... }
```
切点*call(* Myinterface.*(..))*会选择所有在MyInterface签名里面的调用，也就是说，任何MyInterface定义的或者是继承到的方法。

# call VS. execution
当方法或者是构造器运行的时候，有两个切点位置，一个是当被调用的时候，另一个是真正执行的时候。
AspectJ可以通过*call* 和 *execution*去选择切点。
这两个定义都有哪些不同点？
首先，通过*within* 和*withincode*去定义的切点选择的方法是不同的。在一个call连接点上，连接点内部代码就只有调用语句本身，也就是说*call(void m()) && withincode(void m())* 会选择在m方法内的直接递归调用。一个execution连接点内部代码是方法本身，而不是调用语句，所以*execution(void m()) && withincode(void m())* 和 *execution(void m())*是一样的。
其次，call连接点不会捕获对于非静态方法的super call（有点绕，需要做点实验验证一下，todo）。这是由于非静态的super call在Java里面和一般的方法不一样，不会走动态dispatch那一套机制。
一个简单的原则就是，如果你想切在方法真正执行的时候，就使用executiion， 如果想切在当有特定签名的方法被调用的时候，就使用call。

#切点的构造
通过逻辑运算将简单的切点连接起来可以构造出非常灵活的切点，注意*cflow* 和 *cflowbelow*会使人非常困惑。
*cflow(P)*会选择在切点P内的连接点
```
P ---------------------
    \
     \  cflow of P
      \
```
*cflow(P) && cflow(Q)*会选择什么？如下图
```
         P ---------------------
            \
             \  cflow of P
              \
               \
                \
  Q -------------\-------
    \             \
     \  cflow of Q \ cflow(P) && cflow(Q)
      \             \
```
注意P和Q也许不会有公共部分的连接点，但是它们的控制流能有公共部分。
但是*cflow(P && Q)*意思就是切点P和切点Q的公共部分的控制流。
给个例子：
```Java
public class Test {
    public static void main(String[] args) {
        foo();
    }
    static void foo() {
        goo();
    }
    static void goo() {
        System.out.println("hi");
    }
}

aspect A  {
    pointcut fooPC(): execution(void Test.foo());
    pointcut gooPC(): execution(void Test.goo());
    pointcut printPC(): call(void java.io.PrintStream.println(String));

    before(): cflow(fooPC()) && cflow(gooPC()) && printPC() && !within(A) {
        System.out.println("should occur");
    }

    before(): cflow(fooPC() && gooPC()) && printPC() && !within(A) {
        System.out.println("should not occur");
    }
}
```
上面的*!within(A)* 是用来避免*printPC*切点选中在advice body中的*System.out.println*，否则的话会导致无限循环的问题。

#切点参数
考虑在在这篇文章中的第一个切点。
```Java
pointcut setter(): target(Point) && (call(void setX(int)) ||
					call(void setY(int)));
```
正如所见到的，这个切点叫做setter，而且没有参数，意味着这个切点没有上下文信息，考虑下面这个切点：
```Java
pointcut setter(Point p): target(p) && 
				(call(void setX(int)) ||
				(call(void setY(int)));
```
上面这个版本的切点和前面一个切点选择的内容完全相同，但是多了一个参数Point，这意味着任何任何使用这个切点的advice能够访问和连接点的相关联的一个Point对象，这个对象就是方法调用的target 对象。

下面是另外一个展示定义切点参数的灵活机制的例子。
```Java
pointcut testEquality(Point p): target(Point) && args(p) && call(boolean equals(Object));
```
这里的args(p)意思是传递给equals方法的参数。不是调用的target 对象，如果你既想要调用的target对象也想要参数的Point对象，可以这样写：
```Java
pointcut testEquality(Point p1, Point p2) : target(p1) && args(p2) && call(boolean equals(Object));
```

切点中参数的使用非常的灵活，但是记住一点切点参数必须和每个切点选择的连接点绑定起来，所以喜爱安的切点定义会报编译错误：
```Java
pointcut badPointcut(Point p1, Point p2):
	(target(p1) && call(void setX(int)) ||
	 target(p2) && call(void setY(int)));
```
因为p1只会和setX绑定，p2只会和setY绑定，但是每次调用的时候AspectJ都会试图绑定p1和p2。


#如何写出好的切点
在编译期间，为了优化匹配性能，AspectJ处理切点。检查代码决定一个连接点是否匹配（动态或者静态的）一个切点是一个比较耗时的操作。在首次遇到切点声明的时候，AspectJ将会把切点重写为一个优化后的形式便于后续的匹配处理。这是啥意思？简单来说，切点将会被重写成DNF（Disjunctive Normal Form）的形式，而且会首先检查切点的组成部分是否有序，而且便于处理。所以用户可以不必担心切点符号的书写顺序。

然而，AspectJ只能根据已有的信息来工作，为了匹配过程的优化，用户应该思考自己的切点想要的效果和尽可能的缩小匹配搜索的空间。基本上AspectJ有三种类型的符号：**kinded**，**scoping** 和 **context**。
- Kinded 类型符号就是选择一个特定类型的连接点。比如execution, get, set, call和handler。
- Scoping 类型符号会选择一个连接点的范围。比如**within**，**withincode**。
- Contextual 类型符号会基于上下文去选择连接点。比如**this**, **target**和**@annotation**。

写切点的时候，至少要包含前面两种类型的符号（kinded和scoping），上下文类型的符号在有需要的时候书写。如果你只提供来一种类型的符号的话，在weaving阶段就会比较的耗费性能，比如时间和内存的消耗会多一点。Scoping在匹配的时候非常快，而且能非常快的排除连接点，所以在书写切点的时候尽可能的使用Scoping类型的符号。
