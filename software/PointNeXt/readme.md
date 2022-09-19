# 任务列表：
1. :white_check_mark:确定软件是按照map卷积，之后再mp的：
    - 判断输入activation维度是否包含K=32：已确认包含了
    - 判断conv2d是否是全连接，即每个点单独与1x1的filter卷积: 已确认（即便是Conv2d的kernel也是1x1，等价于FC)
2. 确认作为feature的一部分的坐标是原始坐标还是经过变换的坐标: 直接保存原始index及其对应坐标，和卷积输入feature的坐标和对应的index，把结果上传到git
    - :white_check_mark:PointNet++中，MSG方法是使用相对于中心的坐标，SSG是不中心化
      - :question:DGCNN不中心化，是否也能支持？
    - :white_check_mark:PointMLP直接不使用坐标作为feature一部分
    - PointNeXt 在Conv2d（输入35维，输出32维的这种）中结合的坐标（多出来的三个维度）是经过变换的坐标，其保存的为基于中心点的相对位置信息
      - :white_check_mark:改不要中心化试试,relative_xyz=False时，全精度训练得到最后精度为91.73% (epoch=40), 8b量化下降0.3% (epoch=113), 
3. 量化：relative=False；记录train, val, test的acc和loss，并与全精度比较
    - weight 8b, activation 8b
    - weight 4b, activation 8b
    - weight 1b, activation 8b
4. 使用pretrained模型
    - 原汁原味
    - relative=false
6. 去掉Batch Normoralization：（relative=False）
    - 全精度
    - weight 8b, activation 8b
7. 剪枝：weight剪枝稀疏度到80%
8. 探索数据压缩方法

    | Type                      | Wei | Act | Channel | relative_xyz | BatchNorm | Epoch | Best | OA    	| mAcc  	|
    |-------------------------- | --- | --- |-------- |--------------| --------- | ----- | ---- |-------	|-------	|
    | Original (C=32)           | 32  | 32  | 32      | True         | Ture      | None  | None | 93.2+-0.1	| 90.8+-0.2 |
    | full-acu<br>epoch80 @57   | 32  | 32  | 32      | True         | True      | 80    | 57   | 92.91 	| 89.55 	|
    | w8a8<br>epoch80 @45       | 8   | 8   | 32      | True         | True      | 80    | 45   | 92.34 	| 87.87 	|
    | w4a8<br>epoch80 @40       | 4   | 8   | 32      | True         | True      | 80    | 40   | 92.30 	| 88.79 	|
    | ------------------------  | --- | --- | ---     | ----------   | --------- | ----- | ---- | ------	| ----- 	|
    | full-acu<br>epoch80 @64   | 32  | 32  | 32      | False        | True      | 80    | 64   | 91.73 	| 88.35 	|
    | full-acu<br>epoch200 @121 | 32  | 32  | 32      | False        | True      | 200   | 121  | 91.82 	| 88.43 	|
    | w8a8<br>epoch80 @72       | 8   | 8   | 32      | False        | True      | 80    | 72   | 91.45 	| 87.42 	|
    | w8a8<br>epoch120 @113     | 8   | 8   | 32      | False        | True      | 120   | 113  | 92.02 	| 89.35 	|
    | w8a8<br>epoch200 @177     | 8   | 8   | 32      | False        | True      | 200   | 177  | 91.94 	| 89.38 	|
    | w1a8<br>epoch300 @   	    | 1   | 8   | 32      | False        | True      | 300   |   |  	|  	|
    | ------------------------  | --- | --- | ---     | ----         | --------- | ----- | ---- | ------	| ----- 	|
    | Original (C=64)           | 32  | 32  | 64      | True         | Ture      | 600   | 537  | 93.7+-0.3 | 90.9+-0.5 |
    | full-acu<br>epoch600 @    | 32  | 32  | 64      | False        | Ture      | 600   |   |  	|  	|
    | w8a8<br>epoch600 @        | 8   | 8   | 64      | False        | Ture      | 600   |   |  	|  	|
    | w4a8<br>epoch600 @        | 4   | 8   | 64      | False        | Ture      | 600   |   |  	|  	|
    
