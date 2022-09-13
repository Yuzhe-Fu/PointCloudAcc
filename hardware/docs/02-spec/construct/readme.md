# task list
- FPS KNN的概念
- 结合硬件图数据流


# [整个模块和所有子模块的硬件框图（实时维护）](construct-2022-09-08.excalidraw)

# 文件列表
| File | Descriptions |
| ---- | ---- |
| construct.v | 顶层模块 |
| par_sple_sort.v | parallel_sample_sort，并行采样和排序模块 |
| sple_sort_core. v | 采样和排序核 |
| insert_sort.v | 插入排序模块 |
| dist_comp.v | 欧式距离计算模块 |
| RAM_wrap.v | 通用SRAM模块，直接在primitives调用 |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| COORD_WIDTH | 16 | 8 | 坐标x, y, z的位宽 |
| NUM_COORD | 3 |  | 坐标的维度，默认是3维 |
| SRAM_WIDTH | 256 | | SRAM Bank的位宽 |
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
| --config-- |
| cfg_mode | input | 1 | 0: 执行FPS，1: 执行KNN |
| cfg_num_in_points | input | IDX_WIDTH | 第一层输入点的个数，1023表示1024个点 |
| cfg_FPS_factor | 1 |  2 | FPS筛选出原始点数的>> FPS_factor，例如当FPS_factor=1时，>>1表示一半 |
| cfg_K | input | 24 | KNN需要找出多少个邻近点 |

| --data-- |
| in_coord | input | SRAM_WIDTH | 输入的坐标 |
| in_coord_vld | input | 1 | 握手协议的valid信号 |
| in_coord_rdy | output | 1 | 握手协议的ready信号 |
<!-- | in_wgt_above | input | WGT_WIDTH\*NUM_COL\*NUM_BANK | 阵列左侧输入的weight |
| in_wgt_above_vld | input | 1 | 握手协议的valid信号 |
| in_wgt_above_rdy | output | 1 | 握手协议的ready信号 | -->
| out_idx | output | SRAM_WIDTH | 输出KNN构建的map，即排序好的K个最近的点的idx |
| out_idx_vld | output | 1 | 握手协议的valid信号 | 
| out_idx_rdy | input | 1 | 握手协议的ready信号 |


## 模块陈述
构建模块是用来将原始点云采样（FPS)后，找出每个点的K邻近点的index（K个index称为这个点的map即映射）。在顶层模块construct硬件图中，FPS和KNN复用部分硬件（黑色），FPS独有的是青色，KNN独有的是蓝色。在子模块中一律用黑色，不作区别
- FPS
  - 输入点的坐标从global buffer传进来，经位宽转换（从SRAM_WIDTH转为COORD_WIDTH\*NUM_COORD），写入Crd_In_Buffer后，dist_comp从Crd_In_Buffer，一次取一个点的坐标，如point_n，与base_point（FPS中，base_point是上一次找出的最远点的坐标，KNN中，base_point是当前需要找出邻近点的中心点坐标），计算欧式距离ed_n，然后从Dist_Buffer中取出point_n与上一次FPS点集的距离dist_ps_n，比较出ed_n和dist_ps_n的最小值，作为point_n与上当前FPS点集的距离dist_ps_n，并更新到Dist_Buffer；当前点point_n的dist_ps_n需要与之前点到点集的距离比较出最大值，并更新这个最大值，最大值对应的点的index，和最大值对应的点的坐标；对于固定的base——point，当所有非点集的点遍历完成后，这个最大值的点坐标成为新的base_point，对应的index输出到FPS_out_buffer，让表示1024个点是否有效的bit-vector里面对应的bit位置为1（每次FPS开始时，bit-vector全0）；当FPS选出的点集点数达到所需的点数（由cfg_FPS_factor决定每层倍减）时。
- KNN
  - 从第0个点到最后一个点，轮流作为中心点base_point，dist_comp将所有点依次从Crd_In_Buffer取出后，与base_point计算出ed，输出到par_sple_sort模块，par_sple_sort计算出的每个点的map，输出out_idx到global buffer


## par_sple_sort 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 低电平有效 |
| --config-- |
| cfg_num_in_points | input | IDX_WIDTH | 第一层输入点的个数，1023表示1024个点 |
| cfg_K | input | 24 | KNN需要找出多少个邻近点 |
| in_cp_idx | input | IDX_WIDTH | KNN中心点的index |
| in_lp_idx | input | IDX_WIDTH | KNN被遍历(looped)到的点的index |
| in_lp_dist | input| IDX_WIDTH | KNN被遍历(looped)到的点与中心点的距离，即上述的ed |

| out_idx | output | SRAM_WIDTH | 输出KNN构建的map，即排序好的K个最近的点的idx |
| out_idx_vld | output | 1 | 握手协议的valid信号 | 
| out_idx_rdy | input | 1 | 握手协议的ready信号 |



