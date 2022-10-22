# 借助ffmpeg + wasm实现网页截取视频帧以及提取语音功能

## 下载FFmpeg源码
git clone --depth 1 --branch n4.3.1 https://github.com/FFmpeg/FFmpeg 

./configure --disable-x86asm

make -j

./ffmpeg

## 自定义编译ffmpeg
```sh
emconfigure ./configure --cc="emcc" --cxx="em++"  --ar="emar" --ranlib=emranlib --prefix=$(pwd)/dist --cpu=generic \
--target-os=none --arch=x86_32  --enable-cross-compile --disable-stripping --disable-programs --disable-doc --disable-devices --disable-postproc --disable-hwaccels --disable-parsers --disable-bsfs --disable-protocols --disable-indevs --disable-outdevs --disable-network --disable-asm --disable-debug  --enable-protocol=file
```
## make
```sh
emmake make -j
```
成功后

```sh
make install
```
这里会生成dist文件，内部包含我们需要使用的文件以及头文件，为了方便后续操作，我们可以将头文件include和lib下的a文件拷贝到我们需要使用的项目目录下。

## 编译输出wasm
```sh
em++ -O3 src/extract.cpp  -I ./include lib/libavformat.a lib/libavcodec.a lib/libswscale.a lib/libswresample.a lib/libavutil.a -lworkerfs.js --pre-js src/worker.js -s WASM=1 -o dist/extract.js -s EXTRA_EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' -s EXPORTED_FUNCTIONS='["_main", "_destroy", "_extract_image","_extract_audio"]' -s ALLOW_MEMORY_GROWTH=1  -s TOTAL_MEMORY=33554432
```
注意上面的.a文件顺序不能颠倒，被依赖的文件要往后放.

执行完之后会在wasm/dist中生成三个文件:
```
extract.js		extract.wasm
```


## 在html引入
### src/worker.js
这是worker核心代码，在Emscripten 编译出来的代码中包含胶水代码和 wasm 文件两部分，胶水代码可以通过合并编译的方式来直接打包到 Web Worker 的代码中。只需要```-lworkerfs.js --pre-js worker.js```



## 从头开始

新闻创作者平台是一个为创作者、媒体、机构提供内容创作， 视频上传， 图片处理等工具平台。



平台开发过程中会遇到视频相关数据的提取等，为了更快的得到视频相关数据，前端需要在不依赖视频上传结束之后才能从后端返回视频的相关数据，所以需要快速的从本地视频抽取相关数据。FFmpeg是一个用C语言开发的用来记录、转换数字音频、视频，并能将其转化为流的开源计算机程序，前端可以通过emscripten将其编译成可执行的wasm，快速提取视频相关数据。

一，前期准备：
1，安装Emscripten
Emscripten可以将C/C++ 之类的语言编写模块来将它编译到 WebAssembly。

按照下面链接的说明下载并安装

https://emscripten.org/docs/getting_started/downloads.html#download-and-install

# Fetch the latest version of the emsdk (not needed the first time you clone)
git pull

# Download and install the latest SDK tools.
./emsdk install latest

# Make the "latest" SDK "active" for the current user. (writes .emscripten file)
./emsdk activate latest

# Activate PATH and other environment variables in the current terminal
source ./emsdk_env.sh
 然后可以通过 emcc -v 或者em++ -v查看一下是否安装成功以及按照的版本



2，ffmpeg下载
https://ffmpeg.org/download.html 这里可以下载很多版本的ffmpeg包， 我这里下载了4.1.9的包，不同版本的包在编译时的选项可能会稍有不同， 在后边编译时可根据提示情况进行修改。

二，ffmpeg编译
一开始我希望我编译的ffmpeg能够像执行命令行的方式直接执行程序， 这样我在前端使用的时候会比较方便，像下面这样使用

```
ffmpeg.run('-i', file.name, '-vn', '-acodec', 'copy', 'video.aac')
```;
 但是这种方式有比较明显的两个弊端：

编译出来的包会比较大
- 编译出来的包在使用时使用了SharedArrayBuffer，在目前的浏览器中都需要特殊处理，
- 2017.7月（Chrome 60）引入 SharedArrayBuffer。2021.7月（Chrome 92）限制 SharedArrayBuffer只能在 cross-origin isolated 页面使用。在其他浏览器中的支持也不是十分理想。

