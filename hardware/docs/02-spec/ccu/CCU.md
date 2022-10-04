# 指令集-基本参考Thinker
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
| 0         |  3-22       | 23-38        |
| Mode(1b)  |  Ly_Num(20b)| Base_Addr0(32b) |
| Layer Parameters |
| 0-2       | 3-34          | 35-66         | 67-82 | 83-94 |   | 96-107| 108:127   | 128:135       | 136:143           | 144:145           | 146: 161      | 162: 177 | 178: 193 |
| OpCodeCON| DatAddr(32b)   | WgtAddr(32b)  | Nip   | Chi   | 1b| Cho   |quant_scale| quant_shift   | quant_zero_point  | CCUSYA_CfgMod(2b) | WgtAddrRange  |     DatAddrRange | OfmAddrRange | 
| 0-2       | 3-34          | 35-50         | 51-62 | 63-68 |
| OpCodePOL | DatAddr       | Nip           | Chi   |  K    |
| 0-2       | 2-33          | 34-65         | 66-81 | 82-93 | 94-105|
| OpCodeFC  | DatAddr       | WgtAddr       | Nip   | Chi   | Cho   | 
| 0-2       | 3-34          | 35-66         | 67-82 | 
| OpCodeFPS | Crd_addr      | Ni            | No    | 
| 0-2       | 3-34          | 35-66         | 67-72 |
| OpCodeKNN | Map_Idx       |  Ni           | K     | 0:表示没有，1-32 |



| Array Parameter |
| 0 | 1-2 | 3-22 | 23-38 |
| Mode: 1b, Run/Test | CCUSYA_CfgMod: 2b, 2x2, 4x1, 1x4 | Ly_Num: 20b | Base_Addr0: 32b,第一层的参数基址 |
| Layer Parameters |
| 0-1 | 2-33 | 34-65 | 66-81 | 82-93 | 94-105 | 106-125 | 126-133 | 134-141 |
| OpCode: Conv (FC, POOL) | DatAddr: 32b, Base addr of input data | WgtAddr: 32b, Base addr of weights | Nip: 16b, # of input points | Chi: # of input channels | | Cho: # of output channels |  quant_scale | quant_shift | quant_zero_point | 
| 0-2 | 2-33 |  66-81 | 82-93 | 
| OpCode:  POOL (Conv,FC),当片上存不下时，就需要从片外拿 | DatAddr: 32b, Base addr of input data |  Nip: 16b, # of input points | Chi: # of input channels |  
| 0-2 | 2-33 | 34-65 | 66-81 | 82-93 | 94-105 |
| OpCode: FC (Conv, POOL) | DatAddr: 32b, Base addr of input data | WgtAddr: 32b, Base addr of weights | Nip: 16b, # of input points | Chi: # of input channels | | Cho: # of output channels | 
| 0-2 | 2-33 |  34-65 | 66-81 | 
| OpCode: FPS | Crd_addr: 32b, Base addr of coordinates  | Ni: 16b, # of input points | No: 16b, # of output points | 
| 0-2 | 2-33 |  34-65 | 66-70 |
| OpCode: KNN | Map_Idx: 32b, Base addr of Index of KNN Map | K: 5b, # of neghbor points |

| Module Parameters |
| GLB |
| SYA |
| POL |
| CTR |


# 文件列表
| File | Descriptions |
| ---- | ---- |
| ccu.v | 顶层模块 |
| RAM_wrap.v | 通用SRAM模块，直接在primitives调用 |
| counter.v |

# 参数列表
| Parameters | default | optional | Descriptions |
| ---- | ---- | ---- | ---- |
| MODE_WIDTH | 1 |  |  |
| NUM_LAYER_WIDTH | 20 |  |  |
| ADDR_WIDTH | 16 |  |  |
| OP_WIDTH | 3 | |  |
| NP_WIDTH | 16 |   |  |
| CHN_WIDTH | 12 |   |  |
| PORT_WIDTH | 96 | 96 | PAD数据宽度 |
| SRAM_WORD_ISA | 64 | 

