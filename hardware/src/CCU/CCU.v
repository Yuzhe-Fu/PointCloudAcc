// This is a simple example.
// You can make a your own header file and set its path to settings.
// (Preferences > Package Settings > Verilog Gadget > Settings - User)
//
//      "header": "Packages/Verilog Gadget/template/verilog_header.v"
//
// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : zhouchch@pku.edu.cn
// File   : CCU.v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------
module CCU #(
    parameter SRAM_WORD_ISA         = 64,
    parameter PORT_WIDTH            = 256,
    parameter CLOCK_PERIOD          = 10,

    parameter ADDR_WIDTH            = 16,
    parameter DRAM_ADDR_WIDTH       = 32,
    parameter NUM_RDPORT            = 2,
    parameter NUM_WRPORT            = 3,
    parameter IDX_WIDTH             = 16,
    parameter CHN_WIDTH             = 12,
    parameter ACT_WIDTH             = 8,
    parameter MAP_WIDTH             = 6,
    parameter NUM_LAYER_WIDTH       = 20,
    parameter ISARDWORD_WIDTH       = 4,
    parameter OPNUM                 = 6,

    parameter MAXPAR                = 32,
    parameter NUM_BANK              = 32

    )(
    input                               clk                     ,
    input                               rst_n                   ,
    input                                               TOPCCU_start,
    output                                              CCUTOP_NetFnh,
    output                                              CCUITF_Empty ,
    output [ADDR_WIDTH                          -1 : 0] CCUITF_ReqNum,
    output [ADDR_WIDTH                          -1 : 0] CCUITF_Addr  ,
        // Configure
    input   [PORT_WIDTH                         -1 : 0] ITFCCU_Dat,             
    input                                               ITFCCU_DatVld,          
    output                                              CCUITF_DatRdy,

    output  [DRAM_ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT) -1 : 0] CCUITF_BaseAddr,

    output                                              CCUSYA_Rst,  //
    output                                              CCUSYA_CfgVld,
    input                                               SYACCU_CfgRdy,
    output  reg[2                               -1 : 0] CCUSYA_CfgMod,
    output  reg[IDX_WIDTH                       -1 : 0] CCUSYA_CfgNip, 
    output  reg[CHN_WIDTH                       -1 : 0] CCUSYA_CfgChi,         
    output  reg[20                              -1 : 0] CCUSYA_CfgScale,        
    output  reg[ACT_WIDTH                       -1 : 0] CCUSYA_CfgShift,        
    output  reg[ACT_WIDTH                       -1 : 0] CCUSYA_CfgZp,

    output                                              CCUPOL_Rst,
    output                                              CCUPOL_CfgVld,
    input                                               POLCCU_CfgRdy,
    output  reg [MAP_WIDTH                      -1 : 0] CCUPOL_CfgK,
    output  reg [IDX_WIDTH                      -1 : 0] CCUPOL_CfgNip,
    output  reg [CHN_WIDTH                      -1 : 0] CCUPOL_CfgChi,

    output                                              CCUCTR_Rst,
    output                                              CCUCTR_CfgVld,
    input                                               CTRCCU_CfgRdy,
    output  reg                                         CCUCTR_CfgMod,         
    output  reg [IDX_WIDTH                      -1 : 0] CCUCTR_CfgNip,                    
    output  reg [IDX_WIDTH                      -1 : 0] CCUCTR_CfgNop,          
    output  reg [MAP_WIDTH                      -1 : 0] CCUCTR_CfgK,  

    output                                              CCUGLB_Rst,
    output [NUM_RDPORT+NUM_WRPORT               -1 : 0] CCUGLB_CfgVld ,         
    input  [NUM_RDPORT+NUM_WRPORT               -1 : 0] GLBCCU_CfgRdy ,         
    output [NUM_BANK*(NUM_RDPORT + NUM_WRPORT)  -1 : 0] CCUGLB_CfgBankPort ,
    output [ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)  -1 : 0] CCUGLB_CfgPort_AddrMax, 
    output [($clog2(MAXPAR) + 1)*NUM_RDPORT     -1 : 0] CCUGLB_CfgRdPortParBank,
    output [($clog2(MAXPAR) + 1)*NUM_WRPORT     -1 : 0] CCUGLB_CfgWrPortParBank      

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam OPCODE_WIDTH = $clog2(OPNUM);

