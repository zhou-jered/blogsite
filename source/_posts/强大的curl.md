---
title: 强大的curl
date: 2018-05-17 11:38:45
tags:
	- Note
	- Shell
---

# curl 文档手册
curl一般用来模拟Http请求，但是除此之外，curl能做的还有很多，能模拟很多其他和服务器的交互协议数据传输。
比如DICT, FILE, FTP, FTPS, GOPHER, HTTP, HTTPS, IMAP, IMAPS, LDAP, LDAPS, POP3, POP3S, RTMP, RTSP, SCP, SFTP, SMB, SMBS, SMTP, TELNET, TFTP。
curl的目的的是提供一个无需用户交互的工具。指定url的时候，可以通过模式匹配来同时指定多个url，比如
```shell
http://site.{one,two,three}.com
```
同时指定了三个url
```shell
ftp://ftp.example.com/file[1-100].txt
```
同时指定了100个url，curl不支持模式嵌套，注意在使用模式匹配功能时，请加上双引号，避免被shell转义。
通常来说，所有的布尔值参数通过 `--option` 来启用，`--no-option`来关闭。

- -a --append 使用FTP来上传文件的时候，不覆盖文件，而是append，文件不存在的话就创建文件，请注意有些SFTP服务器会忽略这个参数
- -K --config <file> 指定curl参数的配置文件，参数和值要写在同一行内，可以用空格，冒号，或者等号来分隔。



