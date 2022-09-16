# 任务列表
1. :white_check_mark:确定软件是按照map卷积，之后再mp的：
  - 判断输入activation维度是否包含K=32：已确认包含了
  - 判断conv2d是否是全连接，即每个点单独与1x1的filter卷积: 已确认（即便是Conv2d的kernel也是1x1，等价于FC)
2. :white_check_mark: 确认作为feature的一部分的坐标是原始坐标还是经过变换的坐标: 直接保存原始index及其对应坐标，和卷积输入feature的坐标和对应的index，把结果上传到git
  - 在Conv2d（输入35维，输出32维的这种）中结合的坐标（多出来的三个维度）是经过变换的坐标，其保存的为基于中心点的相对位置信息
3. 在relative_xyz=False时，全精度训练得到最后精度为91.73%，现尝试在此情况下的量化对精度的影响
4. 量化：weight到4b和8b，activation到8b；记录train, val, test的acc和loss，并与全精度比较
5. 剪枝：weight剪枝稀疏度到80%
6. 探索数据压缩方法
