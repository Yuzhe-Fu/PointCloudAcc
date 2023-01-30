## 问题
    - 对KNN每层配置起始CrdIdx地址，Nip, K；生成的Map也要配置写地址
    - :question: POL中报seq占60%
    - :question: NUM_SORT_CORE数量是灵活调整的不由SRAM_WIDTH / (Crd+Idx)决定

# 文件列表
| File | Descriptions |
| ---- | ---- |
| KNN.v | 
| INS.v | 插入排序模块 |
| EDC.v | 欧式dist_comp欧式距离计算模块 |
| RAM.v | 通用SRAM模块，直接在primitives调用 |

## 模块陈述
    - :white_check_mark:KNN.PSS.PISO缩小Reg，其实不需要，它的利用率很低
    - :white_check_mark:INS利用率指数降低:读取第一层Crd时，由于FPS过滤掉一半，不能每次读取都有效，需要链表或压缩
    - :white_check_mark:KNN出来的MAP怎么存，好送到POL，暂时一个SRAM_WIDTH的word存cp_idx和lp_idx，但是同一点不同层同时出来的？
        - 方案：目前采用最简单朴素的压缩的方式，Crd+PntIdx一组SRAM，Dist一组SRAM，按照先点再层的排列，KNN的INS核数是SRAM一次读多少组Crd+PntIdx
            - 讨论过程
                - 压缩只需要把LopPntIdx也写入SRAM就行，不需要Mask但需要每一层的Idx
                    - 根据存储量对比Mask和Idx：Mask：1*8*1024; Idx: 16*512 + 16*256...=16*1024，是两倍
                    - 但要满足每层同时KNN时，INS利用率100%，必须用压缩或链表，不能用Mask
                - 关于SRAM中数据的排列问题：:white_check_mark:先点
                    - SRAM宽度不是问题，大不了两个SRAM并联
                    - FPS考虑到Dist，要么先层：一行SRAM一个Dist，MSB是每层的Crd和PntIdx。但不是点在每一层都有的效率低，要么先点：来存需要多存Dist。
                    - KNN：
                        - :white_check_mark:先点：一次读取多个点，给8个INS（中心点不同），并行排序。
                        - 先层：一次读取一个点的多层，理想是多个INS并行，（INS7，Ly7)先完成，承担Ly0，但是，由于一次读取所有层，INS之间不能负载均衡



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
