## 文件列表
| File | Descriptions |
| ---- | ---- |
| pe_array.v | 脉动阵列顶层模块 |
| pe.v | 单元模块 |
| pe_row.v | 一行单元模块 |
| pe_bank.v | 一个pe bank |
| sync_shape.v | 将一个点的按周期顺序出来的不同通道，整形成一个word输出 |

## 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- |
| ACT_WIDTH | 8 | 4, 16 | activation的位宽 |
| WGT_WIDTH | 8 | 4, 16 | weight的位宽 |
| ACC_WIDTH | 26 | | 累加器的位宽，ACT_WIDTH + WGT_WIDTH +LOG(通道深度) |
| NUM_ROW | 16 | | PE阵列的行数 |
| NUM_COL | 16 | | PE阵列的列数，默认是正方形阵列即NUM_COL=NUM_ROW | 
| NUM_BANK | 4 | | PE有多个Bank |

## 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 代电平有效 |
| --config-- |
| mode | input | 2 | 0: 4个bank按照2x2排列，1: 按照1x4排列，2: 按照4x1排列
| in_act_left | input | ACT_WIDTH\*NUM_ROW\*NUM_BANK | 阵列左侧输入的activation |
| in_act_left_vld | input | 1 | 握手协议的valid信号 |
| in_act_left_rdy | output | 1 | 握手协议的ready信号 |
| in_wgt_up | input | WGT_WIDTH\*NUM_COL\*NUM_BANK | 阵列左侧输入的weight |
| in_wgt_up_vld | input | 1 | 握手协议的valid信号 |
| in_wgt_up_rdy | output | 1 | 握手协议的ready信号 |
| out_fm | output | ACT_WIDTH\*NUM_ROW\*NUM_BANK | 阵列输出计算结果feature map |
| out_fm_vld | output | 1 | 握手协议的valid信号 | 
| out_fm_rdy | input | 1 | 握手协议的ready信号 |




