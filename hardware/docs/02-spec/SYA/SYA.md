# 问题：
- 无x态
- 适应将多层直切分块：也是MLP融合：
    - CCU具备控制SYA无缝切换下一层的Wgt和一块Act的读取， 还有输出OFM存的地址  由CCU控制需要流水线跟随计算结果
    - 当少filter且浅通道时，如filter剪枝之后的均少至16个，以16个FLT和2个chn为例
        - 先不管shift，直接默认按chn grp tileifm 有shift在SRAM密集排列不变
        - 而SYA算2个chn就直接取2个WORD的IFM和Flt，boost进BANK就行
        - 然后，IFM的SRAM连续继续取，FLT的SRAM倒回来重复取2个WORD
        - OFM的地址计算还是按照哪一个grp tileifm和tileflt计算
        - state切换方案
            - **必然**state不必等输出完成WAITFNH，而是自动到IDLE等配置，通过流水线传到后面，但问题是读写哪个GLB还是没变，**会导致地址从第一轮的高到第二轮的0有问题，除非给GLB的flag也随流水线??????**或者让GLB支持乱序读写?????
                - 后面考虑增加方案2的整形模块
            - state保留INSHIFT和WAITFNH，那么就要切断此时的输入？但是启动流水线又要SHIFT延迟，相当于两倍即64的延迟，但16chn的256点，flt是16个，总计算时间也才16*256/32=128，**占了一半不能容忍！**

- 优化面积
    - 看Mux是否太大？实验组是替换为拼接16个output的最高位MSB（保证其它位不会被综合掉）

# 文件列表
| File | Descriptions |
| ---- | ---- |---- | ---- |  
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
| CCUSYA_CfgMod | input | 2 | 0: 4个bank按照2x2排列(Act在W,Wgt在N)，1: 按照1x4排列(Act在W,Wgt在N)，2: 按照4x1排列 |
| CCUSYA_CfgNip
| CCUSYA_CfgChn
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
| CCUSYA_AccRstLeft | input | 1 | 不需要，告诉有多少输入通道CCUSYA_CfgChn，传递同in_en_left，高电平时，PE内的累加器不向加法器输出值，给加法器输入0；同时表示累加器已完成累加，累加值是有效的，需要被取走 | -->

## 模块陈述
 - 设计考量：
    - 是一个基于OS的脉动阵列，计算一个序列点与多个filter的一维卷积，
    - 一块点要不间断计算：配置的Nip不是一层网络的所有点，而是这种Bank配置下，一直计算的点数
    - 至于多个点块和filter块怎么进行倒，由CCU控制，组合有很多种(>2)，重新配置Nip，ActRdBaseAddr
 - 输入：
    -     

 - 输出：
 - 计算过程
    - activation按通道秦顺序输入并从左PE向右PE传，weight从上PE向下PE传，不同行输入不同的点，汪同列输入不同的filter。
    - 为了让activation的通道和weight的通道在PE内对应相乘，不同行PE的点的同一个通道，输入相差一个时钟周期。不同列的filter的相同通道输入也相差一个时钟周期。PE内乘加的结果，用MUX选出输出。
    -考虑到卷积A和F会tiling，外层循环是块数（最外层次外层是A或F），最内层是A_tile的size多少个组点（以一次输入为一组）和W_tile，还要配置外层IFM的tile数，Filter的tile数，外层的顺序, 每个for循环都是一个计数器
        - CfgMod
        - NumGrpPerTile: 左和上的一个Tile的列和行数
        - NumTilIfm, NumTilFlt
        - LopOrd: Ifm的几个tile与Filter的tile是怎么loop的，默认是0：先取一个Ifm tile来loop所有的Filter的Tile
        - for IdxTilIfm in NumTilIfm:
            for IdxTilFlt in NumTilFlt:
                for IdxGrp in NumGrpInTile:
                    for IdxChn in CfgChn:
                        OFM[NumGrpInTile*IdxTilIfm + IdxGrp][NumTilFlt*IdxTilFlt + IdxGrp] +=  IFM[NumGrpInTile*NumGrpInTile*IdxTilFlt + NumGrpInTile*IdxGrp + IdxChn][]*FLT[][]// [point][channel]
    - 输出整形模块PhaseShift
        - 只在接mp才有用到，mlp也是shift的连续串行通道(怎么正确得出ofm地址是关键)，直接增加一个CCUSYA_CfgPhaseShift来bypass
        - pol暂时需要整形模块：考虑修正为读入的也是shift的，这样会有一个sram word里有多个连续的点的问题，可能无法取到需要的指定点的问题
    - 输入相移(Phase Shift)导致只loop复用一组点（比如32时），PE利用率降低：暂定方案1，下次优化考虑方案3
        - 问题陈述
            - 原因：斜形导致NUM_ROW的周期浪费，利用率是C/(C+NUM_ROW)：比如32个点要计算完所有的filter，就要求这32个点不间断地输入，但是由于shift菱形，后一个点得重叠下一块的，怎么重叠当前块的呢？由输入格式决定，如果输入格式是shift的，不可能首尾相接(通道为64时，P1C63上面是P0C0）
        - 方案1：不管了，由1x4的模式甚至是1x16的模式来减少利用率降低，而且1x1卷积占与filter可以互换
            - 每层网络的有效计算时间比例是：C/(C+NUM_ROW)\*( (Nf/NUM_COL)*Nip/NUM_ROW )：当Nf >= NUM_COL时Nf/NUM_COL=1
                - 1x4模式下PointMLP:影响
                    - conv1: 3/(3+16)\*( 32/64*1) = 0.078
                    - conv2: 32/(32+16) = 0.67
                    - conv3: 64/(64+16) = 0.8
                    - conv4: 16/(16+16) = 0.5
                    - conv5：64/(64+64) = 0.5
                    - conv6: 16/(16+16) = 0.5
                    - 总体：经excel计算，
                        - 最好情况（NUM_ROW=16)：有16%的时间增加；
                        - 最差情况（NUM_ROW=32): 有33%的时间增加；
                        - 修改SYA为1x16, NUM_ROW=8, 有8%时间增加；说明时间增加与NUM_ROW成反比
                - 1x4模式下PointNeXt-S
                    - conv1: 3/(3+16)*(32/64) = 0.078
                    - conv2: 32/(32+16) = 0.67
                    - conv3: 0.67
                    - conv4: 0.67
                    - conv5: 64/(64+16) = 0.8
                    - conv6: 64/(64+16) = 0.8
                    - conv7: 64/(64+16) = 0.8
                    - conv8: 128/(128+16) = 0.89
                    - 
        - 方案2：解决根源在G0左下角会取到G1右上角的是因为存在SRAM的格式是斜形，改为正形存，一个word存多个点的相同通道。但是需要整形延迟模块来转换，浪费大
        - 方案3：复杂一点，按硬件的逻辑而不是理解的逻辑，在最后一轮时，G0左上角填G1右上角，与G0,G1生成的循序相符，但是复杂很多
        - 方案4：不要用以C为单位进行loop，而是调整策略为多个点比如至少16个点，来降低shift的比重；问题是出来的是一个点的所有输出channel group不连续，间隔点数*Chn后，再次输出这个点的channel group1，要求后期shift一个点的所有通道，始终只有loop复用点这一种模式来得到所有通道，没法处理，除非改变只有loop复用点这一种模式:question:



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


