---
title: lsof 命令
date: 2017-09-14 10:22:16
tags:
	- Note
	- Shell
---

From Mac lsof manual.
lsof -->  list open files

用这个命令可以查看当前机器上打开的文件。

一个打开的文件可以是普通文件，目录，character special file, block special file, 可执行文本的引用，程序库或者网络文件。
character special file 是面向字符io的设备，这类设备的读写不能被buff 或者cache，unable to seek。
block special file 面向块的设备，行为类似普通文件，设备中的数据能被cache，buff。

如果啥参数都不写的话，这个命令会输出所有的进程的所有打开的文件。可怕！
通常来讲，参数之间的关系是OR关系，如果使用了取反操作“^”，由于这是排除操作，不使用OR 或者AND逻辑，在判断filter条件之前排除掉不符合的数据。
参数选项 -a -b -C 可以合并成 -abC。

参数表：
-？ -h  Help
-a 将参数之间的运算关系由OR 变成AND