localparam IDLE     = 4'b0000;
localparam RD_ISA   = 4'b0001;
localparam IDLE_CFG = 4'b0010;
localparam FNH      = 4'b0011;
localparam ARRAY_CFG= 4'b1000; // 0
localparam CONV_CFG = 4'b1001; // 1
localparam POL_CFG  = 4'b1010; // 2ISA_WrAddr
localparam CTR_CFG  = 4'b1011; // 3


localparam OpCode_Array = 3'd0;
localparam OpCode_Conv  = 3'd1;
localparam OpCode_Pool  = 3'd2;
localparam OpCode_CTR   = 3'd3;


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                                        ISA_Full;
wire                                        ISA_Empty;
reg [NUM_LAYER_WIDTH+ISARDWORD_WIDTH-1 : 0] ISA_WrAddr;
reg [NUM_LAYER_WIDTH+ISARDWORD_WIDTH-1 : 0] ISA_RdAddr;
reg [NUM_LAYER_WIDTH+ISARDWORD_WIDTH-1 : 0] ISA_RdAddr_Array [0 : OPNUM -1];
wire [(NUM_LAYER_WIDTH+ISARDWORD_WIDTH)*OPNUM-1 : 0] ISA_RdAddr1D;
reg [NUM_LAYER_WIDTH+ISARDWORD_WIDTH-1 : 0] ISA_RdAddrMin;
wire                                        ISA_WrEn;
reg                                         ISA_RdEn;
reg [ISARDWORD_WIDTH                -1 : 0] ISA_CntRdWord;
wire[ISARDWORD_WIDTH                -1 : 0] ISA_CntRdWord_d;

wire [PORT_WIDTH                    -1 : 0] ISA_DatOut;

reg [NUM_LAYER_WIDTH                -1 : 0] CfgNumLy;
wire                                        ISA_RdEn_d;
wire [OPCODE_WIDTH                  -1 : 0] OpCode;
reg                                         OpCodeMatch;
reg [5                              -1 : 0] OpNumWord[0 : OPNUM -1];

reg [NUM_LAYER_WIDTH                -1 : 0] NumLy;
reg                                         Mode;
reg [DRAM_ADDR_WIDTH                -1 : 0] DramDatAddr; 
reg [DRAM_ADDR_WIDTH                -1 : 0] DramWgtAddr; 
reg [DRAM_ADDR_WIDTH                -1 : 0] DramCrdAddr; 
reg [DRAM_ADDR_WIDTH                -1 : 0] DramWrMapAddr;
reg [DRAM_ADDR_WIDTH                -1 : 0] DramRdMapAddr;
reg [DRAM_ADDR_WIDTH                -1 : 0] DramOfmAddr; 
reg [ NUM_BANK                      -1 : 0] ITF_WrPortActBank;
reg [ NUM_BANK                      -1 : 0] ITF_WrPortWgtBank;
reg [ NUM_BANK                      -1 : 0] ITF_WrPortCrdBank;
reg [ NUM_BANK                      -1 : 0] ITF_WrPortMapBank;
reg [ NUM_BANK                      -1 : 0] SYA_WrPortOfmBank;
reg [ NUM_BANK                      -1 : 0] POL_WrPortOfmBank;
reg [ NUM_BANK                      -1 : 0] CTR_WrPortDstBank;
reg [ NUM_BANK                      -1 : 0] CTR_WrPortMapBank;
reg [ NUM_BANK                      -1 : 0] ITF_RdPortMapBank;
reg [ NUM_BANK                      -1 : 0] ITF_RdPortOfmBank;
reg [ NUM_BANK                      -1 : 0] SYA_RdPortActBank;
reg [ NUM_BANK                      -1 : 0] SYA_RdPortWgtBank;
reg [ NUM_BANK                      -1 : 0] POL_RdPortOfmBank;
reg [ NUM_BANK                      -1 : 0] POL_RdPortMapBank;
reg [ NUM_BANK                      -1 : 0] CTR_RdPortCrdBank;
reg [ NUM_BANK                      -1 : 0] CTR_RdPortDstBank;
reg [ ADDR_WIDTH                    -1 : 0] ITF_WrPortAct_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] ITF_WrPortWgt_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] ITF_WrPortCrd_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] ITF_WrPortMap_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] SYA_WrPortOfm_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] POL_WrPortOfm_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] CTR_WrPortDst_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] CTR_WrPortMap_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] ITF_RdPortMap_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] ITF_RdPortOfm_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] SYA_RdPortAct_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] SYA_RdPortWgt_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] POL_RdPortOfm_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] POL_RdPortMap_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] CTR_RdPortCrd_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] CTR_RdPortDst_AddrMax;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_WrPortActParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_WrPortWgtParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_WrPortCrdParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_WrPortMapParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] SYA_WrPortOfmParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] POL_WrPortOfmParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] CTR_WrPortDstParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] CTR_WrPortMapParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_RdPortMapParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_RdPortOfmParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] SYA_RdPortActParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] SYA_RdPortWgtParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] POL_RdPortOfmParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] POL_RdPortMapParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] CTR_RdPortCrdParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] CTR_RdPortDstParBank;

