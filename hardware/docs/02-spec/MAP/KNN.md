## 问题
    - :question: POL中报seq占60%

# 文件列表
| File | Descriptions |
| ---- | ---- |
| KNN.v | 
| INS.v | 插入排序模块 |
| EDC.v | 欧式dist_comp欧式距离计算模块 |
| RAM.v | 通用SRAM模块，直接在primitives调用 |

## 模块陈述
    - 设计理念和考量
        - 多核：KNN天然存在同一块内不同点的并行计算，还能复用取的点；核数由输入输出带宽共同决定：输入是一个SRAM有5个Crd，有几个SRAM决定有多少个核，输出是约2个SRAM WORD/64分配的平均点数 = 1/32，输出带宽足够。是否还有块间KNN并行？暂不需要：只块内并行核数是否够？是够的，通过多个SRAM也能倍增；块间并行的好处？无
        - 高配置性：每层KNN重新配置
        - 多个核同时出来的的MAP怎么不阻塞地写入到GLB？是一个加寄存器（缓存输入或输出）和阻塞的选择，选择不加寄存器
    - KNN输入
        - Crd：由FPS生成，一个SRAM WORD排5个点
    - KNN输出
        - Map：一个点的MAP占2个SRAM WORD，不需要存CpIdx，地址就表示了CpIdx
    - 计算过程
        - 对KNN每层都重新配置起始Crd读地址，Nip, K；生成的Map也要配置写地址
        - 所有核同步取Crd，同步计算，核的输出MAP不需要暂存，占用reg太多了。

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
