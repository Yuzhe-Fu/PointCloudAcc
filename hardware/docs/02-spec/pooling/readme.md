# [整个模块和所有子模块的硬件框图（实时维护）](pooling-2022-09-08.excalidraw)

# 文件列表
| File | Descriptions |
| ---- | ---- |
| pooling.v | 顶层模块 |
| multi_if.v | 多个pooling核读global buffer的接口模块 |
| pooling_core.v | 做pooling的核 |
| // out.v | 输出转换模块，多个pooling核写output buffer |
| comp_core.v | pooling里面具体做计算的核，比较做max, average |
| arb_net.v | 仲裁多个请求，选出一个请求信息输出，并响应请求 |
| fifo.v | 现成的模块，直接调用 |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| IDX_WIDTH | 10 | 10, 12 | 点的index位宽，1024个点即10b |
| MAP_DEPTH_WIDTH | 5 | | map的深度的位宽，Ball Query有32个邻近点，位宽为5 |
| RD_CMD_DEPTH_WIDTH | 2 | 2, 3 | 每个被读global buffer的指令FIFO深度 |
| 

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

## 模块陈述
是一个基于OS的脉动阵列，计算一个序列点与多个filter的一维卷积，activation按通道秦顺序输入并从左PE向右PE传，weight从上PE向下PE传，不同行输入不同的点，汪同列输入不同的filter。为了让activation的通道和weight的通道在PE内对应相乘，不同行PE的点的同一个通道，输入相差一个时钟周期。不同列的filter的相同通道输入也相差一个时钟周期。PE内乘加的结果，用MUX选出输出。


## pe 端口列表-包含于pe_array 端口列表（需要额外考虑反压）
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| out_act_left | output | ACT_WIDTH | 阵列右侧输出的activation |
| out_wgt_above | output | WGT_WIDTH | 阵列右侧输出的weight |
## 模块陈述

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
## 模块陈述
由于脉动阵列在PE从左向右传activation，导致同一个点的不同通道，是按时钟串行输出，但是如果下一层是pooling层，则需要一次取点的所有通道，则要求点的所有通道在时钟上对齐，形成一个word存入SRAM，因此需要设计这个同步整形模块


