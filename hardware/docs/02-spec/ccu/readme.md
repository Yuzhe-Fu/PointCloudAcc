# 指令集-基本参考Thinker
包含有
- Array parameter：提前确定硬件结构，多少层，第一层参数的基址
- Layer parameter：层参数：控制每层具体的执行
  - 硬件上：act, wgt的存储地址，网络形状：channel数，点数等
- :question: PE configuration是什么？: 每个PE的每周期的切换信号（开关选择，也是指令：mode+直接控制状态机4个状态），迁移过来是子模块的控制
![config](https://user-images.githubusercontent.com/33385095/190861936-6e883bf5-593f-4304-bedb-e5d8686e9021.png)
![PE_config](https://user-images.githubusercontent.com/33385095/190861939-9f72cfcd-18de-454d-97a1-910ee08c98dc.png)
![image](https://user-images.githubusercontent.com/33385095/190882888-761b0439-953b-425a-b31b-dac4791b1596.png)


| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| Array Parameter |
| 0         |  3-22       | 23-38        |
| Mode(1b)  |  Ly_Num(20b)| Base_Addr0(32b) |
| Layer Parameters |
| 0-2       | 3-34          | 35-66         | 67-82 | 83-94 |   | 96-107| 108:127   | 128:135       | 136:143           | 144:145           | 146: 161      | 162: 177 | 178: 193 |
| OpCodeCON| DatAddr(32b)   | WgtAddr(32b)  | Nip   | Chi   | 1b| Cho   |quant_scale| quant_shift   | quant_zero_point  | CCUSYA_CfgMod(2b) | WgtAddrRange  |     DatAddrRange | OfmAddrRange | 
| 0-2       | 3-34          | 35-50         | 51-62 | 63-68 |
| OpCodePOL | DatAddr       | Nip           | Chi   |  K    |
| 0-2       | 2-33          | 34-65         | 66-81 | 82-93 | 94-105|
| OpCodeFC  | DatAddr       | WgtAddr       | Nip   | Chi   | Cho   | 
| 0-2       | 3-34          | 35-66         | 67-82 | 
| OpCodeFPS | Crd_addr      | Ni            | No    | 
| 0-2       | 3-34          | 35-66         | 67-72 |
| OpCodeKNN | Map_Idx       |  Ni           | K     | 0:表示没有，1-32 |



| Array Parameter |
| 0 | 1-2 | 3-22 | 23-38 |
| Mode: 1b, Run/Test | CCUSYA_CfgMod: 2b, 2x2, 4x1, 1x4 | Ly_Num: 20b | Base_Addr0: 32b,第一层的参数基址 |
| Layer Parameters |
| 0-1 | 2-33 | 34-65 | 66-81 | 82-93 | 94-105 | 106-125 | 126-133 | 134-141 |
| OpCode: Conv (FC, POOL) | DatAddr: 32b, Base addr of input data | WgtAddr: 32b, Base addr of weights | Nip: 16b, # of input points | Chi: # of input channels | | Cho: # of output channels |  quant_scale | quant_shift | quant_zero_point | 
| 0-2 | 2-33 |  66-81 | 82-93 | 
| OpCode:  POOL (Conv,FC),当片上存不下时，就需要从片外拿 | DatAddr: 32b, Base addr of input data |  Nip: 16b, # of input points | Chi: # of input channels |  
| 0-2 | 2-33 | 34-65 | 66-81 | 82-93 | 94-105 |
| OpCode: FC (Conv, POOL) | DatAddr: 32b, Base addr of input data | WgtAddr: 32b, Base addr of weights | Nip: 16b, # of input points | Chi: # of input channels | | Cho: # of output channels | 
| 0-2 | 2-33 |  34-65 | 66-81 | 
| OpCode: FPS | Crd_addr: 32b, Base addr of coordinates  | Ni: 16b, # of input points | No: 16b, # of output points | 
| 0-2 | 2-33 |  34-65 | 66-70 |
| OpCode: KNN | Map_Idx: 32b, Base addr of Index of KNN Map | K: 5b, # of neghbor points |

| Module Parameters |
| GLB |
| SYA |
| POL |
| CTR |


# 文件列表
| File | Descriptions |
| ---- | ---- |
| ccu.v | 顶层模块 |
| RAM_wrap.v | 通用SRAM模块，直接在primitives调用 |
| counter.v |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| MODE_WIDTH | 1 |  |  |
| NUM_LAYER_WIDTH | 20 |  |  |
| ADDR_WIDTH | 16 |  |  |
| OP_WIDTH | 3 | |  |
| NP_WIDTH | 16 |   |  |
| CHN_WIDTH | 12 |   |  |
| PORT_WIDTH | 96 | 96 | PAD数据宽度 |
| SRAM_WORD_ISA | 64 | 

# 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 代电平有效 |

| ITFCCU_Dat                | input | 
| ITFCCU_DatVld             | input |
| ITFCCU_DatRdy             | output |
// SYA
| CCUSYA_CfgMod             | output | 2 | 0: 4个bank按照2x2排列，1: 按照1x4排列，2: 按照4x1排列 | 
| CCUSYA_CfgScale           | output | 20           |               |
| CCUSYA_CfgShift           | output | ACT_WIDTH    | 同quant_scale |
| CCUSYA_CfgZp              | output | ACT_WIDTH    | 同quant_scale |
| CCUSYA_Start              | output | 1            |               |
| CCUPOL_CfgK               | output | 24           | 24: KNN, 32: Ball Query |
| CCUCTR_CfgMod             | output | 1            | 0: 执行FPS，1: 执行KNN |
| CCUCTR_CfgNip             | output | IDX_WIDTH    | 第一层输入点的个数，1023表示1024个点 |
| CCUCTR_CfgNfl             | output | NUM_FPS_WIDTH| FPS的层数     |
| CCUCTR_CfgNop             | output |IDX_WIDTH     |  2            | FPS筛选出原始点数的>> FPS_factor，例如当FPS_factor=1时，>>1表示一半 |
| CCUCTR_CfgK               | output | K_WIDTH           | KNN/BQ需要找出多少个邻近点 |
| CCUGLB_CfgVld             | output |NUM_PORT| 每个Port单独配置和使能，vld rdy取代rst和fnh
| GLBCCU_CfgRdy             | input  |NUM_PORT|
| CCUGLB_CfgPort_BankFlg    | output |
| CCUGLB_CfgPort_AddrMax    | output |
| CCUGLB_CfgRdPortParBank   | output |
| CCUGLB_CfgWrPortParBank   | output |
<!-- | GLBCCU_Port_fnh           | input  |1
| CCUGLB_Port_rst           | output |1 -->

# 模块描述
CCU是中央控制器，有专门的4bit IO来读指令集，负责配置模块和模块的**最顶层控制**（模块内部只要配置能控制的都不要用CCU控制，多少层由CCU控制，CfgVld相当于控制了层的开始，CfgRdy相当于模块反馈结束，再加上整个网络的Rst）
    - 与片外通信：先通过统一接口，从片外读取ARRAY parameter和layer parameters和configurations(可以用来选择的模块配置），存入到RAM里面，再从RAM里的ARRAY parameter和layer parameters
    - FSM控制片内：用FSM，t每层输出一次配置，IDLE(芯片启动空状态）->RD_CFG(读取整个网络的参数配置）->->FNH（整个网络计算完成）
        - 转到配置子FSM: IDLE_CFG ->接收到Triggerif (ReqCfg)...ARRAY_CFG, CONV_CFG（配置网络一层）， FC....-> 
    根据模块请求FPS、KNN、CONV、POL、FC等层的配置，各自取各自下一层的配置
    - RAM_ISA：
        - 写：每次请求的就是一整个RAM深度的，addr_w是所有层数，是深度的倍数，满深度后，仍然加1，相当于重新写RAM
        - 读：每种层单独配置，Cfg不同信息归属不同种的层，所有种层的信息连续存到RAM，RAM的宽度就是PORT_WIDTH=96，每个种层有多个PROT_WIDTH的word，深度为64（PointMLP-lite就有43层）
            - 用FSM直接使能读RAM，用读数中的OpCode确认是否取到相应的种层的配置，否则地址加1，当取完各种层一层的所有word后（当取到配置数为需要的-1且当前取的match时），完成种层的配置
    - GLB控制：达到单独控制一个Port转移到另一个Bank，需要：
        - 单独控制到哪个Bank：
            - 不影响其它Bank：在刷新时，其它的配置信息应该是不变的
            - 从Bank哪个地址开始读写起止，（IF还有DRAM的读写起止地址）：
                - 用相应的CfgVld的bit位，是一个脉冲，与SYA_RdPortActBank等信息同时变化。
        - 配置信息怎么来？
            - 直接从片外配置的来得出，每个口随层变：但什么时候Port改变呢？**每种层变化时也即取配置时**
                - 每种层配置port的bank flag，得到如下口的信息，然后assign 给让CCUGLB_CfgBankPort，CCUGLB_CfgPortMod，防止multidriver
                - SYA_RdPortAct
                - SYA_RdPortWgt
                - SYA_WrPortFm
                - POL_RdPortFm
                - POL_WrPortFm
                - ITF_RdPort
                - ITF_WrPort
            - 先一步步回溯：
                - CCUGLB_CfgBankPort：每个口单独配置：
                    - 对SYA：SYA的mode决定RdPortParBank和WrPortParBank即基数，在知道整个filter数量和ifm的情况下，假设只有loop ifm和loop filter两种情况（由片外配置），固定的项的总量可得到，Loop项的可以是1或多个，RdPortLoop的次数用总数除以Bank量，CCUGLB_CfgPort_AddrMax为Bank数，
                    - 对IF口：哪里没有了就去哪里，灵活配置
                    - 对POOL：根据片外配置的Nip和Chi，分配Bank
                    - 
    - Debug: 暂未考虑
# 下一步：回到怎么生成每个输出？？？？？？再完善细节代码，简化逻辑：易懂，功能模块，去除中间冗余信号



