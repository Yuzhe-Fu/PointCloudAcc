# [整个模块和所有子模块的硬件框图（实时维护）](pooling-2022-09-08.excalidraw)

# 文件列表
| File | Descriptions |
| ---- | ---- |
| POL.v | 顶层模块 |
| POL_MIF.v | multiple interface module多个pooling核读global buffer的接口模块 |
| PLC.v | pool_core做pooling的核 |
| PLCC.v | pool_compute_core, pooling里面具体做计算的核，比如做max, average |
| PAN.v | pool_arb_net仲裁多个请求，选出一个请求信息输出，并响应请求 |
| FIFO.v | 通用模块，直接调用 |
| PARB.v | prior arb通用模块，直接调用 |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| IDX_WIDTH | 10 | 10, 12 | 点的index位宽，1024个点即10b |
| POOL_MAP_DEPTH_WIDTH | 5 | | map的深度的位宽，Ball Query有32个邻近点，位宽为5 |
| POOL_CMD_DEPTH_WIDTH | 2 | 2, 3 | 每个被读global buffer的指令FIFO深度 |
| POOL_OUT_DEPTH_WIDTH | 2 | | 每个被读global buffer的输出IFO深度 |
| POOL_CORE | 6 | |pooling有多个少核，对应多少个读的口 |
| POOL_COMP_CORE | 64 | | pool_core里面有多个做计算的核 |

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
| CCUPOL_CfgK   | input | 24 | 24: KNN, 32: Ball Query |
| CCUPOL_CfgNip | input | 
| CCUPOL_CfgChi | input | 
| GLBPOL_IdxVld | input | 1 | 握手协议的valid信号 |
| GLBPOL_Idx    | input | SRAM_WIDTH | 输入的map idx |
| POLGLB_IdxRdy | output | 1 | 握手协议的ready信号 |
| POLGLB_AddrVld| output | 1 | 握手协议的valid信号 |
| POLGLB_Addr   | output | IDX_WIDTH\*POOL_CORE | 输出的地址来请求读数据 |
| GLBPOL_AddrRdy| input | 1 | 握手协议的ready信号 |
| GLBPOL_Fm     | input | ACT_WIDTH\*POOL_COMP_CORE\*POOL_CORE | 输入的feature map=fm，同时给6个pool_core |
| GLBPOL_Fmld   | input | 1 | 握手协议的valid信号 |
| POLGLB_FmRdy  | output | 1 | 握手协议的ready信号 |
| POLGLB_Fm     | output | ACT_WIDTH\*POOL_COMP_CORE\*POOL_CORE | pool输出计算结果 |
| POLGLB_FmVld  | output | 1 | 握手协议的valid信号 | 
| GLBPOL_FmRdy  | input | 1 | 握手协议的ready信号 |

## 模块陈述
背景：需要做pooling的整块feature map，均匀分为6块，存于global buffer中。
由于需要满足输出给下一层卷积计算的带宽的需求，pooling模块有6个pooling核(pool_core)，每个pool_core里面有64个取大值核(pool_comp_core), 因此整个pooling的算力为，每周期读取6个点（其中每个点64个通道）并与pool_comp_core的reg中的值比出最大值后更新pool_comp_core的reg最大值；
运行过程：
    - stage0: 启动阶段：FSM的state处于IDLE，等待CfgVld使其进入工作模式，
    - stage1: 工作模式下，6个PLC核同时取Map中相同位置的Idx，存于各自FIFO，当每个核map的idx都算完，输出ofm，后计算下一个map，（因为各个PLC独立工作，自己才知道算了多少个，因此不能在POL顶层统一控制）

## PLC 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk           | input | 1 | clock |
| rst_n         | input | 1 | reset, 低电平有效 |
| CCUPOL_CfgK   | input | POOL_MAP_DEPTH_WIDTH | 24: KNN, 32: Ball Query |
| POLPLC_IdxVld | input | 1 | 握手协议的valid信号 |
| POLPLC_Idx    | input | IDX_WIDTH | 输入的map idx,从pool顶层模块的SRAM_WIDTH位宽的pool_idx分割出来的 |
| PLCPOL_IdxRdy | output | 1 | 握手协议的ready信号 |
| PLCPOL_AddrVld| output | 1 | 握手协议的valid信号 |
| PLCPOL_Addr   | output | IDX_WIDTH | 输出的地址来请求读数据 |
| POLPLC_AddrRdy| input | 1 | 握手协议的ready信号 |
| POLPLC_Fm     | input | ACT_WIDTH\*POOL_COMP_CORE | 输入的feature map=fm |
| POLPLC_FmVld  | input | 1 | 握手协议的valid信号 |
| PLCPOL_FmRdy  | output | 1 | 握手协议的ready信号 |
| PLCPOL_Fm     | output | ACT_WIDTH\*POOL_COMP_CORE | pool输出计算结果 |
| PLCPOL_FmVld  | output | 1 | 握手协议的valid信号 | 
| POLPLC_FmRdy  | input | 1 | 握手协议的ready信号 |

