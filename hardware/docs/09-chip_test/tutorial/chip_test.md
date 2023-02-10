# Task List
- 2.17前，HLS实现读写DDR到FIFO或Memory(例如BRAM)
- 3.15前，实现PS读写PC数据到DDR（一次成功读写即可）

# 功能陈述
- 从PC读写数据到FPGA的FMC端口（通用引脚）
- 方案1
    - FPGA的PS从外设UART(串口)或SD卡或网口读数据后，写入外设DDR
    - HLS或verilog（PL端口）通过AXI读到DDR的数据到FMC端口（通用引脚）
- 方案2
    - PC传数据到FPGA的外设（串口、SD卡或网口），DDR， 和PL端的FMC，视为FPGA的PS三个外设
    - 通过对PS嵌入式编程，实现PS把PC的数据搬运到DDR和PL端的FMC
# 参考教程
- B站、Youtube等搜索
- tutorial文件夹有VC707（FPGA开发板）和Vivado资料
- 视频现成项目教学：[正点原子-手把手教你学FPGA视频](https://www.bilibili.com/video/BV19A411N7L3/)
- 小项目
    - [zedboard如何从PL端控制DDR读写(五)](https://www.cnblogs.com/christsong/p/5689283.html)
    - [用PS控制DDR3内存读写](https://www.cnblogs.com/geekite/p/5570796.html)
    - [zedboard通过BRAM实现PS和PL的简单通信](https://www.cnblogs.com/wangdaling/p/9912014.html)
        - [PS与PL内部寄存器通信](https://blog.csdn.net/wordwarwordwar/article/details/80841565)
    - [BRAM DDR DSP资源使用](https://www.jianshu.com/p/4ce255f2735e)
    - 网口：
        - 参考资料：B站正点原子+代码