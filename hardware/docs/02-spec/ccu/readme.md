# 指令集-基本参考Thinker
包含有
- Array parameter：提前确定硬件结构，多少层，第一层参数的基址
- Layer parameter：层参数：控制每层具体的执行
  - 硬件上：act, wgt的存储地址，网络形状：channel数，点数等
- :question: PE configuration是什么？: 每个PE的每周期的切换信号（开关选择，也是指令：mode+直接控制状态机4个状态），迁移过来是子模块的控制
![config](https://user-images.githubusercontent.com/33385095/190861936-6e883bf5-593f-4304-bedb-e5d8686e9021.png)
![PE_config](https://user-images.githubusercontent.com/33385095/190861939-9f72cfcd-18de-454d-97a1-910ee08c98dc.png)
![image](https://user-images.githubusercontent.com/33385095/190882888-761b0439-953b-425a-b31b-dac4791b1596.png)


| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| Array Parameter |
| 0 | 1-2 | 3-22 | 23-38 |
| Mode: 1b, Run/Test | PE_Bank_Mode: 2b, 2x2, 4x1, 1x4 | Ly_Num: 20b | B_Addr0: 32b |
| Layer Parameters |
| 0-1 | 2-33 | 34-65 | 66-81 | 82-93 | 94-105 | 106-125 | 126-133 | 134-141 |
| Op_code: Conv (FC, POOL) | D_addr: 32b, Base addr of input data | W_addr: 32b, Base addr of weights | N: 16b, # of input points | Chi: # of input channels | | Cho: # of output channels |  quant_scale | quant_shift | quant_zero_point | 
| 0-2 | 2-33 |  66-81 | 82-93 | 
| Op_code:  POOL (Conv,FC),当片上存不下时，就需要从片外拿 | D_addr: 32b, Base addr of input data |  N: 16b, # of input points | Chi: # of input channels |  
| 0-2 | 2-33 | 34-65 | 66-81 | 82-93 | 94-105 |
| Op_code: FC (Conv, POOL) | D_addr: 32b, Base addr of input data | W_addr: 32b, Base addr of weights | N: 16b, # of input points | Chi: # of input channels | | Cho: # of output channels | 
| 0-2 | 2-33 |  34-65 | 66-81 | 
| Op_code: FPS | Crd_addr: 32b, Base addr of coordinates  | Ni: 16b, # of input points | No: 16b, # of output points | 
| 0-2 | 2-33 |  34-65 | 66-70 |
| Op_code: KNN | Idx_addr: 32b, Base addr of Index of KNN Map | K: 5b, # of neghbor points |

| Module Parameters |
| GB |
| SA |
| POOL |
| Construct |


# 文件列表
| File | Descriptions |
| ---- | ---- |
| ccu.v | 顶层模块 |
| RAM_wrap.v | 通用SRAM模块，直接在primitives调用 |
| counter.v |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| MODE_WIDTH | 1 |  |  |
| NUM_LAYER_WIDTH | 20 |  |  |
| ADDR_WIDTH | 16 |  |  |
| OP_WIDTH | 3 | |  |
| NP_WIDTH | 16 |   |  |
| CHN_WIDTH | 12 |   |  |

# 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 代电平有效 |
| --config SA-- |
| ccu_sa_mode | output | 2 | 0: 4个bank按照2x2排列，1: 按照1x4排列，2: 按照4x1排列 |
| quant_scale | output | 20 |  |
| quant_shift | output | ACT_WIDTH | 同quant_scale |
| quant_zero_point | output | ACT_WIDTH | 同quant_scale |
| --control SA-- |
| CCUSA_start | output | 1 | |
| --config PL-- |
| CCUPL_K | output | 24 | 24: KNN, 32: Ball Query |
| --config CONSTR -- |
| CCUCONSTR_mode | output | 1 | 0: 执行FPS，1: 执行KNN |
| CCUCONSTR_Ni | input | IDX_WIDTH | 第一层输入点的个数，1023表示1024个点 |
| CCUCONSTR_NFPS | input | NUM_FPS_WIDTH | FPS的层数 |
| CCUCONSTR_No | IDX_WIDTH |  2 | FPS筛选出原始点数的>> FPS_factor，例如当FPS_factor=1时，>>1表示一半 |
| CCUCONSTR_K | input | 24 | KNN/BQ需要找出多少个邻近点 |


# 模块描述
CCU是中央控制器，有专门的4bit IO来读指令集，先从片外读取ARRAY parameter和layer parameters和configurations(可以用来选择的模块配置），存入到RAM里面，再从RAM里的ARRAY parameter和layer parameters，用FSM，解析出每个子模块需要执行的每周期的配置的index，用index来取出每个模块每周期的配置。


