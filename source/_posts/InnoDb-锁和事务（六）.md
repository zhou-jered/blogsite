---
title: InnoDb 锁和事务（六）
date: 2017-08-10 10:19:49
tags:
	- Note
	- MySQL
	- InnoDB
---

这篇讲幽灵行，幽灵行是官方文档的叫法，国内一般叫幻读。

所谓幽灵行就是在事务范围内执行同样的查询语句两次，两次的结果不一样。

假设有个child表，id 列上有索引，你想要读取并锁定所有id大于100的行，接下来更新这些行。
```SQL
SELECT * FROM CHILD WHERE ID >100 FOR UPDATE
```
假设现在表里有两条id记录，分别是90 和102，如果锁只是加在了索引记录上（记录锁）而不加在索引的空白空间上的话，其他session就能插入id为101的新行，如果这个101在两次查询之间插入的话，第二次查询就能够看到第一次查询不存在的数据。如果将数据行集合看作是数据项的话，id为101的新行的插入就违背了事务的规则。

为了避免这种情况的出现，InnoDB使用的一种叫做后键锁的算法，除了锁定扫描到的索引记录之外，同时将索引之间的间隙也锁定了。后键锁的准确定义是索引记录锁加上索引紧邻索引前面的空闲空间锁。

当InnoDB扫描索引的时候，为了避免在最大索引记录的后面插入新数据，最大索引记录的后面空闲空间也会被加锁。在上面这个例子中，区间(102,+∞) 也会被加锁。

你可以使用后键锁在你的程序中实现唯一性检查，如果你在读取数据的时候加上了共享锁（读锁），在你的要插入的位置上没有发现数据的话，在你设置完成后键锁之后你就可以安全的插入数据，事实上，后键锁提供了一种锁住不存在数据的一种机制。

间隙锁是可以通过设置被禁用的，但是这样会带来幻读的问题。

注意事项
> 如果你想要通过SELECT FOR UPDATE 来实现唯一性检查的话，在有条件竞争的情况下会发生死锁。避免的方法是插入的时候在唯一列上使用INSERT IGNORE，然后来检查影响的行数量。
