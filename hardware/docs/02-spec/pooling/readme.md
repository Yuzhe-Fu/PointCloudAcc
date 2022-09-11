# [整个模块和所有子模块的硬件框图（实时维护）](pooling-2022-09-08.excalidraw)

# 文件列表
| File | Descriptions |
| ---- | ---- |
| pool.v | 顶层模块 |
| pool_multi_if.v | 多个pooling核读global buffer的接口模块 |
| pool_core.v | 做pooling的核 |
| // pool_out.v | 输出转换模块，多个pooling核写output buffer |
| pool_comp_core.v | pooling里面具体做计算的核，比较做max, average |
| pool_arb_net.v | 仲裁多个请求，选出一个请求信息输出，并响应请求 |
| fifo.v | 通用模块，直接调用 |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| IDX_WIDTH | 10 | 10, 12 | 点的index位宽，1024个点即10b |
| POOL_MAP_DEPTH_WIDTH | 5 | | map的深度的位宽，Ball Query有32个邻近点，位宽为5 |
| POOL_CMD_DEPTH_WIDTH | 2 | 2, 3 | 每个被读global buffer的指令FIFO深度 |
| POOL_OUT_DEPTH_WIDTH | 2 | | 每个被读global buffer的输出IFO深度 |
| POOL_CORE | 6 | |pooling有多个少核，对应多少个读的口 |

## pooling 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 代电平有效 |
| --config-- |
| K | input | 24 | 24: KNN, 32: Ball Query |
| --data-- |
| pool_idx_vld | input | 1 | 握手协议的valid信号 |
| pool_idx | input | IDX_WIDTH | 输入的map idx |
| pool_idx_rdy | output | 1 | 握手协议的ready信号 |
| pool_in_fm | input | ACT_WIDTH\*POOL_CORE | 阵列左侧输入的weight |
| pool_in_fm_vld | input | 1 | 握手协议的valid信号 |
| pool_in_fm_rdy | output | 1 | 握手协议的ready信号 |
| out_fm | output | ACT_WIDTH\*NUM_ROW\*NUM_BANK | 阵列输出计算结果feature map |
| out_fm_vld | output | 1 | 握手协议的valid信号 | 
| out_fm_rdy | input | 1 | 握手协议的ready信号 |
| --control-- |

## 模块陈述



