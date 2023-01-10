**去掉无用的PSS，按照KNN硬件图**

| KNN.v | 
| PSS.v | parallel_sample_sort，并行采样和排序模块 |
| SSC. v | 采样和排序核 |
| INS.v | 插入排序模块 |
| EDC.v | 欧式dist_comp欧式距离计算模块 |
| RAM.v | 通用SRAM模块，直接在primitives调用 |

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
