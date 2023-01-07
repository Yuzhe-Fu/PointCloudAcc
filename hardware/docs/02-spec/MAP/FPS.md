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
构建模块是用来将原始点云采样（FPS)后，找出每个点的K邻近点的index（K个index称为这个点的map即映射）。在顶层模块construct硬件图中，FPS和KNN复用部分硬件（黑色），FPS独有的是青色，KNN独有的是蓝色。在子模块中一律用黑色，不作区别，CTR分为FPS模块，KNN模块和共同部分，用流水线顺序分级分块写。
Mask也使用GLB存储：为了便于KNN一次取所有层的Mask的bit，在GLB中，先按照一个点的所有层从LSB到MSB，再下一个点；向GLB请求的地址是LopIdx与GLB的word存多少个点（SRAM_WIDTH/NUM_SORT_CORE)的取整，一次到的是SRAM_WIDTH，怎么区别是哪NUM_SORT_WIDTH宽的呢？是LopIdx与GLB的word存多少个点的取余
    - 好处
        - 面积最小，不占用额外面积，8KB = 0.048
        - 灵活程度高：Nip=1024->10*16都可以存到1-2个GLB的BANK的不同byte
        - 可配置：
            - 当后面修改KNN和FPS分开时，KNN和FPS可单独读写各自的MASK，
            - 当KNN的核数增加时，需要一次同时读多个MASK时，可？？？
    - 坏处
        - 功耗增加：FPS每次只存1bit到GLB，考虑Bank多byte
    
- FPS
    - Stage0: **两个计数器：Cp和Lop** 生成地址
        - FPS时，Cp计数从0到Nop-1，Lop从0到Nip-CpIdx，但第二层FPS由于Mask需要跳着生成地址？（需要把列为最远点的坐标存到GLB，但暂时不用）直接取GLB中的Mask_Loop（对应取GLB中同一个点的不同层的(GLBFPS_MaskRdDat)，是上一次Mask与本次Mask的非的与，表示当前点经前面层的过滤是否还剩下来Mask_Before，剩下来前面层都是1）来使能计数器生成的Addr的有效(Mask_Before前面位要为均为1)
    - Stage1: 同时取1. 输入点的坐标LopIdx的GLBCTR_Crd从ITF（经位宽转换（从SRAM_WIDTH转为COORD_WIDTH\*NUM_COORD））和2. Dist_Buffer中取出与上一次FPS点集的距离FPS_LastPsDist，
    - Stage2: 都同时打一拍后，得(LopCrd_s2,LopIdx_s2)和(FPS_LastPsIdx_s2, FPS_LastPsDist_s2)，必须要打拍
        - 将LopCrd_s2与FPS_CpCrd（FPS中，FPS_CpCrd是上一次找出的最远点的坐标，KNN中，KNN_CpCrd_s2是当前需要找出邻近点的中心点坐标），计算欧式距离EDC LopDist_s2，比较出LopDist_s2和FPS_LastPsDist_s2的最小值，作为与当前FPS点集的距离FPS_PsDist，当前点FPS_PsDist需要与之前点到点集的距离FPS_MaxDist比较出最大值FPS_UpdMax，
    - Stage3: 并更新到Dist_Buffer；和更新这个最大值FPS_MaxDist，最大值对应的点的index FPS_MaxIdx，和最大值对应的点的坐标FPS_MaxCrd；
        - 对于固定的FPS_CpCrd，当所有非点集的点遍历完成LopLast_s2后，这个最大值的点坐标FPS_MaxCrd成为新的FPS_CpCrd，:question:对应的index输出到GLB的FPS_out_buffer，让表示1024个点是否有效的Mask里面对应的bit位置为1并存到GLB相应的bit(FPSGLB_MaskWrDat)
        - 当FPS选出的点集点数达到所需的点数（Nop）时，state转到FNH，后转到IDLE，发出CfgRdy，配置下一层FPS
    - :question:
        - :question:跳过的就无效和等，还会存在读写GLB冲突会等的问题, 还有除法和取余数要用加法循环替换
        - :question: LopIdx怎么生成？因为每次loop使得GLB随机少一个需要loop的点，LopIdx读取的是除了ps之外的点，是在原始的DistIdx存储上跳着读的
            - 每次把ps之外的点选入ps后
                - 方法一：更新GLB的DistIdx使其连续有效；
                - 方法二：读取有效的地址跳过GLB无效的点
                    - 有效地址存为一个地址LUT，用LopIdx取，地址LUT怎么去除某个点的地址？
                    - 采用链表（原理是按顺序读下一个），Linked List(LL)地址是原始点的Idx，存的数据是下一个点的Idex；当某个点x被去掉时，指向x的地址的Idx应当更新为x指向的Idx（也就是直接跳过了x)，关键是怎么找到指向x的地址？





