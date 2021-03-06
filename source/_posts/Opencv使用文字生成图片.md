---
title: Opencv使用文字生成图片
date: 2017-07-13 09:43:17
tags: 
- Opencv
- Image
- Fun
---


记得之前有人在网上说过，可以通过计算图片的像素块的灰度来实现使用Ascii字符模拟图片的效果，
最近花了两天试了一下，感觉还蛮好玩的。

原图片如下：
![Lena](/img/ascimg/lena.jpg)

初步的效果如下：
![lenagray](/img/ascimg/lenagray.png)

大致原理就是使用字符来模拟像素。

步骤：
	首先将单个的ascii字符写在一张图片上，然后计算这张图片的灰度值。
	读入原图像的灰度图
	然后用最接近像素灰度的字符模拟原图片

如果耿直的使用一个字符来模拟一个像素的话，额。。。屏幕不够大，看不了。
改进一下，一个字符模拟一个小的像素块，比如一个字符模拟一个2x2的像素块，这个小像素块的大小作为参数，可以调整。
在刚开始的测试实验中，如果小像素块是一个正方形的话，输出的文字图就会瘦高瘦高的，稍微变形。经过仔细观察发现字符本身就是瘦高瘦高的23333，发现一个字符模拟一个2x3， 或者5x7的矩形小像素块效果会比较好。


到这一步，生成的文字图效果也一般般，只能看到大概的轮廓。
=========
下面来思考一个改进的算法，目前的算法只能对像素块的灰度值进行模拟，能不能做到对小像素块形状的模拟呢？
opencv是有很多的图片匹配算法的，现在需要一个衡量两张图片匹配程度的算法。
这里使用了opencv 的ssim算法，结构性匹配检测，要求输入两张图片，并且两张图片的大小一致，简直完美符合我们的需求。
[SSIM Document](http://docs.opencv.org/3.2.0/dd/d3d/tutorial_gpu_basics_similarity.html)

这里使用了官网示例的一个方法 `getMSSIM()` ， 这个方法能返回一个0到1 之间的数字来代表两张图片的结构相似度，因为之前没有使用过，所以首先测试下不同数字之间的相似度。
参考下方代码链接里面的ssimtest.cpp
结果如下：
![](/img/ascimg/ssim0.png)![](/img/ascimg/ssim1.png)![](/img/ascimg/ssim2.png)![](/img/ascimg/ssim3.png)![](/img/ascimg/ssim4.png)
![](/img/ascimg/ssim5.png)![](/img/ascimg/ssim6.png)![](/img/ascimg/ssim7.png)![](/img/ascimg/ssim8.png)![](/img/ascimg/ssim9.png)

额，排版可能会丑一点，不过可以看到自己和自己的相似度为1 ，说明自己和自己会百分之百一样的。
最后的结构相似度匹配的版本是这样的。

模拟5x6像素块
![](/img/ascimg/lena56.png)

效果确实比直接模拟灰度要好一点

模拟6x8的像素块
![](/img/ascimg/lena68.png)

可以看到和直接灰度模拟出来的图像完全是两种不同的风格，总的来说，结构模拟的相似度要高一点，但是算法的速度要差一点，在同样的图片测试下，灰度模拟基本能在1秒以内完成，结构模拟由于计算量比较大，一张图需要一两分钟才能计算完成，如果对性能有要求的话，官网有使用gpu优化的文档。

代码：[Github](https://github.com/zhou-jered/AsciiImage)


