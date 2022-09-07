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
| ---- | ---- | ---- | ---- |
| ACT_WIDTH | 8 | 4, 16 | activation的位宽 |
| WGT_WIDTH | 8 | 4, 16 | weight的位宽 |
| ACC_WIDTH | 26 | | 累加器的位宽，ACT_WIDTH + WGT_WIDTH +LOG(通道深度) |
| NUM_ROW | 16 | | PE阵列的行数 |
| NUM_COL | 16 | | PE阵列的列数，默认是正方形阵列即NUM_COL=NUM_ROW | 
| NUM_BANK | 4 | | PE有多个Bank |
| SRAM_WIDTH | 256 | | SRAM Bank的位宽 |

## pe_array 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 代电平有效 |
| --config-- |
| mode | input | 2 | 0: 4个bank按照2x2排列，1: 按照1x4排列，2: 按照4x1排列 |
| -- config Quantization-- |
| quant_scale | input | 20 | quant_psum = (computed_psum * quant_scale) >> quant_shift + quant_zero_point； 根据量化公式：y_q = y_f * s_y = (x_f\*w_f + b_f)\*s_y = Scale_y * x_q\*w_q + zero_point_y; 其中scale_y是小数，暂时用* quant_scale) >> quant_shift来近似 |
| quant_shift | input | ACT_WIDTH | 同quant_scale |
| quant_zero_point | input | ACT_WIDTH | 同quant_scale |
| --data-- |
| in_act_left | input | ACT_WIDTH\*NUM_ROW\*NUM_BANK | 阵列左侧输入的activation |
| in_act_left_vld | input | 1 | 握手协议的valid信号 |
| in_act_left_rdy | output | 1 | 握手协议的ready信号 |
| in_wgt_above | input | WGT_WIDTH\*NUM_COL\*NUM_BANK | 阵列左侧输入的weight |
| in_wgt_above_vld | input | 1 | 握手协议的valid信号 |
| in_wgt_above_rdy | output | 1 | 握手协议的ready信号 |
| out_fm | output | ACT_WIDTH\*NUM_ROW\*NUM_BANK | 阵列输出计算结果feature map |
| out_fm_vld | output | 1 | 握手协议的valid信号 | 
| out_fm_rdy | input | 1 | 握手协议的ready信号 |
| --control-- |
| in_en_left | input | 1 | 整个PE 阵列的使能输入信号，高电平时，执行乘加操作和PE手机拍输出activation, weight, 和in_acc_reset_right，一个PE row的不同PE通过依次打拍第一个PE来获得相应的en，不同pe row，通过依次打拍PE row的第一个PE来获得相应的en; 目前没有反压机制，全靠控制en信号 |
| in_acc_reset_left | input | 1 | 传递同in_en_left，高电平时，PE内的累加器不向加法器输出值，给加法器输入0；同时表示累加器已完成累加，累加值是有效的，需要被取走 |

## pe 端口列表-包含于pe_array 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| out_act_left | output | ACT_WIDTH | 阵列右侧输出的activation |
| out_wgt_above | output | WGT_WIDTH | 阵列右侧输出的weight |

## pe_row 端口列表-包含于pe_array 端口列表和pe 端口列表
## pe_bank 端口列表-包含于pe_array 端口列表和pe 端口列表

## sync_shape 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| in_data | input | ACT_WDITH\*NUM_ROW\*NUM_BANK | 不同点同一周期出来的channel |
| in_data_vld | input | NUM_ROW\*NUM_BANK | 不同点同一周期出来的channel的有效信号 |
| in_data_rdy | output | NUM_ROW\*NUM_BANK | 不同点同一周期出来的channel的ready信号 |
| out_data | output | SRAM_WIDTH\*2 | 同一个点的不同channel同时出来 |
| out_data_vld | output | 2 | |
| out_data_rdy | input | 2 | |



