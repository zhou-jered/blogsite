---
title: drools 学习笔记
date: 2018-05-11 19:30:02
tags:
	- Notes
	- Drools
---

Drools是一个规则引擎，属于KIE项目下面的一个子工程，KIE，Knowledge Is Everything。
KIE是一套业务管理和自动化的一条龙系统，包含以下的子工程。
- Drools 规则引擎，可以基于这个系统构建出复杂的基于规则的系统。
- jBPM 流程引擎
- OptaPlanner 规约解决方案。
- DRools WorkBench 规则的web可视化系统
- UberFire 基于web的workbench framework， 我也不知道这是个啥。

## Forward Chaining & Backward Chaining
实现生产规则系统有两种模型，前向链和后向链，两种模型都实现的系统叫做Hybrid Production Rule System，混合动力生产系统。

### Forward Chaining
实现前向链模型的规则系统由数据驱动，数据进入引擎后会触发任意数量的规则匹配，然后由Agenda来决定规则动作的执行顺序，从数据开始，得到关于这个数据的结论，这就叫做前向链。Drools 是基于前向链的规则引擎。
![Forward Chaining](/images/drools/Forward_Chaining.png)

### Backward Chaining
后向链是基于目标驱动的模型，从引擎尝试满足的结论出发，如果不能满足，就搜索能满足的结论，叫做子结论，这些子结论能够满足当前结论的某一部分，一直重复直到出事结论能够满足或者没有更多的子结论来验证。ProLog 是一个后向链引擎的例子。
![Backward Chaining](/images/drools/Backward_Chaining.png)


## Drools 无状态规则session
无状态规则session是Drools里最简单的use case，和方法的使用类似，传入数据，接收结果。一些用法如下：
- 验证
- 计算
- 路由和过滤

假设我们有下面这个对象
```java
public class Applicat {
	private String name;
	private int age;
	private boolean valid;
}
```
下面规则，如果这个对象的年龄小于18岁，那么就设置valid为false
```java
rule "Is of valid age"
when
	$a : Applicant(age <18)
then 
	$a.setValid(false)
end
```
首先要把数据传入到引擎里面，当数据被传入到引擎中时，引擎就会采取恰当的规则来处理数据，在上面这个规则里面，有两个条件需要被满足，第一个是对象的类型是*Applicant*，第二个是对象的年龄小于18岁。在这里$a绑定了条件匹配的对象，$不是必须的。

.drl 的格式是drools的规则文件，放在工程的资源文件夹里面就可以了。
Drools还需要使用一个叫做kmodule.xml的配置文件，但是由于配置都有默认值，所以这个文件可以是下面的形式：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<kmodule xmlns="http://www.drools.org/xsd/kmodule" />
```
现在可以从classpath读取文件来构建一个KieContainer
```java
KieServices kieServices = KieServices.Factory.get()
KieContainer kContainer = kieServices.getKieClasspathContainer()
```
上面这段代码会编译drl，然后可以从Container中获取session，session中包含了已经编译好的规则，可以用来处理数据。
 ```java
StatelessKieSession kSession = kContainer.newStatelessKieSession()
Applicant applicant = new Applicant("Mr Smith", 16);
assertTrue(applicant.isValid());
kSession.execute(applicant);
assertFalse(applicant.isValid())
```
除此之外，还可以一次性处理多个对象，execute方法除了可以传入单个对象，还可以传入Iterator，上面说过对象的类型也是一个条件，所以会按照对象类型去匹配不同的规则。
下面是一个同时处理不同对象的例子。
```java
public class Application {
	private Date dataApplied;
	private boolean valid;
}
```
```java
rule "is Valid age"
when 
	Applicant (age <18 )
	$a : Application()
then 
	$a.setValid(false);
end

rule "Application was made this year"
when 
	$a : Application(dataApplied > '2018-01-01')
then
	$a.setValid(false);
