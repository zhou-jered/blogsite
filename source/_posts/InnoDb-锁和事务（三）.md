---
title: InnoDb 锁和事务（三）
date: 2017-08-08 14:05:58
tags:
	- Note
	- MySQL
	- InnoDB
---

这篇讲InnoDB的`autocommit`, `Commit`，和`Rollback`

InnoDB里，所有用户活动都在事务里进行，如果`autocommit`开启，每一个sql语句都作为一个单独的事务运行，默认的，MySQL启动为每个连接启动session并设置`autocommit`开启，这样的话，如果每条SQL语句没有返回错误的话，就自动执行提交动作，如果语句出错里，则依据错误的类型来执行提交或者回滚操作，具体的看[这里](https://dev.mysql.com/doc/refman/5.7/en/innodb-error-handling.html)

如果想要在一个已经开启了`autocommit`的session中将多条SQL语句在一个事务中执行的话，可以显式的使用`START TRANSACTION` 或者 `BEGIN`，更新信息看[这里](https://dev.mysql.com/doc/refman/5.7/en/commit.html)

如果`autocommit`设置关闭的话，session总是有一个当前事务，使用`COMMIT`或者`ROLLBACK`来结束当前事务并开启下一个事务。

如果`autocommit`设置关闭的情况下，没有显式的提交修改的话，MySQL就会默认回滚事务。

一些语句会隐式的提交当前事务，效果就像在你执行这条语句之前执行了`COMMIT`，更多信息，看[这里](https://dev.mysql.com/doc/refman/5.7/en/implicit-commit.html)

`COMMIT`提交的意思当前事务的更改永久生效并且可以被其他session看到，`ROLLBACK`语句意思是取消当前的更改，`COMMIT`和`ROLLBACK`都会释放当前事务获取的所有锁。


