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
| NUM_SORT_CORE | 8 | | 排序的核数 |
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
<!-- | CCUCTR_CfgNfl | input | NUM_FPS_WIDTH | FPS的层数 | -->
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
| CTRGLB_Idx        | output | SRAM_WIDTH | 输出KNN构建的map，即排序好的K个最近的点的idx |
| CTRGLB_IdxVld     | output | 1 | 握手协议的valid信号 |
| CTRGLB_IdxRdy     | input | 1 | 握手协议的ready信号 |


## 模块陈述
**增加使用状态机：IDLE, SORT, OUTPUT**
构建模块是用来将原始点云采样（FPS)后，找出每个点的K邻近点的index（K个index称为这个点的map即映射）。在顶层模块construct硬件图中，FPS和KNN复用部分硬件（黑色），FPS独有的是青色，KNN独有的是蓝色。在子模块中一律用黑色，不作区别
- FPS
    - 输入点的坐标从global buffer传进来，经位宽转换（从SRAM_WIDTH转为COORD_WIDTH\*NUM_COORD），写入Crd_In_Buffer后，dist_comp从Crd_In_Buffer，一次取一个点的坐标，如point_n，与base_point（FPS中，base_point是上一次找出的最远点的坐标，KNN中，base_point是当前需要找出邻近点的中心点坐标），计算欧式距离ed_n，然后从Dist_Buffer中取出point_n与上一次FPS点集的距离dist_ps_n，比较出ed_n和dist_ps_n的最小值，作为point_n与上当前FPS点集的距离dist_ps_n，并更新到Dist_Buffer；当前点point_n的dist_ps_n需要与之前点到点集的距离比较出最大值，并更新这个最大值，最大值对应的点的index，和最大值对应的点的坐标；对于固定的base_point，当所有非点集的点遍历完成后，这个最大值的点坐标成为新的base_point，对应的index输出到FPS_out_buffer，让表示1024个点是否有效的mask里面对应的bit位置为1（每次FPS开始时，mask全0）；当FPS选出的点集点数达到所需的点数（由cfg_FPS_factor决定每层倍减）时。
- KNN
    - 从第0个点到最后一个点，轮流作为中心点base_point，dist_comp将所有点依次从Crd_In_Buffer取出后，与base_point计算出ed，输出到par_sple_sort模块，par_sple_sort计算出的每个点的map，输出out_idx到global buffer
- 随网络Scaling
    - Crd_Buffer是用GLB还是内建？Dist_Buffer是内建还是统一？
        - 取决于有多大？ModelNet40有1024,那最大的S3DIS呢？有15, 000个点，96KB，scanoPart也有2K个点，需要放到GLB，而且可以给SA让位灵活测试
    - K最大多少？32，即使是S3DIS的最大nsample也是32
    - FPS层最大？S3DIS XL也才5个
    - KNN层最大？


## PSS par_sple_sort 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| --config-- |
| cfg_num_in_points | input | IDX_WIDTH | 第一层输入点的个数，1023表示1024个点 |
| cfg_num_FPS | input | NUM_FPS_WIDTH | FPS的层数 |
| cfg_K | input | 24 | KNN需要找出多少个邻近点 |
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
- par_sple_sort用于将construct模块输入进来的每个中心点in_cp_idx的邻近点in_lp，经FPS传进来的mask，逐层过滤后，输入到insert_sort排序。
- FPS后面接KNN是一个构建组合，在点云网络里，连续有多个这样的组合，因此KNN排序的是经FPS的mask过滤后的点的距离，而每层FPS的mask由顶层construct模块生成后，每层依次输入到par_sple_sort里面的每个的sple_sort_core的mask寄存器组，（注意第一个sple_sort_core接收的是第一个FPS层的mask，第一个sple_sort_core接收的是第二个FPS层的mask与第一个FPS层的mask的按位与）。
- 从construct输入的in_lp包含index和距离，同时输入到每个sple_sort_core，lp的index要在每个sple_sort_core的mask中找对应的bit是否为1，如果为1，说明在这层FPS是保留的，则将其in_lp包含index和距离输入到这个sple_sort_core里面的参与排序，否则不输入到sple_sort_core。
- 从所有sple_sort_core输出的map（最邻近的K个点的indx组合），与中心点in_cp_idx组成新的map （即(cp_idx, lp_idx\*K)），将其转成SRAM_WIDTH位宽后，存入输出Map_Out_Buffer。