end
```
```java
StatelessKieSession kSession = kContainer.newStatelessKieSession();
Applicant applicant = new Applicant("Mr Smith", 16)
Application application = new Application();
assertTrue(application.isValid());
kSession.execute(Arrays.asList(new Object[]{applicant, application}));
assertFalse(applicaiton.isValid());
```
还可以借助KieCommand来传入数据。
```java
kSession.execute(kieServices.getCommands()
.newInsertElements(Arrays.asList(new Object[]{application, applicant})));
```

此外还可以批量执行处理
```kava
KieCommands kieCommands = kieServices.getCommands();
List<Command> cmds = new ArrayList<Command>();
cmds.add(kieCommands.newInsert(new Person("Smith"), "MrSmith", true, null));
cmds.add(kieCommands.newInsert(new Person("John"), "MrJohn", true, null));
BatchExecutionResults  results = kSession.execute(kieCommands.newBatchExecutions(cmds));
assertEquals(new Person("Smith"), results.getValue("MrSmith"));
```

## 有状态的session
和无状态的session相比，有状态的session使用完后必须调用`dispose`方法来避免内存泄漏。`KieSession` Api返回的就是有状态的session，有状态的session不会主动去验证规则，需要调用`FirAllRules`方法。
下面是例子，假设有以下的对象
```java
public class Room {
	private String name
}
public class Sprinkler {
	Room room;
	boolean on;
}
public class Fire {
	Room room;
}
```
这个例子的情景是模拟房间起火，灭火喷头自动工作。
下面写一个当房间起火，喷头没有开启的话，就打开灭火喷头的规则
```java
rule "when there is a fire turn the sprinkler"
when 
	Fire($room : room)
	$sprinkler : Sprinkler(room == $room, on == false)
then 
	modify($sprinkler){setOn(true)};
	System.out.println("Ture on the sprinkler for roomo: "+ $room.getName());
end
```
和无状态的规则直接修改对象不同，这里使用`modify`语句，相当于with，这是由于引擎需要知道对象的状态变化来适用其他规则。重点！

到现在位置都是基于数据存在的判断，如果判断数据不存在？关键字`not`可以匹配数据不存在的情况。下面的规则是当火情不存在的情况下关闭喷头。
```java
rule "when the fire is gone turn off the sprinkler"
when 
	$room : Room()
	$sprinkler : $Sprinkler(room == $room, on == true)
	not Fire(room == $room)
then 
	modify($sprinkler) {setOn(false)};
	Ssytem.out.println("Trun off the sprinkler for room" + $room.getName());
end
```

下面引入警报器来丰富场景，一个房间有一个喷头，但是一栋楼里面只有一个警报器，无论多少个房间着火，都只能想一个警报器，前面的`not`来匹配数据缺失的情况，现在因为另外一个关键字`exists`来判断数据的存在情况，无论多少个。

```java
rule "Raise the alarm when we have one or more fires"
when 
	exists Fire()
then 
	insert(new Alarm());
	System.out.println("raise the alarm");
end
```

同样的，火情消失的时候，需要关闭警报器
```java
rule "Cancel the alarm when all the fires have gone"
when
	not Fire()
	$alarm : Alarm()
then
	delete($alarm)
	System.out.println("Cancel the alarm");
end
```
上述的规则应该写在同一个.drl规则文件中。然后就可以不停的往session中插入数据，然后调用`fireAllRules`方法来触发规则判断。

### 叉积问题
还是上面的场景，假设有下面的规则。
```java
rule "Show Sprinklers" when
    $room : Room()
    $sprinkler : Sprinkler()
then
    System.out.println( "room:" + $room.getName() +
                        " sprinkler:" + $sprinkler.getRoom().getName() );
end
```
从SQL的角度来说，规则相当于于`select * from Room, Spinkler`，然后会得到下面的输出。
```
room:office sprinkler:office
room:office sprinkler:kitchen
room:office sprinkler:livingroom
room:office sprinkler:bedroom
room:kitchen sprinkler:office
room:kitchen sprinkler:kitchen
....
```
这样的规则会导致结果集过大从而导致性能问题，应该像下面这样写
```
rule
when
    $room : Room()
    $sprinkler : Sprinkler( room == $room )
then
    System.out.println( "room:" + $room.getName() +
                        " sprinkler:" + $sprinkler.getRoom().getName() );
end
```
这样写的效果相当于SQL `select * from Room, Sprinkler where Room==Sprinkler.room`

## 执行控制
### Agenda
Agenda维护规则的执行。当同时有个规则匹配的时候，Agenda使用解决冲突的策略来决定规则的执行顺序。
引擎不停的重复两个阶段
+ Rule Runtime Actions。规则的判定过程
+ Agenda Evaluation。 规则选取过程

目前为止的例子都还比较简单，下面引入的现金存取场景会有更加复杂的示例。
```java
class CashFlow {
	Date data;
	double amount;
	int type;
	long accountNo
}

class Account {
	long accountNo;
	double balance;
}

