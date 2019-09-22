---
title: redis-源码学习-1
date: 2019-04-21 19:26:47
tags:
	- Redis
	- Source Code
	- NoSQL
---

学一下Redis的源代码吧，看下自己能学习到什么程度。
首先从 git@github.com:antirez/redis.git  clone 下源代码，看最新的 unstable 分支吧。
我们知道redis 是C/S架构的，核心代码都在 server端，所以First step，找到server 的main函数，先搞清楚redis server的启动流程，btw，redis是由c写成的。

## 查找Server Main
全局搜索 `main(` ，可以看到结果还是挺多的，在server.c 文件中找到了main入口，应该就是整个server的入口代码了。
下面开始看。

看到usage了
```c
void usage(void) {
    fprintf(stderr,"Usage: ./redis-server [/path/to/redis.conf] [options]\n");
    fprintf(stderr,"       ./redis-server - (read config from stdin)\n");
    fprintf(stderr,"       ./redis-server -v or --version\n");
    fprintf(stderr,"       ./redis-server -h or --help\n");
    fprintf(stderr,"       ./redis-server --test-memory <megabytes>\n\n");
    fprintf(stderr,"Examples:\n");
    fprintf(stderr,"       ./redis-server (run the server with default conf)\n");
    fprintf(stderr,"       ./redis-server /etc/redis/6379.conf\n");
    fprintf(stderr,"       ./redis-server --port 7777\n");
    fprintf(stderr,"       ./redis-server --port 7777 --replicaof 127.0.0.1 8888\n");
    fprintf(stderr,"       ./redis-server /etc/myredis.conf --loglevel verbose\n\n");
    fprintf(stderr,"Sentinel mode:\n");
    fprintf(stderr,"       ./redis-server /etc/sentinel.conf --sentinel\n");
    exit(1);
}
```
就是这里了。
启动流程：
- 设置 locale
- 设置 时区
- 设置 oomHandler
- 初始化随机种子：`srand(time(NULL)^getpid());`
- 设置dict 的hash函数
- 检查sentinel mode
- 初始化配置
- 初始化ACL，访问控制
- 初始化模块系统（？）
- 根据命令开始检查rdb 或者 aof
- 解析命令行参数，加载到config中，config一开始是从配置文件中读取的，命令行参数可以覆盖掉文件配置。
- 调用 `initServer()` 这个函数做了大部分的server初始化工作
- 打印redis 的 文本logo，也就是说，在console 上看到redis的ascii logo之后，server就已经初始化完成了。
- 检查tcp 的backlog 设置。tcp 的backlog 是accept队列的大小。
- 根据启动角色配置（sentinel， server）决定正常启动server还是进入sentinel 状态。我们从正常server角色流程里走
    - 从Queue 加载module（？）
    - 加载ACL控制列表
    - 从磁盘加载数据

然后调用 `aeMain(server.el);` 开启Event Loop 就可以开始正常的接受处理请求了。下面开始看Redis 的Event Loop 模块。

## Redis AE
Redis 使用的事件驱动lib 是自己写的叫做AE的一个简单lib。一共6个文件。基于系统提供的多路复用技术来实现事件驱动，支持 epool，evport，kqueue，select。
在ae lib 的设计上，使用了接口和实现分离。相关的struct 和接口定义在 ae.h 文件中。一共定义了 4 个struct 和 16个接口。
ae.c 文件中实现了ae.h 的接口，上文中在server.c文件开启eventloop 的函数`aeMain(server.el);`就是在ae.h文件中定义的。
在涉及到多路复用相关的和平台有关的api的时候，就会调用 ae_epoll.c, ae_evport.c, ae_kqueue.c, ae_select.c. 中其中一个文件的实现代码。
ae.c  中具体怎么决定选择平台多路复用实现的代码文件，通过下面的宏来实现
```c
/* Include the best multiplexing layer supported by this system.
 * The following should be ordered by performances, descending. */
#ifdef HAVE_EVPORT
#include "ae_evport.c"
#else
    #ifdef HAVE_EPOLL
    #include "ae_epoll.c"
    #else
        #ifdef HAVE_KQUEUE
        #include "ae_kqueue.c"
        #else
        #include "ae_select.c"
        #endif
    #endif
#endif
```
可以认为ae.c 实现了平台无关Event Loop 功能。在Java 中，这应该是一个抽象类。

