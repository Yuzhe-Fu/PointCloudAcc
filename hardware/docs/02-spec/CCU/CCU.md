# 问题
    - 从ISARAM取ISA会堵死：当ISARAM满了，还未取完的指令要等一条新的从DRAM读的指令执行完：让RAM深，多个bank
    
# 文件列表
| File | Descriptions |
| ---- | ---- |
| CCU.v | 顶层模块 |
| RAM_wrap.v | 通用SRAM模块，直接在primitives调用 |
| counter.v |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| NUM_LAYER_WIDTH | 20 |  |  |
| ADDR_WIDTH | 16 |  |  |
| DRAM_ADDR_WIDTH | 32 |  |  |
| OPCODE_WIDTH | 3 | |  |
| IDX_WIDTH | 16 |   |  |
| CHN_WIDTH | 12 |   |  |
| SRAM_WIDTH | 256 | 256 | GLB宽度 |
| SRAM_WORD_ISA | 64 | 

# 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 代电平有效 |

| ITFCCU_Dat                | input | SRAM_WIDTH | 从GLB统一取的 |
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
| CCUGLB_CfgVld             | output |NUM_PORT| 用CCUGLB_CfgVld**重置**相应的Port |
| GLBCCU_CfgRdy             | input  |NUM_PORT| 代表完成了 |
| CCUGLB_CfgPort_BankFlg    | output |
| CCUGLB_CfgPort_AddrMax    | output |
| CCUGLB_CfgRdPortParBank   | output |
| CCUGLB_CfgWrPortParBank   | output |
<!-- | GLBCCU_Port_fnh           | input  |1
| CCUGLB_Port_rst           | output |1 -->

# 模块描述
- CCU是中央控制器，负责配置模块和模块的**最顶层控制**（模块内部只要配置能控制的都不要用CCU控制，多少层由CCU控制，CfgVld相当于控制了层的开始，CfgRdy相当于模块反馈结束，再加上整个网络的Rst）
    - 对GLB按口配置Flag时，本应该是配置子模块时一并配置它的GLB口（有读写地址当然应该有读写哪一块），而不是当成两个配置（配置子模块和配置它的口），实际操作上是CCU配置Flag给TOP，跳过（TOP给子模块，子模块再给GLB），TOP直接给GLB
        - 包括给ITF的DramAddr也是
    - FSM控制片内：需要给每个模块，甚至是模块中的口(如GLB的口），单独配置，因此每个都有单独指令操作码
        - 模块请求信号CfgRdy, 如FPS、KNN、SYA、POL等模块或GLB的各个口，各自取下一个的配置

    - RAM_ISA：
        - 由GLB指定第0个bank是RAM_ISA, 通用GLB的ISA会错误地认为已被读走，将CCU的RdAddr过的但没取走的其它模块的指令盖写:
            - 方案1-不用：原来方式，还是单独给RAM吧，位宽128不变，需要PISO（128面积小，PISO_NOCACHE不占面积且好辨认各字节）
            - 方案2-采用：额外加逻辑判断这种情况：当RdAddrMin导致满时，让ITF接收到的WrDatRdy置为0，而不是GLB发出的WrDatRdy
        - 写：每次请求的就是一整个RAM深度的，addr_w是所有层数，是深度的倍数，满深度后，仍然加1，相当于重新写RAM
        - 读：每种层单独配置，Cfg不同信息归属不同种的层，所有种层的信息连续存到RAM，RAM的宽度就是PORT_WIDTH=96，每个种层有多个PROT_WIDTH的word，深度为64（PointMLP-lite就有43层）
            - 用FSM直接使能读RAM，用读数中的OpCode确认是否取到相应的种层的配置，否则地址加1，当取完各种层一层的所有word后（当取到配置数为需要的-1且当前取的match时），完成种层的配置
# 下一步：画图



