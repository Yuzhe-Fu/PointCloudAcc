# [整个模块和所有子模块的硬件框图（实时维护）](global_buffer.excalidraw)

# 文件列表
| File          | Descriptions      |
| ----          | ----              |
| global_buffer.v | 顶层模块        |
| RAM_wrap.v    | 单个Bank封装模块  |
| SRAM_GB. v    | 所有Bank封装模块  |


# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| NUM_BANK | 32 |  | SRAM BANK的个数 |
| IF_WIDTH | 96 | | 接口的位宽，即数据pad个数 |
| BAND_IDX_WIDTH | LOG2(NUM_BANK) | | SRAM BANK的索引的位宽 |
| NUM_GLBPORT | 7 | |读写GLB总共口数 |

## global_buffer 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| --config-- | | | 顶层模块只分最顶层的东西，跟网络相关的，比如： |
| cfg_Port_BankIdx | input | NUM_BANK*NUM_GLBPORT | 每个Port分给读/写Bank是哪些，用1表示分了，0表示未被分，其实是一个矩阵LUT查表 |
| cfg_sa_mode | | | 决定act, weight, sa_fm的输出位宽 |
| --control-- |
| 每个读/写口一组控制信号，多组 |
| ctrl_wgt_finish | output | 1 | 电平信号，表示weight的SRAM BANK数被一次取完了，需要等待控制器装新的weight或不装，后让地址复位｜
| ctrl_wgt_reset | output | 1 | 电平信号，控制器让地址复位 |

| --data -- |
| in_if_data | input | IF_WIDTH | IF写入到SRAM的数 |
| in_if_vld |
| in_if_rdy |
| out_if_data |
| out_if_vld |
| out_if_rdy |
| out_sa_act |
| out_sa_act_vld |
| out_sa_act_rdy |
| out_sa_wgt |
| out_sa_wgt_vld |
| out_sa_wgt_rdy |
| in_sa_fm |
| in_sa_fm_vld |
| in_sa_fm_rdy |
| out_pool_fm |
| out_pool_fm_vld |
| out_pool_fm_rdy |
| in_pool_fm |
| in_pool_fm_vld |
| in_pool_fm_rdy |


# 模块陈述
**目标是写成通用的多Bank，多读写口的存储模块。**
将32块单口SRAM Bank并联，封装成32B*32宽，深为128的整个大的SRAM_GB具备自动SRAM读写功能，但需要顶层里面loop来控制地址复位，ctrl_finish和ctrl_reset信号。
FSM： IDLE， CFG，WORK;
- 写口：
    - IF根据数据类型和其分配的SRAM Bank ID，写入到Bank，位宽  固定为96b转成256b，固定为一个Bank位宽
    - SA写sa_fm  Bank，64B，固定为两个Bank位宽
    - POOL写pool_fm
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
  
- 计算每个单口Bank的输入地址：地址由各个SRAM Bank的读/写口的选择器生成
    - 来源：各个GLB读/写口的地址生成器：
        - CCU根据cfg_bank_type，控制地址计数器0-多少的地址范围，根据finish什么时候置0；
        - 自己根据能否读/写成功，控制什么时候INC，和读/写完发出finish到CCU
    - 选择：
        - 首先是判断是读/写，读优先
        - 分配的读/写口的Port_Idx：由配置的Bank_IdxGrp生成
    - AddrEn
        - Addr的选择器能决定接到口所分配的所有Bank的addr，但不同Bank的En肯定不一样，由Bank所在第几个Bank，和同时读取几个块决定
            - 如分配4个Bank，并行读2个，则第0个bank：是否En=并行读第几块\*并行度==自身第几块：例如(IF_RdAddr>>7)*2 == Relative_Idx
        - 有读不能写：单口SRAM
- 计算读口数据从哪里来？大选择器取32个地址的哪几个：
    - 读口划分的是哪些Bank： Bank_IdxGrp组，直接片外配置
    - Bank组里，有哪些是上个周期RdEn为高的，则这个周期就被取出来了
- 多个Bank怎么实现同时读写？
    - 因为同一数据类型，读写分的Bank块组是相同的，可以控制En，使得写完第一块后，**同时读第一块和写第二块。**
- **通用模块的SRAM输出怎么打拍？**

# addr_gen 端口列表
| | | |


 