# 端口列表
| Ports | Input/Output | Width | Descriptions |
| ---- | ---- | ---- | ---- |
| clk | input | 1 | clock |
| rst_n | input | 1 | reset, 代电平有效 |

| ITFCCU_Dat                | input | 
| ITFCCU_DatVld             | input |
| ITFCCU_DatRdy             | output |
// SYA
| CCUSYA_CfgMod             | output | 2 | 0: 4个bank按照2x2排列，1: 按照1x4排列，2: 按照4x1排列 | 
| CCUSYA_CfgScale           | output | 20           |               |
| CCUSYA_CfgShift           | output | ACT_WIDTH    | 同quant_scale |
| CCUSYA_CfgZp              | output | ACT_WIDTH    | 同quant_scale |
| CCUSYA_Start              | output | 1            |               |
| CCUPOL_CfgK               | output | 24           | 24: KNN, 32: Ball Query |
| CCUCTR_CfgMod             | output | 1            | 0: 执行FPS，1: 执行KNN |
| CCUCTR_CfgNip             | output | IDX_WIDTH    | 第一层输入点的个数，1023表示1024个点 |
| CCUCTR_CfgNfl             | output | NUM_FPS_WIDTH| FPS的层数     |
| CCUCTR_CfgNop             | output |IDX_WIDTH     |  2            | FPS筛选出原始点数的>> FPS_factor，例如当FPS_factor=1时，>>1表示一半 |
| CCUCTR_CfgK               | output | K_WIDTH           | KNN/BQ需要找出多少个邻近点 |
| CCUGLB_CfgVld             | output |NUM_PORT| 每个Port单独配置和使能，vld rdy取代rst和fnh
| GLBCCU_CfgRdy             | input  |NUM_PORT|
| CCUGLB_CfgPort_BankFlg    | output |
| CCUGLB_CfgPort_AddrMax    | output |
| CCUGLB_CfgRdPortParBank   | output |
| CCUGLB_CfgWrPortParBank   | output |
<!-- | GLBCCU_Port_fnh           | input  |1
| CCUGLB_Port_rst           | output |1 -->

