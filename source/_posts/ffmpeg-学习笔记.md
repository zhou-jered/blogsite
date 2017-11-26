---
title: ffmpeg 学习笔记
date: 2017-11-26 10:05:57
tags:
	- ffmpeg
	- video
	- Note
---
用法：
> ffmpeg [global_options] {[input_file_options] -i input_url} ... {[output_file_options] output_url} ...
这里{}表示花括号中间的内容必须选择一项。

ffmpeg 可以从任意数量的文件中读取数据（这些文件可以是普通文件，pipe，网络流，物理设备等），通过参数`-i` 来指定输入文件。可以写入到任意的文件中去，输出文件的指定不需要参数，命令行中不能解析成为参数的部分就当作输出文件的url来看待。
为了在命令行参数中引用输入文件，你必须通过数字索引（从0开始）来指定，第一个文件是`0`，第二个文件是`1`，类似的，文件中的流也是通过数字索引来指定的，比如`2:3`引用了第三个输入文件的第四个流。在流引用章节有更详细的描述。
一个通用的规则是，参数都是引用到接下来的文件中的，所以，参数的顺序很重要。但是全局参数（global options）作用在全局，不是单个文件。


## 细节
ffmpeg的转码工作流程如下所示：
 _______              ______________
|       |            |              |
| input |  demuxer   | encoded data |   decoder
| file  | ---------> | packets      | -----+
|_______|            |______________|      |
                                           v
                                       _________
                                      |         |
                                      | decoded |
                                      | frames  |
                                      |_________|
 ________             ______________       |
|        |           |              |      |
| output | <-------- | encoded data | <----+
| file   |   muxer   | packets      |   encoder
|________|           |______________|

先解码，再重新编码。

### filtering  转换
编码之前，ffmpeg使用来自libavfilter library的filters来处理转换视频和音频帧，多个filter组成filter graph，ffmpeg区分 `简单`和 `复杂`的两种filter graph。

#### 简单 filter graph
只有一个输入和输出的filter graph叫做简单filter graph
 _________                        ______________
|         |                      |              |
| decoded |                      | encoded data |
| frames  |\                   _ | packets      |
|_________| \                  /||______________|
             \   __________   /
  simple     _\||          | /  encoder
  filtergraph   | filtered |/
                | frames   |
                |__________|
简单fg通过参数 -vf 或者 -af 来配置，分别配置video或者audio
 _______        _____________        _______        ________
|       |      |             |      |       |      |        |
| input | ---> | deinterlace | ---> | scale | ---> | output |
|_______|      |_____________|      |_______|      |________|

#### 复杂 filter graph
不能被简单的链式线性处理的单一流叫做复杂filter graph，比如下图有多个的输入和输出，而且类型还不一样
 _________
|         |
| input 0 |\                    __________
|_________| \                  |          |
             \   _________    /| output 0 |
              \ |         |  / |__________|
 _________     \| complex | /
|         |     |         |/
| input 1 |---->| filter  |\
|_________|     |         | \   __________
               /| graph   |  \ |          |
              / |         |   \| output 1 |
 _________   /  |_________|    |__________|
|         | /
| input 2 |/
|_________|

复杂fg通过 -filter_complex 参数来指定，注意这个参数是全局参数，这是由于复杂fg不单一指定输入输入流或文件来决定的。
参数 -lavfi 等同于参数 -filter_complex

### 复制流
复制流是参数 -codec的一个选项，令ffmpeg省略掉解码和编码的步骤，所以这ffmpeg会快很多，在改变container 格式和container-level metadata的时候会很有用，这是ffmpeg的工作流程就变成来下图所示
 _______              ______________            ________
|       |            |              |          |        |
| input |  demuxer   | encoded data |  muxer   | output |
| file  | ---------> | packets      | -------> | file   |
|_______|            |______________|          |________|

 这种模式会由于多种原因不可用，显然，这种模式下是不能使用任何filter的。filter的工作在解码之后的数据上。

## 数据流的选择
默认情况下，ffmpeg在输出文件中仅包含输出文件中每种数据类型（视频，音频，字幕）的一条数据流，根据解析度，channel数，出现次序来选择包含进输出文件的中流。

# 参数:

