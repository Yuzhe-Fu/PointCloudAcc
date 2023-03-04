# 问题：
- 减少sram的位宽到128位(因为sya需要的一个单位是128)，加倍深度，块数不变（有pingpongbuffer的需求）
- GLB打拍
    - SRAM打拍时不要对每个Wr/RdPort打拍，因为口太多，而是对bank输入输出打拍，但是还是尽量不打拍，寄存器太多了
- RAM的DO_d占用太大面积了

# 文件列表
| File          | Descriptions      |
| ----          | ----              |
| GLB.v | 顶层模块        |
| RAM.v    | 单个Bank封装模块  |
| SRAM_GB. v    | 所有Bank封装模块  |


# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| NUM_BANK | 32 |  | SRAM BANK的个数 |
| IF_WIDTH | 96 | | 接口的位宽，即数据pad个数 |
| BANK_IDX_WIDTH | LOG2(NUM_BANK) | | SRAM BANK的索引的位宽 |
| NUM_WRPORT | 3 |
| NUM_RDPORT | 4 |
| ADDR_WIDTH | 16 | 128KB/32B=4K, 12|
| SRAM_WIDTH |
| SRAM_WORD  |
| CLOCK_PERIOD | 

## GLB (global_buffer) 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk                       | input     | 1 | clock |
| rst_n                     | input     | 1 | reset, 低电平有效 |
| --control--            |
| CCUGLB_Rst            |
| --config--            |           | | 顶层模块只分最顶层的东西，跟网络相关的，比如： |
| CCUGLB_CfgVld             | i nput | NUM_PORT | 每个Port单独配置的使能，vld rdy取代rst和fnh, 重置Port所有信号
| GLBCCU_CfgRdy             | output | NUM_PORT | 含义是读/写到配置的CfgNum：写表示写完了，读表示读完了一次，CCU可以知道读完了多少次
| CCUGLB_CfgBankPort        | input     | (NUM_RDPORT + NUM_WRPORT)* NUM_BANK | 为每个Bank分配读/写Port是两个，1表示有分到，也表示Port是否有效 |
| CCUGLB_CfgPortNum |input     | 配置数据容量（个数）:写：最大个数；读：一次循环的个数不是所有循环个数
| CCUGLB_CfgRdPortParBank|input     | 
| CCUGLB_CfgWrPortParBank|input     | 
| CCUGLB_CfgPortLoop|input     | 表示是否要循环读写，目前只用了循环读功能
| WrPortAddr_Out | output | 实时输出写地址只用于给ITF，用于ITF从DRAM读时，(CCUITF_BaseAddr+WrPortAddr_Out)作为读DRAM的基址 |
| RdPortAddr_Out | output | 同上 |
# 模块陈述
localparam GLBWRIDX_ITFISA = 0; 
localparam GLBWRIDX_ITFCRD = 1; IF写Crd：~
localparam GLBWRIDX_ITFMAP = 2; IF写MAP：~
localparam GLBWRIDX_ITFACT = 3; IF写Act：IF写都是1个SRAM_WIDTH
localparam GLBWRIDX_ITFWGT = 4; IF写Wgt：~
localparam GLBWRIDX_FPSMSK = 5; FPS写Mask：固定最少的一个Bank位宽
localparam GLBWRIDX_FPSCRD = 6; 
localparam GLBWRIDX_FPSDST = 7; 写Dist 
localparam GLBWRIDX_FPSIDX = 8; 写采样之后的Idx
localparam GLBWRIDX_KNNMAP = 9;写MAP
localparam GLBWRIDX_SYAOFM = 10;SA写sa_fm SYAGLB_Ofm：2个Bank，64B，固定为两个Bank位宽，不随CCUSYA_CfgMod
localparam GLBWRIDX_POLOFM = 11;POOL写pool_fm POLGLB_Fm: 2个Bank，64个比较器出，就64出，要是channel=128，就两次loop，写两次64
                                        
