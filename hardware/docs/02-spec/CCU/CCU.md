# 问题
    - 通用GLB的ISA会错误地认为已被读走，将CCU的RdAddr过的但没取走的其它模块的指令盖写
    - 从ISARAM取ISA会堵死：当ISARAM满了，还未取完的指令要等一条新的从DRAM读的指令执行完
    
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

    - FSM控制片内：需要给每个模块，甚至是模块中的口(如GLB的口），单独配置，因此每个都有单独指令操作码
        - 模块请求信号CfgRdy, 如FPS、KNN、SYA、POL等模块或GLB的各个口，各自取下一个的配置
        - IDLE(芯片启动空状态）->RD_CFG(读取整个网络的参数配置）
        - 转到配置子模块FSM: IDLE_CFG ->接收到CfgRdy（表示完成计算，需要重新配置）
            - ARRAY_CFG, localparam OpCode_Array = 3'd0;
            - SYA_CFG（配置网络一层）, localparam OpCode_Conv  = 3'd1; == FC
            - POL_CFG: OpCode_Pool  = 3'd3;
            - FPS_CFG OpCode_FPS   = 3'd4;
            - KNN_CFG OpCode_KNN   = 3'd5;
            - GLB_CFG
                localparam IDLE     = 4'b0000;
                localparam RD_ISA   = 4'b0001;
                localparam IDLE_CFG = 4'b0010;
                localparam NETFNH   = 4'b0011;
                // localparam ARRAY_CFG= 4'b1000; // 0

                // localparam OpCode_TOP             = 128 + 0;
                // localparam OpCode_SYA             = 128 + 1;
                // localparam OpCode_POL             = 128 + 2;
                // localparam OpCode_FPS             = 128 + 3;
                // localparam OpCode_KNN             = 128 + 4;
                // localparam OpCode_GLBWRIDX_ITFACT = 128 + 5 + 0;
                // localparam OpCode_GLBWRIDX_ITFWGT = 128 + 5 + 1;
                // localparam OpCode_GLBWRIDX_ITFCRD = 128 + 5 + 2;
                // localparam OpCode_GLBWRIDX_ITFMAP = 128 + 5 + 3;
                // localparam OpCode_GLBWRIDX_SYAOFM = 128 + 5 + 4;
                // localparam OpCode_GLBWRIDX_POLOFM = 128 + 5 + 5;
                // localparam OpCode_GLBWRIDX_FPSDST = 128 + 5 + 6;
                // localparam OpCode_GLBWRIDX_FPSFMK = 128 + 5 + 7;
                // localparam OpCode_GLBWRIDX_KNNMAP = 128 + 5 + 8;
                // localparam OpCode_GLBRDIDX_ITFMAP = 128 + 5 + 9 + 0;
                // localparam OpCode_GLBRDIDX_ITFOFM = 128 + 5 + 9 + 1;
                // localparam OpCode_GLBRDIDX_SYAACT = 128 + 5 + 9 + 2;
                // localparam OpCode_GLBRDIDX_SYAWGT = 128 + 5 + 9 + 3;
                // localparam OpCode_GLBRDIDX_FPSCRD = 128 + 5 + 9 + 4;
                // localparam OpCode_GLBRDIDX_FPSDST = 128 + 5 + 9 + 5;
                // localparam OpCode_GLBRDIDX_FPSFMK = 128 + 5 + 9 + 6;
                // localparam OpCode_GLBRDIDX_KNNCRD = 128 + 5 + 9 + 7;
                // localparam OpCode_GLBRDIDX_KNNKMK = 128 + 5 + 9 + 8;
                // localparam OpCode_GLBRDIDX_POLMAP = 128 + 5 + 9 + 9;
                // localparam OpCode_GLBRDIDX_POLOFM = 128 + 5 + 9 + 10; // + 5(POOL_CORE)
        - 到FNH（整个网络计算完成）

    - 与片外通信：先直接通过统一接口ITF（ITF相当于挂载了CCU和GLB），从片外读取ARRAY parameter和layer parameters和configurations(可以用来选择的模块配置），存入到RAM里面，再从RAM里的ARRAY parameter和layer parameters

    - RAM_ISA：
        - 写：每次请求的就是一整个RAM深度的，addr_w是所有层数，是深度的倍数，满深度后，仍然加1，相当于重新写RAM
        - 读：每种层单独配置，Cfg不同信息归属不同种的层，所有种层的信息连续存到RAM，RAM的宽度就是PORT_WIDTH=96，每个种层有多个PROT_WIDTH的word，深度为64（PointMLP-lite就有43层）
            - 用FSM直接使能读RAM，用读数中的OpCode确认是否取到相应的种层的配置，否则地址加1，当取完各种层一层的所有word后（当取到配置数为需要的-1且当前取的match时），完成种层的配置
    - GLB控制：达到单独控制一个Port转移到另一个Bank，需要：
        - 什么时候重置：检测口写完/读完一次的信号CfgRdy(Fnh)后根据loop次数决定是否要重新配置口，一旦完成loop次数，口就要重新配置；
        - 重置什么信息：用CCUGLB_CfgVld重置相应的Port: Bank对应(Flag, Num, Par), loop次数，ITF读写还要配置DramAddr
            - 每种层配置port的bank flag，得到如下口的信息，然后assign 给让CCUGLB_CfgBankPort，CCUGLB_CfgPortMod，防止multidriver
            - SYA_RdPortAct
            - SYA_RdPortWgt
            - SYA_WrPortFm
            - POL_RdPortFm
            - POL_WrPortFm
            - ITF_RdPortAct
            - ITF_WrPortWgt
            - ITF_WrPort...
    - Debug: 暂未考虑
# 下一步：画图



