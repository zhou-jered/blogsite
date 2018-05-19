---
title: 加速Spring Test 运行
date: 2018-05-14 15:29:18
tags:
	- Notes
	- Spring
	- Test
---

# 正确的单元测试
POJO make your application testable，如果测试的依赖对象只是简单的new出来的话，可以使用mock object。
真正的测试运行速度是很快的，因为不需要启动过多的基础环境，如果你的测试运行过慢了，就需要改进你的测试方法论。
使用Spring提供的Mock对象可以帮助你提高测试的效率。

# Mock对象

## Environment
包 org.springframework.mock.env 提供了一系列的env Mock 对象，MockEnvironment 和MockPropertySource 可以用来测试和环境相关的功能。

## JNDI
包 org.springframework.mock.jndi 包含了JNDI SPI的实现

## Servlet API
包 org.springframework.mock.web 提供Servlet API的mock实现，可以用来测试web context，controller和filter。

## Spring Web Reactive
包 org.springframework.mock.http.server.reactive 包含了ServerHttpRequest 和 ServerHttpREsponse的mock 实现。

# 集成测试
除了测试单个POJO的功能正常之外，还需要测试这些POJO能不能配合正常工作。Spring 提供的集成测试功能可以做
- 在测试case之间 管理 IoC Container Cache
- 提供DI
- 提供是事务管理功能
- 提供一些Spring的基础类

下面是重点
## Context 管理和缓存

