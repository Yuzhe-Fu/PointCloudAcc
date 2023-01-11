# 每个模块先图后代码优化，同时进行
硬件设计
    - 正解决
        - 图结合代码
            - KNN
            - POL
            - GLB
            - SYA

2. :white_check_mark:整体性能评估超过SOTA两倍，各个模块核数的确立
    - 总体带宽是否满足; 技术减少了多少访问量带宽
        - 每层FPS: 原本：读Nip*Crd+写Nop；现在：整个网络只读一次Nip+无写
        - 每层KNN：原本：读Nip*Crd+写Nip*Idx*K; 现在：现成的第一层的FPS的Nip就够了+写Nip*Idx*K(512*B*24=12kB可以存起来)
        - 每层MLP：
            - 原本：片上复用为0时：
                - 读act：Cin*Nip*K*(Nop/PE_Col)，
                - 读wgt: Cin*Nop*C，
                - 读Map：Nip*Idx*K; 
            - 现在：act片上复用+K复用：
                - 整个网络只读第一层act，
                - 每层wgt，
                - 每层Map（按照KNN存起来）


    - 三元二次方程：
        - 公式1：面积随MAC变化：    Area = FA*NBANK + BA;
        - 公式2：带宽随MAC变化：    BW   = FB*NBANK + BB; 带宽是指pad约束
        - 公式3：带宽随面积变化：   BW = FAB*$\sqrt{Area}$; 
            - x = NBANK; y = Area; z = BW
            - y = 0.17*x + 0.5; z = 20*x + 12; z = FAB*y^0.5
            - 师姐面积1.5x2.2=3.3， IO的是83，FAB=45.6, 则NBANK=1.3
                - 当IO加倍时，FAB=91.4, NBANK =4.55, Area=1.27, PAD = 103，刚好符合，优化其它部分
                    - 当GLB减半到0.25时，x = 3.67,y = 0.87, z = 85，面积减少显著

# 文件列表
| File | Descriptions |
| ---- | ---- |
| TOP.v | 顶层模块 |


# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| NUM_LAYER_WIDTH | 20 |  |  |
| ADDR_WIDTH | 16 |  |  |
| OPCODE_WIDTH | 3 | |  |
| IDX_WIDTH | 16 |   |  |
| CHN_WIDTH | 12 |   |  |
| SRAM_WIDTH | 256 | 256 | GLB宽度 |
| SRAM_WORD_ISA | 64 | 

# 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| I_SysRst_n            | input | 1 | 系统复位，代电平有效 |
| I_SysClk              | input | 1 | 系统时钟 |
| I_BypAsysnFIFO        | input | 1 | 不用接口的异步FIFO，直接与片外同步通信 |
| IO_Dat                | inout | PORT_WIDTH |  |
| IO_DatVld             | inout |
| OI_DatRdy             | inout |
| O_DatOE               | output| 输出pad方向，1。表示数据是向片外输出的，0表从片外输入，用来控制PAD的方向，同时告诉片外要准备好接收输出的数据了 |


# 模块描述
整个系统的顶层模块，