## sple_sort_core 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| --config-- |
| cfg_num_in_points | input | IDX_WIDTH | 第一层输入点的个数，1023表示1024个点 |
| cfg_num_FPS | input | NUM_FPS_WIDTH | FPS的层数 |
| cfg_K | input | 24 | KNN需要找出多少个邻近点 |
| in_mask | input | IDX_WIDTH | FPS输出给每个sple_sort_core的mask |
| in_mask_vld | input | 1 | 握手协议的valid信号 |
| in_mask_rdy | output | 1 | 握手协议的ready信号 |
| in_cp_idx | input | IDX_WIDTH | KNN中心点的index |
| in_cp_idx_vld | input | 1 | 握手协议的valid信号 |
| in_cp_idx_rdy | output | 1 | 握手协议的ready信号 |
| in_lp | input| IDX_WIDTH + DIST_WIDTH | (KNN被遍历(looped)到的点的index, KNN被遍历(looped)到的点与中心点的距离，即上述的ed) |
| in_lp_vld | input | 1 | 握手协议的valid信号 |
| in_lp_rdy | output | 1 | 握手协议的ready信号 |
| out_idx | output | IDX_WIDTH\*K_WIDTH | 输出KNN构建的map，即排序好的K个最近的点的idx组合 |
| out_idx_vld | output | 1 | 握手协议的valid信号 | 
| out_idx_rdy | input | 1 | 握手协议的ready信号 |

## 模块陈述
sple_sort_core是具体执行上述过滤和排序的模块，输出是经过一层的mask过滤后排序出K个最小距离的index组合。

## insert_sort 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| --config-- |
| SSCINS_Lop    | input| IDX_WIDTH + DIST_WIDTH | (KNN被遍历(looped)到的点的index, KNN被遍历(looped)到的点与中心点的距离，即上述的ed) |
| SSCINS_LopVld | input | 1 | 握手协议的valid信号 |
| SSCINS_LopRdy | output | 1 | 握手协议的ready信号 |
| INSSSC_Idx    | output | IDX_WIDTH\*K_WIDTH | 输出KNN构建的map，即排序好的K个最近的点的idx组合 |
| INSSSC_IdxVld | output | 1 | 握手协议的valid信号 | 
| INSSSC_IdxRdy | input | 1 | 握手协议的ready信号 |

## 模块陈述
insert_sort是插入排序模块，输入的in_lp，包含要排序的点的index和距离，根据距离从小到大对index排序后输出。
具体工作方式是：输入的in_lp_dist_n，同时与Dist_reg_array里面的前(n-1)的排序好的距离，比较得出Cur_insert是否为1，Dist_reg_array里面的距离比in_lp_dist_n小，则dist和index不动，最开始距离比in_lp_dist_n大，则这个位置插入in_lp_dist_n和其对应的in_lp_idx_n，往后的寄存器依次移位。
因此Dist_reg_array有三种更新情况：
  - Cur_insert = 0，则保持不变，同时向后面的寄存器输出cur_shift =0（是否需要往后移位）
  - Cur_insert = 1，且cur_shift =0，说明当前位置上刚好需要插入in_lp_dist_n和其对应的in_lp_idx_n， 同时向后面的寄存器输出cur_shift =1
  - Cur_insert = 1，且cur_shift =1，说明已经插入在前面了，此位置需要接收前面一个寄存器移位过来，同时向后面的寄存器输出cur_shift =1