localparam GLBRDIDX_ITFMAP = 0; IF读MAP：IF读都是1个SRAM_WIDTH
localparam GLBRDIDX_ITFOFM = 1; IF读ofm：IF读都是1个SRAM_WIDTH
localparam GLBRDIDX_ITFIDX = 2; 
localparam GLBRDIDX_CCUISA = 3; 
localparam GLBRDIDX_FPSMSK = 4; 的FPS读Mask：固定最少的一个Bank位宽// FPS Read MASK
localparam GLBRDIDX_FPSCRD = 5; 读Crd GLBCTR_Crd：固定最少的一个Bank位宽
localparam GLBRDIDX_FPSDST = 6; 读Dist GLBCTR_DistIdx：固定最少的一个Bank位宽
localparam GLBRDIDX_KNNCRD = 7; 
localparam GLBRDIDX_SYAACT = 8; SA读sa_fm(act/ofm) GLBSYA_Act：连接位宽是SYA_NUM_BANK，实际位宽是根据CCUSYA_CfgMod：0时2，1时1，2时4
localparam GLBRDIDX_SYAWGT = 9; SA读weight GLBSYA_Wgt：连接位宽是SYA_NUM_BANK，实际位宽是根据CCUSYA_CfgMod：0时2，1时4，2时1
localparam GLBRDIDX_POLMAP = 10;POL读MAP GLBPOL_Map：固定最少的一个Bank
localparam GLBRDIDX_POLOFM = 11;POOL读sa_fm GLBPOL_Fm：固定为64B*6，12个Bank位宽

- 设计考量
    - 简洁通用：不要自循环读，因为怎么读本就是读口决定的，由CCU配置给每个模块要读哪些bank，怎么读，而不是配置GLB来提供读的选项，不会增加计数器
    - GLB的功能定义作为中间媒介，一是给每个读写口提供读写信息(总体的读写握手协议)，二是给每个Bank也提供读写握手协议；内部对请求进行仲裁；
    - 满空怎么知道？
            - 当Port单一时，它的值来自于各自的计数器不变（ITF也要每个数据口单独的计数器，也就是同一块数据的读写口同时打开和释放）
        - 要加上缓存上次成功读写的地址reg：怎么判定结束？只能根据读写模块的CfgRdy表示完成，此时子模块内的计数器可能提前重置了，导致GLB接受到的地址突然变为0，妨碍空满判断；
- 输入
    - 
- 输出
    - 很纯粹，只是握手协议