# 模块描述
- CCU是中央控制器，有专门的4bit IO来读指令集，负责配置模块和模块的**最顶层控制**（模块内部只要配置能控制的都不要用CCU控制，多少层由CCU控制，CfgVld相当于控制了层的开始，CfgRdy相当于模块反馈结束，再加上整个网络的Rst）
    - 与片外通信：先通过统一接口，从片外读取ARRAY parameter和layer parameters和configurations(可以用来选择的模块配置），存入到RAM里面，再从RAM里的ARRAY parameter和layer parameters
    - FSM控制片内：用FSM，t每层输出一次配置，IDLE(芯片启动空状态）->RD_CFG(读取整个网络的参数配置）->->FNH（整个网络计算完成）
        - 转到配置子FSM: IDLE_CFG ->接收到Triggerif (ReqCfg)...ARRAY_CFG, CONV_CFG（配置网络一层）， FC....-> 
    根据模块请求FPS、KNN、CONV、POL、FC等层的配置，各自取各自下一层的配置
    - RAM_ISA：
        - 写：每次请求的就是一整个RAM深度的，addr_w是所有层数，是深度的倍数，满深度后，仍然加1，相当于重新写RAM
        - 读：每种层单独配置，Cfg不同信息归属不同种的层，所有种层的信息连续存到RAM，RAM的宽度就是PORT_WIDTH=96，每个种层有多个PROT_WIDTH的word，深度为64（PointMLP-lite就有43层）
            - 用FSM直接使能读RAM，用读数中的OpCode确认是否取到相应的种层的配置，否则地址加1，当取完各种层一层的所有word后（当取到配置数为需要的-1且当前取的match时），完成种层的配置
    - GLB控制：达到单独控制一个Port转移到另一个Bank，需要：
        - 单独控制到哪个Bank：
            - 不影响其它Bank：在刷新时，其它的配置信息应该是不变的
            - 从Bank哪个地址开始读写起止，（IF还有DRAM的读写起止地址）：
                - 用相应的CfgVld的bit位，是一个脉冲，与SYA_RdPortActBank等信息同时变化。
        - 配置信息怎么来？
            - 直接从片外配置的来得出，每个口随层变：但什么时候Port改变呢？**每种层变化时也即取配置时**
                - 每种层配置port的bank flag，得到如下口的信息，然后assign 给让CCUGLB_CfgBankPort，CCUGLB_CfgPortMod，防止multidriver
                - SYA_RdPortAct
                - SYA_RdPortWgt
                - SYA_WrPortFm
                - POL_RdPortFm
                - POL_WrPortFm
                - ITF_RdPort
                - ITF_WrPort
            - 先一步步回溯：
                - CCUGLB_CfgBankPort：每个口单独配置：
                    - 对SYA：SYA的mode决定RdPortParBank和WrPortParBank即基数，在知道整个filter数量和ifm的情况下，假设只有loop ifm和loop filter两种情况（由片外配置），固定的项的总量可得到，Loop项的可以是1或多个，RdPortLoop的次数用总数除以Bank量，CCUGLB_CfgPort_AddrMax为Bank数，
                    - 对IF口：哪里没有了就去哪里，灵活配置
                    - 对POOL：根据片外配置的Nip和Chi，分配Bank
                    - 
    - ITF控制：
        - 陈述功能：ITF是伺服于其它口的，当其它口将读空时，需要ITF写入，当其它口将写满时，需要ITF读出数据，ITF在不同Bank之间不断切换，相当于灵活接来接去的送水接水的水管。**当接上时再配置ITF的CfgInfo**相当于又刷新了一次Cfg打拍，，（CCU不能配置数据类型，因为数据类型可能32或更多，只能配置固定的Port),
        <!-- 或者是CCU也都配置好了ITF，只不过GLB自己控制使能接选择相应的ITF_CfgInfo,但配置ITF时，AddrMax, NumBank, ParBank等等无法配置，要按需给 -->
        - 方案0：还是CCU根据GLB按需配置？基于：GLB是灵活的，只固定了哪几个读写口，怎么接上要完全按配置，保证GLB通用性。
            - CCU给ITF的NumBank, ParBank直接选择后给，但AddrMax怎么给？不像是其它Port不会动，读写Bank的基址始终是0，AddrMax表个数，ITF需要轮流读写，也就是接着地址当基址，这个基址地址也由CCU提供，CCU肯定知道上一次ITF写完的地址，GLB不做特殊处理。
                - 问题1：CCU怎么决策来配置？那就需要知道GLB的的其它Port的情况，其它Port发出读将空（不能用CfgRdy，用另外一个信号发出，如Req请求再有数），CCU再配置一次能满足其需要的口。由什么口来呢？由片外配置的CfgBankPort，决定，相比于方案1，把本该在GLB内部的放到CCU和自外配置的CfgBankPort，更规范灵活。变成了通用：当一个口负责多个口时，要仲裁。否则就不用。变成了GLB是通用的，3个通用写，4个通用读，**甚至有可能复用读写口？更通用的？**
                    - :white:折衷方案是把ITF当成方案1的特殊口(用MaskPort配置好的)，用方案0的CCU来根据其它口的需要来配置ITF。不动GLB。但问题是：与ITF不好结合，比如传cmd用控制数据读写；不传指令只传数据，CCU来传指令
        - **方案1**：GLB控制ITF
            - 需要CCU配置ITF读写是到哪些Port(Mask)，然后这些Port因为共用ITF而需要仲裁轮流使用，好处是全自动的，跟实际情况一致，但问题是GLB不够通用了，ITF是特殊口，还会出现其它口也会变成ITF这样的怎么办？也不会变成其它口，够用了就行了（不能让ITF去补缺少读或写的，因为可能会其它口自己临时调整），问题是GLB本来是不区别特殊口，都是通用口的。
            - GLB内部过程是：有个专门对ITF的FSM，Empty_RdPort & Mask -> RdPortIdx，发出指令（基址从哪里来？CCU给其它口的，RdPortIdx选），FSM再转接收或发送数据。
            - GLB内部的，一个口负责多个数据块或口，这个功能是使能配置的通用功能，**必须内置**,GLB只负责完整的数据部分，CCU负责跟外围的指令控制等,像DRAM基址等外围的，不要再输入进GLB了, GLB一定是最通用的，只不过CCU让其特殊化了
            - GLB输出：
                - 输出的是不是负责口的id因为万一负责的也是要多个口的，而是bank，用来区分数据的类型，而CCU是通过片外配置的bankport知道bank对应的数据类型的，从而知道负责多口的每个口对应数据类型的，从而给出指令里面的基址，
                - 那么个数呢？怎么控制这个通用的glb： GLB的外部需要接收响应，和准备好响应的数据, 不能以bank为单位，因为有时写不满一个bank，可以需要传出去个数，附带还传出去写的基础地址，避免CCU再计数
                - 用ITFGLB_Last作为传输完成，让GLB内ITF口重新置位
                - 没有没有一对多，需要一个使能信号EnMul, 控制源头empty_bankRd
        - 方案2：GLB通用只配置成一口读对应一口写，在外部仲裁
            - 不搞一口多用，一口只按配置一用。
            - 需要做的：
                - ITF外部仲裁多个口的请求后，响应其中一个，把数传给它后，再仲裁，
                - （还是需要GLB输出之前写的地址和差的个数），
                - CCU给每个送到ITF的口分配基址
                - 口也要输出地址和个数
        - 与片外接口：**PAD方向转向的延时**
            - 参考IFT.md，需要先输出地址再传读写数据:question:
                - 输出到片外的地址是配置的绝对地址生成的，Bank都是相对地址，GLB作为被控制的封闭的通用模块（CCU只负责配置除了ITF的CfgVld和CfgInfo，内部调度由GLB自己完成，执行完读写再反馈Rdy给CCU），绝对地址的基址要由CCU配置，偏址由Bank给出，两者结合输出到片外。
                - 什么时候请求ITF？还要考虑是单口SRAM，因此至少有一个ParBank就请求：判断信号类似于PortWrEn:question:读写地址怎么来？，
                    - 请求什么？基址和多少个（多少个ParBank）用最高1bit位表示：0表指令，1表数据,由于保持传输的一致性，指令和数据一样的传输路径
                    - ITF有FSM：IDLE->CMD->RESE或SEND->IDLE，但问题是有空闲周期：传出去CMD到进数据，暂时管了
                - ITF读片外写到Bank：Bank发出读片外数据请求，经仲裁，生成一个CMD经GLBITF_Dat传到ITF，ITF判断高位0，确认是CMD后，FSM到CMD状态，不再接收GLBITF_Dat，当CMD被片外取走后，进入RESE状态，等待接收，接收到了拉高ITFGLB_DatVld。什么时候完成转到IDLE?: 片外应该给个RdLast信号(Last信号与Vld信号方向一致，注意Last信号与个数指令相**自洽**)
                - ITF读Bank写到片外：Bank发出写到片外数据请求，经仲裁，生成一个CMD经GLBITF_Dat传到ITF，ITF判断高位0，确认是CMD后，FSM到CMD状态，不再接收GLBITF_Dat，当CMD被片外取走后（片外准备好接收数据），进入SEND状态，拉高ITFGLB_DatRdy，接收Bank的数据。
                - 什么时候释放ITF？没有一个完整的ParBank就释放
        - 与GLB的Bank通过CfgInfo
            - 输出到Bank的地址是相对地址
    - Debug: 暂未考虑
# 下一步：画图



