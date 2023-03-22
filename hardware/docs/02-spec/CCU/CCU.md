# 问题
- 增加预取机制准备好数据(比如预取下一层的wgt)
    - CCU：对ITF读写GLB口的控制指令要分离成单独的ITF模块指令
        - 方案1(弃用)：还是由子模块决定，只不过ITF为了避免同时读写，满一块才读，剩空一块就写；但是子模块从工作到有数据还是有SRAM深度128的延迟
        - 方案2-CCU主动（弃用）：ITF什么时候读写哪个口读写多少完全由CCU决定，不由对应口的请求决定，
            - 好处是可以避免同时ITF与功能模块读写导致ITF和功能模块的速度都减半，
            - 坏处是指令复杂，属于是对ITF读写给功能模块的数据和功能模块双重控制，容易冲突，本来就是功能模块时候时候需要数据自己控制就行
            - 问题
                - **给ITF的指令会出错**：ITF不断请求指令，CCU需要根据子模块情况来判断哪些GLB数据是需要读写，而这个判断是实时变化的跟IFM也有关系，放在芯片内部是黑盒子，容易出错
                - 取指令延迟也大：当所有子模块请求指令时，要对RAM进行遍历找足对应的指令
                - 从ISARAM取ISA会堵死：当ISARAM满了，还未取完的指令要等一条新的从DRAM读的指令执行完：让RAM深，多个bank
        - 方案3(选定)-PC主动实时控制:**升级版-流片必做**
            - 好处：完全容错可配置性强甚至可重置SRAM的数据
            - 问题
                - 怎么让外部透明知道内部哪里需要指令？
                    - 把内部请求信息(CfgRdy)全输出出来（清楚知道模块是否完成和**是否阻塞需要重置**），PC继承原CCU的仲裁，判断CfgRdy后直接取指令，通过接口一条一条地发送到CCU原本的读ISA口（含last）和发送要重置哪个模块，CCU负责把接收到的ISA译码到指定的模块的控制REG，用last来拉高CfgVld，CfgVLd会在相应的模块拉低CfgRdy，拉低的CfgRdy会让PC和CCU启动下一轮的取指。来实时控制某个模块
                        - 异常突发模式：PC检测到（如CfgRdy写出的数据）的异常，直接发指令到CCU，CCU拉高CfgVld后强制子模块复位并拉高CfgRdy，后取指令，去掉无用的CfgRst
                - 延迟大？在没有预存机制下，怎么在芯片测试时保证PC从接收CfgRdy到CCU发出CfgVld的延迟小于10个周期？不能用串口，只能共用数据口。增加的延时是(1个片外检测+1个取指+3个接口读写)+word数\*时钟频率倍数\*位宽倍数(平均是5*2*256/64=**40)，压力主要在接口带宽不够**
                    - 暂不考虑，后期要么缩减指令，要么缩小GLB面积，保留128pad的带宽，可10MHz跑然后等比到100MHz
    - GLB：增加当无对应读或写口时，所有口写或读口依然能写或读
        - 读写时，有接着上次读写或从0读写的模式
        - 读时，默认是保留上次的写的数及其写地址的
        - :question:写时，GLB默认是保留上次的写的数及其写地址的？wready是否受无读影响？待测试验证
    - ITF: :question:确认只有一个读写GLB的口，会出现之前未解决的问题吗？

    
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



