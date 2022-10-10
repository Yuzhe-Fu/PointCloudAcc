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
3. 量化：relative=False, C=32；记录train, val, test的acc和loss，并与全精度比较
    - :white_check_mark:weight 8b, activation 8b
    - :white_check_mark:weight 4b, activation 8b
    - :white_check_mark:weight 1b, activation 8b
    - :white_check_mark:weight(4b, 1b...1b, 4b) activation 8b
    - :white_check_mark:weight(4b, 4b, 1b...1b, 4b, 4b) activation 8b
===================
已跑成功，结果在表中，精度较差，稳定性较差
===================
4. :white_check_mark:使用pretrained模型
    - 原汁原味
    - relative=false
6. :white_check_mark:去掉Batch Normoralization：（relative=False, C=32）
    - 全精度
    - weight 8b, activation 8b
9. 探索数据压缩方法
    - 剪枝：
        - :white_check_mark:weight剪枝稀疏度到80% 
        - sensitivity到平均95%稀疏度
        - 统计activation的稀疏度
10. :question: 提取跑硬件每层的数据(hex格式, MSB-LSB，脚本存于HW/scripts，数据存到DRAM文件夹)
    - 坐标: 按照(x, y, z)各8位组一个word，到Crd.txt
    - activation: 先按点数排阵列个，再按通道排列，存到Act.txt
        - 设变量点数Nip，通道数Chi，阵列行数Row，参考[SYA.excalidraw](hardware/docs/02-spec/SYA\SYA.excalidraw)
    - weight：设变量filter个数Cho，通道数Chi，阵列列数Col，操作同act，存到Wgt.txt 
    - 步骤：
        - 1. 用hook，存每层的tensor(坐标，act, weight output): <torch.save(tensor, tensor.pth.tar)>
        - 2. tensor.pth.tar送入到脚本(torch.load(tensor, tensor.pth.tar))

    | Type                              | Wei       | Act | Channel | relative_xyz | BatchNorm | Prune | Epoch | Best | OA    	    | mAcc  	|
    |--------------------------         | ---       | --- |-------- |--------------| --------- | ----- | ----- | ---- |-------	    |-------	|
    | Original (C=32)                   | 32        | 32  | 32      | True         | Ture      | F     | None  | None | 93.2+-0.1	| 90.8+-0.2 |
    | full-acu<br>epoch80 @57           | 32        | 32  | 32      | True         | True      | F     | 80    | 57   | 92.91 	    | 89.55 	|
    | w8a8<br>epoch80 @45               | 8         | 8   | 32      | True         | True      | F     | 80    | 45   | 92.34 	    | 87.87 	|
    | w4a8<br>epoch80 @40               | 4         | 8   | 32      | True         | True      | F     | 80    | 40   | 92.30 	    | 88.79 	|
    | ------------------------          | Wei       | Act | Channel | relative_xyz | BatchNorm | Prune | Epoch | Best | OA    	    | mAcc  	|
    | full-acu<br>epoch80 @64           | 32        | 32  | 32      | False        | True      | F     | 80    | 64   | 91.73 	    | 88.35 	|
    | full-acu<br>epoch200 @121         | 32        | 32  | 32      | False        | True      | F     | 200   | 121  | 91.82 	    | 88.43 	|
    | w8a8<br>epoch80 @72               | 8         | 8   | 32      | False        | True      | F     | 80    | 72   | 91.45 	    | 87.42 	|
    | w8a8<br>epoch120 @113             | 8         | 8   | 32      | False        | True      | F     | 120   | 113  | 92.02 	    | 89.35 	|
    | w8a8<br>epoch200 @177             | 8         | 8   | 32      | False        | True      | F     | 200   | 177  | 91.94 	    | 89.38 	|
    | w8a8<br>epoch600 @488             | 8         | 8   | 32      | False        | True      | F     | 600   | 488  | 92.34 	    | 89.47 	|
    | w4a8<br>epoch600 @580             | 4         | 8   | 32      | False        | True      | F     | 600   | 580  | 92.59       | 89.66    	|
    | mix<br>epoch117 @116              |4-1-4      | 8   | 32      | False        | True      | F     | 117   | 116  | 41.53 	    | 27.52 	|
    | mix<br>epoch600 @584              |44-1-4     | 8   | 32      | False        | True      | F     | 600   | 584  | 85.7 	    | 78.57 	|
    | mix<br>epoch600 @597              |88-1-8     | 8   | 32      | False        | True      | F     | 600   | 597  | 84.36 	    | 75.81 	|
    | prune0.8 w8a8<br>epoch100 @90     | 8         | 8   | 32      | False        | True      | 79.81 | 100   | 90   | 91.45 	    | 86.74 	|
    | prune0.8 w8a8<br>epoch370 @266    | 8         | 8   | 32      | False        | True      | 79.34 | 370   | 266  | 92.22 	    | 89.04 	|
    | ------------------------          | Wei       | Act | Channel | relative_xyz | BatchNorm | Prune | Epoch | Best | OA    	    | mAcc  	|
    | Original (C=64)                   | 32        | 32  | 64      | True         | True      | F     | 600   | 537  | 93.7+-0.3   | 90.9+-0.5 |
    | full-acu<br>epoch600 @486         | 32        | 32  | 64      | True         | True      | F     | 600   | 486  | 93.44 	    | 90.79 	|
    | full-acu<br>epoch600 @522         | 32        | 32  | 64      | False        | True      | F     | 600   | 522  | 92.54 	    | 89.89 	|
    | w8a8<br>epoch536 @509             | 8         | 8   | 64      | False        | True      | F     | 600   | 509  | 92.45 	    | 90.05 	|
    | w4a8<br>epoch600 @580             | 4         | 8   | 64      | False        | True      | F     | 600   | 580  | 92.34 	    | 90.13 	|
    | ------------------------          | Wei       | Act | Channel | relative_xyz | BatchNorm | Prune | Epoch | Best | OA    	    | mAcc  	|
    | w8a8 bnf<br>epoch600 @544         | 8         | 8   | 32      | False        | False     | F     | 600   | 544  | 79.09 	    | 70.96 	|
    <br>
    *note: <br>
    mix epoch117 @116这一栏中的4-1-4代表，第一层weight4bit，最后一层的最后一个linear用4bit，其余均为1bit <br>
    mix epoch600 @584这一栏中的44-1-4代表，前两层weight4bit，最后一层三个linear用4bit，其余均为1bit <br>
    感觉mix的都不是很稳定，在训练时的val_oa变化幅度巨大

    
