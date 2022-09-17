# Task List
- FPS KNN的概念
- 结合硬件图数据流


# [整个模块和所有子模块的硬件框图（实时维护）](global_buffer.excalidraw)

# 文件列表
| File | Descriptions |
| ---- | ---- |
| global_buffer.v | 顶层模块 |
| RAM_wrap.v | 单个Bank封装模块 |
| SRAM_GB. v | 所有Bank封装模块 |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| NUM_BANK | 32 |  | SRAM BANK的个数 |
| IF_WIDTH | 96 | | 接口的位宽，即数据pad个数 |
| BAND_IDX_WIDTH | LOG2(NUM_BANK) | | SRAM BANK的索引的位宽 |

## global buffer 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| --config-- | | | 顶层模块只分最顶层的东西，跟网络相关的，比如： |
| cfg_bank_type | input | 3*NUM_BANK | 每个Bank分给什么数据类型 |
| cfg_sa_mode | | | 决定act, weight, sa_fm的输出位宽 |
| --data -- |
| in_if_data |
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
将32块单口SRAM Bank并联，封装成32B*32宽，深为128的整个大的SRAM_GB。
- 写：
  - IF根据数据类型和其分配的SRAM Bank ID，写入到Bank，位宽固定为96b转成256b，固定为一个Bank位宽
  - SA写Bank，64B，固定为两个Bank位宽
  - POOL写
- 读：
  - IF读
  - SA读act和weight
  - POOL读，固定为64B*6，12个Bank位宽
- 存的数据类型：
  - activation
  - weight
  - sa_fm
  - mp_fm
  
- 计算每个单口Bank的输入地址：
  - 预先定读或写，
  - 地址由各个读/写口的仲裁器
  - 地址生成器
  - 分配的ID来定
- 计算读口数据从哪里来？大选择器取32个地址的哪几个：
  - 哪几个Bank拼成就行
