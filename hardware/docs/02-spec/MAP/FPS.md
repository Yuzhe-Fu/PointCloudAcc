# 问题

# 文件列表
| File | Descriptions |
| ---- | ---- |
| FPS.v | 顶层模块 |
| EDC.v | 欧式dist_comp欧式距离计算模块 |
| RAM.v | 通用SRAM模块，直接在primitives调用 |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| CRD_WIDTH | 16 | 8 | 坐标x, y, z的位宽 |
| NUM_COORD | 3 |  | 坐标的维度，默认是3维 |
| DIST_WIDTH | LOG2(NUM_COORD\*COORD_WIDTH^2) | 17 | 距离的位宽 |
| NUM_SORT_CORE | 8 | | 排序的核数 | **必须是2的指数** |
| NUM_FPS_WIDTH | 3 | | FPS的层数位宽，层数需小于NUM_SORT_CORE |
| K_WIDTH | 5 | | KNN邻点个数的位宽 |
| IF_WIDTH | 96 | | SRAM Bank的位宽 |

## construct 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| --control-- |
| CCUCTR_Rst | input | 1 | 整个网络完成后Rst |
| --config-- |
| CCUCTR_CfgVld
| CTRCCU_CfgRdy
| CCUCTR_CfgMod | input | 1 | 0: 执行FPS，1: 执行KNN |
| CCUCTR_CfgNip | input | IDX_WIDTH | 第一层输入点的个数，1023表示1024个点 |
| CCUCTR_CfgNop | IDX_WIDTH |   | FPS筛选出的点数 |
| CCUCTR_CfgK   | input | K_WIDTH | KNN需要找出多少个邻近点,最大是32 |
| --data-- |
| CTRGLB_CrdAddr    | output | IDX_WIDTH |  |
| CTRGLB_CrdAddrVld | output | 1 | 握手协议的valid信号 |
| GLBCTR_CrdAddrRdy | input | 1 | 握手协议的ready信号 |
| GLBCTR_Crd        | input | SRAM_WIDTH | 输入的坐标 |
| GLBCTR_CrdVld     | input | 1 | 握手协议的valid信号 |
| CTRGLB_CrdRdy     | output | 1 | 握手协议的ready信号 |
| CTRGLB_DistAddr   | output | IDX_WIDTH |  |
| CTRGLB_DistAddrVld| output | 1 | 握手协议的valid信号 |
| GLBCTR_DistAddrRdy| input | 1 | 握手协议的ready信号 |
| GLBCTR_DistIdx       | input | SRAM_WIDTH | 输入的距离 |
| GLBCTR_DistIdxVld    | input | 1 | 握手协议的valid信号 |
| CTRGLB_DistIdxRdy    | output | 1 | 握手协议的ready信号 |
| CTRGLB_Map        | output | SRAM_WIDTH | 输出KNN构建的map，即排序好的K个最近的点的idx |
| CTRGLB_MapVld     | output | 1 | 握手协议的valid信号 |
| CTRGLB_MapRdy     | input | 1 | 握手协议的ready信号 |


## 模块陈述
    - FPS输出有
        - 给MLP说明原始点中哪些点是保留下来的，即在原始点集中的Index
        - FPS的输出点的Idx是否需要重头编号：输出是给KNN的MAP用于POL，因此是密集排列的，需要重头编号！那就没必要存PntIdx了
    - 多核FPS的必要性：1. 分块计算的必然；2. Crd输入SRAM带宽满足5个核，Mask满足256个核，Dist输入满足256/34/2=3.7个核，暂定为4个核并行。
    - FPS输入有
        - KNN与FPS的CrdIdx存储方式不一致：FPS是做完所有层，连续存CrdIdx，而KNN是只算一层，考虑到高配置性来适应分块的点数随机性，需要对FPS和KNN每层配置：FPS读起始CrdIdx地址CCUFPS_CfgCrdBaseRdAddr（默认每层从新的SRAM WORD开始写，不存在从WORD中间开始读写)，Nip, Nop，写起始CrdIdx地址CCUFPS_CfgCrdBaseWrAddr，读写Mask起始地址CCUFPS_CfgMaskBaseAddr（考虑到多个FPS核并行共享SRAM带宽，同时算第一层，写的地址不一样，写最后一个WORD不论是否凑够SRAM_WIDTH都要写出去），写使用地址控制Dist读写;
    - FPS中间缓存有
        - Mask
            - 直接加Mask SRAM表示是否需要计算来跳过无效的计算周期：FPS在一层计算中，需要知道已被筛选出的点，否则导致1/4速度下降（Nop/Nip=1/2)，设计MaskCheck来找出为0的点，MaskCheck保留了点的自然顺序，不能用保留下来点的Idx，因为它是随机乱序的。
            - 取得的Mask需要与CrdRdAddr同周期：取完了需要同时控制CrdRdAddrVld？






