# 任务列表
1. 确定软件是按照map卷积，之后再mp的：判断输入activation维度是否包含K=32
2. 量化：weight到4b和8b，activation到8b；记录train, val, test的acc和loss，并与全精度比较
3. 剪枝：
4. 探索数据压缩方法