来看下EventLoop 的数据结构
```c
/* State of an event based program */
typedef struct aeEventLoop {
    int maxfd;   /* highest file descriptor currently registered */
    int setsize; /* max number of file descriptors tracked */
    long long timeEventNextId;
    time_t lastTime;     /* Used to detect system clock skew */
    aeFileEvent *events; /* Registered events */
    aeFiredEvent *fired; /* Fired events */
    aeTimeEvent *timeEventHead;
    int stop;
    void *apidata; /* This is used for polling API specific data */
    aeBeforeSleepProc *beforesleep;
    aeBeforeSleepProc *aftersleep;
} aeEventLoop;
```

可以看到事件类型分成了3种，file，fired和time Event。 `void *apidata`是和多路复用的api需要用到的数据，多一句嘴，void * data 这种定义就很像Java 中的Object。

关于 ae 先了解到这里，更多的细节通过后续的其他模块来了解。到这里就知道了整个redis server是靠一个事件队列来驱动工作的。

## server 模块
主要是指 server.h 和 server.c 两个文件。在头文件中定义了
> extern struct redisServer server;

`struct redisServer` 是个好复杂的结构体，300多个field，好奇编码的时候是怎么记住这些的。
从`initServer()`这个函数入手吧，看下server是怎么初始化的？

除了初始化 server 结构体的成员变量之外，监听tcp 读那口也是在initServer 函数中，创建全局共享对象，调整打开文件限制的数量。创建主 Event Loop。
redis 支持多数据库，数据库由数字编号，每个数据库有自己的内部状态。下面是初始化数据库内部状态的代码。
```c
/* Create the Redis databases, and initialize other internal state. */
    for (j = 0; j < server.dbnum; j++) {
        server.db[j].dict = dictCreate(&dbDictType,NULL);
        server.db[j].expires = dictCreate(&keyptrDictType,NULL);
        server.db[j].blocking_keys = dictCreate(&keylistDictType,NULL);
        server.db[j].ready_keys = dictCreate(&objectKeyPointerValueDictType,NULL);
        server.db[j].watched_keys = dictCreate(&keylistDictType,NULL);
        server.db[j].id = j;
        server.db[j].avg_ttl = 0;
        server.db[j].defrag_later = listCreate();
    }
```

顺藤摸瓜来看下 数据库db 的结构体
```c
/* Redis database representation. There are multiple databases identified
 * by integers from 0 (the default database) up to the max configured
 * database. The database number is the 'id' field in the structure. */
typedef struct redisDb {
    dict *dict;                 /* The keyspace for this DB */
    dict *expires;              /* Timeout of keys with a timeout set */
    dict *blocking_keys;        /* Keys with clients waiting for data (BLPOP)*/
    dict *ready_keys;           /* Blocked keys that received a PUSH */
    dict *watched_keys;         /* WATCHED keys for MULTI/EXEC CAS */
    int id;                     /* Database ID */
    long long avg_ttl;          /* Average TTL, just for stats */
    list *defrag_later;         /* List of key names to attempt to defrag one by one, gradually. */
} redisDb;
```
从comment不难猜测，如果指定了一个key的过期时间，那么这个key就会被驾到 expires 字段中去，以便后续的expire检查。除此之外，redis 还维护了阻塞队列的key，被观察的key。注意 dict 类型，这是redis自己写的HashMap，后续还要研究一下。

接下来就可以看到和Event Loop 配合工作的代码了。
```c
/* Create the timer callback, this is our way to process many background
     * operations incrementally, like clients timeout, eviction of unaccessed
     * expired keys and so forth. */
    if (aeCreateTimeEvent(server.el, 1, serverCron, NULL, NULL) == AE_ERR) {
        serverPanic("Can't create event loop timers.");
        exit(1);
    }

    /* Create an event handler for accepting new connections in TCP and Unix
     * domain sockets. */
    for (j = 0; j < server.ipfd_count; j++) {
        if (aeCreateFileEvent(server.el, server.ipfd[j], AE_READABLE,
            acceptTcpHandler,NULL) == AE_ERR)
            {
                serverPanic(
                    "Unrecoverable error creating server.ipfd file event.");
            }
    }
```
先来看下`aeCreateTimeEvent`  第一个参数Event Loop，第二个参数是fd，这里传入是1是标准输出，然后serverCron 就是时间到了之后的处理函数。看到了serverCron 函数之后，server结构体里有个字段hz，没错就赫兹的意思，表示频率，什么频率呢？serverCron 函数的运行频率。
啊，好复杂，server的代码会涉及到其他模块，如果对其他模块不了解的话就会像我一样看哭的了，so，Let's from bottom to top。
