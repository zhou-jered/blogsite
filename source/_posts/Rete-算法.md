---
title: Rete 算法
date: 2018-05-15 16:24:07
tags:
	- Note
	- Algorithm
	- Drools
---


# 介绍
Rete 是一种实现规则系统的模式匹配算法。IBM的规则引擎和Drools规则引擎都使用了这个算法。Rete 在设计上以牺牲内存空间换取运行时性能的做法，在非常庞大的规则系统中，内存问题会凸显出来。一些Rete的改进算法可以避免内存消耗过大的问题。
Rete是拉丁文中的网络的意思，有Charles Forgy博士在1978年提出的一个算法。这个算法主要分为两个部分，规则的编译和运行时规则的判定。
规则会被编译成一个descrimination 网络，这个网络用不同类型的节点组成，用来过滤数据，数据在网络中传送，节点运行自己的规则，最后生成判定结果。在Forgy的论文中，描述了4中基本node，root，1-input，2-input，terminal。
就是根结点，单输入节点，双输入节点，结束节点。
![Node Type](/images/rete/Rete_Nodes.png)

#算法流程

## Rete Nodes
Root Node 是整个算法的入口Node，数据进入root node之后立马传送给ObjectTypeNode， 这个类型的node用来判断数据对象的类型，避免规则的应用在错误的数据类型上面。
我理解的是会按照数据类型传送到匹配的的ObjectTypeNode上。
![ObjectTypeNode](/images/rete/Object_Type_Nodes.png)

ObjectTypeNode后面接的是AlphaNode和BeteNode，AlphaNode用来做text判断，尽管在论文中只描述了相等这一种判断，但是后来的实现中提供了多种的text判断。下图展示了一个ObjectTypeNode后面接的两个AlphaNode
![AlphaNode](/images/rete/Alpha_Nodes.png)

Drools使用hash来优化了AlphaNode的查找，创建了一个HashMap，key是text，value是AlphaNode。

有两种双输入类型的node，JoinNode 和 NotNode，这两种node都是BetaNode，用来比较两个对象和它们的field，对象可能是相同的或者不同的类型，BetaNode左边的输入通常是一个对象列表，在Drools中，是tuple，右边是一个单一的对象，两个Not判断可以用来实现exists的逻辑。
BetaNode有自己的缓存（原文叫做memory，应该和缓存是一个意思），左边的输入叫做Beta缓存（memory），缓存了所有的输入对象列表（tuples），右边的输入叫做Alpha缓存（memory），缓存了所有的输入对象。再次强调一下，左边输入是一个列表（tuple），右边的输入是单个对象。Drools通过对BetaNode建立索引扩展了Rete。这部分我也不是很清楚，应该是一个HashMap加速查找的过程了，应该要对算法有具体了解才能够理解。

网络的终点叫做terminal Nodes，到达ternimal nodes的时候，就可以说满足了所有匹配的条件，当然了，一条数据能够到达的ternimal node不止一个，也就是不止匹配一条规则，当匹配多条的规则的时候，需要引入冲突解决机制，Drools的做法是给rule添加优先级，默认是0。
最后一条，Drools通过在不同rule之间共享Node来提高性能，Node内部还可以缓存结果，进一步提高来效率和降低空间占用。

下图是下面两条规则的共享Node示例图
```java
rule
when 
	Cheese ($cheddar : name == "cheddar"")
	$person : Person (favouriteCheese == $cheddar)
then
	System.out.println($person.getName + " likes cheddar");
end


rule
when
	Cheese ($cheddar  : name == "cheddar")
	$person : Person (favouriteCheese != $cheddar)
then
	System.out.println($person.getName + "does not like cheddar");
end
```
![Node Sharing](/images/rete/Node_Sharing.png)



相关资料：
Rete wiki：https://en.wikipedia.org/wiki/Rete_algorithm#cite_note-7
Drools Rete：http://www.jbug.jp/trans/jboss-rules3.0.2/ja/html/ch01s04.html
Rete Explain： http://www.drdobbs.com/architecture-and-design/the-rete-matching-algorithm/184405218

