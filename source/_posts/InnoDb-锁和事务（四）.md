---
title: InnoDb 锁和事务（四）
date: 2017-08-08 15:09:43
tags:
	- Note
	- MySQL
	- InnoDB
---

这篇讲一致性无锁读

### 一致性读
一个一致性读是说InnoDB使用多版本系统来呈现数据库在某个时间点上的数据。查询能够看到在那个时间点之前的事务提交更改的数据，但是看不到在那个时间点之后提交修改的数据或者尚未提交的数据，有一点例外就是查询能够看到在同一个事务中被之前语句修改的数据。这个例外会造成以下的现象，如果你更新表中的某些行，SELECT语句能够看到最新版本的更新行，但是也能看到任何行的较老的版本，如果其他session同时修改这个表的话，这意味着你能够看到也许永远不会出现在数据库中的状态。

如果事务的隔离级别是REPEATABLE READ，所有的一致性读得到的数据都是建立事务后第一次同样的读操作得到的数据，如果想看最新的数据的话，可以提交当前事务。

对于READ COMMITTED隔离级别来说，事务内每一次一致性读都会设置并读取新的数据快照

一致性读是InnoDB在READ COMMITTED 和 REPEATABLE READ隔离级别中处理SELECT语句时的默认模式。一致性读不会在读取的表上设置任何的锁，从而其他session能够自由的并发的改变表中的数据。

假设你运行在默认的REPEATABLE READ隔离级别下，你想要执行一致性读（就是SELECT语句）的时候，InnoDB会根据你的查询看到数据库的时候给你的事务一个时间点，如果其他事务在这个时间点之后删除了一行数据并提交，你是看不到这行被删除了的，对于插入和更新来说也一样。

*注意*
数据库快照的时间点决定是根据第一条SELECT语句的，并不是根据DML语句来决定时间点的。

到现在为止所说就是大名鼎鼎的多版本并发控制。

如果你像看到最新的数据库状态，那就使用READ COMMITTED隔离级别或者使用锁定读操作。
当处于READ COMMITTED隔离级别的时候，每次一致性读都会设置并读取新的数据快照。在LOCK IN SHARE MODE的情况下，会发生锁定读，select会阻塞到事务包含了最新的结束行。

#### 一致性读在DDL语句的时候并不生效
- DROP TABLE，表的删除了，InnoDB在删除的表上不能工作。
- ALTER TABLE，由于这个语句会原表的临时副本后删除原表，当你在这个表上再次执行一致性读的时候，新表的数据快照不存在，就会抛出错误。

***

### 无锁读
如果你在同一个事务内先查询数据，然后又执行插入或者更新相关的数据，普通的select语句并不能提供足够的保护，其他事务能够更新或者删除你刚刚查询的数据。InnoDb 支持两种类型的能提供额外安全性的锁定读操作

+ **SELECT ... LOCK IN SAHRE MODE**
 在读到的行上设置共享模式的锁，其他session能够读取到该行，但是在我们的事务结束之前不能修改该行，如果其他事务正在修改我们查询到的行而且还没提交的话，我们的查询就是等待其他事务结束，然后拿到最新的值。

+ **SELECT ... FOR UPDATE**
对于在查询中遇到的索引记录，锁住相关的行和关联的索引，锁定效果和在这行执行update语句一样。其他事务想要更新这些行的话就会阻塞，在这些行上执行SELECT... LOCK IN SAHRE MODE 也会阻塞，或者在特定的隔离级别下读取这些行也会阻塞。一致性读操作会忽略目标行上的锁（老版本的记录是不能被锁定的，他们是由`undo log`在内存构造出来的数据副本）。

这些语句在处理单表或者跨多表的树形结构或者图结构的数据会比较有用。在你穿过图边或者树形分支的时候，保留着回来改变这些值的能力。

所有被LOCK IN SHARE MODE 或者 FOR UPDATE 设置的锁都会在事务结束的时候被释放。


注意：
> 语句SELECT ... FOR UPDATE的锁，只有在禁用autocommit的时候才能生效，也就是说，在显式的开始事务START TRANSACTION 或者 设置autocommit=0的时候，行锁才能生效。在autocommit=1的时候锁是不会生效的。

#### 锁定读例子
假设你想在child表中插入一条新数据，而且保证在parent表中有一条对应的parent记录，您的应用程序可以确保整个操作顺序的引用完整性。

首先，使用一个一致性读来查询在parent表中是否有相应的记录存在，你能安全的往child表中插入一条记录吗？不能，因为其他session会在你的select语句和insert语句的执行间隙删除你的parent记录，这个过程你并不知道。

为了避免这个问题，使用SELECT ... LOCK IN SHARE MODE操作。
···SQL
SELECT * FROM PARENT WHERE NAME ="JONES" LOCK IN SHARED MODE
```
在lock in share mode成功返回之后，你就可以安全的在child表中插入数据了，别了提交操作。在这过程中，其他想要在parent 表中对应记录上获取X Lock的session都必须等到你的事务结束，换言之，就是等到表中所有数据处于一致性状态。

考虑另外一个例子，假设在表CHILD_CODES中有一个counter字段，用来给child表中的每一条child记录添加一个唯一标识，不要使用一致性读或者共享读模式来读取这个counter的值，因为两个用户能后看到同一个counter值，如果接下来两个用户都试图使用同一个标识往child表中插入数据时就会发生duplicate-key错误。

在这里，LOCK IN SHARE MODE 并不是一个好的解决方案，因为吐过两个用户在同一时间读取counter，至少有一个在试图更新counter的时候会陷入死锁。

为了实现读取并自增的counter计数器，首先时候FOR UPDATE锁定读操作，然后在执行自增操作，比如
```SQL
SELECT COUNTER_FIELD FROM CHILD_CODES FOR UPDATE;
UPDATE CHILD_CODES SET COUNTER_FIELD = COUNTER_FIELD+1;
```
上面的描述仅仅是一个SELECT ... FOR UPDATE 的一个例子，在MySQL中，实际上生成一个唯一标识能够使用一句语句就能完成
```SQL
UPDATE CHILD_CODES SET COUNTER_FIELD = LAST_INSERT_ID(COUNTER_FIELD+1);
SELECT LAST_INSERT_ID();
```
SELECT 语句仅仅是取出来标识信息，而且没有访问任何表。

