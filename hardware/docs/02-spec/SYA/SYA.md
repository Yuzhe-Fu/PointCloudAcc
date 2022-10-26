# [整个模块和所有子模块的硬件框图（实时维护）](PointCloudAccelerator_Design_01_Systolic_Array-2022-09-6.excalidraw)

# 文件列表
| File | Descriptions |
| ---- | ---- |
| pe_array.v | 脉动阵列顶层模块 |
| pe.v | 单元模块 |
| pe_row.v | 一行单元模块 |
| pe_bank.v | 一个pe bank |
| sync_shape.v | 将一个点的按周期顺序出来的不同通道，整形成一个word输出 |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| ACT_WIDTH | 8 | 4, 16 | activation的位宽 |
| WGT_WIDTH | 8 | 4, 16 | weight的位宽 |
| ACC_WIDTH | 26 | | 累加器的位宽，ACT_WIDTH + WGT_WIDTH +LOG(通道深度) |
| NUM_ROW   | 16 | | PE阵列的行数 |
| NUM_COL   | 16 | | PE阵列的列数，默认是正方形阵列即NUM_COL=NUM_ROW | 
| NUM_BANK  | 4 | | PE有多个Bank |
| SRAM_WIDTH | 256 | | SRAM Bank的位宽 |
| CHN_WIDTH | 12 | 通道数的位宽 |
| QNTSL_WIDTH | 20 | | 量化的scale位宽 |
| IDX_WIDTH  | 16 | Nip（输入点的个数）的位宽 |
## pe_array 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| C input | 1 | clock |
| C | input | 1 | reset, 代电平有效 |
| --control-- |
| CCUSYA_Rst |
| --config-- |
| CCUSYA_CfgVld | 
| SYACCU_CfgRdy | 
| CCUSYA_CfgMod | input | 2 | 0: 4个bank按照2x2排列，1: 按照1x4排列，2: 按照4x1排列 |
| CCUSYA_CfgNip
| CCUSYA_CfgChi
| -- config Quantization-- |
| CCUSYA_CfgScale | input | 20 | quant_psum = (computed_psum * quant_scale) >> quant_shift + quant_zero_point； 根据量化公式：y_q = y_f * s_y = (x_f\*w_f + b_f)\*s_y = Scale_y * x_q\*w_q + zero_point_y; 其中scale_y是小数，暂时用* quant_scale) >> quant_shift来近似 |
| CCUSYA_CfgShift | input | ACT_WIDTH | 同quant_scale |
| CCUSYA_CfgZp | input | ACT_WIDTH | 同quant_scale |
| --data-- |
| GLBSYA_Act    | input | ACT_WIDTH\*NUM_ROW\*NUM_BANK | 阵列左侧输入的activation |
| GLBSYA_ActVld | input | 1 | 握手协议的valid信号 |
| SYAGLB_ActRdy | output | 1 | 握手协议的ready信号 |
| GLBSYA_Wgt    | input | WGT_WIDTH\*NUM_COL\*NUM_BANK | 阵列左侧输入的weight |
| GLBSYA_WgtVld | input | 1 | 握手协议的valid信号 |
| SYAGLB_WgtRdy | output | 1 | 握手协议的ready信号 |
| SYAGLB_Ofm    | output | ACT_WIDTH\*NUM_ROW\*NUM_BANK | 阵列输出计算结果feature map |
| SYAGLB_OfmVld | output | 1 | 握手协议的valid信号 | 
| GLBSYA_OfmRdy | input | 1 | 握手协议的ready信号 |
<!-- | --control-- |
| CCUSYA_EnLeft | input | 1 | 不需要，只需要千诉有多少个点CCUSYA_CfgNip，整个PE 阵列的使能输入信号，高电平时，执行乘加操作和PE手机拍输出activation, weight, 和in_acc_reset_right，一个PE row的不同PE通过依次打拍第一个PE来获得相应的en，不同pe row，通过依次打拍PE row的第一个PE来获得相应的en; 目前没有反压机制，全靠控制en信号 |
| CCUSYA_AccRstLeft | input | 1 | 不需要，告诉有多少输入通道CCUSYA_CfgChi，传递同in_en_left，高电平时，PE内的累加器不向加法器输出值，给加法器输入0；同时表示累加器已完成累加，累加值是有效的，需要被取走 | -->

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


