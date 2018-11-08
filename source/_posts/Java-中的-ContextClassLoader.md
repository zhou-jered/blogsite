---
title: Java 中的 ContextClassLoader
date: 2018-08-17 23:41:17
tags:
	- Java
	- ClassLoader
---

Java 中的Thread类中有个类型为ClassLoader的实例变量，`contextClassLoader`。

```java
 /* The context ClassLoader for this thread */
    private ClassLoader contextClassLoader;
```

Java 中的SPI机制的工作机制会涉及到这个ClassLoader，举个获取jdbc连接的例子。
```java
//  Worker method called by the public getConnection() methods.
    private static Connection getConnection(
        String url, java.util.Properties info, Class<?> caller) throws SQLException {
        /*
         * When callerCl is null, we should check the application's
         * (which is invoking this class indirectly)
         * classloader, so that the JDBC driver class outside rt.jar
         * can be loaded from here.
         */
        ClassLoader callerCL = caller != null ? caller.getClassLoader() : null;
        synchronized(DriverManager.class) {
            // synchronize loading of the correct classloader.
            if (callerCL == null) {
                callerCL = Thread.currentThread().getContextClassLoader();
            }
        }
.....   

        for(DriverInfo aDriver : registeredDrivers) {
            // If the caller does not have permission to load the driver then
            // skip it.
            if(isDriverAllowed(aDriver.driver, callerCL)) {
        ....
        ....
        ....
    }
```

代码`ClassLoader callerCL = caller != null ? caller.getClassLoader() : null;` 尝试获取一个ClassLoader，首先尝试caller的classLoader，如果caller的classloader为空，就使用currentThread的
contextClassLoader。java中，哪些类的classloader是null？jre中由Bootstrap Classloader加载的类。

如果caller的classloader为空，则使用 Thread.currentThread().getContextClassLoader() 作为驱动类的加载器。

代码`if(isDriverAllowed(aDriver.driver, callerCL))`的实现如下：
```java
private static boolean isDriverAllowed(Driver driver, ClassLoader classLoader) {
    boolean result = false;
    if(driver != null) {
        Class<?> aClass = null;
        try {
            aClass =  Class.forName(driver.getClass().getName(), true, classLoader);
        } catch (Exception ex) {
            result = false;
        }

         result = ( aClass == driver.getClass() ) ? true : false;
    }

    return result;
}   
```
就是判断加载器能不能加载驱动类，能的话尝试获取链接，成功之后就返回。
注意在这个加载过程中，并没有遵循java加载类机制中著名的双亲委派模型机制。

