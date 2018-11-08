---
title: Programer Tips
date: 2018-05-17 12:00:50
tags:
---
- 
less命令中，&pattern \* Display only matching lines
- 
curl -F key=value -F filename=@file.tar.gz http://localhost/upload 如果使用了-F参数，curl会以multipart/form-data的方式发送POST请求。-F以key=value的形式指定要上传的参数，如果是文件，则需要使用key=@file的形式。
- 
MAC 和 HMAC 是一种带密钥的hash算法，可以用来验证消息的完整性和真实性。
- 
SSLv3.0 中fragment 最大不能超过2^14, 2KB
 

- 
PPTP 协议连接1723端口
- 
Redis cluster 不支持多数据库，select 命令不能用
- 
Redis cluster 4.0 之后的命令返回的主机部分格式为
 > ip:port@number 

 会导致redisson解析主机错误。redisoon解析主机的格式为 ip:port 。
- 
Redis cluster 4.0 之后的`cluster nodes`命令返回的主机部分格式为
 > ip:port@number 

 会导致redisson解析主机错误。redisoon解析主机的格式为 ip:port 。
- 
Java Nio 中的Buffer 不是线程安全的
- 
Mybatis Generator 分页插件：<plugin type=org.mybatis.generator.plugins.RowBoundsPlugin></plugin>
- 
nginx 不会转发下划线 _ 开头的haeder
