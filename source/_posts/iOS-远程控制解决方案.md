---
title: iOS 远程控制解决方案
date: 2017-09-03 10:31:20
tags:
	- iOS
	- remote control
---

因为新开发的测试平台有在网页上远程控制iPhone的需求，屏幕投影可以用IOS-Minicap 来做，远程控制动作的话，没有现成的东西，找了很多资料，除了官方提供的XCTest之外，发现Facebook开发了一个WebDriverAgent的东西，开源在了github上，逛了一圈论坛，发现大家都在用这个，自己试了一下之后发现手机控制动作的延时很大，基本都有一两秒左右，而且还有session限制，没法用，又继续找资料。发现了一个叫做  XCEventGenertor 的私有API，试了一下，相当的好用，延时几十个毫秒，基本可以忽略。支持单点触控，按压，多点触摸，pinch， rotate等多个动作事件，完整的API方法列表就在WebDriverAgent代码里。
下面是从别人的代码中记录的代码片段：
```Object-c
  private var sharedXCEventGenerator : XCEventGenerator {
        let generatorClass = unsafeBitCast(NSClassFromString("XCEventGenerator"), to: XCEventGenerator.Type.self)
        return generatorClass.sharedGenerator()
    }
@objc protocol XCEventGenerator {
    static func sharedGenerator() -> XCEventGenerator
    var generation:UInt64 {get set}

    @discardableResult func rotateInRect(_: CGRect, withRotation: CGFloat, velocity: CGFloat, orientation: UIDeviceOrientation, handler: @escaping () -> Void) -> CGFloat
    @discardableResult func pinchInRect(_: CGRect, withScale: CGFloat, velocity: CGFloat, orientation: UIDeviceOrientation, handler: @escaping() -> Void) -> CGFloat
    @discardableResult func pressAtPoint(_: CGPoint, forDuration: TimeInterval, lifeAtPoint: CGPoint, velocity: CGFloat, orientation: UIDeviceOrientation, name: AnyObject, handler: @escaping()-> Void) ->CGFloat
    @discardableResult func pressAtPoint(_: CGPoint, forDuration: TimeInterval, orientation: UIDeviceOrientation, handler : @escaping()->Void) -> CGFloat
    @discardableResult func tapAtTouchLocations(_:[CGPoint], numberOfTaps: UInt, orientation: UIDeviceOrientation, handler: @escaping()->Void) -> CGFloat
    @discardableResult func typeText(_:String) -> CGFloat

    init()

}
```
为了这个项目还学习了一波Object-C 和 Swift，Swift的烂生态让我蛋疼不已，也是心累。
因为要在网页上做远程控制，后期还有用户权限控制的需求，所以在网页端就打算使用WebSocket。在Mac上使用XCode创建一个测试Case，启动后在手机上监听一个端口，接收用户事件，WebScoket的服务端和手机用Socket 连上传递事件消息。等于是说在网页用户和手机之间多了一个WebSocket 服务器的角色。WebSocket 的服务器用Openresty配合Lua写的，这个还比较顺利。

在网页上检测用户动作事件的时候，要区分出，拖拽，点击，长按，目前还不支持多点事件，目前一个鼠标也没法多点触控，不过我想这个后期肯定也是要有的。
用Js来分别监听鼠标的down，up ， move事件。在down 和 up 事件的中间如果发生了move事件，那么就是一次滑动swipe事件，反之就是click事件，加上时间的记录可以区分出长按和点击时间。
下面的代码中，canvas是屏幕在网页上的投影canvas。
```Javascript
function bindControlEvent(canvas, onClick, onSwipe) {
  var mouseDown = false
  var moveed = false
  var from, to
  function onMouseDown(e) {
    mouseDown = true
    from = {x: e.layerX, y:e.layerY}
  }
  function onMouseMove() {
    if(mouseDown && !moveed) {
      moveed = true
    }
  }
  function onMouseUp(e) {
    if(mouseDown && moveed) {
      to = {x: e.layerX, y: e.layerY}
      onSwipe(from, to)
    } else if(mouseDown && ! moveed) {
      onClick(e)
    }
    mouseDown = moveed = false
  }
  function onMouseLeave() {
    mouseDown = moveed = false

  }

  canvas.addEventListener("mousedown", onMouseDown)
  canvas.addEventListener("mousemove", onMouseMove)
  canvas.addEventListener("mouseup", onMouseUp)
  canvas.addEventListener("mouseleave", onMouseLeave)

}
```


