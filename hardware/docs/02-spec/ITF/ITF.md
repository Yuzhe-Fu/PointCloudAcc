# 问题
- IO不必要太高，占用率低

# 文件列表
| File | Descriptions |
| ---- | ---- |
| ITF.v | 顶层模块 |
| PISO.v | |
| SIPO.v | |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| MODE_WIDTH | 1 |  |  |
| NUM_LAYER_WIDTH | 20 |  |  |
| ADDR_WIDTH | 16 |  |  |
| PORT_WIDTH | **128** | 128 | PAD数据宽度 |

# 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk                       | input | 1                                 | clock |
| rst_n                     | input | 1                                 | reset, 代电平有效 |
| ITFPAD_Dat                | output| PORT_WIDTH                        | |
| ITFPAD_DatVld             | output| 1                                 ||
| ITFPAD_DatLast            | output| 1                                 ||????????????????????????????????????????????????:question
| PADITF_DatRdy             | input | 1                                 ||
| PADITF_Dat                | input | PORT_WIDTH                        || 
| PADITF_DatVld             | input | 1                                 ||
| PADITF_DatLast            | input | 1                                 ||
| ITFPAD_DatRdy             | output| 1                                 ||
| GLBITF_EmptyFull          | input | (NUM_RDPORT+NUM_WRPORT)           ||
| GLBITF_ReqNum             | input | ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)| 务必保证实时反映个数，即写/读有效的下一个周期就变|
| GLBITF_Addr               | input | ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)|
| CCUITF_BaseAddr           | input | ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)|
| GLBITF_Dat                | input | SRAM_WIDTH*NUM_RDPORT             |
| GLBITF_DatVld             | input | NUM_RDPORT                        |
| ITFGLB_DatRdy             | output| NUM_RDPORT                        |
| ITFGLB_Dat                | output| SRAM_WIDTH*NUM_WRPORT             |
| ITFGLB_DatVld             | output| NUM_WRPORT                        |
| GLBITF_DatRdy             | input | NUM_WRPORT                        |


# 模块陈述
WRPORT[0]给CCU
WRPORT[1 +:4]写给GLB

WRIDX_ITFCCU = 0;
WRIDX_ITFACT = 1;
WRIDX_ITFWGT = 2;
WRIDX_ITFCRD = 3;
WRIDX_ITFMAP = 4;

RDIDX_ITFMAP = 0;
RDIDX_ITFOFM = 1;


Interface负责将GLB的握手协议，与PAD的协议相连接
PAD的协议是：借鉴AHB协议，先传首地址（决定是取哪种数据类型）和取多少个(统称为指令），然后收发数据。地址和数据共用PAD, 所以，有1bit控制信号区别指令和数据，数据传输还是基于握手协议。
- 先是没有异步FIFO的，直接与PAD相连
- 陈述功能：ITF是伺服于其它口的，当其它口将读空时，需要ITF写入，当其它口将写满时，需要ITF读出数据，ITF在不同Bank之间不断切换，相当于灵活接来接去的送水接水的水管。**当接上时再配置ITF的CfgInfo**相当于又刷新了一次Cfg打拍，，（CCU不能配置数据类型，因为数据类型可能32或更多，只能配置固定的Port),
- 与CCU
    - ISA怎么传？为了简化ITF，让ITF和GLB做成统一模块，CCU也通过GLB传ISA
- 与GLB: GLB一个口只一个作用，不能调换，ITF对这些口仲裁
    - ITF读的CCU的ISA就是GLB
        - 好处：逻辑统一，CCU也是读GLB的一个模块；
        - 问题：初始就需要对GLB配置，目前假设Bank0就是专配给ISA的（好处是配置成功后也不需要变，不会出现用读出的ISA改变ISA存储的情况）
    - 请求ITF：
        - 信号从哪里来：在保持GLB信号只有握手协议的前提下，用GLB的Rdy信号(GLB_WrPortDatRdy和GLB_RdPortAddrRdy，它们自动发出）仲裁出哪个口
        - ITF读写DRAM到什么时候算完成：不要用一块固定多少的包来请求，而是只要有Rdy就直接读写片外，当Rdy突然拉低时，DRAM到GLB之间的数据是多余的直接丢弃，只要Addr在，就能同时记录这次读写的地址（每个口都有个计数器），下次可以接着读写，为了防止一个口不断地读一个写一个，采用轮询仲裁。

- 与片外接口：**PAD方向转向的延时?**
    - 参考IFT.md，需要先输出地址再传读写数据
        - 输出到片外的地址是配置的绝对地址生成的，绝对地址的基址要由CCU配置，偏址由Bank给出，两者结合输出到片外。
            - 基址和多少个（多少个ParBank）用最高1bit位表示：0表指令，1表数据,由于保持传输的一致性，指令和数据一样的传输路径
            - ITF有FSM：IDLE->CMD->IN或OUT->IDLE，但问题是有空闲周期：传出去CMD到进数据，暂时不管了
        - ITF读片外写到Bank：Bank发出读片外数据请求，经仲裁，生成一个CMD经GLBITF_Dat传到ITF，ITF判断高位0，确认是CMD后，FSM到CMD状态，不再接收GLBITF_Dat，当CMD被片外取走后，进入RESE状态，等待接收，接收到了拉高ITFGLB_DatVld。什么时候完成转到IDLE?: 片外应该给个PADITF_DatLast信号(Last信号与Vld信号方向一致，注意Last信号与个数指令相**自洽**)
        - ITF读Bank写到片外：Bank发出写到片外数据请求，经仲裁，生成一个CMD经GLBITF_Dat传到ITF，ITF判断高位0，确认是CMD后，FSM到CMD状态，不再接收GLBITF_Dat，当CMD被片外取走后（片外准备好接收数据），进入IN状态，拉高ITFGLB_DatRdy，接收Bank的数据。当ITF内容的计数器计数完读数之后，TOPITF_DatLast(是内部信号)拉高，不会存存在多取因为state下周期转向FNH
        - 什么时候释放ITF？没有一个完整的ParBank_Word就释放
        - FMC怎么判断传数完成（没有DatLast)：增加区分命令和数据的信号O_CmdVld