wire                                        Conv_CfgRdy;
wire                                        Pool_CfgRdy;
wire                                        Ctr_CfgRdy;
reg                                         Conv_CfgVld;
reg                                         Pool_CfgVld;
reg                                         Ctr_CfgVld;

reg [CHN_WIDTH                      -1 : 0] Cho;

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE    :   if( TOPCCU_start)
                        next_state <= RD_ISA; //
                    else
                        next_state <= IDLE;

        RD_ISA  :   if( ISA_Full ) // 
                        next_state <= IDLE_CFG;
                    else
                        next_state <= RD_ISA;

        IDLE_CFG:   if (NumLy == CfgNumLy)
                        next_state <= FNH;
                    else if ( ISA_Empty )
                        next_state <= RD_ISA;
                    else if (NumLy==0)
                        next_state <= ARRAY_CFG;
                    else if (SYACCU_CfgRdy)
                        next_state <= CONV_CFG;
                    else if (POLCCU_CfgRdy)
                        next_state <= POL_CFG;
                    else if (CTRCCU_CfgRdy)
                        next_state <= CTR_CFG;
                    else 
                        next_state <= IDLE_CFG;

        ARRAY_CFG:  if ( ISA_RdEn_d & OpCode == OpCode_Array)
                        next_state <= IDLE_CFG;
                    else 
                        next_state <= ARRAY_CFG;
        CONV_CFG:   if( SYACCU_CfgRdy & CCUSYA_CfgVld)
                        next_state <= IDLE_CFG;
                    else
                        next_state <= CONV_CFG;
        POL_CFG :   if (POLCCU_CfgRdy & CCUPOL_CfgVld)
                        next_state <= IDLE_CFG;
                    else 
                        next_state <= POL_CFG;
        CTR_CFG :   if (CTRCCU_CfgRdy & CCUCTR_CfgVld)
                        next_state <= IDLE_CFG;
                    else 
                        next_state <= CTR_CFG;
        FNH     :   next_state <= IDLE;
        default :   next_state <= IDLE;
    endcase
end
always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

//=====================================================================================================================
// Logic Design TOP
//=====================================================================================================================
assign CCUTOP_NetFnh = state == FNH;
always @(posedge clk or rst_n) begin
    if(!rst_n) begin
        NumLy <= 0;
    end else if(state ==IDLE) begin
        NumLy <= 0;
    end else if(state==IDLE_CFG & next_state[3]) begin // transfer to layer config
        NumLy <= NumLy + 1;
    end
end

//=====================================================================================================================
// Logic Design 3: ISA RAM Write
//=====================================================================================================================
// Write Path
assign CCUITF_Empty = ISA_Empty;
assign CCUITF_ReqNum = SRAM_WORD_ISA - (ISA_WrAddr - ISA_RdAddrMin); // ISA_Empty number
assign CCUITF_Addr = 0;

assign ISA_WrEn = ITFCCU_DatVld & CCUITF_DatRdy;
assign CCUITF_DatRdy = state == RD_ISA;


always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        ISA_WrAddr <= 0;
    end else if (state == IDLE ) begin
        ISA_WrAddr <= 0;
    end else if (ISA_WrEn ) begin
        ISA_WrAddr <= ISA_WrAddr + 1;
    end
end

assign ISA_Full = ISA_WrAddr - ISA_RdAddrMin == SRAM_WORD_ISA;
assign ISA_Empty = ISA_WrAddr == ISA_RdAddrMin;


//=====================================================================================================================
// Logic Design 3: Address of ISA RAM: input ReqCfg, output AckCfg
//=====================================================================================================================

always @(posedge clk or rst_n) begin
    if (!rst_n)
        OpNumWord[0] = 1;// localparam Word_Array = 1;
        OpNumWord[1] = 6;// localparam Word_Conv  = 2;
        OpNumWord[2] = 3;// localparam Word_Pool  = 2;
        OpNumWord[3] = 5;// localparam Word_CTR   = 1;
end

