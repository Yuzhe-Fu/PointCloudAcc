# 问题
- 各块点数不同，负载不均衡：点数相差2倍，FPS时间相差4倍
    - FPS和POL各核要求可独立配置，FPS和POL的请求信号CfgRdy太多怎么办？只有高的CfgRdy才输出(16+8=5bit)，不是每个周期都要输出，CfgRdy并转串
    
- 给所有模块加断言：
    - CCU的cfgrdy高了，cfgvld没拉高；CCU的ISA RAM满堵塞满了；
    - GLB的空满，同时读写
- SYA的4个PE_bank输出ofm怎么连GLB？

- 流片
    - 可靠性设计
        - 复位信号有问题：每个模块增加同步复位信号state或reset到所有寄存器；
        - 同步接口有问题：
            - pad转向时间：务必让每次传输都先state使得OE作用两倍时间，双向控制信号IO_DatVld，OI_DatRdy也需要OE提前控制PAD转向
            - 数据约束要统一且方便统一调相位；
        - 异步接口有问题再看？
        - 指令传输有问题：预设初始指令能默认模式跑。
        - 信号无高阻态不定态，位宽一致
    - 可测性设计

# 文件列表
| File | Descriptions |
| ---- | ---- |
| TOP.v | 顶层模块 |


# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
parameter CLOCK_PERIOD   = 10,

parameter PORT_WIDTH     = 128, // 是2的指数
parameter SRAM_WIDTH     = 256, // *NUM_BANK要满足最大带宽：SYA最多需要8*32*2+16*8*4=1024bit，
parameter SRAM_WORD      = 128, // GLB SRAM深度
parameter ADDR_WIDTH     = 16,  // GLB
parameter DRAM_ADDR_WIDTH= 32,  
parameter ISA_SRAM_WORD  = 64,
parameter ITF_NUM_RDPORT = 2,   // 目前只需要MAP和OFM输出到片外
parameter ITF_NUM_WRPORT = 6,   // ACT, WGT, OFM, CRD, MAP, ISA(CCU)
parameter GLB_NUM_RDPORT = 16,  // 11 + 5(POOL_CORE)
parameter GLB_NUM_WRPORT = 9, 
parameter MAXPAR         = 2,   // Max(ACT_WIDTH*POOL_COMP_CORE, ACT_WIDTH*NUM_ROW*NUM_BANK): 2，二者最大值 
parameter NUM_BANK       = 32,  //
parameter POOL_CORE      = 8,   // 2的指数
parameter POOL_COMP_CORE = 64,  // 2的指数
parameter NUM_FPC        = 8,   // 由FPS的Dist输入带宽决定上限，256/18/2=7.1个核，暂定为8个核并行。
CUT_MASK_WIDTH           = 32,  // FPS一次处理（截取的）多少个bit的Mask，为FPC核的4倍（向上取2的指数），（在一个SRAM带宽256的情况下）

// NetWork Parameters
parameter IDX_WIDTH      = 16,
parameter CHN_WIDTH      = 12,
parameter ACT_WIDTH      = 8,
parameter MAP_WIDTH      = 5,   // MAP Idx的表示，但CfgK位宽是MAP_WIDTH+1，表实际个数

parameter CRD_WIDTH      = 16,   
parameter CRD_DIM        = 3,   
parameter NUM_SORT_CORE  = 4,   // 数量是灵活调整的，但由于期望SRAM一次给所有KNN的Cp点赋初值，所以暂定10个核

parameter SYA_NUM_ROW    = 16,
parameter SYA_NUM_COL    = 16,  // 是正方形，必须等于SYA_NUM_ROW
parameter SYA_NUM_BANK   = 4,
parameter QNTSL_WIDTH    = 20,
parameter MASK_ADDR_WIDTH = $clog2(2**IDX_WIDTH*NUM_SORT_CORE/SRAM_WIDTH)



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
整个系统的顶层模块
执行策略
    - Loop
        - 从外到内是：分块-层-tile点/filter组（为实现mlp-pol的流水线，块先于层）

整体性能评估：excel表中，整体性能评估超过SOTA 13倍，各个模块核数的确立
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