最终采用的方式是通过写C++代码，在C++里面把功能实现了，最后再暴露一个接口给JS使用，这样JS和WASM只需要通过一个接口API进行通信。

1）configure
```sh
emconfigure ./configure \
--cc="emcc" \
--cxx="em++" \
--ar="emar" \
--ranlib=emranlib \
--prefix=$(pwd)/dist --cpu=generic \
--target-os=none \
--arch=x86_32  \
--enable-cross-compile \
--disable-logging \
--disable-programs \
--disable-ffmpeg \
--disable-ffplay \
--disable-ffprobe \
--disable-doc \
--disable-devices \
--disable-postproc \
--disable-hwaccels \
--disable-parsers \
--disable-bsfs \
--disable-protocols \
--disable-avfilter \
--disable-pthreads \
--disable-w32threads \
--disable-os2threads \
--disable-indevs \
--disable-outdevs \
--disable-network \
--disable-asm \
--disable-debug  \
--enable-protocol=file
```
 2）构建
```sh
emmake make -j4


# 如果出现错误 可以参看这里的文章 https://zhuanlan.zhihu.com/p/40786748
# 查看 生成编译文件的时候 --ranlib=emranlib 

# 安装ffmpeg及相关lib到指定目录
make install 
# 可以看到dist目录
```

3）编写C++代码
Emscripten支持虚拟文件系统, 具体查看https://emscripten.org/docs/api_reference/Filesystem-API.html， 这里采用的是WORKERFS： 这个文件系统提供了对worker内部的file和Blob对象的只读访问，而不需要将整个数据复制到内存中，并且可以用于巨大的文件。非常适用于在实际的浏览器端处理的项目中，不会造成内存过大浏览器崩溃的问题。

3）-1. 抽取视频中的语音数据
将视频文件通过内存传递给C++处理， C++接收到文件后，调用ffmpeg库进行处理，最后我们将提取的音频数据返回
```cpp
uint8_t *extract_audio(char *path, uint32_t *len)
{
  AVFormatContext *pFormatCtx = NULL;
//查找音频流
  int audioStream = av_find_best_stream(pFormatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);

AVCodecContext *pCodecCtx = pFormatCtx->streams[audioStream]->codec;

AVPacket packet;                  //数据包
std::vector<AudioData> audio_vec; //创建缓存容器
uint32_t totalsize = 0;           //总音频数据量

//解析音频
  while (av_read_frame(pFormatCtx, &packet) >= 0)
  {
    if (packet.stream_index == audioStream) //如果为音频标志
    {
      AudioData audio;
      audio.len = packet.size + 7; //加上acc的7个字节头
      totalsize += audio.len;      //数据总量
      audio.data = (uint8_t *)av_malloc(audio.len);
      //添加acc头
      addHeader((char *)audio.data, packet.size, pCodecCtx->profile, pCodecCtx->sample_rate, pCodecCtx->channels); ////添加acc数据
      //添加音源
      memcpy(audio.data + 7, packet.data, packet.size);
      audio_vec.push_back(audio);
    }
    //释放数据包
    av_packet_unref(&packet);
  }

  uint8_t *out_buf = (uint8_t *)malloc(totalsize);
  uint32_t currindex = 0;
  for (size_t i = 0; i < audio_vec.size(); i++)
  {
    AudioData &audio = audio_vec[i];
    memcpy(out_buf + currindex, audio.data, audio.len);
    currindex += audio.len;
    av_free(audio.data);
  }
  *len = totalsize;
  //内存清理
  std::vector<AudioData>().swap(audio_vec);
  avcodec_close(pCodecCtx);
  avformat_close_input(&pFormatCtx);
  return out_buf;
}
```
需要传递两个参数，一个是文件内存地址， 一个是文件大小， 这里的文件大小我们先通过emscripten 申请一段内存地址：
```js
const len = Module._malloc(8); // uint64_t
```
 在c++中直接赋值，由于在c++中赋值是该地址对应的int32值，由于Module.HEAP32每个元素占用4字节，因此int_ptr需除以4（既右移2位）方为正确的索引。
```js
const realLen = Module.HEAPU32[len / 4];
```
 最后取到音频的buffer数据：
```js
let audioBuffer = Module.HEAPU8.slice(audioDataPtr, audioDataPtr + realLen)
```



需要注意的是在音频逐帧数据的抽取需要添加aac头， 否则获取的音频数据无法播放。