## 模块陈述
每个pool_core根据index序列（可以简单理解为取读取用来pooling的feature map中点的地址，序列长度为2^POOL_MAP_DEPTH_WIDTH），依次取index序列中的index，作为地址向multi_if模块请求读取数据，将读取的64个通道数据并行同时送入64个pool_comp_core，计算出64个最大值，当比较完index序列中指向的所有点后，输出到pool_out_fm，拉高pool_out_fm_vld等待被取走后，再比较下一轮index序列中的数；
    -stage0: 输入Map的Idx到FIFO，并同步计数个数
    -stage1: FIFO输出Addr
    -stage2: GLB输入ofm到PCC比较
    -stage3: 当计算到K个时，将Last与GLB输入的ofm同步，给PCC
    -stage4: 

## PLCC 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk       | input | 1 | clock |
| rst_n     | input | 1 | reset, 低电平有效 |
| DatInVld  | input | 1 | 握手协议的valid信号 |
| DatInLast | input | 1 | 最后一个有效的数 |
| DatIn     | input | IDX_WIDTH*POOL_COMP_CORE | 输入的map idx,从pool顶层模块的SRAM_WIDTH位宽的pool_idx分割出来的 |
| DatInRdy  | output | 1 | 握手协议的ready信号 |
| DatOutVld | output | 1 | 握手协议的valid信号 |
| DatOut    | output | IDX_WIDTH*POOL_COMP_CORE | 输出的地址来请求读数据 |
| DatOutRdy | input | 1 | 握手协议的ready信号 |


## MIF 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| --data-- |
| POLMIF_AddrVld    | input | 1 | 握手协议的valid信号 |
| POLMIF_Addr       | input | IDX_WIDTH*\POOL_CORE | 输出的地址来请求读数据 |
| MIFPOL_Rdy        | output | 1 | 握手协议的ready信号 |
| MIFGLB_AddrVld    | output | 1 | 握手协议的valid信号 |
| MIFGLB_Addr       | output | IDX_WIDTH*\POOL_CORE | 输出的地址来请求读数据 |
| GLBMIF_AddrRdy    | input | 1 | 握手协议的ready信号 |
| GLBMIF_Fm         | input | ACT_WIDTH\*POOL_COMP_CORE*\POOL_CORE | 输入的feature map=fm |
| GLBMIF_FmVld      | input | 1 | 握手协议的valid信号 |
| MIFGLB_FmRdy      | output | 1 | 握手协议的ready信号 |
| MIFPOL_Fm         | output | ACT_WIDTH\*POOL_COMP_CORE*\POOL_CORE | 输出给6个POOL_CORE的feature map=fm |
| MIFPOL_FmVld      | output | 1 | 握手协议的valid信号 |
| MIFPOL_FmRdy      | input | 1 | 握手协议的ready信号 |

## 模块陈述
作为global buffer与pool_core的接口模块，multi_if是为了满足6个pool_core能够同时读取global buffer的需求（6个口的带宽），因为feature map被均分到6块buffer中（即6个SRAM）中，因此每个pool_core都有可能同时读取同一块SRAM，导致读取同一块SRAM有多个口出现冲突，结果一次只能有一个口能成功读取，其它5个口闲置。为了解决这个问题，multi_if用来仲裁6个SRAM的读口与6个pool_core的读请求。整体概念上是，6个pool_core同时发出6个读的信息(idx, vld)，每个arb_net接收到这6个信息，并根据自身的地址范围，确认其对应的global buffer块是否有其需要的数据，然后仲裁出一个pool_core，并将其pool_core编号(idx_core(0-5))和请求的idx存入指令cmd_fifo，cmd_fifo不断地取出里面的指令解析出pool_addr给global buffer来执行里面的指令，并把idx_core和读到的数据pool_in_fm合并，一起写入out_fifo；为了响应6个pool_core，有6个输出的仲裁器，每个输出的仲裁器负责把6个out_fifo中，正确的idx_core对应的数据取出来，给相应的pool_core。


## arb_net参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| NUM_PORT | 6 |  | 请求的端口数 |
| IN_INFO_WIDTH | 10 | | 请求附加信息的位宽 |
| OUT_INFO_WIDTH | 10+3 | | 请求附加信息的位宽 |

## arb_net端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| --data-- |
| req_vld | input | NUM_PORT | 握手协议的valid信号 |
| req_info | input | INFO_WIDTH\*NUM_PORT | 输出的地址来请求读数据 |
| req_rdy | output | NUM_PORT | 握手协议的ready信号 |
| out_info | output | OUT_INFO_WIDTH |  |
| out_vld | output | 1 | 握手协议的valid信号 |
| out_rdy | input | 1 | 握手协议的ready信号 |

## prior_arb参数列表（通用模块）
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| REQ_WIDTH | 6 |  | 请求的端口数 |

## prior_arb端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| req | input | REQ_WIDTH |  |
| gnt | output | REQ_WIDTH | 响应 |

## 模块陈述
[代码位于](/hardware/src/primitives/prior_arb.v), prior_arb负责接收多个请求信息（多位req），并仲裁出一个来输出（gnt中只有一位被拉高）。仲裁方法为最简单的固定优先级的仲裁，参考[博文](https://mp.weixin.qq.com/s/82o9iAIw1LiDsjBNmiBVDQ)






