---
title: 写几点关于bean copy
date: 2018-11-14 11:41:58
tags:
    - Java
    - Utils
    - Spring
---

在Java 里面，如果你想复制出一个对象来单独修改，或者在两个对象之间复制几个相同的字段，又不想写好几行setter和getter的话。可以用BeanUtils。

```java
BeanUtils.copyProperties(sourceObj, targetObj);
```

方法执行完之后，targetObj对象内和sourceObj相同的字段就有了相同的值。
copyProperties的完整签名是
```java
copyProperties(Object source, Object target, Class<?> editable, String... ignoreProperties)
```
其中editable参数是个Class 类型，表示读取editable 类的字段来进行复制，具体操作这样，读取editable的成员变量（字段），然后获取sourceObj的对该字段的readMethod 和 targetObj的writeMethod，判断兼容性（ ClassUtils.isAssignable()）之后，调用writeMethod进行复制。看到这里，就知道了这个方法是一个浅拷贝，在后续的打印toString()返回的对象地址 和 == 操作符判断中均验证了这个猜测。
关于editable这个参数有个限制，targetObj必须是一个editable的实例，换个说法，editable必须是targetObj的类或者其父类。
`ignoreProperties` 参数是一个不参与复制的字段列表。

说个这个类的优化，关于字段的读取，使用的是Java的BeanInfo类来获取PropertyDescriptor。大概是觉得这个方法比较慢，所以把类有哪些字段也就是相应的PropertyDescriptor数组缓存起来了。具体的缓存数据结构是ConcurrentMap，缓存分了两种类型`strongClassCache` 和 `softClassCache`。
```java
static final ConcurrentMap<Class<?>, CachedIntrospectionResults> strongClassCache = new ConcurrentHashMap(64);
static final ConcurrentMap<Class<?>, CachedIntrospectionResults> softClassCache = new ConcurrentReferenceHashMap(64);
```
可以看到 softClassCache 是一个ConcurrentReferenceHashMap类型的Map， 这个ConcurrentReferenceHashMap 是`org.springframework.util`包下的实现了`ConcurrentMap`接口的Map，支持soft ref和weak ref的并发Map，默认的引用类型是soft。Spring自己搞的这个Map还是挺6的。
转到strongClassCache和softClassCache上来看：
```java
if (!ClassUtils.isCacheSafe(beanClass, CachedIntrospectionResults.class.getClassLoader()) && !isClassLoaderAccepted(beanClass.getClassLoader())) {
    classCacheToUse = softClassCache;
} else {
    classCacheToUse = strongClassCache;
}

```
如果 *cacheSafe* 或者 *ClaassLoader Accepted* 就使用strongCache，否则使用softCache。
下面来看看这两个条件判断，首先是cacheSafe，方法签名如下：
```java
public static boolean isCacheSafe(Class<?> clazz, ClassLoader classLoader
```
里面的逻辑是：如果clazz是由Java的Bootstrap ClassLoader 加载的，或者是由参数 classLoader加载，或者是参数 classLoader的父加载器加载，返回true，否则false。
看到这里，只知道逻辑的话，好像也不知道为啥要这么做（答案在下面，嘻嘻）。

关于isClassLoaderAccepted的逻辑的话，就是判断传入的参数classLoader在不在预先设置的一个acceptedClassloader集合里面。
关于这个acceptedClassLoader 集合的设置，有个`public static void acceptClassLoader(ClassLoader classLoader)`方法，可以往这个集合里面添加ClassLoader，通过查找这个方法的显式调用者，在spring-web里面找到了下面的代码：
```java
public class IntrospectorCleanupListener implements ServletContextListener {

	@Override
	public void contextInitialized(ServletContextEvent event) {
		CachedIntrospectionResults.acceptClassLoader(Thread.currentThread().getContextClassLoader());
	}

	@Override
	public void contextDestroyed(ServletContextEvent event) {
		CachedIntrospectionResults.clearClassLoader(Thread.currentThread().getContextClassLoader());
		Introspector.flushCaches();
	}

}
```
看了下相关类的文档。大概就知道了在strongCache里面的缓存具备主动清理的能力，softCache里面的缓存就需要依赖gc相关的机制去清理。否则的话就会由于Spring App的生命周期的影响造成leak的风险。


##
写到这里，说的都是在 `org.springframework.beans`包下面的BeanUtils，不过如果你在IDE里面敲出BeanU....， 就会发现不止一个BeanUtils，而且也有copyProperties方法，下面来看下在`org.apache.commons.beanutils`包下面的BeanUtils。

Aapche的BeanUtils大概长下面这样子
```java
public void copyProperties(final Object dest, final Object orig)
        throws IllegalAccessException, InvocationTargetException {
 // Copy the properties, converting as necessary
        if (orig instanceof DynaBean) {
            ....
        } else if (orig instanceof Map) {
            ....
        } else /* if (orig is a standard JavaBean) */ {
            final PropertyDescriptor[] origDescriptors =
                getPropertyUtils().getPropertyDescriptors(orig);   //  有缓存
            for (PropertyDescriptor origDescriptor : origDescriptors) {
                final String name = origDescriptor.getName();
                if ("class".equals(name)) {
                    continue; // No point in trying to set an object's class
                }
                if (getPropertyUtils().isReadable(orig, name) &&
                    getPropertyUtils().isWriteable(dest, name)) {
                    try {
                        final Object value =
                            getPropertyUtils().getSimpleProperty(orig, name);
                        copyProperty(dest, name, value);
                    } catch (final NoSuchMethodException e) {
                        // Should not happen
                    }
                }
            }
        }
    }
```
首先可以确定的是，apache的拷贝也是浅拷贝，另外不支持ignoreProperties。它首先判断是是不是 DynaBean，看了下这玩意，文档说

> A DynaBean is a Java object that supports properties whose names and data types, as well as values, may be dynamically modified.

一个支持key和value同时动态变化的对象，不就是个map吗，你们apache真会玩。接下来判断是不是map，是的话就采取另外的复制策略。
否则的话就进行正常的字段复制操作。看了下PropertyDescriptor的缓存，使用的是apache自家的 `WeakFastHashMap`，使用weak ref。注意的是，它并不是ConcurrentMap。

关于Bean copy，大致就是这些吧。
学无止境。
