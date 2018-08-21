---
title: Java  中的Unsafe 类
date: 2018-08-13 10:44:48
tags:
---

所以在 JDK7 中引入了 VM Anonymous Class 这一真正意义上的匿名类，不需要 ClassLoader 加载，没有类名，当然也没其他权限管理等操作，这意味着效率更高(不必要的锁操作)、GC 更方便（没有 ClassLoader）；VM Anonymous Class 通过调用 sun.misc.Unsafe.defineAnonymousClass 生成。

用于定义匿名类
