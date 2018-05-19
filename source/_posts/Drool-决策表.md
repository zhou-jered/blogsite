---
title: Drool 决策表
date: 2018-05-18 10:54:50
tags:
	- Note
	- Drools
---
Drool 支持通过excel等电子表格处理软件来维护rules。可以将规则写在excel中然后教过drools处理。适用场景是当规则具有一定的规律，可以用过模版template来表述，通过更改模版的参数来控制规则的表达。而且规则的量很大，少量的规则用电子表格来维护就没有直接写高效。

使用表格规则的时候，每行是一个rule，每列要么是一个condition，要么是一个action。表格中在特定的相对位置带上关键字方便drools创建rule。

