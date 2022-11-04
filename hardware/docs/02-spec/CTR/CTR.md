# Task List
- FPS KNN的概念
- 结合硬件图数据流


# [整个模块和所有子模块的硬件框图（实时维护）](construct-2022-09-08.excalidraw)

# 文件列表
| File | Descriptions |
| ---- | ---- |
| CTR.v | 顶层模块 |
| PSS.v | parallel_sample_sort，并行采样和排序模块 |
| SSC. v | 采样和排序核 |
| INS.v | 插入排序模块 |
| EDC.v | 欧式dist_comp欧式距离计算模块 |
| RAM.v | 通用SRAM模块，直接在primitives调用 |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| COORD_WIDTH | 16 | 8 | 坐标x, y, z的位宽 |
| NUM_COORD | 3 |  | 坐标的维度，默认是3维 |
| DIST_WIDTH | LOG2(NUM_COORD\*COORD_WIDTH^2) | 17 | 距离的位宽 |
| NUM_SORT_CORE | 8 | | 排序的核数 | **必须是2的指数** |
| NUM_FPS_WIDTH | 3 | | FPS的层数位宽，层数需小于NUM_SORT_CORE |
| K_WIDTH | 5 | | KNN邻点个数的位宽 |
| IF_WIDTH | 96 | | SRAM Bank的位宽 |

<!-- | ACC_WIDTH | 26 | | 累加器的位宽，ACT_WIDTH + WGT_WIDTH +LOG(通道深度) |
| NUM_ROW | 16 | | PE阵列的行数 |
| NUM_COL | 16 | | PE阵列的列数，默认是正方形阵列即NUM_COL=NUM_ROW | 
| NUM_BANK | 4 | | PE有多个Bank |
| SRAM_WIDTH | 256 | | SRAM Bank的位宽 | -->

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
        - FPS时，Cp计数从0到Nop-1，Lop从0到Nip-CpIdx，但第二层FPS由于Mask需要跳着生成地址？需要把列为最远点的坐标存到GLB，但暂时不用，直接取GLB中的Mask_Loop（对应取GLB中同一个点的不同层，是上一次Mask与本次Mask的非的与）使能计数器生成的Addr的有效，**:question:跳过的就无效和等，还会存在读写GLB冲突会等的问题, 还有除法和取余数要用加法循环替换**
    - Stage1: 同时取1. 输入点的坐标LopIdx的GLBCTR_Crd从ITF（经位宽转换（从SRAM_WIDTH转为COORD_WIDTH\*NUM_COORD））和2. Dist_Buffer中取出与上一次FPS点集的距离FPS_LastPsDist，
    - Stage2: 都同时打一拍后，得(LopCrd_s2,LopIdx_s2)和(FPS_LastPsIdx_s2, FPS_LastPsDist_s2)，必须要打拍
        - 将LopCrd_s2与FPS_CpCrd（FPS中，FPS_CpCrd是上一次找出的最远点的坐标，KNN中，KNN_CpCrd_s2是当前需要找出邻近点的中心点坐标），计算欧式距离EDC LopDist_s2，比较出LopDist_s2和FPS_LastPsDist_s2的最小值，作为与当前FPS点集的距离FPS_PsDist，当前点FPS_PsDist需要与之前点到点集的距离FPS_MaxDist比较出最大值FPS_UpdMax，
    - Stage3: 并更新到Dist_Buffer；和更新这个最大值FPS_MaxDist，最大值对应的点的index FPS_MaxIdx，和最大值对应的点的坐标FPS_MaxCrd；
        - 对于固定的FPS_CpCrd，当所有非点集的点遍历完成LopLast_s2后，这个最大值的点坐标FPS_MaxCrd成为新的FPS_CpCrd，:question:对应的index输出到GLB的FPS_out_buffer，让表示1024个点是否有效的Mask里面对应的bit位置为1并存到GLB相应的bit；
        - 当FPS选出的点集点数达到所需的点数（Nop）时，state转到FNH，后转到IDLE，发出CfgRdy，配置下一层FPS

- KNN
    - stage0是送地址：从第0个点到最后一个点，轮流作为中心点KNN_CpCrd_s2，将所有点LopIdx依次从GLB取出后。地址计数器，Cp和Lop都从0到Nip
    - stage2:pipe是把SRAM取来的数存到LopCrd_s2, LopCrd_s2与KNN_CpCrd_s2计算出LopDist_s2，直接输出到PSS模块，PSS计算出的每个点的map，输出out_idx到ITF
