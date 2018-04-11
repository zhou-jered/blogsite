---
title: Mybatis代码学习-会话篇
date: 2018-03-01 16:03:29
tags:
	- Note
	- Mybatis
---

Mybatis 里面，所有sql语句的执行，都是通过SqlSession来完成了，SqlSession定义了crud操作数据的一系列接口，还有对事务的回滚或提交，本地缓存的管理。

# SqlSession 的构建
先介绍一下Mybatis里面的Configuation 类，作为Mybatis的核心类之一，这个类存储了Mybatis的所有配置信息，除此之外意外，Configuration类还有一个重要的作用就是映射绑定Mapper接口与Sql语句。
假设有一个UserMapper接口来对User表进行操作
```Java
interface UserMapper {

	@Insert("insert into user(name, age) values (#{name}, #{age})")
    void addUser(User user);

    @Select("select * from user")
    List<User> getAllUser();

    @Select("select * from user where id=#{1}")
    User selectById(Integer id);

    @Delete("delete from user")
    int deleteAll();
}
```

我们首先定义了数据操作的接口，这里先称之为Mapper接口，并提供了Sql语句和与之对应的参数。Mybatis会提供了Mapper接口的代理类，并将方法的的执行实现为对应Sql语句的执行。

在完成Configuration的创建之后。可以像下面的代码这样拿到一个可执行的接口的代理类

```Java
	Configuration  configuration = initConfiguration();
	configuration.addMapper(UserMapper.class);
	SqlSession sqlSession = initSqlSessionWithConfiguration(configuration);
	UserMapper userMapper = configuration.getMapper(UserMapper.class, sqlSession);
	User firstUser = userMapper.selectById(1);
```

上面的代码只是为了表现Mapper接口是在通过Configuration类来实现和Sql语句的绑定的。然而是实际使用中，一般这样获取Mapper接口的代理类

```Java
	SqlSession sqlsession = initSqlsession();
	UserMapper userMapper = sqlsession.getMapper(UserMapper.class);
```

而实际上，对Mapper接口与Sql语句完成绑定操作是一个叫MapperRegistry的类来完成的，顾名思义，所有的Mapper接口都在这个类里面进行注册了。
在MapperRegitry的内部，由一个叫MapperAnnotationBuilder的类来完成对接口内函数的实现代理操作。

回到主题，SqlSession的构建需要依赖配置文件。对应配置文件的获取，可以写xml，然后利用XMLConfigBuilder类来完成Configuration的创建，也可以直接实例化Configuration类，然后利用setter来完成Configuration的配置。为了创建SqlSession，需要创建SqlSessionFactory，SqlSessionFactory又是使用SqlSessionFactoryBuilder创建的。所以可以使用以下代码来创建SqlSession
```Java
	SqlSessionFactory sqlSessionFactory = new SqlSessionFactoryBuilder().build(getConfiguration());
	SqlSession sqlSession = sqlSessionFactory.openSession();
```

可以简单的理解为一个SqlSession就是一个数据库连接，对于这个连接的比如说事物隔离级别，自动提交的配置项都是在调用openSession方法的时候来指定的。
```Java
public interface SqlSessionFactory {

  SqlSession openSession();

  SqlSession openSession(boolean autoCommit);
  SqlSession openSession(Connection connection);
  SqlSession openSession(TransactionIsolationLevel level);

  SqlSession openSession(ExecutorType execType);
  SqlSession openSession(ExecutorType execType, boolean autoCommit);
  SqlSession openSession(ExecutorType execType, TransactionIsolationLevel level);
  SqlSession openSession(ExecutorType execType, Connection connection);

  Configuration getConfiguration();

}
```
可以看到，还有一个叫做ExecutorType的参数。Executor可以单独写一篇了，后面再写。
Mybatis提供了SqlSessionFactory的实现，叫做DefaultSqlSessionFactory，这里面有两个核心的方法
```Java
private SqlSession openSessionFromDataSource(ExecutorType execType, TransactionIsolationLevel level, boolean autoCommit) 
private SqlSession openSessionFromConnection(ExecutorType execType, Connection connection) 
```
从名字上一个看出，一个从Datasource打开一个session，一个从connection打开一个session。其实就是connection的来源不一样，Mybatis提供了自己管理connection的机制。
如果不传入connection的话，就从datasource获取一个connection。虽然在openSession方法的时候可以传入connection，但是SqlSession并不会直接使用connection，Sqlsession内部使用的是Executor。

下面是从datasource打开Sqlsession的代码
```Java
  private SqlSession openSessionFromDataSource(ExecutorType execType, TransactionIsolationLevel level, boolean autoCommit) {
    Transaction tx = null;
    try {
      final Environment environment = configuration.getEnvironment();
      final TransactionFactory transactionFactory = getTransactionFactoryFromEnvironment(environment);
      tx = transactionFactory.newTransaction(environment.getDataSource(), level, autoCommit);
      final Executor executor = configuration.newExecutor(tx, execType);
      return new DefaultSqlSession(configuration, executor, autoCommit);
    } catch (Exception e) {
      closeTransaction(tx); // may have fetched a connection so lets call close()
      throw ExceptionFactory.wrapException("Error opening session.  Cause: " + e, e);
    } finally {
      ErrorContext.instance().reset();
    }
  }
```

# SqlSession
SqlSession是一个接口，提供了对数据的crud操作，清空缓存，事务回滚提交支持。
```Java
/**
 * The primary Java interface for working with MyBatis.
 * Through this interface you can execute commands, get mappers and manage transactions.
 *
 * @author Clinton Begin
 */
public interface SqlSession extends Closeable { 
	<T> T selectOne(String statement);
	<T> T selectOne(String statement, Object parameter);
	<E> List<E> selectList(String statement);
	<E> List<E> selectList(String statement, Object parameter);
	<E> List<E> selectList(String statement, Object parameter, RowBounds rowBounds);
	<K, V> Map<K, V> selectMap(String statement, String mapKey);
	void select(String statement, Object parameter, ResultHandler handler) 
	int insert(String statement);
  	int update(String statement, Object parameter);
	int delete(String statement);	
	void commit();
	void commit(boolean force);
  	void rollback();
	void rollback(boolean force);
	List<BatchResult> flushStatements();
	void clearCache();
	Configuration getConfiguration();
	<T> T getMapper(Class<T> type);
	Connection getConnection();
	。。。。。
}
```

还有一些重载的方法没有列出来，但是上面基本涵盖SqlSession提供的主要功能。同样的，Mybatis也对SqlSession提供了默认的实现DefaultSqlSession

```Java
public class DefaultSqlSession implements SqlSession {

  private final Configuration configuration;
  private final Executor executor;

  private final boolean autoCommit;
  private boolean dirty;
  private List<Cursor<?>> cursorList;

  public DefaultSqlSession(Configuration configuration, Executor executor, boolean autoCommit) {
    this.configuration = configuration;
    this.executor = executor;
    this.dirty = false;
    this.autoCommit = autoCommit;
  }
}
```	

可以看到，实现类中有exectuor和dirty，其中dirty在执行update操作的时候会被标记为true，表明此时的数据还没有提交到数据库里面，在执行commit或者rollback操作之后，dirty设置为false。
注意一下SqlSession里面有个select方法没有返回值，因为参数里面有个ResultHandler，这种机制给了开发者自己处理返回结果的机会，如果返回的类型处理不能满足自己的要求的话，就可以自己来处理结果。
```Java

public interface ResultHandler<T> {

  void handleResult(ResultContext<? extends T> resultContext);

}
```
Done