class AccountPeriod {
	Date start;
	Date end;
}
```
下面表格展示了账户的现金流动过程
<table>
<th>CashFlow</th>
<tr>
	<td> data </td>
	<td> amount </td>
	<td> type </td>
	<td> accountNo </td>
</tr>
<tr>
	<td> 1-12 </td>
	<td> 100 </td>
	<td> CREDUT </td>
	<td> 1 </td>
</tr>
<tr>
	<td> 2-2 </td>
	<td> 200 </td>
	<td> DEBIT </td>
	<td> 1 </td>
</tr>
<tr>
	<td> 3-18 </td>
	<td> 50 </td>
	<td> CREDIT </td>
	<td> 1 </td>
</tr>
<tr>
	<td> 5-9 </td>
	<td> 75</td>
	<td> CREDIT</td>
	<td> 1</td>
</tr>
</table>

<table>
	<th> Account </th>
	<tr>
		<td> accountNo  </td>
		<td> balance </td>
	</tr>
	<tr>
		<td> 1 </td>
		<td> 0 </td>
	</tr>
</table>

下面两个规则用来通过计算借贷来得到账户余额，请注意`&&`可以不用写field name 两次
```java
rule "increse balance for credits"
when
	ap : AccountPeriod()
	acc : Account( $accountNo : accountNo )
	CashFlow (type == CREDIT , accountNo == $accountNo, 
		date >= ap.start && <= ap.end,
		$amount : amount)
then
	acc.balance += $amount
end

rule "decrese balance for debits"
when
	ap : AccountPeriod()
	acc : Account($accountNo :accountNo)
	CashFlow (type == DEBIT, accountNo == $accountNo,
		date >= ap.start && <= ap.end,
		$amount : amount)
then
	acc.balance -= $amount
end
```
同样如果将这两条规则改写成SQL的话，相当于
```sql
select * from account acc, CashFlow cf, AccountPeriod ap
where acc.accountNo == cf.accountNo and
	cf.type == CREDIT and cf.date >= ap.start and cf.date <= ap.end

---

select * from Account acc, CashFlow cf, AccountPeriod ap
where acc.accountNo == cf.accountNo and
	cf.type ==DEBIT and cf.date >= ap.start and cf.date <= ap.end
```

trigger如下
```sql
acc.balance += cf.amount
acc.balance -= cf.amount
```

通过设置AccountPeriod时间周期来计算账户余额，如果将时间周期设置为1.1 到 3.31 第一个季度的话，现金流量表中将会有三条记录被规则匹配，规则会被执行三次，就目前来说，这三条规则的执行顺序是随机的，但是结果都是一样的，执行完之后账户的余额都是-25。

### 
如果你不想让规则随机执行的话，可以给规则一个`salience`值，这个值就是规则的优先级，默认值为0.
```java
rule "Print balance for AccountPeriod"
	salience -50
when 
	ap : AccountPeriod()
	acc : Account()
then 
	System.out.println(acc.accountNo + " : " + acc.balance)
end
```
这个规则会在所有的借贷规则计算完成之后，打印出账户余额，由于salience的默认值是0，设为-10，就会在默认规则之后执行。

### Agenda Group
Agenda group 允许你将多个规则归入到一个组别中，然后可以将这个Agenda Group放置到一个栈中，出栈入栈操作称为*setFocus*
```java
kSession.getAgenda().getAgendaGroup("Group A").setFocus()
```
agenda总是执行栈顶的规则组，栈顶的规则组执行完之后，出栈，继续执行下一个规则组。
```java
rule "increase balance for credits"
	agenda-group "calculation"
when
	ap : AccountPeriod()
	acc : Account($accountNo : accountNo)
	CashFlow(type ==CREDIT, accountNo == $accontNo,
		date >= ap.start && <= ap.end,
		$amount : amount)
then 
	acc.balance += $amount
end

rule "Print balance for AccountPeriod"
  agenda-group "report"
when
  ap : AccountPeriod()
  acc : Account()
then
  System.out.println( acc.accountNo +
                      " : " + acc.balance );
end
```

首先将report入栈，然后将calculation入栈，就可以得到我们想要的先计算在report的操作，入栈通过`setFocus`来完成
```java
Agenda agenda = kSession.getAgenda();
agenda.getAgendaGroup("reporty").setFocus();
agenda.getAgendagroup("calculation").setFocus();
kSession.firAllRules();
```

