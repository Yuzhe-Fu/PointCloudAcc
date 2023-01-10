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
<!-- 或者是CCU也都配置好了ITF，只不过GLB自己控制使能接选择相应的ITF_CfgInfo,但配置ITF时，AddrMax, NumBank, ParBank等等无法配置，要按需给 -->
- 与CCU
    - ISA怎么传？为了简化ITF，让ITF和GLB做成统一模块，CCU也通过GLB传ISA，那么**AddrMax怎么来呢？**暂时就64读满吧
- 与GLB
    <!-- - 方案0：还是CCU根据GLB按需配置？基于：GLB是灵活的，只固定了哪几个读写口，怎么接上要完全按配置，保证GLB通用性。
        - CCU给ITF的NumBank, ParBank直接选择后给，但AddrMax怎么给？不像是其它Port不会动，读写Bank的基址始终是0，AddrMax表个数，ITF需要轮流读写，也就是接着地址当基址，这个基址地址也由CCU提供，CCU肯定知道上一次ITF写完的地址，GLB不做特殊处理。
            - 问题1：CCU怎么决策来配置？那就需要知道GLB的的其它Port的情况，其它Port发出读将空（不能用CfgRdy，用另外一个信号发出，如Req请求再有数），CCU再配置一次能满足其需要的口。由什么口来呢？由片外配置的CfgBankPort，决定，相比于方案1，把本该在GLB内部的放到CCU和自外配置的CfgBankPort，更规范灵活。变成了通用：当一个口负责多个口时，要仲裁。否则就不用。变成了GLB是通用的，3个通用写，4个通用读，甚至有可能复用读写口？更通用的？
                - :white:折衷方案是把ITF当成方案1的特殊口(用MaskPort配置好的)，用方案0的CCU来根据其它口的需要来配置ITF。不动GLB。但问题是：与ITF不好结合，比如传cmd用控制数据读写；不传指令只传数据，CCU来传指令
    - 方案1：GLB控制ITF
        - 需要CCU配置ITF读写是到哪些Port(Mask)，然后这些Port因为共用ITF而需要仲裁轮流使用，好处是全自动的，跟实际情况一致，但问题是GLB不够通用了，ITF是特殊口，还会出现其它口也会变成ITF这样的怎么办？也不会变成其它口，够用了就行了（不能让ITF去补缺少读或写的，因为可能会其它口自己临时调整），问题是GLB本来是不区别特殊口，都是通用口的。
        - GLB内部过程是：有个专门对ITF的FSM，Empty_RdPort & Mask -> RdPortIdx，发出指令（基址从哪里来？CCU给其它口的，RdPortIdx选），FSM再转接收或发送数据。
        - GLB内部的，一个口负责多个数据块或口，这个功能是使能配置的通用功能，**必须内置**,GLB只负责完整的数据部分，CCU负责跟外围的指令控制等,像DRAM基址等外围的，不要再输入进GLB了, GLB一定是最通用的，只不过CCU让其特殊化了
        - GLB输出：
            - 输出的是不是负责口的id因为万一负责的也是要多个口的，而是bank，用来区分数据的类型，而CCU是通过片外配置的bankport知道bank对应的数据类型的，从而知道负责多口的每个口对应数据类型的，从而给出指令里面的基址，
            - 那么个数呢？怎么控制这个通用的glb： GLB的外部需要接收响应，和准备好响应的数据, 不能以bank为单位，因为有时写不满一个bank，可以需要传出去个数，附带还传出去写的基础地址，避免CCU再计数
            <!-- - 用ITFGLB_Last作为传输完成，让GLB内ITF口重新置位 -->
            <!-- - 没有没有一对多，需要一个使能信号EnMul, 控制源头empty_bankRd --> -->
    - 方案2：GLB通用只配置成一口读对应一口写，在外部仲裁
        - 不搞一口多用，一口只按配置一用。
        - 需要做的：
            - ITF模块仲裁多个口的请求后，响应其中一个进入CMD状态，后进入IN或OUT把数传给它后，进入CMD再仲裁，
                - 优先级高的是
                    - 先是紧迫性：读满写空；
                    - 然后是个数多的，
                    - 最后是固定优先级的：在前面两级都满足情况下，读的空了，写的也满了，先把要写到片外的拿出来，不要堵住，即SYA_Ofm>POL_Ofm>POL_Ifm>SYA_Act>SYA_Wgt
            - （还是需要GLB输出之前写的地址和差的个数），
            - CCU给每个送到ITF的口分配基址
            - GLB输出：每个口也要输出地址和个数，但需要给口一个响应？因为ITF一次取很多个数，不能多取，解决：ITF获取个数后，进入CMD状态，不会再传数，不会存大多取数，在DAT状态也不会多响应指令
- 与片外接口：**PAD方向转向的延时?**
    - 参考IFT.md，需要先输出地址再传读写数据:question:
        - 输出到片外的地址是配置的绝对地址生成的，Bank都是相对地址，GLB作为被控制的封闭的通用模块（CCU只负责配置除了ITF的CfgVld和CfgInfo，内部调度由GLB自己完成，执行完读写再反馈Rdy给CCU），绝对地址的基址要由CCU配置，偏址由Bank给出，两者结合输出到片外。
        - 什么时候请求ITF？还要考虑是单口SRAM，因此至少有一个ParBank就请求：判断信号类似于PortWrEn:question:读写地址怎么来？，
            - 请求什么？基址和多少个（多少个ParBank）用最高1bit位表示：0表指令，1表数据,由于保持传输的一致性，指令和数据一样的传输路径
            - ITF有FSM：IDLE->CMD->IN或OUT->IDLE，但问题是有空闲周期：传出去CMD到进数据，暂时管了
        - ITF读片外写到Bank：Bank发出读片外数据请求，经仲裁，生成一个CMD经GLBITF_Dat传到ITF，ITF判断高位0，确认是CMD后，FSM到CMD状态，不再接收GLBITF_Dat，当CMD被片外取走后，进入RESE状态，等待接收，接收到了拉高ITFGLB_DatVld。什么时候完成转到IDLE?: 片外应该给个PADITF_DatLast信号(Last信号与Vld信号方向一致，注意Last信号与个数指令相**自洽**)
        - ITF读Bank写到片外：Bank发出写到片外数据请求，经仲裁，生成一个CMD经GLBITF_Dat传到ITF，ITF判断高位0，确认是CMD后，FSM到CMD状态，不再接收GLBITF_Dat，当CMD被片外取走后（片外准备好接收数据），进入IN状态，拉高ITFGLB_DatRdy，接收Bank的数据。当ITF内容的计数器计数完读数之后，TOPITF_DatLast(是内部信号)拉高，不会存存在多取因为state下周期转向FNH
        - 什么时候释放ITF？没有一个完整的ParBank就释放

