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
| clk                   | input     | 1 | clock |
| rst_n                 | input     | 1 | reset, 低电平有效 |
| --config--            |           | | 顶层模块只分最顶层的东西，跟网络相关的，比如： |
| CCUGLB_CfgVld | input | SRAM_WIDTH | 
| GLBCCU_CfgRdy | output | SRAM_WIDTH | 
| CCUGLB_CfgPort_BankFlg| input     | ($clog2(NUM_RDPORT) + $clog2(NUM_WRPORT))* NUM_BANK | 为每个Bank分配读/写Port是两个， |
| GLBCCU_Port_fnh       | output    | NUM_RDPORT+NUM_WRPORT | 电平信号，表示读写口完成配置的Loop次读写｜
| CCUGLB_Port_rst       | output    | NUM_RDPORT+NUM_WRPORT | 电平信号，重置Port所有信号 |
| CCUGLB_CfgPortMod     | input     | NUM_RDPORT+NUM_WRPORT | Port的读写模式 |
|CCUGLB_CfgRdPortLoop   | input     | LOOP_WIDTH*NUM_RDPORT | Port的读写总共圈数 |
|CCUGLB_CfgWrPortLoop   | input     | LOOP_WIDTH*NUM_WRPORT | Port的读写总共圈数 |
| CCUGLB_CfgPort_AddrMax |input     | 
| CCUGLB_CfgRdPortParBank|input     | 
| CCUGLB_CfgWrPortParBank|input     | 
| ITFGLB_Dat            | input     | IF_WIDTH | IF写入到SRAM的数 |
| ITFGLB_DatVld         | input     |
| GLBITF_DatRdy         | output    |
| GLBITF_Dat            | output    |
| GLBITF_DatVld         | output    |
| ITFGLB_DatRdy         | input     |
| GLBSYA_Act            | output    |
| GLBSYA_ActVld         | output    |
| SYAGLB_ActRdy         | input     |
| GLBSYA_Wgt            | output    |
| GLBSYA_WgtVld         | output    |
| SYAGLB_WgtRdy         | input     |
| SYAGLB_Fm             | input     |
| SYAGLB_FmVld          | input     |
| GLBSYA_FmRdy          | output    |
| GLBPOL_Fm             | output    |
| GLBPOL_FmVld          | output    |
| POLGLB_FmRdy          | input     |
| POLGLB_Fm             | input     |
| POLGLB_FmVld          | input     |
| GLBPOL_FmRdy          | output    |


# 模块陈述
**目标是写成通用的多Bank，多读写口的存储模块。**
将32块单口SRAM Bank并联，封装成32B*32宽，深为128的整个大的SRAM_GB具备自动SRAM读写功能，GLB的功能应该是完整的，CCU只能配置，不能直接控制，只配置bank的性质，只需要顶层里面loop来控制读完写完的复位。读写口统一为多个二维阵列，RdPortDat_Array和WrPortDat_Array，宽度取最大并行度MAXPAR，在综合时会去除掉无用的口。
FSM控制： IDLE， CFG，WORK; 只有配置好了，进入WORK状态，对于araddrvld和wvalid才有可能有效

- 写口：
    - 0: IF根据数据类型和其分配的SRAM Bank ID，写入到Bank，位宽  固定为96b转成256b，固定为一个Bank位宽
    - 1: SA写sa_fm  Bank，64B，固定为两个Bank位宽
    - 2: POOL写pool_fm
- 读口：
    - IF读
    - SA读sa_fm(act/ofm)
    - SA读weight
    - POOL读sa_fm，固定为64B*6，12个Bank位宽

- 存的数据类型：
    - activation
    - weight
    - sa_fm
    - mp_fm
- Port的读写模式：
    - Mode0: 一次写的数固定到Bank，循环读，读的RdLoop表示复用次数
    - Mode1: 写入的数只被读一次，相当于串入串出的FIFO，Loop没有实际意义

- 计算每个单口Bank的输入地址：地址由各个SRAM Bank的读/写口的选择器生成
    - 来源：各个GLB读/写口的地址生成器：
        - CCU根据CCUGLB_CfgPort_BankIdx，控制地址计数器0-多少的地址范围，当达到最大值时，根据port读写模式：
            - 模式0：写满后固定，再循环读时，WrPortAddr等待统一CCUGLB_Port_rst；RdPort未满Loop自动置位。
            - 模式1：Wrport地址计数器在WrLoop未满时，自动CLEAR；RdPort也是一样
        - 自己根据能否读/写成功(Port对应的Bank只要有arrvalid & arready握手），控制什么时候INC,CLEAR还有让地址重新有效即启动读写的功能
    - 选择：
        - 首先是判断是读/写，读优先
        - 分配的读/写口的Port_Idx：由配置的RdPortBank生成
    - AddrEn
        - 有读写请求才读写使能，直接用端口的RdPortDatRdy作为arvalid的一部分，和WrPortDatVld作为wvalid的一部分
        - Addr的选择器能决定接到口所分配的所有Bank的addr，但不同Bank的En肯定不一样，由Bank所在第几个Bank，和同时读取几个块决定
            - 如分配4个Bank，并行读2个，则第0个bank：是否En=是否读&是否这个Bank是要读的Bank( Wr allocated或Rd allocated)
                - 即并行读第几块\*并行度（RdPortParBank）==自身第几块(读写口第几块都一样）：例如(IF_RdAddr>>7)*2 == BankRelIdx(reg在配置时，就可以自身第几块用for来遍历判断)
        - 有读不能写：单口SRAM
        - 读空写满：
            - 读：有写入了数才能读：假定读写口分配相同Bank且读写顺序一致，则非空时可以读，即RdEn= !(RdAddr == WrAddr); 且读写同一圈RdLoop == WrLoop，（圈数GLB自己控制，GCCU只负责配置，比如有多少圈，当Mode0时，WrAddr大于最后一个有效地址，当RdAddr也最后一个有效地址时，发出fnh，然后复位0）
            - 写：有写满的存在(像FIFO），只当串入串出时，RdAddr==WrAddr且写多一圈RdLoop < WrLoop

- 计算读口数据往哪里去？大选择器取32个地址的哪几个：
    - 读口划分的是哪些Bank： RdPortBank组(由配置生成)
    - Bank组里，有哪些是上个周期RdEn（read_en_d）为高的，则这个周期就被取出来了
    - 注意，从RdPortRdy(RdPortEn)到RdPortDat会延时一个周期，相当于fifo的pop，vld&rdy取走的同时会再pop出一次相同addr的数据，
- 每个Bank写口数据从哪里来？
    - 这个Bank分到哪个Port，第几个Bank(BankRelIdx), Port总共有多少个Bank Port的并行度WrPortNumBank
    - Port的并行度WrPortParBank
    - = PortDat_Arry[][ParIdx], ParIdx=WrPortNumBank % WrPortParBank, 表示Port并行写时，Port里第几个SRAM_WIDTH的数据的位置
- 多个Bank怎么实现同时读写？
    - 因为同一数据类型，读写分的Bank块组是相同的，可以控制En，使得写完第一块后，**同时读第一块和写第二块。**
- 通用模块的SRAM输出怎么打拍？师姐没有刻意打拍

# 下一步
- 合并读写的generate


 

