# 指令集-基本参考Thinker，:question: 也参考dnnweaver的指令及如何使用
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
| Mode: 1b, Run/Test | PE_Bank_Mode: 2b, 2x2, 4x1, 1x4 | Ly_Num: 20b | B_Addr0: 16b |
| Layer Parameters |
| 0-1 | 2-33 | 34-65 | 66-81 | 82-93 | 94-105 |
| Op_code: Conv (FC, POOL) | D_addr: 32b, Base addr of input data | W_addr: 32b, Base addr of weights | N: 16b, # of input points | Chi: # of input channels | | Cho: # of output channels |  
| 0-1 | 2-33 |  66-81 | 82-93 | 
| Op_code:  POOL (Conv,FC),当片上存不下时，就需要从片外拿 | D_addr: 32b, Base addr of input data |  N: 16b, # of input points | Chi: # of input channels |  
| 0-1 | 2-33 | 34-65 | 66-81 | 82-93 | 94-105 |
| Op_code: FC (Conv, POOL) | D_addr: 32b, Base addr of input data | W_addr: 32b, Base addr of weights | N: 16b, # of input points | Chi: # of input channels | | Cho: # of output channels | 
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
| 

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| COORD_WIDTH | 16 | 8 | 坐标x, y, z的位宽 |


# 模块描述
CCU是中央控制器，有专门的4bit IO来读指令集，先从片外读取ARRAY parameter和layer parameters和configurations(可以用来选择的模块配置），存入到RAM里面，再从RAM里的ARRAY parameter和layer parameters，用FSM，解析出每个子模块需要执行的每周期的配置的index，用index来取出每个模块每周期的配置。


