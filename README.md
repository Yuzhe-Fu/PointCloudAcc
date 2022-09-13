
# User guide
- 参考[教程](https://docs.github.com/cn/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)，编辑readme.md。

- 参考这个[教程](https://developer.aliyun.com/article/604633)，把自己的修改提交到此源仓库的master分支。
！注意，只上传源文件如代码和脚本，不要上传生成文件和大文件(>1M)
  - 提交的格式参考 [教程] (https://www.cnblogs.com/daysme/p/7722474.html); 
    - 简化格式是<type是操作的类型>(<scope是操作的对象>): <subject是具体操作的描述> (例如feat(hardware/pool.v): add a arb_fifo module))
  

- verilog设计编程风格
  - 优先参考[Verilog编程艺术](./hardware/docs/tutorial/0-Verilog编程艺术_compressed.pdf)
  - verilog项目参考[DnnWeaver开源AI加速器](https://github.com/zhouchch3/DNNWeaver/tree/master/hsharma35-dnnweaver.public/hsharma35-dnnweaver.public-6be20110b751/fpga/hardware/source)
  - 完整详细代码编写说明参考[Verilog/SystemVerilog 设计编码风格指南](https://verilogcodingstyle.readthedocs.io/en/latest/index.html)
- verilog模块库位于[primitives](/hardware/src/primitives)

# 分工及目录
| 人员 | 负责 | 目录 |
| ---- | ---- | ---- |
| 丘思远 | 脉动阵列 | spec文档位于hardware/docs/02-spec/systolic_array/；源代码位于/hardware/src/systolic_array/；仿真脚本位于/hardware/sim/systolic_array/ |
| 付宇哲 | 适配硬件的算法 | 文档位于software/PointNeXt/readme.md |
| 管宇江，孙天逸 | 综合及后端 | 文档位于hardware/work/readme.md，脚本位于 hardware/work/syn/；库及生成文件位于hardware/project/ |
| | 排序模块 |  spec文档位于hardware/docs/02-spec/construct/ |
| 宋祥杰 | 池化模块 | spec文档位于hardware/docs/02-spec/pooling/； 源代码位于/hardware/src/pooling/；仿真脚本位于/hardware/sim/poolingy/|