- 设计过程分为两大块
    - Port端：负责判断空满和分配给要读写的bank信号
    - Bank端：负责记录上一次成功读写地址，每次cfg读/写都要重置其初始地址
    - 配置：
        - GLB的TOPGLB_CfgVld怎么办？根本就不用CfgVld和CfgRdy，完全由口决定而不是自身决定
        - **注意要求：口对应的配置Bank是连续的（由于ParBank是直接向上加），Bank深度必须是2的指数（由于地址raddr/waddr直接截取）**
        - 由于需要不中断其它口实时动态配置Bank，因此CCU给GLB的所有配置和控制信号需要同一个周期变，
        - 而且给Bank都要是reg信号
        - 因此把CfgVld和CfgInfo，组合逻辑从原始配置生成所有需要的控制的信号,因为采用口不复用方式，配置CCUGLB_CfgPortBank即可，先不打拍
    - 控制：每个口有一套控制逻辑，控制生成addr, PortEn等，然后每个Bank根据BandPortIdx来选取Port的信号。
        - 地址来源：用是否分配到读写口来选择来源1和来源2
            - 来源. 各个GLB读/写口的地址生成器：（采用口不复用方式，也不用保持上次读的地址）
                - 模式0：连续读数，计数器自动生成
                        - 读循环读模式：写完某个数后，（小于等于容量）；计数器MAXCNT是配置的个数CfgNum-1；在0-MaxCNT循环计数；PortCur1stBankIdx因为地址不超过容量不需要改(实际上统一手动cut到指定bank的地址范围)；写ReqNum是CfgNum-WrAddr(即写到CfgNum就可以了)
                        - 读一次模式：一直读够CfgNum个（小于容量，等于容量，大于容量）：计数器MAXCNT是配置的个数CfgNum-1；在0-MaxCNT一次计数；PortCur1stBankIdx因为地址可能超过容量，需要手动改范围(实际上统一手动cut到指定bank的地址范围)；写ReqNum是CfgNum-WrAddr(即写到CfgNum就可以了)
                    - 自己根据能否读/写成功(Port对应的Bank只要有arrvalid & arready握手），控制什么时候INC,CLEAR还有让地址重新有效即启动读写的功能
                    - 因为目前是单口模式不复用口，所以写的地址会自动保留用来判断读空Empty。
                    - 不需要给地址，Addr相关的信号没起作用，自动地址向上累加，提前准备好数据，数据取走后再地址加1准备好数据
                - **模式1**：输入地址来跳着读写，读空判断写满判断不变，但输出的ReqNum和Addr是实变的，而且之前读过的不能被盖，目前需要addr的是接CTR和POL的不是ITF，因此不需要，先不管
        - 读写使能生成
            - 有读写请求才读写使能，直接用端口的RdPortDatRdy作为arvalid的一部分，和WrPortDatVld作为wvalid的一部分
            - 读空写满：
                - 读：有写入了数才能读：假定读写口分配相同Bank且读写顺序一致，则非空时可以读，即RdEn= !(RdAddr == WrAddr); 且RdAddr=WrAddr，（圈数由CCU通过RdAddr发出CfgRdy知道多少圈了，当Mode0时，WrAddr大于最后一个有效地址，当RdAddr也最后一个有效地址时，发出CfgRdy，然后复位0）
                - 写：有写满的存在(像FIFO），只当串入串出时，RdAddr相差WrAddr一圈(AddrMax)
                - Empty当未写时怎么为1？Full当第一个数未读时，怎么置1？
                    - 增加表示是否写进了至少一个数的标志，Wrtn区分wraddr_d的0是否确实有写了第一个数；同理增加Rden表示是否确实被读了第一个数
            - 有读不能写：单口SRAM
        - 选择：
            - 首先是判断是读/写，读优先
            - 分配的读/写口的Port_Idx：由配置的RdPortBank生成
        - AddrEn选择
            - Addr的选择器能决定接到口所分配的所有Bank的addr，但不同Bank的En肯定不一样，由Bank所在第几个Bank，和同时读取几个块决定
                - 如分配4个Bank，并行读2个，则第0个bank：是否En=是否读&是否这个Bank是要读的Bank( Wr allocated或Rd allocated)
                    - 即并行读第几块\*并行度（RdPortParBank）==自身第几块(读写口第几块都一样）：例如(IF_RdAddr>>7)*2 == BankRelIdx(reg在配置时，就可以自身第几块用for来遍历判断)

    - 计算读口数据往哪里去？大选择器取32个地址的哪几个：
        - 读口划分的是哪些Bank： RdPortBank组(由配置生成)
        - Bank组里，有哪些是上个周期RdEn（read_en_d）为高的，则这个周期就被取出来了
        - 注意，从RdPortRdy(RdPortEn)到RdPortDat会延时一个周期，相当于fifo的pop，vld&rdy取走的同时会再pop出一次相同addr的数据，
    - 每个Bank写口数据从哪里来？
        - 这个Bank分到哪个Port，第几个Bank(BankRelIdx), Port总共有多少个Bank Port的并行度WrPortNumBank
        - Port的并行度WrPortParBank
        - = PortDat_Arry[][ParIdx], BankWrPortParIdx, 表示Port并行写时，Port里第几个SRAM_WIDTH的数据的位置，是0, 1,..到WrPortParBank-1的循环，BankWrPortRelIdx是处于第几个循环
    - 多个Bank怎么实现同时读写？
        - 因为同一数据类型，读写分的Bank块组是相同的，可以控制En，使得写完第一块后，**同时读第一块和写第二块。**
    - bank被分配给新的port时，怎么重置相关信号
        - 只有bank里面的BankWrAddr_d和BankWrtn之类才是寄存信号，需要被重置，重置的条件是这个bank的口切换了：BankWrPortIdx_d[gv_i] != BankWrPortIdx[gv_i]
- 接口与ITF
    - 需要：
        - 配置指定：CCU指定哪些子模块侧的GLB口需要ITF来协助读写到DRAM，
        - 仲裁请求：从多个子模块GLB口到ITF一个口
        - 请求停止，ITF切换到下一个口
        - 方案1. 只用IIF一个口，ITF灵活游走在多个需要与DRAM交互的口：
            - 好处：ITF完全灵活了，减少约1/3口，不用穷举数据类型，而且符合实际上多少个口就该是多少个口的原则，再加上应该是配置口来主动读写的原则
            - 坏处：
                - GLB不通用了，需要额外输出addr来读写，与其它口作为slave不相符；
                - 从配置角度没有减少复杂度，反而让glb复杂
                - 
            - 过程：
                - CCU配置ITF口的flag需要协助哪些口
                - 当这些口rdy时，按照轮询仲裁，响应一个输出：idx给ITF+输出从bank继承的地址addr用来读取dram
                    - addr是bank保持的地址：需要有bank保持每个bank的地址的功能而不是port，下次写这些bank时，读或写（数据在SRAM不会丢失除非手动盖）
                - ITF根据idx（选择baseaddr）和addr读写dram，传给GLB相应的口
                - 如果rdy为0时，要丢弃这些数据需要判断是问题？，自动仲裁到下一个，发出新的idx和addr
                - ITF判断是新的idx，选择新的baseaddr
        - 方案2. GLB读写口是完全配对的，ITF在外部仲裁连接到它的口
            - 固定有几个口(类型)是专门给ITF的






 

