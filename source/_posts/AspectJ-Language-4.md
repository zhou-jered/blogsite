---
title: AspectJ Language 4 inter-type声明
date: 2018-04-15 15:44:37
tags:
	- AspectJ
	- AOP
	- Note
---

# Inter-Type declarations 新类型声明
Aspect可以声明其他类型（大概就是类）内的成员变量，方法和构造器。这个叫做类型间声明。Aspect也可以声明类型实现类某个接口或者是继承类某个类。下面是一些例子。

这个声明类每个*Server*类又一个boolean类型的成员变量叫做disabled，初始值是false。
```java
private boolean Server.disabled = false;
```
注意private属性，代表的是在aspect内属性是私有，只有在aspect范围内的代码能够访问这个disabled属性。即使是Server 内也声明了一个private的disabled属性也没关系，各玩各的。

下面这个声明在Point内一个getX的方法，没有参数，返回this.x
```java
public int Point.getX() { return this.x; }
```
由于这个在切片里面定义的public getX() 方法在Server的原生代码里面也能访问到，所以如果Server里面也同时定义了这个getX方法的话，就会冲突。

下面这个例子定义了带有两个参数的构造器：
```java
public Server.new(String location, String country) {
	this.location = location + " in " + country;
}
```

声明一个公有初始值为0的int属性
```Java
public int Point.x = 0;
```
请注意，由于这是一个public的属性，如果其他aspect或者是Point内本来就定义了x的话，就会发生冲突。

下面这个声明Point实现了*Comparable*接口
```java
declare parents: Point implements Comparable;
```
当然，Point得有Comparable对应的方法才不会报错。

下面这个声明Point继承自*GeometricObject*类
```java
declare parents: Point extends GeometricObject
```

其实，可以同时声明多个inter-type，比如
```java
public String Point.name;
public void Point.setName(String name) { this.name = name;}
```


一个inter-type成员只能有一个target type，但是你通常有同时声明多个类的成员的需求。这个需求可以通过私有接口和inter-type成员相结合来完成。
```java
aspect A {
	private interface HasName{} 
	declare parents: (Point || Line || Square) implements HasName;

	private String HasName.name;
	public String HasName.getName() { return name;}
}
```
通过对Point，Line，Square同时声明实现一个接口，然后在接口内定义成员变量和getter来实现同时对类添加声明变量的效果，如果有需要的话，还可以添加一个setter。

上面的例子演示了如何声明已有类的接口，成员变量和方法，甚至可以添加声明非常量的成员变量。

# inter-type 范围（scope）
AspectJ 可以允许各种访问控制类型的声明。如果声明为private的话，这个private仅仅是针对aspect而言，除了这个aspect，没有其他地方能够访问到该变量，即使是目标类也不行。
如果是default或者是protected的话，根据是否在同一个包下面来决定是否冲突。

# 一个PointAssertions的例子
```java
class Point  {
      int x, y;

      public void setX(int x) { this.x = x; }
      public void setY(int y) { this.y = y; }

      public static void main(String[] args) {
          Point p = new Point();
          p.setX(3); p.setY(333);
      }
  }

  aspect PointAssertions {

      private boolean Point.assertX(int x) {
          return (x <= 100 && x >= 0);
      }
      private boolean Point.assertY(int y) {
          return (y <= 100 && y >= 0);
      }

      before(Point p, int x): target(p) && args(x) && call(void setX(int)) {
          if (!p.assertX(x)) {
              System.out.println("Illegal value for x"); return;
          }
      }
      before(Point p, int y): target(p) && args(y) && call(void setY(int)) {
          if (!p.assertY(y)) {
              System.out.println("Illegal value for y"); return;
          }
      }
  }
```
