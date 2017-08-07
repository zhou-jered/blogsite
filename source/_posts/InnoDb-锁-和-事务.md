---
title: InnoDb 锁 和 事务（一）
date: 2017-08-07 13:59:30
tags:
	- Note
	- MySql
	- InnoDb
---

## Innodb 锁的种类

- 共享锁和排它锁 （Shared and Exclusive Lock）
- 意向锁 （Intention Lock）
- 记录锁 （Record Lock）
- 间隙锁（Gap Lock）
- 后键锁（Next-Key Lock）
- 插入意向锁 （Insert Intention Lock）
- 自增锁 （AUTO_INC Lock）
- 空间索引预测锁 （Predicate Locks for Spatial Indexes）

## 共享锁和排它锁
InnoDb 实现了两种标准的行级别锁，共享锁和排它锁。

- 共享锁 -- 读锁
- 排他锁 -- 写锁

## 意向锁
InnoDb支持多种粒度的锁，并且允许它们同时存在。
意向锁是一个针对表的锁，表明一个事务在接下来将要在这个表上的某些行获取S Lock 或者 X Lock。
> S Lock 是共享锁（Shared Lock），X Lock是排它锁（Exclusive Lock）

有两种意向锁
- Intention Shared （IS）：意向共享锁，一个事务希望在表t上某些行获取共享锁
- Intention exclusive （IX）：意向排它锁，一个事务希望在表t上某些行获取排它锁

语句`select ... lock in share mode` 将会设置一个IS lock
语句`select for update` 将会设置一个IX lock

意向锁是这样用的：
在一个事务获取某行的S lock前，必须先获取一个IS lock， 获取X Lock 之前也必须先获取一个IX lock。

## 记录锁
在索引上的锁叫做记录锁。
语句`select c1 from t where c1 = 10 for update` 将会避免其他事务更新这一行数据。记录锁只能锁定索引，如果表上没有索引，就创建隐式集群索引。

## 间隙锁
锁定索引之间的间隙的锁，或者锁定第一个索引之前或者最后一个索引之后的锁。
语句`select t1 from t where c1 between 10 and 20`将会避免其他事务更新t.c1=15的行。锁定不存在的数据区域，在某些事务隔离级别的时候需要使用这个锁。
注意在使用唯一索引的行上是不需要间隙锁的。
间隙锁是一种的纯粹的抑制锁，意思就是这个锁的作用只是避免其他事务在锁定区间插入数据，所以间隙S锁和间隙X锁是一样的。
间隙锁会在事务隔离级别为`READ_COMMITED`的时候失效。

## 后键锁（Next-Key Lock）
由索引上的记录锁和索引前的间隙锁混合而来。
InnoDb在锁定行记录的时候是这样执行的，首先在目标行上加锁，这样，行锁其实就是索引记录锁。然后间隙锁锁住索引前面的区域，这样就组成了一个后键锁（Next-Key Loc））。
InnoDB 默认的事务隔离级别是`REPEATABLE READ`，InnoDb使用后键锁来防止幻影行。

## 插入意向锁
所谓的插图意向锁就是`INSERT`操作设置的一个间隙锁。用来告诉其他事务，不要再往这个间隙里面插入数据了，在获取到插入意向锁之后，在锁定需要插入的行，再执行插入操作，在这个过程中，如果有其他事务也想要往这个区间插入数据的话，首先也需要获取一个插图意向锁，然后获取目标行的行锁来执行操作。
For Example  session A
```SQL
CREATE TABLE CHILD(ID INT PRIMARY KEY);
INSERT INTO CHILD() VALUES (50, 102);
START TRANSACTION;
SELECT * FROM CHILD WHERE ID > 80 FOR UPDATE;
```
此时 id大于80的行都被锁住了
此时重启另一个session B如果执行以下sql
```sql
INSERT INTO CC() VALUES (99);
```
语句将会阻塞，直到前一个session A 执行commit 或者rollback操作来释放锁。

## 自增锁
自增锁是一个特殊的表锁，在插图带自增列的事务中使用，在简单的情况下，如果一个事务正在插入一条带有自增列的记录，另一个事务也要执行插入操作，这个事务只能等待，从而获取一个连续的自增键值。
配置项`innodb_autoinc_lock_mode`控制自增锁的算法，

## 空间索引预测锁
InnoDb 支持在有空间数据的列上使用空间索引。
由于在`REPEATABLE READ`和`SERIALIZABLE`的隔离级别上，后键锁不能很好的支持，在多位数据上，没有绝对的前后概念，所以next-key中的next不是很好确定。
对于空间数据，InnoDb使用的R-tree来维护索引，所以空间预测索引锁住的是区域的最小矩形区域。