genvar i;
generate
    for(i=0; i<OPNUM; i=i+1) begin
        always @(posedge clk or negedge rst_n)  begin
            if (!rst_n) begin
                ISA_RdAddr_Array[i] <= 0;
            end else if ( state == IDLE ) begin
                ISA_RdAddr_Array[i] <= 0;
            end else if ( ISA_RdEn & state[0 +: 3] == i) begin
                ISA_RdAddr_Array[i] <= ISA_RdAddr_Array[i] + 1;
            end
        end
        assign ISA_RdAddr1D[(NUM_LAYER_WIDTH+ISARDWORD_WIDTH)*i +: (NUM_LAYER_WIDTH+ISARDWORD_WIDTH)] = ISA_RdAddr_Array[i];
    end
endgenerate

integer j;
always @(*) begin
    OpCodeMatch = 0;
    ISA_RdAddr = 0;
    ISA_RdEn = 0;
    ISA_CntRdWord = ISA_CntRdWord_d;
    for (j=0; j<OPNUM; j=j+1) begin
        if ( state[0 +: 3] == j) begin
            ISA_CntRdWord = (ISA_RdEn_d & OpCodeMatch) ? ISA_CntRdWord + 1 : ISA_CntRdWord;
            OpCodeMatch = OpCode == j;
            ISA_RdEn = !(ISA_CntRdWord[j] == OpNumWord[j] & OpCodeMatch);

            ISA_RdAddr = ISA_RdAddr_Array[j];
        end
    end
end


