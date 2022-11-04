# 解决问题列表Task List：放入到MindJet :question:
1. 创新点只有一个，不够
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
        - 每层POL: 
        结论：达到最理想状态：
            - 总数据访问量：FPS和KNN只读一次第一层Crd，且不读写Map，MLP只读第一层act（同Crd)和每层weight；
                - PointMLP: 8bitx3*1024 + 579KB = 582KB / (总计算时间) = 6.65 bit/cycle
                    - 即使考虑每层都读写Map：8bit\*24\*512\*2 + 8bit\*24\*256\*2 +...= 24KB + 12KB + 6KB.. = 48KB << weight
                        - 最差片上不存Crd（即SRAM很小时）则：
                            - FPS：Nip*Crd*3/4Nip + Nip*3B(Dist)*3/4Nip*2（读和写） + 1/2Nip = (3B+6B)*3/4Nip*Nip = 6.75*Nip^2= 6.75M + Ly1...(每层除以4) = 8M
                            - KNN: (Nip*Crd + K*2)*Nip = 3M + 每层除以4 = 4M，而且未用KNN优化之前，还要乘以层数4，总计16M
                            - 总计12M，（未KNN有24M）
                            - 严格根据每层参数量控制片上存储并每层评估
                                - weight 3个64，一个32；activation，7个32；共20层；因此片上最小为32KB **（原本）**
                                    - Embedding：A 3KB，W 0.1KB，周期：96*16/3=512clk
                                    - Stage1：
                                        - FPS周期数3/4Nip*Nip=0.75M clk, KNN: Nip*Nip=1M clk此时：要么两倍存储Crd使得FPS和KNN都同时工作，要么交替计算（但总计算周期0.7M，故不可行）
                                            - KNN是否可以并行？
                                                - 可以：取相同的邻近点，中心点不同，过滤取的mask也一样，速度加倍，
                                                - 但收益：硬件开销？INS模块的大小占KNN的比例？80%，无额外收益
                                                - 但考虑到CTR整个才占1%面积，却占用的存储（或带宽）和时间太大了：
                                                    - 时间是整个计算过程还多：总时间是0.75M + 1/4倍...= 1M，KNN是1M+1/4倍..=1.5M,总计2.5M是计算的4倍
                                                        - :white_check_mark:KNN优化，将计算时间从1.5M到1M；将存储从每层Crd的6KB减少到1bit的总计1024bit（存储大带宽小方案）；对带宽从16M到4M（带宽大方案）
                                                            - :white_check_mark: 结论：运用KNN优化之后：计算时间减少了：0.5M/2.5M = 25%，存储减少了6KB/32KB=20%（）或带宽减少50%（占CTR总带宽）
                                                            - 但是计算时间还是太长：为了满足计算时间的硬性需求，故而加大FPS和KNN，故而存储加大：
                                                                - 计算时间减少4倍：FPS4倍，KNN4倍：
                                                                    - 由下可知:FPS由于只能串行算，计算时间固定为1M，不可能，因此也要优化，分4块，每块做FPS：存储总量不变但4个读中，让总量4倍
                                                                    - KNN：4倍并行，只让INS4倍即可，存储？不变？
                                                    - 存储或带宽（原本）
                                                        - 要么存储大带宽小：
                                                            - 存储：
                                                                - FPS: 每层累加：(Crd+Dist)*Nip = 6KB + 3KB +... = 12KB（稳定且大）
                                                                - KNN: 不需要在FPS基础上额外存
                                                            - 带宽最小为读第一层Crd，写和读Map：3KB + 48KB，带宽占用稳定且小（但1%面积也占了10%带宽）
                                                        - 要么存储小带宽大：对应上述片上不存Crd
                                                            - 存储：基本为0
                                                            - 带宽24M（太大了，不可接受，因此是存储大的方案）
                                        - A 16KB, W 2
                                        - A 32KB，W 1
                                        - A 8KB，W 1
            - 总计算时间：0.7G乘法/1024 = 0.7M周期数
    - 总体计算量评估：
        - 根据Excel: FPS和KNN所有的计算为1M，比较为9M，计算量<< MLP；计算周期为1M/3=0.3M 也<<0.7M

    - 三元二次方程：
        - 公式1：面积随MAC变化：    Area = FA*NBANK + BA;
        - 公式2：带宽随MAC变化：    BW   = FB*NBANK + BB; 带宽是指pad约束
        - 公式3：带宽随面积变化：   BW = FAB*$\sqrt{Area}$; 
            - x = NBANK; y = Area; z = BW
            - y = 0.17*x + 0.5; z = 20*x + 12; z = FAB*y^0.5
            - 师姐面积1.5x2.2=3.3， IO的是83，FAB=45.6, 则NBANK=1.3
                - 当IO加倍时，FAB=91.4, NBANK =4.55, Area=1.27, PAD = 103，刚好符合，优化其它部分
                    - 当GLB减半到0.25时，x = 3.67,y = 0.87, z = 85，面积减少显著

3. 硬件设计
        - :white_check_mark: 修改看timing_post-synth的check，log，和面积报告
            - 面积里面优化
                - 寄存器
                    - 减少不必要的寄存器：也是为了工具能自动优化组合逻辑
                    - **:question:大寄存器都换成SRAM** 
                        - 查report gates的seq面积比例(<0.25)
                        - <128bit，每个模块定义的reg，包括通用模块如FIFO实际的reg大小
        - :question:KNN和FPS拆开同时运行：共享太少，KNN太大但运行时间短闲置多
        - :question:FPS增加bitEn, KNN.PSS.PISO缩小（暂不）
        - **仿真调试**
            - 问题1：目前CCU.ISADatOut是x态，读使能是对的，读地址也是1，考虑是RAM的问题，尝试用FUNC_SIM就通过了，是RAM的问题
            - 问题2：SYACCU_CfgRdy为x态：bank_ena_you是x态，先考虑GLBSYA的都要不是x态
            - 且ISA在state==CONV_CFG读完后一直被读
    - :question: 最后是C_Model验证
    - 暂不解决
        - CTR
            - CTR出来的MAP怎么存，好送到POL，暂时一个SRAM_WIDTH的word存cp_idx和lp_idx，但是同一点不同层同时出来的？
            - CTR中报seq占60%
        - POL
            - POL输出怎么规则存到GLB？先6个核顺序输出
            - POL：当通道不是64时待后面补全
            - POL面积太大，功耗太高: 
                - 6个MIC的FIFO_OUT太大，深度4x宽度(3+8*64=515)=2kb x 6=12kb，占MIF的70%，暂时深度为2，后面再调整为1
                - Idx FIFO总容量为：16x32x8=4kb



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