3）-2. 抽取视频中的画面数据
抽取视频画面的逻辑大体和抽取音频数据的逻辑差不多，大体如下，网上能找到很多相关的资料， 这里不再重述。

// 图片数据结构
```cpp
typedef struct
{
  uint32_t width;
  uint32_t height;
  uint32_t duration;
  uint8_t *data;
} ImageData;


ImageData *extract_image(int ms, char *path) 
{
...
return imageData
}
```
4）编写胶水代码调用
将C导出函数可以按cwrap方式进行封装,方便调用
```js
Module.cwrap('extract_audio', 'number', ['string', 'number'])
```
基本格式如：
```js
var func = Module.cwrap(ident, returnType, argTypes);
```
参数：

- ident ：C导出函数的函数名（不含“_”下划线前缀）；
- returnType ：C导出函数的返回值类型，可以为'boolean'、'number'、'string'、'null'，分别表示函数返回值为布尔值、数值、字符串、无返回值；
- argTypes ：C导出函数的参数类型的数组。参数类型可以为'number'、'string'、'array'，分别代表数值、字符串、数组；
 这里需要注意的是就是后边我们编译的时候需要导出
```
EXPORTED_FUNCTIONS='["_main", "_destroy", "_extract_image","_extract_audio"]'
```
 另外，如果是c++的代码的话，需要declare 导出的方法名(否则在编译的时候会报错找不到这些方法名)：
```cpp
// Declare this so it's exported as non-mangled symbol "_extract_image", "_extract_audio", "_destroy"
extern "C"
{
  
  ImageData *extract_image(int ms, char *path);
  uint8_t *extract_audio(char *path, uint32_t *len);
  void destroy(uint8_t *p);
}
```
三，编译为wasm


上面的都准备完毕后 我们只需要编译
```sh
em++ -O3 src/extract.cpp  -I ./include lib/libavformat.a lib/libavcodec.a lib/libswscale.a lib/libswresample.a lib/libavutil.a \
-lworkerfs.js \
--pre-js src/worker.js \
-s WASM=1 -o dist/extract.js \
-s EXTRA_EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' \
-s EXPORTED_FUNCTIONS='["_main", "_destroy", "_extract_image","_extract_audio"]' \
-s ALLOW_MEMORY_GROWTH=1  \
-s TOTAL_MEMORY=33554432
```
- -O3:   编译优化，官网推荐生产环境使用该配置；具体O1,O2,O3 ... 等的区别看这里https://emscripten.org/docs/tools_reference/emcc.html#emccdoc

- -lworkerfs.js: 提供了对worker内部的file和Blob对象的只读访问, 注意只能在worker中使用

- ExPORTED_FUNCTIONS: 导出的方法名， 需要注意方法名前面需要加上下划线

四，前端接收数据使用
在worker中我们获取到buffer数据，剩下的就是将buffer转为我们可以使用的数据，但在实际项目中往往会遇到使用者同时上传多个视频的情况，而worker和js主线程之间又是通过postMessage的方式传递数据的，那么多个视频提取数据要是能够做到一一对应的方式，包装一个WorkerManager
```js
function createWorker() {
  const extractWorker = new Worker('../dist/extract.js');
  return extractWorker;
}

class WorkerManager {
  constructor(worker) {
    this.callbacks = {};
    this.worker = worker;
    this.worker.onmessage = e => {
      const { id, data, } = e.data;
      this.callbacks[id]?.call(this, data);
      delete this.callbacks[id];
    };
  }
  postMessage(action, callback) {
    const id = WorkerManager.msgId++;
    this.worker.postMessage(Object.assign({ id, }, action));
    this.callbacks[id] = callback;
  }
}
WorkerManager.msgId = 1;

const extractWorker = new WorkerManager(createWorker());
```
 五，补充
再补充一下视频提取音频的方式：纯前端实现：

offlineAudioContext
offlineAudioContext这个API可以实现纯前端视频转音频，从我本地的测试效果来个各个浏览器都可以兼容，并且提取的速度也不逊于文中上述的ffmpeg+wasm的方式。但是如果你想做更多的音频数据处理还是得用上述ffmpeg+wasm的方式。


六，编译过程中的常见问题
1. error: Resource temporarily unavailable
编译线程限制，可以将`emmake make -j` 改为 `emmake make`试试；