//=====================================================================================================================
// Logic Design 3: ISA Decoder
//=====================================================================================================================
assign OpCode = ISA_DatOut[0 +: 3];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        CfgNumLy                <= 0;
        Mode                    <= 0;
        DramDatAddr             <= 0; 
        DramWgtAddr             <= 0; 
        DramCrdAddr             <= 0; 
        DramWrMapAddr           <= 0;
        DramRdMapAddr           <= 0;
        DramOfmAddr             <= 0; 
        ITF_WrPortActBank       <= 0;
        ITF_WrPortWgtBank       <= 0;
        ITF_WrPortCrdBank       <= 0;
        ITF_WrPortMapBank       <= 0;
        SYA_WrPortOfmBank       <= 0;
        POL_WrPortOfmBank       <= 0;
        CTR_WrPortDstBank       <= 0;
        CTR_WrPortMapBank       <= 0;
        ITF_RdPortMapBank       <= 0;
        ITF_RdPortOfmBank       <= 0;
        SYA_RdPortActBank       <= 0;
        SYA_RdPortWgtBank       <= 0;
        POL_RdPortOfmBank       <= 0;
        POL_RdPortMapBank       <= 0;
        CTR_RdPortCrdBank       <= 0;
        CTR_RdPortDstBank       <= 0;
        ITF_WrPortAct_AddrMax   <= 0;
        ITF_WrPortWgt_AddrMax   <= 0;
        ITF_WrPortCrd_AddrMax   <= 0;
        ITF_WrPortMap_AddrMax   <= 0;
        SYA_WrPortOfm_AddrMax   <= 0;
        POL_WrPortOfm_AddrMax   <= 0;
        CTR_WrPortDst_AddrMax   <= 0;
        CTR_WrPortMap_AddrMax   <= 0;
        ITF_RdPortMap_AddrMax   <= 0;
        ITF_RdPortOfm_AddrMax   <= 0;
        SYA_RdPortAct_AddrMax   <= 0;
        SYA_RdPortWgt_AddrMax   <= 0;
        POL_RdPortOfm_AddrMax   <= 0;
        POL_RdPortMap_AddrMax   <= 0;
        CTR_RdPortCrd_AddrMax   <= 0;
        CTR_RdPortDst_AddrMax   <= 0;
        ITF_WrPortActParBank    <= 0;
        ITF_WrPortWgtParBank    <= 0;
        ITF_WrPortCrdParBank    <= 0;
        ITF_WrPortMapParBank    <= 0;
        SYA_WrPortOfmParBank    <= 0;
        POL_WrPortOfmParBank    <= 0;
        CTR_WrPortDstParBank    <= 0;
        CTR_WrPortMapParBank    <= 0;
        ITF_RdPortMapParBank    <= 0;
        ITF_RdPortOfmParBank    <= 0;
        SYA_RdPortActParBank    <= 0;
        SYA_RdPortWgtParBank    <= 0;
        POL_RdPortOfmParBank    <= 0;
        POL_RdPortMapParBank    <= 0;
        CTR_RdPortCrdParBank    <= 0;
        CTR_RdPortDstParBank    <= 0;
        Conv_CfgVld             <= 0;
        Pool_CfgVld             <= 0;
        Ctr_CfgVld              <= 0;
    end else if ( ISA_RdEn_d ) begin
        if ( OpCode == OpCode_Array) begin
            {CfgNumLy, Mode} <= ISA_DatOut[PORT_WIDTH -1 : 3];

        end else if ( OpCode == OpCode_Conv) begin
            if (ISA_CntRdWord == 1) begin
                DramDatAddr     <= ISA_DatOut[3  +: 32];
                DramWgtAddr     <= ISA_DatOut[35 +: 32];
                DramOfmAddr     <= ISA_DatOut[67 +: 32];
                CCUSYA_CfgNip   <= ISA_DatOut[99 +: 16];
                CCUSYA_CfgChi   <= ISA_DatOut[115+: 13];
            end else if (ISA_CntRdWord == 2) begin
                Cho             <= ISA_DatOut[0  +: 12];       
                CCUSYA_CfgScale <= ISA_DatOut[12 +: 20];       
                CCUSYA_CfgShift <= ISA_DatOut[32 +:  8];
                CCUSYA_CfgZp    <= ISA_DatOut[40 +:  8];
                CCUSYA_CfgMod   <= ISA_DatOut[48 +:  1];
            end else if (ISA_CntRdWord == 3) begin
                // GLB Ports
                SYA_RdPortActBank <= ISA_DatOut[0  +: 32];
                SYA_RdPortWgtBank <= ISA_DatOut[32 +: 32];
                SYA_WrPortOfmBank <= ISA_DatOut[64 +: 32];
            end else if (ISA_CntRdWord == 4) begin
                ITF_WrPortActBank <= ISA_DatOut[0 +: 32];
                ITF_WrPortWgtBank <= ISA_DatOut[32 +: 32];
                ITF_RdPortOfmBank <= ISA_DatOut[64 +: 32];
            end else if (ISA_CntRdWord == 5) begin
                SYA_RdPortAct_AddrMax <= ISA_DatOut[0 +: 16];
                SYA_RdPortWgt_AddrMax <= ISA_DatOut[16 +: 16];
                SYA_WrPortOfm_AddrMax <= ISA_DatOut[32 +: 16];
                SYA_RdPortActParBank  <= ISA_DatOut[48 +: 6];
                SYA_RdPortWgtParBank  <= ISA_DatOut[54 +: 6];
                SYA_WrPortOfmParBank  <= ISA_DatOut[60 +: 6];
            end else if (ISA_CntRdWord == 6) begin
                ITF_WrPortAct_AddrMax <= ISA_DatOut[0 +: 16];
                ITF_WrPortWgt_AddrMax <= ISA_DatOut[16 +: 16];
                ITF_RdPortOfm_AddrMax <= ISA_DatOut[32 +: 16];
                ITF_WrPortActParBank  <= ISA_DatOut[48 +: 6];
                ITF_WrPortWgtParBank  <= ISA_DatOut[54 +: 6];
                ITF_RdPortOfmParBank  <= ISA_DatOut[60 +: 6];
            end
            if ( Conv_CfgVld & Conv_CfgRdy)
                Conv_CfgVld <= 1'b0;
            else if(ISA_CntRdWord == 4 )
                Conv_CfgVld <= 1'b1;

        end else if (OpCode == OpCode_Pool) begin
            if (ISA_CntRdWord == 1) begin
                DramWrMapAddr   <= ISA_DatOut[3  +: 32];
                CCUPOL_CfgNip   <= ISA_DatOut[35 +: 16];
                CCUPOL_CfgChi   <= ISA_DatOut[51 +: 12];// 
                CCUPOL_CfgK     <= ISA_DatOut[63 +: 16];// 
                
            end else if(ISA_CntRdWord == 2) begin
                POL_RdPortOfmBank <= ISA_DatOut[0  +: 32];
                POL_WrPortOfmBank <= ISA_DatOut[32 +: 32];
                POL_RdPortMapBank <= ISA_DatOut[64 +: 32];
                ITF_WrPortMapBank <= ISA_DatOut[96 +: 32];
            end else if(ISA_CntRdWord == 3) begin
                POL_RdPortOfm_AddrMax <= ISA_DatOut[0  +: 16];
                POL_WrPortOfm_AddrMax <= ISA_DatOut[16 +: 16];
                POL_RdPortMap_AddrMax <= ISA_DatOut[32 +: 16];
                ITF_WrPortMap_AddrMax <= ISA_DatOut[48 +: 16];
                POL_RdPortOfmParBank  <= ISA_DatOut[64 +:  6];
                POL_WrPortOfmParBank  <= ISA_DatOut[70 +:  6];
                POL_RdPortMapParBank  <= ISA_DatOut[76 +:  6];
                ITF_WrPortMapParBank  <= ISA_DatOut[82 +:  6];
            end
            if (Pool_CfgVld & Pool_CfgRdy) begin
                Pool_CfgVld <= 1'b0;
            end else if(ISA_CntRdWord == 3) 
                Pool_CfgVld <= 1'b1;

        end else if (OpCode == OpCode_CTR) begin
                if(ISA_CntRdWord == 1) begin
                    CCUCTR_CfgMod   <= ISA_DatOut[3];
                    DramCrdAddr        <= ISA_DatOut[4  +: 32];
                    CCUCTR_CfgNip   <= ISA_DatOut[36 +: 16];
                    CCUCTR_CfgNop   <= ISA_DatOut[52 +: 16];
                    CCUCTR_CfgK     <= ISA_DatOut[68 +: 6];
                    DramRdMapAddr   <= ISA_DatOut[74 +: 32];
                end else if(ISA_CntRdWord == 2) begin
                    ITF_WrPortCrdBank <= ISA_DatOut[0 +: 32];
                    ITF_RdPortMapBank <= ISA_DatOut[32+: 32];
                    CTR_WrPortDstBank <= ISA_DatOut[64+: 32];
                end else if(ISA_CntRdWord == 3) begin
                    CTR_WrPortMapBank <= ISA_DatOut[0 +: 32];
                    CTR_RdPortCrdBank <= ISA_DatOut[32+: 32];
                    CTR_RdPortDstBank <= ISA_DatOut[64+: 32];
                end else if( ISA_CntRdWord == 4) begin
                    ITF_WrPortCrd_AddrMax <= ISA_DatOut[0  +: 16];
                    ITF_RdPortMap_AddrMax <= ISA_DatOut[16 +: 16];
                    CTR_WrPortDst_AddrMax <= ISA_DatOut[32 +: 16];
                    CTR_WrPortMap_AddrMax <= ISA_DatOut[48 +: 16];
                    CTR_RdPortCrd_AddrMax <= ISA_DatOut[64 +: 16];
                    CTR_RdPortDst_AddrMax <= ISA_DatOut[80 +: 16];
                end else if ( ISA_CntRdWord == 5) begin 
                    ITF_WrPortCrdParBank <= ISA_DatOut[0  +: 6];
                    ITF_RdPortMapParBank <= ISA_DatOut[6  +: 6];
                    CTR_WrPortDstParBank <= ISA_DatOut[12 +: 6];
                    CTR_WrPortMapParBank <= ISA_DatOut[18 +: 6];
                    CTR_RdPortCrdParBank <= ISA_DatOut[24 +: 6];
                    CTR_RdPortDstParBank <= ISA_DatOut[30 +: 6];            
                end
                if(Ctr_CfgVld & Ctr_CfgRdy) 
                    Ctr_CfgVld <= 1'b0;
                else
                    Ctr_CfgVld <= 1'b1;
        end
                
    end 