- 随网络Scaling
    - Crd_Buffer和Dist_Buffer是用GLB统一
        - 取决于有多大？ModelNet40有1024,那最大的S3DIS呢？有15, 000个点，96KB，ScanNetPart也有2K个点，需要放到GLB，而且可以给SA让位灵活测试
        - 取决于能否用GLB? 结论是要用GLB缩小面积
            -（Crd_buffer是单口读，Dist_Buffer是双口？无所谓，可以用PingPong buffer），
            - 而且是用地址取的，GLB能支持，POL也是
    - K最大多少？32，即使是S3DIS的最大nsample也是32
    - FPS层最大？S3DIS XL也才5个
    - KNN层最大？


## PSS 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| CTRPSS_LopLast    | input |
| CTRPSS_Rst        | input |
| CTRPSS_Mask       | input | IDX_WIDTH | FPS输出给KNN的mask |
| CTRPSS_MaskVld    | input | 1 | 握手协议的valid信号 |
| PSSCTR_MaskRdy    | output| 1 | 握手协议的ready信号 |
| CTRPSS_CpIdx      | input | IDX_WIDTH | KNN中心点的index |
| CTRPSS_CpIdxVld   | input | 1 | 握手协议的valid信号 |
| PSSCTR_CpIdxRdy   | output| 1 | 握手协议的ready信号 |
| CTRPSS_Lp         | input | IDX_WIDTH + DIST_WIDTH | (KNN被遍历(looped)到的点的index, KNN被遍历(l)到的点与中心点的距离，即上述的ed) |
| CTRPSS_LpVld      | input | 1 | 握手协议的valid信号 |
| PSSCTR_LpRdy      | output| 1 | 握手协议的ready信号 |
| PSSCTR_Idx        | output| SRAM_WIDTH | 输出KNN构建的map，即排序好的K个最近的点的idx |
| PSSCTR_IdxVld     | output| 1 | 握手协议的valid信号 | 
| PSSCTR_IdxRdy     | input | 1 | 握手协议的ready信号 |

## 模块陈述
- PSS用于将construct模块输入进来的每个中心点CpIdx的邻近点LopIdx，经FPS传进来的CTRPSS_Mask，逐层过滤后，输入到INS排序。
- FPS后面接KNN是一个构建组合，在点云网络里，连续有多个这样的组合，因此KNN排序的是经FPS的mask过滤后的点的距离，而每层FPS的mask由顶层construct模块生成后，每层依次输入到GLB的Bank，（注意第一个bit是第一个FPS层的mask，第二个bit是第二个FPS层的mask）。
- 从construct输入的CTRPSS_Lop包含index和距离，同时输入，lp的index要在GLB的BANK中找对应的bit是否为1，如果为1，说明在这层FPS是保留的，则将其in_lp包含index和距离输入到这个INS里面的参与排序，否则不输入到INS。
- 从所有INS输出的map（最邻近的K个点的indx组合），与中心点CTRPSS_CpIdx组成新的map （即(cp_idx, lp_idx\*K)），将其转成SRAM_WIDTH位宽后，PISO输出。

## INS (insert_sort) 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| SSCINS_LopLast | input |
| SSCINS_Lop    | input| IDX_WIDTH + DIST_WIDTH | (KNN被遍历(looped)到的点的index, KNN被遍历(looped)到的点与中心点的距离，即上述的ed) |
| SSCINS_LopVld | input | 1 | 握手协议的valid信号 |
| SSCINS_LopRdy | output | 1 | 握手协议的ready信号 |
| INSSSC_Idx    | output | IDX_WIDTH\*K_WIDTH | 输出KNN构建的map，即排序好的K个最近的点的idx组合 |
| INSSSC_IdxVld | output | 1 | 握手协议的valid信号 | 
| INSSSC_IdxRdy | input | 1 | 握手协议的ready信号 |

## 模块陈述
INS是插入排序模块，输入的SSCINS_Lop，包含要排序的点的index和距离，根据距离从小到大对index排序后输出。
具体工作方式是：输入的Dist，同时与DistArray里面的前(n-1)的排序好的距离，比较得出Cur_insert是否为1，DistArray里面的距离比Dist小，则dist和index不动，最开始距离比Dist大，则这个位置插入Dist和其对应的Idx，往后的寄存器依次移位。
因此DistArray有三种更新情况：
  - Cur_insert = 0，则保持不变，同时向后面的寄存器输出cur_shift =0（是否需要往后移位）
  - Cur_insert = 1，且cur_shift =0，说明当前位置上刚好需要插入in_lp_dist_n和其对应的in_lp_idx_n， 同时向后面的寄存器输出cur_shift =1
  - Cur_insert = 1，且cur_shift =1，说明已经插入在前面了，此位置需要接收前面一个寄存器移位过来，同时向后面的寄存器输出cur_shift =1




