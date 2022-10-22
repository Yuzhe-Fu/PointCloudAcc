# [整个模块和所有子模块的硬件框图（实时维护）](global_buffer.excalidraw)

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
| CCUGLB_CfgVld             | i nput | NUM_PORT | 每个Port单独配置和使能，vld rdy取代rst和fnh, 重置Port所有信号
| GLBCCU_CfgRdy             | output | NUM_PORT | 表示读写口完成配置的addrmax次读写
| CCUGLB_CfgBankPort        | input     | (NUM_RDPORT + NUM_WRPORT)* NUM_BANK | 为每个Bank分配读/写Port是两个，1表示有分到，也表示Port是否有效 |
| CCUGLB_CfgPort_AddrMax |input     | 
| CCUGLB_CfgRdPortParBank|input     | 
| CCUGLB_CfgWrPortParBank|input     | 

# 模块陈述
**目标是写成通用的多Bank，多读写口的存储模块。**
将32块单口SRAM Bank并联，封装成32B*32宽，深为128的整个大的SRAM_GB具备自动SRAM读写功能，GLB的功能应该是完整的，CCU只能配置，不能直接控制，只配置bank的性质，只需要顶层里面addrmax和numbank来控制读完写完的复位（addrmax/numbank是圈数，真实地址是=addr%(numbank\*128)=(addr>>7)%numbank）。读写口统一为多个二维阵列，RdPortDat_Array和WrPortDat_Array，宽度取最大并行度MAXPAR，在综合时会去除掉无用的口。
FSM控制： IDLE， CFG，WORK; 只有配置好了，进入WORK状态，对于araddrvld和wvalid才有可能有效

- 写口：
    - 0: IF写Act：IF写都是1个SRAM_WIDTH
    - 1: IF写Wgt：~
    - 2：IF写Crd：~
    - 3: IF写MAP：~
    - 4: SA写sa_fm SYAGLB_Ofm：2个Bank，64B，固定为两个Bank位宽，不随CCUSYA_CfgMod
    - 5: POOL写pool_fm POLGLB_Fm: 2个Bank，64个比较器出，就64出，要是channel=128，就两次loop，写两次64
    - 6: CTR写Dist CTRGLB_DistIdx：固定最少的一个Bank
    - 7: CTR写MAP CTRGLB_Map：固定最少的一个Bank
- 读口：
    - 0: IF读MAP：IF读都是1个SRAM_WIDTH
    - 1: IF读ofm：IF读都是1个SRAM_WIDTH
    - 2: SA读sa_fm(act/ofm) GLBSYA_Act：连接位宽是SYA_NUM_BANK，实际位宽是根据CCUSYA_CfgMod：0时2，1时1，2时4
    - 3: SA读weight GLBSYA_Wgt：连接位宽是SYA_NUM_BANK，实际位宽是根据CCUSYA_CfgMod：0时2，1时4，2时1
    - 4: CTR读Crd GLBCTR_Crd：固定最少的一个Bank
    - 5: CTR读Dist GLBCTR_DistIdx：固定最少的一个Bank
    - 6: POL读MAP GLBPOL_Map：固定最少的一个Bank
    - 7-12: POOL读sa_fm GLBPOL_Fm：固定为64B*6，12个Bank位宽

localparam GLBWRIDX_ITFACT = 0;
localparam GLBWRIDX_ITFWGT = 1;
localparam GLBWRIDX_ITFCRD = 2;
localparam GLBWRIDX_ITFMAP = 3;
localparam GLBWRIDX_SYAOFM = 4;
localparam GLBWRIDX_POLOFM = 5;
localparam GLBWRIDX_CTRDST = 6;
localparam GLBWRIDX_CTRMAP = 7;

localparam GLBRDIDX_ITFMAP = 0;
localparam GLBRDIDX_ITFOFM = 1;
localparam GLBRDIDX_SYAACT = 2;
localparam GLBRDIDX_SYAWGT = 3;
localparam GLBRDIDX_POLOFM = 4;
localparam GLBRDIDX_POLMAP = 5;
localparam GLBRDIDX_CTRCRD = 6;
localparam GLBRDIDX_CTRDST = 7;

- 存的数据类型：
    - activation
    - weight
    - sa_fm
    - mp_fm
- Port的读写模式：
    - 读写都是由远大于深度的AddrMax控制一次还是循环读写

- 配置：
    - **注意要求：口对应的配置Bank是连续的（由于ParBank是直接向上加），Bank深度必须是2的指数（由于地址raddr/waddr直接截取）**
    - 由于需要不中断其它口实时动态配置Bank，因此CCU给GLB的所有配置和控制信号需要同一个周期变，
    - 而且给Bank都要是reg信号
    - 因此把CfgVld和CfgInfo，组合逻辑从原始配置生成所有需要的控制的信号,因为采用口不复用方式，配置CCUGLB_CfgPortBank即可，先不打拍
- 控制：每个口有一套控制逻辑，控制生成addr, PortEn等，然后每个Bank根据BandPortIdx来选取Port的信号。
    - 地址来源：用是否分配到读写口来选择来源1和来源2
        - 来源. 各个GLB读/写口的地址生成器：（采用口不复用方式，也不用保持上次读的地址）
            - 模式0：连续读数，计数器自动生成
                - CCU根据CCUGLB_CfgPort_AddrMax，控制地址计数器0-多少的地址范围，当达到最大值addrmax时，写等CfgVld重新配置置位，读直接循环
                - 自己根据能否读/写成功(Port对应的Bank只要有arrvalid & arready握手），控制什么时候INC,CLEAR还有让地址重新有效即启动读写的功能
                - 但写地址作为判断读地址，当写口如ITF移走时，写地址是空：
                    - 每个Bank需要保持读口对应的写地址来判断空满
                        - 读这一大块Bank应该会保留之前写的地址：但地址不能由每个bank内部产生，需要额外一个表来记录每个Bank的读写地址：当有分到写口时，以写口为准，没有则以表为准
                        - 在下一次换写的时候被更新
            - **模式1**：输入地址来跳着读写，读空判断写满判断不变，但输出的ReqNum和Addr是实变的，而且之前读过的不能被盖，目前需要addr的是接CTR和POL的不是ITF，因此不需要，先不管
    - 读写使能生成
        - 有读写请求才读写使能，直接用端口的RdPortDatRdy作为arvalid的一部分，和WrPortDatVld作为wvalid的一部分
        - 读空写满：
            - 读：有写入了数才能读：假定读写口分配相同Bank且读写顺序一致，则非空时可以读，即RdEn= !(RdAddr == WrAddr); 且RdAddr=WrAddr，（圈数GLB自己控制，GCCU只负责配置，比如有多少圈，当Mode0时，WrAddr大于最后一个有效地址，当RdAddr也最后一个有效地址时，发出CfgRdy，然后复位0）
            - 写：有写满的存在(像FIFO），只当串入串出时，RdAddr相差WrAddr一圈(AddrMax)
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
- 通用模块的SRAM输出怎么打拍？师姐没有刻意打拍

# 下一步



 

