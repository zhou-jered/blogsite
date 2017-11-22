---
title: Swift ARC 自动引用计数内存管理
date: 2017-11-22 16:33:40
tags:
	- Swift
	- ARC
	- Note
---

Swift 使用自动应用计数（Auto Reference Counting, ARC）来追踪和管理app内存使用，在大多数情况下，swift帮助你管理着内存，你不需要自己来管理内存，ARC会在类实例没有引用的时候释放这些实例的内存

# ARC 工作原理
你每次创建一个类实例的时候，ARC分配一段内存来存储实例的信息，这些内存里面有实例的类型（class），还有字段信息。
当实例不再被需要的时候，ARC就会自动释放该实例的内存。
为了保证实例在被使用的时候不被释放，ARC维护着实例的引用计数。

## ARC in Action
```Swift
class Person {
	let name:String
	init(name:String) {
		self.name = name
		print("\(name) is being initialized")
	}
	deinit {
		print("\(name) is being deinitialized")
	}
}
```
我们在这里定义了一个Person类，使用一个name参数来进行初始化。
```Swift
var reference1: Person?
var reference2: Person?
var reference3: Person?
reference1 = Person(name:"John Smith")
reference2 = reference1
reference3 = reference1
```
现在有3个实例指向了 name为John Smith的实例。此时ARC不会释放该实例的内存
```Swift
reference1 = nil
reference2 = nil
reference3 = nil
```
由于三个引用都没有指向Person实例，所以此时ARC会自动释放该实例。

## 循环引用
为了避免循环引用造成的内存泄漏，建议用户使用weak关键字来定义引用类型。
被weak关键字修饰的引用，只会引用对象，但是不会增加被引用对象的引用计数。一旦被引用对象被释放了的话，引用的值就会变为nil，所以被weak关键字修饰的引用类型必须是optional的。

除了使用weak引用之外，还可以使用另外一个关键字 unowned
同样的，被unowned关键字修饰的引用类型不会增加被引用对象的引用计数，而且，引用不会被ARC设置为nil，也就是 unowned的引用不是optional的，这个建立在一下的假设之上
> 引用类型的生命周期 小于或者等于 被引用对象的生命周期

> Important 
> 如果你不能保证以上假设成立，而且你的unowned引用类型引用了一个dealloc的对象的话，会触发一个Runtime error

一般情况下，我们使用的unowned 引用叫做 *safe unowned reference*，就是如果强行访问一个dealloc的引用的话，会触发Runtime error。也可以使用一种叫做*unsafe unowned reference*的unowned引用，此时强行访问被dealloc的内存区域不会触发Runtime error，通过unoened(unsafe) 关键字来声明一个unsafe unowned 引用。

### Unowned 引用和隐式optional 拆包
weak 和 unowned 引用可以解决大部分的循环引用问题，但是还有一种情况下需要 unowned 和 隐式拆包optional特性来配合才能解决循环引用的问题。

下面的例子定义了两个类，Country和City，没有都有一个彼此的强引用属性，在这个数据模型里面，每个country必须有个首都，而且每个city必须属于一个country。
```Swift
class Country {
	let name:String
	var capitalCity:City!
	init(name:String, capitalName:String) {
		self.name = name
		self.capitalCity = City(name: capitalName, country: self)
	}
}

class City {
	let name:String
	unowned let country: Country
	init(name: String, country: Country) {
		self.name = name
		self.country = country
	}
}
```



