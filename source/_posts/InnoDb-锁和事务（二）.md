---
title: InnoDb 锁和事务（二）
date: 2017-08-07 16:46:41
tags:
	- Note
	- MySQL
	- InnoDB
---

### 事务隔离级别
事务隔离是数据处理的一个基础，Isolation 就是ACID原则中的I，事务隔离级别是在多个事务同时在改变和查询数据时一个平衡性能和结果有效性，一致性和再生性的调节按钮。
InnoDb 提供在 SQL:1992 标准中提及的四个事务隔离级别：
- READ_UNCOMMITED
- READ_COMMITED
- REPTEATABLE_READ
- SERIALIZABLE
InnoDb默认的隔离级别是 REPEATABLE_READ。

用户可以改变单个session的事务隔离级别，也可以设置服务器的默认隔离级别。[see Section 13.3.6, “SET TRANSACTION Syntax”.](https://dev.mysql.com/doc/refman/5.7/en/set-transaction.html)

InnoDb使用不同的锁策略来实现不同的事务隔离级别，在数据一致性要求比较高的情况下，可以使用默认的`REPEATABLE READ`隔离级别，要求比较宽松的话就可以使用`READ_COMMITED` 甚至 `READ_UNCOMMITED`。`SERIALIZABLE` 采取比`REPEATABLE READ`更加严格的规则，在一些特殊的情况下会采取这个规则，比如 *XA transactions*，或者用来定位并发的事务问题或者死锁。

## REPEATABLE READ
这是InnoDb的默认事务隔离级别，保证在事务期间能读取到一致的数据快照。通过多版本来实现，应该是在事务开始之后就只读取同一个版本的数据了。
对于锁定读来说（*SELECT* with *FOR UPDATE*或者*LOCK IN SHARED MODE*），*UPDATE*和*DELETE*，锁定行为取决于是否在唯一索引上有唯一的查询条件或者一个范围查询条件
- 对于唯一索引上的唯一查询条件，InnoDB只会锁定索引记录，不会锁定索引前面的gap
- 对于其他查询条件，InnoDb锁定扫描到的索引范围，使用间隙锁或者后键锁来阻止其他session在这个范围内插入新数据。

## READ COMMITED
每一个一致性读，甚至在同一个事务内，都会设置并读取数据快照内的内容。
对于锁定读来说，InnoDb只锁定索引记录，不锁定索引间隙，所以允许在事务期间在间隙插入新的数据，间隙锁只是在外键和重复键的检查上使用。
由于没有使用间隙锁，其他session能在间隙内插入数据，所以会造成幻读的问题。
如果你使用`READ COPMMITTED`隔离级别的话，就必须使用基于行的binlog。
使用`READ COMMITTED`的一些额外效果：
- 对于*UPDATE*和*DELETE*语句来说，InnoDb仅持有它正在更新或者删除的行的锁，在MySQL计算完成where条件后，不匹配的行对应的记录锁会被释放。这可以降低死锁的发生几率，但是并不能完全防止死锁的发生。
- 对于*UPDATE*语句，如果一行已经被锁了，InnoDb就会执行**semi-consistent** 读操作，返回最近的提交的数据，MySQL据此来判断这行数据是否满足update的where条件，如果满足，就必须更新这行，MySQL会再次读取这行，而且这次会lock或者等待lock这行数据。

考虑以下的数据
```sql
CREATE TABLE T (A INT NOT NULL, B INT) ENGINE=InnoDB;
INSERT INTO T VALUES (1,2),(2,3),(3,2),(4,3),(5,2);
COMMIT;
```
在这个例子里，由于没有显示的创建索引，所以查询的时候会使用隐式的集群索引。
假设一个客户端执行update操作
```sql
SET autocommit=false;
UPDATE T SET B=5 WHERE B=3;
```
假设另外一个客户端在第一个客户端执行完后执行以下update操作
```sql
SET AUTOCOMMIT = 0;
UPDATE T SET B=4 WHERE B=2;
```
在InnoDb执行Update操作的时候，它首先会在每一行上获取一个X Lock，然后决定是否更新这一行，如果不更新，就释放锁，否则InnoDB会持有锁直到事务结束。事务处理的影响如下。
当使用默认的*REPEATABLE READ*的隔离级别的时候，第一个update会获取每一行的X Lock而且一个都不放
```
x-lock(1,2); retain x-lock
x-lock(2,3); update(2,3) to (2,5); retain x-lock;
x-lock(3,2); retain x-lock;
x-lock(4,3); update(4,3) to (4,5); retain x-lock;
x-lock(5,2); retain x-lock;
```
第一个update操作会阻塞直到第一个update提交或者回滚
```
x-lock(1,2); block and wait for first UPDATE to commit or rollback
```

如果使用`READ COMMITTED`隔离级别， 第一个update操作获取到锁之后如果发现不需要更新这一行就会释放锁
```
x-lock (1,2); unlock (1,2);
x-lock (2,3); update(2,3) to (2,5); retain x-lock;
x-lock (3,2); unlock(3,2)
x-lock (4,3); update(4,3) to (4,5); retain x-lock;
x-lock (5,2); unlock(5,2)
```
对于第二个update来说，InnoDB执行*semi-consistent*读，返回最近一次提交的数据让MySQL决定是否更新这一行数据
```
x-lock (1,2); update(1,2) to (1,4); retain x-lock;
x-lock (2,3); unlock(2,3);
x-lock (3,2); update(3,2) to (3,4); retain x-lock;
x-lock (4,3); unlock(4,3)
x-lock (5,2); update(5,2) to (5,4); retain x-lock;
```

## READ UNCOMMITED
`SELECT`在无锁的情况下执行，可能读到一个之前版本的数据，没有数据一致性，这种操作也叫做脏读，在其他方面，此隔离级别表现跟`READ COMMITTED`行为类似

## SERIABLEZED
行为类似`REPEATABLE READ`，但是在autocommit=false的情况下，InnoDB会隐式的转换所有的*select*语句到*select ... lock in share mode*。如果autocommit=true，*select*语句就会有自己的事务。而且，这个事务被认为是只读的，如果执行一致性读（无锁）的话就能够被串行化而且不需要阻塞其他事务。如果需要在select语句的时候阻塞其他事务，就设置autocommit=false。