end


//=====================================================================================================================
// Logic Design 3: SYA Control
//=====================================================================================================================
assign CCUSYA_Rst = state == IDLE;
assign CCUPOL_Rst = state == IDLE;
assign CCUCTR_Rst = state == IDLE;
assign CCUGLB_Rst = state == IDLE;


//=====================================================================================================================
// Logic Design 4: GLB Control
//=====================================================================================================================

generate
    for (i=0; i<NUM_BANK; i=i+1) begin 
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 0] = ITF_WrPortActBank[i];
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 1] = ITF_WrPortWgtBank[i];  
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 2] = ITF_WrPortCrdBank[i];  
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 3] = ITF_WrPortMapBank[i];  
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 4] = SYA_WrPortOfmBank[i];
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 5] = POL_WrPortOfmBank[i];
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 6] = CTR_WrPortDstBank[i];
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 7] = CTR_WrPortMapBank[i];
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 0] = ITF_RdPortMapBank[i];
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 1] = ITF_RdPortOfmBank[i];
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 2] = SYA_RdPortActBank[i];// SYA_RdPortActBank is 4th Column of SYA_RdPortActBank 
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 3] = SYA_RdPortWgtBank[i];
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 4] = POL_RdPortOfmBank[i];
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 5] = POL_RdPortMapBank[i];
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 6] = CTR_RdPortCrdBank[i];
        assign CCUGLB_CfgBankPort[i*(NUM_RDPORT+NUM_WRPORT) + 7] = CTR_RdPortDstBank[i];
    end
