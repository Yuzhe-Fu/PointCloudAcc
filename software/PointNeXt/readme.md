# 任务列表：:question:md和源码
1. :white_check_mark:确定软件是按照map卷积，之后再mp的：
  - 判断输入activation维度是否包含K=32：已确认包含了
  - 判断conv2d是否是全连接，即每个点单独与1x1的filter卷积: 已确认（即便是Conv2d的kernel也是1x1，等价于FC)
2. 确认作为feature的一部分的坐标是原始坐标还是经过变换的坐标: 直接保存原始index及其对应坐标，和卷积输入feature的坐标和对应的index，把结果上传到git
  - :white_check_mark:PointNet++中，MSG方法是使用相对于中心的坐标，SSG是不中心化
    - :question:DGCNN不中心化，是否也能支持？
  - :white_check_mark:PointMLP直接不使用坐标作为feature一部分
  - PointNeXt 在Conv2d（输入35维，输出32维的这种）中结合的坐标（多出来的三个维度）是经过变换的坐标，其保存的为基于中心点的相对位置信息
    - :white_check_mark:改不要中心化试试,relative_xyz=False时，全精度训练得到最后精度为91.73% (epoch=40), 8b量化下降0.3% (epoch=113), 

    | Type                             	| relative_xyz 	| OA    	| mAcc  	|
    |----------------------------------	|--------------	|-------	|-------	|
    | Original github                  	| True         	| 93.7  	| 90.9  	|
    | full-acu<br>epoch80 best@57      	| True         	| 92.91 	| 89.55 	|
    | comp w8a8b8<br>epoch80 best@45   	| True         	| 92.34 	| 87.87 	|
    | comp w4a8b8<br>epoch80 best@40   	| True         	| 92.30 	| 88.79 	|
    | full-acu<br>epoch80 best@64      	| False        	| 91.73 	| 88.35 	|
    | full-acu<br>epoch200 best@121    	| False        	| 91.82 	| 88.43 	|
    | comp w8a8b8<br>epoch80 best@72   	| False        	| 91.45 	| 87.42 	|
    | comp w8a8b8<br>epoch120 best@113 	| False        	| 92.02 	| 89.35 	|
    | comp w8a8b8<br>epoch200 best@177 	| False        	| 91.94 	| 89.38 	|

3. 量化：weight到4b和8b，activation到8b；记录train, val, test的acc和loss，并与全精度比较
  - weight 1b, activation 8b
4. 剪枝：weight剪枝稀疏度到80%
5. 探索数据压缩方法

