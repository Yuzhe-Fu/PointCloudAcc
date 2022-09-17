# 指令集-基本参考Thinker
包含有
- Array parameter：提前确定硬件结构，多少层，第一层参数的基址
- Layer parameter：层参数：控制每层具体的执行
  - 硬件上：act, wgt的存储地址，网络形状：channel数，点数等
- :question: PE parameter是什么？: 每个PE的执行，其实是每个子模块的控制信号；thinker里面是怎么生成的？
![config](https://user-images.githubusercontent.com/33385095/190861936-6e883bf5-593f-4304-bedb-e5d8686e9021.png)
![PE_config](https://user-images.githubusercontent.com/33385095/190861939-9f72cfcd-18de-454d-97a1-910ee08c98dc.png)

| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| COORD_WIDTH | 16 | 8 | 坐标x, y, z的位宽 |


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