endgenerate

assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*0      +: ADDR_WIDTH] = ITF_WrPortAct_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*1      +: ADDR_WIDTH] = ITF_WrPortWgt_AddrMax;  
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*2      +: ADDR_WIDTH] = ITF_WrPortCrd_AddrMax;  
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*3      +: ADDR_WIDTH] = ITF_WrPortMap_AddrMax;  
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*4      +: ADDR_WIDTH] = SYA_WrPortOfm_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*5      +: ADDR_WIDTH] = POL_WrPortOfm_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*6      +: ADDR_WIDTH] = CTR_WrPortDst_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*7      +: ADDR_WIDTH] = CTR_WrPortMap_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(0+8)  +: ADDR_WIDTH] = ITF_RdPortMap_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(1+8)  +: ADDR_WIDTH] = ITF_RdPortOfm_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(2+8)  +: ADDR_WIDTH] = SYA_RdPortAct_AddrMax;// SYA_RdPortActBank is 4th Column of SYA_RdPortActBank 
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(3+8)  +: ADDR_WIDTH] = SYA_RdPortWgt_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(4+8)  +: ADDR_WIDTH] = POL_RdPortOfm_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(5+8)  +: ADDR_WIDTH] = POL_RdPortMap_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(6+8)  +: ADDR_WIDTH] = CTR_RdPortCrd_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(7+8)  +: ADDR_WIDTH] = CTR_RdPortDst_AddrMax;

assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*0 +: ($clog2(MAXPAR) + 1)] = ITF_WrPortActParBank;
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*1 +: ($clog2(MAXPAR) + 1)] = ITF_WrPortWgtParBank;  
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*2 +: ($clog2(MAXPAR) + 1)] = ITF_WrPortCrdParBank;  
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*3 +: ($clog2(MAXPAR) + 1)] = ITF_WrPortMapParBank;  
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*4 +: ($clog2(MAXPAR) + 1)] = SYA_WrPortOfmParBank;
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*5 +: ($clog2(MAXPAR) + 1)] = POL_WrPortOfmParBank;
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*6 +: ($clog2(MAXPAR) + 1)] = CTR_WrPortDstParBank;
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*7 +: ($clog2(MAXPAR) + 1)] = CTR_WrPortMapParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*0 +: ($clog2(MAXPAR) + 1)] = ITF_RdPortMapParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*1 +: ($clog2(MAXPAR) + 1)] = ITF_RdPortOfmParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*2 +: ($clog2(MAXPAR) + 1)] = SYA_RdPortActParBank;// SYA_RdPortActBank is 4th Column of SYA_RdPortActBank 
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*3 +: ($clog2(MAXPAR) + 1)] = SYA_RdPortWgtParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*4 +: ($clog2(MAXPAR) + 1)] = POL_RdPortOfmParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*5 +: ($clog2(MAXPAR) + 1)] = POL_RdPortMapParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*6 +: ($clog2(MAXPAR) + 1)] = CTR_RdPortCrdParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*7 +: ($clog2(MAXPAR) + 1)] = CTR_RdPortDstParBank;


assign Conv_CfgRdy = SYACCU_CfgRdy & GLBCCU_CfgRdy[0] & GLBCCU_CfgRdy[1] & GLBCCU_CfgRdy[4] &  GLBCCU_CfgRdy[9] &  GLBCCU_CfgRdy[10] &  GLBCCU_CfgRdy[11];
assign CCUSYA_CfgVld = Conv_CfgVld & SYACCU_CfgRdy;
assign CCUGLB_CfgVld[ 0] = Conv_CfgVld & GLBCCU_CfgRdy[ 0];
assign CCUGLB_CfgVld[ 1] = Conv_CfgVld & GLBCCU_CfgRdy[ 1];
assign CCUGLB_CfgVld[ 4] = Conv_CfgVld & GLBCCU_CfgRdy[ 4];
assign CCUGLB_CfgVld[ 9] = Conv_CfgVld & GLBCCU_CfgRdy[ 9];
assign CCUGLB_CfgVld[10] = Conv_CfgVld & GLBCCU_CfgRdy[10];
assign CCUGLB_CfgVld[11] = Conv_CfgVld & GLBCCU_CfgRdy[11];

