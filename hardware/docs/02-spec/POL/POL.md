# 问题
- 解决POL造成SYA阻塞的问题，固有的顺序问题，考虑SYA算下一个什么？:question:
- 减少通道到16，适用剪枝
- 增加读上层FPS输出的原始Idx组，来选哪些中心点需要算MP的
- 要减少pool的sram块数，预计到总共6块

# 文件列表
| File | Descriptions |
| ---- | ---- |
| POL.v | 顶层模块 |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| IDX_WIDTH | 16 | 16 | 点的index位宽 |
| ACT_WIDTH | 8 | 8 | act, wgt的位宽 |
| POOL_CORE | 8 | | pooling有多个少核PLC |
| POOL_COMP_CORE | 64 | | pool_core里面有多个做计算的核 |
| MAP_WIDTH | 5 | 5 | map个数的位宽，0-31 |


# 模块详解
## POL 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| --control-- |
| CCUPOL_Rst |
| --config-- |
| CCUPOL_CfgVld | input
| POLCCU_CfgRdy | input
| CCUPOL_CfgK   | input | 6 | 24: KNN, 32: Ball Query，32就表示32个 |
| CCUPOL_CfgNip | input | 
| CCUPOL_CfgChi | input | 
| GLBPOL_MapVld | input | 1 | 握手协议的valid信号 |
| GLBPOL_Map    | input | SRAM_WIDTH | 输入的map idx |
| POLGLB_MapRdy | output | 1 | 握手协议的ready信号 |
| POLGLB_AddrVld| output | 1 | 握手协议的valid信号 |
| POLGLB_Addr   | output | IDX_WIDTH\*POOL_CORE | 输出的地址来请求读数据 |
| GLBPOL_AddrRdy| input | 1 | 握手协议的ready信号 |
| GLBPOL_Ofm     | input | ACT_WIDTH\*POOL_COMP_CORE\*POOL_CORE | 输入的feature map=fm，分别给8个pool_core |
| GLBPOL_Ofmld   | input | 1 | 握手协议的valid信号 |
| POLGLB_OfmRdy  | output | 1 | 握手协议的ready信号 |
| POLGLB_Ofm     | output | ACT_WIDTH\*POOL_COMP_CORE\*POOL_CORE | pool输出计算结果 |
| POLGLB_OfmVld  | output | 1 | 握手协议的valid信号 | 
| GLBPOL_OfmRdy  | input | 1 | 握手协议的ready信号 |

## 模块陈述

- 点并行转为块并行
    - 按照分块的原则：各PLC完全独立（包含配置、输入和输出SRAM)，负责不同的块，（当然块内也可以并行，但由于需要倍增SRAM甚至copy，先不考虑，还不如倍增POOL_COMP_CORE）
        - 读的map块，读的ofm块，和PCC，写的ofm都是独立的。问题是PLC的负载不均衡，但由于只有一个ofm读口也不能帮，先不管
    - 按照流水线原则：各PLC不一定要都完成才算完成，各PLC由CCU独立调度，POL内直接generate多个PLC
    - 各个PLC共用一个MAP SRAM，分开OFM输入SRAM，分开OFM输出SRAM，输出OFM的位宽在POOL_COMP_CORE的基础上可缩小，以阻塞几个周期为代价，暂时位宽不变
    - MAP缓存采用reg，因为PLC需要缓存MAP为16*32=512，远未达到reg与uhddpsram的4096bit临界点

    - 当通道不是64时，还要适应不同通道数在GLB存多个word时，多次取来比较
        - 计算max: 内循环是不同点的64通道，外循环是不同通道，要保留32的map，相比于保留通道数个的ifm更加节省。先可变通道数配置通道数除以同时数的商为步长和记数器结合点的idx来生成取的地址，
        - 输出: 输出的循环是外循环是不同的中心点（如P0的MAP K个点，P1的Map的K个点，内循环是不同通道组（如C0-C63, C64-C127): P0(C0-63), P0(C64-127), P1(C0-63).... 
        - POL写Ofm为2个：
            - （ACT\*POOL_COMP_CORE)\*POOL_CORE/K=（ACT\*POOL_COMP_CORE)/4，则设计2个（暂定）SRAM_WIDTH的口存输出即可
            - 而且POL的输出是给MLP的，格式不是ACT*POOL_COMP_CORE并行的，所有PLC的核输出的数据是存到一起的，按照SYA 0模式，两块SRAM， SYA 1模式，一块SRAM
    - 暂不增加特征中心化功能：借鉴Mesorasi直接对单点多层卷积OFM减中心点OFM的Delayed-Aggregation方法（基于ReLU可多层嵌套拆）

## prior_arb端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| req | input | REQ_WIDTH |  |
| gnt | output | REQ_WIDTH | 响应 |

## 模块陈述
[代码位于](/hardware/src/primitives/prior_arb.v), prior_arb负责接收多个请求信息（多位req），并仲裁出一个来输出（gnt中只有一位被拉高）。仲裁方法为最简单的固定优先级的仲裁，参考[博文](https://mp.weixin.qq.com/s/82o9iAIw1LiDsjBNmiBVDQ)