assign Pool_CfgRdy = POLCCU_CfgRdy & GLBCCU_CfgRdy[3] & GLBCCU_CfgRdy[5] & GLBCCU_CfgRdy[12] & GLBCCU_CfgRdy[13];
assign CCUPOL_CfgVld = Pool_CfgVld & POLCCU_CfgRdy; 
assign GLBCCU_CfgRdy[ 3] = Pool_CfgVld & GLBCCU_CfgRdy[ 3];
assign GLBCCU_CfgRdy[ 5] = Pool_CfgVld & GLBCCU_CfgRdy[ 5];
assign GLBCCU_CfgRdy[12] = Pool_CfgVld & GLBCCU_CfgRdy[12];
assign GLBCCU_CfgRdy[13] = Pool_CfgVld & GLBCCU_CfgRdy[13];

assign Ctr_CfgRdy = CTRCCU_CfgRdy & GLBCCU_CfgRdy[2] & GLBCCU_CfgRdy[6] & GLBCCU_CfgRdy[7] & GLBCCU_CfgRdy[8] & GLBCCU_CfgRdy[14] & GLBCCU_CfgRdy[15];
assign CCUCTR_CfgVld = Ctr_CfgVld & CTRCCU_CfgRdy;
assign GLBCCU_CfgRdy[ 2] = Ctr_CfgVld & GLBCCU_CfgRdy[ 2];
assign GLBCCU_CfgRdy[ 6] = Ctr_CfgVld & GLBCCU_CfgRdy[ 6];
assign GLBCCU_CfgRdy[ 7] = Ctr_CfgVld & GLBCCU_CfgRdy[ 7];
assign GLBCCU_CfgRdy[ 8] = Ctr_CfgVld & GLBCCU_CfgRdy[ 8];
assign GLBCCU_CfgRdy[14] = Ctr_CfgVld & GLBCCU_CfgRdy[14];
assign GLBCCU_CfgRdy[15] = Ctr_CfgVld & GLBCCU_CfgRdy[15];


assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*0     +: DRAM_ADDR_WIDTH] = DramDatAddr; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*1     +: DRAM_ADDR_WIDTH] = DramWgtAddr; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*2     +: DRAM_ADDR_WIDTH] = DramCrdAddr; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*3     +: DRAM_ADDR_WIDTH] = DramWrMapAddr;//
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*4     +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*5     +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*6     +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*7     +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(0+8) +: DRAM_ADDR_WIDTH] = DramRdMapAddr; // Read
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(1+8) +: DRAM_ADDR_WIDTH] = DramOfmAddr; // Read
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(2+8) +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(3+8) +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(4+8) +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(5+8) +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(6+8) +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(7+8) +: DRAM_ADDR_WIDTH] = 0; // 

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

RAM#(
    .SRAM_BIT     ( PORT_WIDTH   ),
    .SRAM_BYTE    ( 1            ),
    .SRAM_WORD    ( SRAM_WORD_ISA),
    .CLOCK_PERIOD ( CLOCK_PERIOD )
)u_RAM_ISA(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .addr_r       ( ISA_RdAddr   ),
    .addr_w       ( ISA_WrAddr   ),
    .read_en      ( ISA_RdEn     ),
    .write_en     ( ISA_WrEn     ),
    .data_in      ( ITFCCU_Dat   ),
    .data_out     ( ISA_DatOut     )
);

MINMAX#(
    .DATA_WIDTH ( (NUM_LAYER_WIDTH+ISARDWORD_WIDTH) ),
    .PORT       ( OPNUM ),
    .MINMAX     ( 0 )
)u_MINMAX(
    .IN         ( ISA_RdAddr1D         ),
    .IDX        ( AddrRdMinIdx        ),
    .VALUE      ( ISA_RdAddrMin      )
);


DELAY#(
    .NUM_STAGES ( 1 ),
    .DATA_WIDTH ( 1 )
)u_DELAY_read_en_d(
    .CLK        ( clk        ),
    .RST_N      ( rst_n      ),
    .DIN        ( ISA_RdEn        ),
    .DOUT       ( ISA_RdEn_d       )
);

DELAY#(
    .NUM_STAGES ( 1 ),
    .DATA_WIDTH ( ISARDWORD_WIDTH )
)u_DELAY_cnt_word_d(
    .CLK        ( clk        ),
    .RST_N      ( rst_n      ),
    .DIN        ( ISA_CntRdWord        ),
    .DOUT       ( ISA_CntRdWord_d       )
);


endmodule
