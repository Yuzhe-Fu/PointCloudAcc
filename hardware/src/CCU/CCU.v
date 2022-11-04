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
    parameter ISA_SRAM_WORD         = 64,
    parameter SRAM_WIDTH            = 256,
    parameter PORT_WIDTH            = 128,
    parameter POOL_CORE             = 6,
    parameter CLOCK_PERIOD          = 10,

    parameter ADDR_WIDTH            = 16,
    parameter DRAM_ADDR_WIDTH       = 32,
    parameter GLB_NUM_RDPORT        = 2,
    parameter GLB_NUM_WRPORT        = 3,
    parameter IDX_WIDTH             = 16,
    parameter CHN_WIDTH             = 12,
    parameter QNTSL_WIDTH           = 20,
    parameter ACT_WIDTH             = 8,
    parameter MAP_WIDTH             = 6,
    parameter NUM_LAYER_WIDTH       = 20,
    parameter ISARDWORD_WIDTH       = 4,
    parameter OPNUM                 = 6,

    parameter MAXPAR                = 32,
    parameter NUM_BANK              = 32,
    parameter ITF_NUM_RDPORT        = 2,
    parameter ITF_NUM_WRPORT        = 4

    )(
    input                               clk                     ,
    input                               rst_n                   ,
    input                                               TOPCCU_start,
    output                                              CCUTOP_NetFnh,
    output                                              CCUITF_Empty ,
    output [ADDR_WIDTH                          -1 : 0] CCUITF_ReqNum,
    output [ADDR_WIDTH                          -1 : 0] CCUITF_Addr  ,
        // Configure
    input   [SRAM_WIDTH                         -1 : 0] ITFCCU_Dat,             
    input                                               ITFCCU_DatVld,          
    output                                              CCUITF_DatRdy,

    output  [DRAM_ADDR_WIDTH*(ITF_NUM_RDPORT+ITF_NUM_WRPORT)-1 : 0] CCUITF_BaseAddr,

    output                                              CCUSYA_Rst,  //
    output                                              CCUSYA_CfgVld,
    input                                               SYACCU_CfgRdy,
    output  reg[2                               -1 : 0] CCUSYA_CfgMod,
    output  reg[IDX_WIDTH                       -1 : 0] CCUSYA_CfgNip, 
    output  reg[CHN_WIDTH                       -1 : 0] CCUSYA_CfgChi,         
    output  reg[QNTSL_WIDTH                     -1 : 0] CCUSYA_CfgScale,        
    output  reg[ACT_WIDTH                       -1 : 0] CCUSYA_CfgShift,        
    output  reg[ACT_WIDTH                       -1 : 0] CCUSYA_CfgZp,

    output                                              CCUPOL_Rst,
    output                                              CCUPOL_CfgVld,
    input                                               POLCCU_CfgRdy,
    output  reg [MAP_WIDTH                      -1 : 0] CCUPOL_CfgK,
    output  reg [IDX_WIDTH                      -1 : 0] CCUPOL_CfgNip,
    output  reg [CHN_WIDTH                      -1 : 0] CCUPOL_CfgChi,
    output  reg [IDX_WIDTH*POOL_CORE            -1 : 0] CCUPOL_AddrMin,
    output  reg [IDX_WIDTH*POOL_CORE            -1 : 0] CCUPOL_AddrMax,// Not Included

    output                                              CCUCTR_Rst,
    output                                              CCUCTR_CfgVld,
    input                                               CTRCCU_CfgRdy,
    output  reg                                         CCUCTR_CfgMod,         
    output  reg [IDX_WIDTH                      -1 : 0] CCUCTR_CfgNip,                    
    output  reg [IDX_WIDTH                      -1 : 0] CCUCTR_CfgNop,          
    output  reg [MAP_WIDTH                      -1 : 0] CCUCTR_CfgK,  

    output                                              CCUGLB_Rst,
    output [GLB_NUM_RDPORT+GLB_NUM_WRPORT               -1 : 0] CCUGLB_CfgVld ,         
    input  [GLB_NUM_RDPORT+GLB_NUM_WRPORT               -1 : 0] GLBCCU_CfgRdy ,         
    output [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)*NUM_BANK  -1 : 0] CCUGLB_CfgPortBankFlag ,
    output [ADDR_WIDTH*(GLB_NUM_RDPORT+GLB_NUM_WRPORT)  -1 : 0] CCUGLB_CfgPort_AddrMax, 
    output [($clog2(MAXPAR) + 1)*(GLB_NUM_RDPORT+GLB_NUM_WRPORT)     -1 : 0] CCUGLB_CfgPortParBank  

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam OPCODE_WIDTH = $clog2(OPNUM);
localparam ISA_SRAM_DEPTH_WIDTH = $clog2(ISA_SRAM_WORD);

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
wire [NUM_LAYER_WIDTH+ISARDWORD_WIDTH-1 : 0] ISA_RdAddr;
reg [NUM_LAYER_WIDTH+ISARDWORD_WIDTH-1 : 0] ISA_RdAddr_Array [0 : OPNUM -1];
wire [(NUM_LAYER_WIDTH+ISARDWORD_WIDTH)*OPNUM-1 : 0] ISA_RdAddr1D;
reg [NUM_LAYER_WIDTH+ISARDWORD_WIDTH-1 : 0] ISA_RdAddrMin;
wire                                        ISA_WrEn;
wire                                        ISA_RdEn;
wire [ISARDWORD_WIDTH               -1 : 0] ISA_CntRdWord;
wire[ISARDWORD_WIDTH                -1 : 0] ISA_CntRdWord_d;

wire [PORT_WIDTH                    -1 : 0] ISA_DatOut;
reg                                         ISA_DatOutVld;

reg [NUM_LAYER_WIDTH                -1 : 0] CfgNumLy;
wire                                        ISA_RdEn_d;
wire [OPCODE_WIDTH                  -1 : 0] OpCode;
wire                                        OpCodeMatch;
reg [5                              -1 : 0] OpNumWord[0 : OPNUM -1];

reg [NUM_LAYER_WIDTH                -1 : 0] NumLy;
reg [8                              -1 : 0] Mode;
reg [DRAM_ADDR_WIDTH                -1 : 0] DramActAddr; 
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
reg [ NUM_BANK                      -1 : 0] POL_RdPortOfm0Bank;
reg [ NUM_BANK                      -1 : 0] POL_RdPortOfm1Bank;
reg [ NUM_BANK                      -1 : 0] POL_RdPortOfm2Bank;
reg [ NUM_BANK                      -1 : 0] POL_RdPortOfm3Bank;
reg [ NUM_BANK                      -1 : 0] POL_RdPortOfm4Bank;
reg [ NUM_BANK                      -1 : 0] POL_RdPortOfm5Bank;
reg [ NUM_BANK                      -1 : 0] POL_RdPortMapBank;
reg [ NUM_BANK                      -1 : 0] CTR_RdPortCrdBank;
reg [ NUM_BANK                      -1 : 0] CTR_RdPortDstBank;
reg [ NUM_BANK                      -1 : 0] CTR_WrPortFmkBank;
reg [ NUM_BANK                      -1 : 0] CTR_RdPortFmkBank;
reg [ NUM_BANK                      -1 : 0] CTR_RdPortKmkBank;
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
reg [ ADDR_WIDTH                    -1 : 0] POL_RdPortOfm0_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] POL_RdPortOfm1_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] POL_RdPortOfm2_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] POL_RdPortOfm3_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] POL_RdPortOfm4_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] POL_RdPortOfm5_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] POL_RdPortMap_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] CTR_RdPortCrd_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] CTR_RdPortDst_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] CTR_WrPortFmk_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] CTR_RdPortFmk_AddrMax;
reg [ ADDR_WIDTH                    -1 : 0] CTR_RdPortKmk_AddrMax;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_WrPortActParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_WrPortWgtParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_WrPortCrdParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_WrPortMapParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] SYA_WrPortOfmParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] POL_WrPortOfmParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] CTR_WrPortDstParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] CTR_WrPortMapParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] CTR_WrPortFmkParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] CTR_RdPortFmkParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] CTR_RdPortKmkParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_RdPortMapParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] ITF_RdPortOfmParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] SYA_RdPortActParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] SYA_RdPortWgtParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] POL_RdPortOfm0ParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] POL_RdPortOfm1ParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] POL_RdPortOfm2ParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] POL_RdPortOfm3ParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] POL_RdPortOfm4ParBank;
reg [ ($clog2(MAXPAR) + 1)          -1 : 0] POL_RdPortOfm5ParBank;
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
wire [OPCODE_WIDTH                  -1 : 0] AddrRdMinIdx;

wire                                        PISO_ISAInRdy;
wire [PORT_WIDTH                    -1 : 0] PISO_ISAOut;
wire                                        PISO_ISAOutVld;
wire                                        PISO_ISAOutRdy;
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [4      -1 : 0] state       ;
reg [4      -1 : 0] next_state  ;
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

        IDLE_CFG:   if (NumLy == CfgNumLy & CfgNumLy != 0)
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
always @(posedge clk or negedge rst_n) begin
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
assign CCUITF_ReqNum = ISA_SRAM_WORD - (ISA_WrAddr - ISA_RdAddrMin); // ISA_Empty number
assign CCUITF_Addr = 0;

assign CCUITF_DatRdy = state == RD_ISA & PISO_ISAInRdy;

assign ISA_WrEn = PISO_ISAOutVld & PISO_ISAOutRdy;
assign PISO_ISAOutRdy = !ISA_Full;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ISA_WrAddr <= 0;
    end else if (state == IDLE ) begin
        ISA_WrAddr <= 0;
    end else if (ISA_WrEn ) begin
        ISA_WrAddr <= ISA_WrAddr + 1;
    end
end

assign ISA_Full = ISA_WrAddr - ISA_RdAddrMin == ISA_SRAM_WORD;
assign ISA_Empty = ISA_WrAddr == ISA_RdAddrMin;


//=====================================================================================================================
// Logic Design 3: Address of ISA RAM: input ReqCfg, output AckCfg
//=====================================================================================================================

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        OpNumWord[0] = 1;// localparam Word_Array = 1;
        OpNumWord[1] = 6;// localparam Word_Conv  = 2;
        OpNumWord[2] = 9;// localparam Word_Pool  = 2;
        OpNumWord[3] = 7;// localparam Word_CTR   = 1;
    end
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

assign ISA_CntRdWord = state[3] ? ( (ISA_RdEn_d & OpCodeMatch) ? ISA_CntRdWord_d + 1 : ISA_CntRdWord_d ) : 0;
assign OpCodeMatch = state[3] & OpCode == state[0 +: 3];
assign ISA_RdEn = state[3] & !(ISA_CntRdWord == OpNumWord[state[0 +: 3]] & OpCodeMatch);
assign ISA_RdAddr = ISA_RdAddr_Array[state[0 +: 3]];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ISA_DatOutVld <= 0;
    end else if ( !next_state[3] ) begin // finish CFG
        ISA_DatOutVld <= 0;
    end else if (ISA_RdEn ) begin
        ISA_DatOutVld <= 1;
    end
end


//=====================================================================================================================
// Logic Design 3: ISA Decoder
//=====================================================================================================================
assign OpCode = ISA_DatOutVld ? ISA_DatOut[0 +: 8] : 63;


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        CfgNumLy                <= 0;
        Mode                    <= 0;
        DramActAddr             <= 0; 
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
        POL_RdPortOfm0Bank       <= 0;
        POL_RdPortOfm1Bank       <= 0;
        POL_RdPortOfm2Bank       <= 0;
        POL_RdPortOfm3Bank       <= 0;
        POL_RdPortOfm4Bank       <= 0;
        POL_RdPortOfm5Bank       <= 0;
        POL_RdPortMapBank       <= 0;
        CTR_RdPortCrdBank       <= 0;
        CTR_RdPortDstBank       <= 0;
        CTR_WrPortFmkBank       <= 0;
        CTR_RdPortFmkBank       <= 0;
        CTR_RdPortKmkBank       <= 0;
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
        POL_RdPortOfm0_AddrMax   <= 0;
        POL_RdPortOfm1_AddrMax   <= 0;
        POL_RdPortOfm2_AddrMax   <= 0;
        POL_RdPortOfm3_AddrMax   <= 0;
        POL_RdPortOfm4_AddrMax   <= 0;
        POL_RdPortOfm5_AddrMax   <= 0;
        POL_RdPortMap_AddrMax   <= 0;
        CTR_RdPortCrd_AddrMax   <= 0;
        CTR_RdPortDst_AddrMax   <= 0;
        CTR_WrPortFmk_AddrMax   <= 0;
        CTR_RdPortFmk_AddrMax   <= 0;
        CTR_RdPortKmk_AddrMax   <= 0;
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
        POL_RdPortOfm0ParBank    <= 0;
        POL_RdPortOfm1ParBank    <= 0;
        POL_RdPortOfm2ParBank    <= 0;
        POL_RdPortOfm3ParBank    <= 0;
        POL_RdPortOfm4ParBank    <= 0;
        POL_RdPortOfm5ParBank    <= 0;
        POL_RdPortMapParBank    <= 0;
        CTR_RdPortCrdParBank    <= 0;
        CTR_RdPortDstParBank    <= 0;
        CTR_WrPortFmkParBank    <= 0;
        CTR_RdPortFmkParBank    <= 0;
        CTR_RdPortKmkParBank    <= 0;
        Conv_CfgVld             <= 0;
        Pool_CfgVld             <= 0;
        Ctr_CfgVld              <= 0;
        CCUSYA_CfgNip           <= 0;
        CCUSYA_CfgChi           <= 0;
        Cho                     <= 0;
        CCUSYA_CfgScale         <= 0;
        CCUSYA_CfgShift         <= 0;
        CCUSYA_CfgZp            <= 0;
        CCUSYA_CfgMod           <= 0;
        CCUPOL_CfgNip           <= 0;
        CCUPOL_CfgChi           <= 0;
        CCUPOL_AddrMin          <= 0;
        CCUPOL_AddrMax          <= 0;
        CCUPOL_CfgK             <= 0;
        CCUCTR_CfgMod           <= 0;
        CCUCTR_CfgNip           <= 0;
        CCUCTR_CfgNop           <= 0;
        CCUCTR_CfgK             <= 0;
    end else if ( ISA_RdEn_d ) begin
        if ( OpCode == OpCode_Array) begin
            {CfgNumLy, Mode} <= ISA_DatOut[PORT_WIDTH -1 : 8];

        end else if ( OpCode == OpCode_Conv) begin
            if (ISA_CntRdWord == 1) begin
                DramActAddr     <= ISA_DatOut[8   +: 32];
                DramWgtAddr     <= ISA_DatOut[40  +: 32];
                DramOfmAddr     <= ISA_DatOut[72  +: 32];
            end else if (ISA_CntRdWord == 2) begin
                CCUSYA_CfgNip   <= ISA_DatOut[8  +: 16];
                CCUSYA_CfgChi   <= ISA_DatOut[24 +: 16];
                Cho             <= ISA_DatOut[40 +: 16];       
                CCUSYA_CfgScale <= ISA_DatOut[56 +: 32];       
                CCUSYA_CfgShift <= ISA_DatOut[88 +:  8];
                CCUSYA_CfgZp    <= ISA_DatOut[96 +:  8];
                CCUSYA_CfgMod   <= ISA_DatOut[104+:  8];
            end else if (ISA_CntRdWord == 3) begin
                // GLB Ports
                SYA_RdPortActBank <= ISA_DatOut[8  +: 32];
                SYA_RdPortWgtBank <= ISA_DatOut[40 +: 32];
                SYA_WrPortOfmBank <= ISA_DatOut[72 +: 32];
            end else if (ISA_CntRdWord == 4) begin
                ITF_WrPortActBank <= ISA_DatOut[8  +: 32];
                ITF_WrPortWgtBank <= ISA_DatOut[40 +: 32];
                ITF_RdPortOfmBank <= ISA_DatOut[72 +: 32];
            end else if (ISA_CntRdWord == 5) begin
                SYA_RdPortAct_AddrMax <= ISA_DatOut[ 8 +: 16];
                SYA_RdPortWgt_AddrMax <= ISA_DatOut[24 +: 16];
                SYA_WrPortOfm_AddrMax <= ISA_DatOut[40 +: 16];
                SYA_RdPortActParBank  <= ISA_DatOut[56 +:  8];
                SYA_RdPortWgtParBank  <= ISA_DatOut[64 +:  8];
                SYA_WrPortOfmParBank  <= ISA_DatOut[72 +:  8];
            end else if (ISA_CntRdWord == 6) begin
                ITF_WrPortAct_AddrMax <= ISA_DatOut[ 8 +: 16];
                ITF_WrPortWgt_AddrMax <= ISA_DatOut[24 +: 16];
                ITF_RdPortOfm_AddrMax <= ISA_DatOut[40 +: 16];
                ITF_WrPortActParBank  <= ISA_DatOut[56 +:  8];
                ITF_WrPortWgtParBank  <= ISA_DatOut[64 +:  8];
                ITF_RdPortOfmParBank  <= ISA_DatOut[72 +:  8];
            end
            if ( Conv_CfgVld & Conv_CfgRdy)
                Conv_CfgVld <= 1'b0;
            else if(ISA_CntRdWord == OpNumWord[OpCode] )
                Conv_CfgVld <= 1'b1;

        end else if (OpCode == OpCode_Pool) begin
            if (ISA_CntRdWord == 1) begin
                DramWrMapAddr   <= ISA_DatOut[8  +: 32];
                CCUPOL_CfgNip   <= ISA_DatOut[40 +: 16];
                CCUPOL_CfgChi   <= ISA_DatOut[56 +: 16];// 
                CCUPOL_CfgK     <= ISA_DatOut[72 +: 16];// 
            end else if(ISA_CntRdWord == 2) begin  
                CCUPOL_AddrMin  <= ISA_DatOut[PORT_WIDTH-1 : 8]; // Min BUG with 120 bit
            end else if(ISA_CntRdWord == 3) begin  
                CCUPOL_AddrMax  <= ISA_DatOut[PORT_WIDTH-1 : 8];
            end else if(ISA_CntRdWord == 4) begin
                ITF_WrPortMapBank <= ISA_DatOut[8  +: 32];
                POL_WrPortOfmBank <= ISA_DatOut[40 +: 32];
                POL_RdPortMapBank <= ISA_DatOut[72 +: 32];
            end else if (ISA_CntRdWord == 5) begin
                POL_RdPortOfm0Bank <= ISA_DatOut[8  +: 32];
                POL_RdPortOfm1Bank <= ISA_DatOut[40  +: 32];
                POL_RdPortOfm2Bank <= ISA_DatOut[72  +: 32];
            end else if (ISA_CntRdWord == 6) begin
                POL_RdPortOfm3Bank <= ISA_DatOut[8  +: 32];
                POL_RdPortOfm4Bank <= ISA_DatOut[40  +: 32];
                POL_RdPortOfm5Bank <= ISA_DatOut[72  +: 32];
            end else if(ISA_CntRdWord == 7) begin
                POL_RdPortOfm0_AddrMax <= ISA_DatOut[8  +: 16];
                POL_RdPortOfm1_AddrMax <= ISA_DatOut[24  +: 16];
                POL_RdPortOfm2_AddrMax <= ISA_DatOut[40  +: 16];
                POL_RdPortOfm3_AddrMax <= ISA_DatOut[56  +: 16];
                POL_RdPortOfm4_AddrMax <= ISA_DatOut[72  +: 16];
                POL_RdPortOfm5_AddrMax <= ISA_DatOut[88  +: 16];
            end else if(ISA_CntRdWord == 8) begin
                POL_RdPortOfm0ParBank  <= ISA_DatOut[8 +:  8];
                POL_RdPortOfm1ParBank  <= ISA_DatOut[16 +:  8];
                POL_RdPortOfm2ParBank  <= ISA_DatOut[24 +:  8];
                POL_RdPortOfm3ParBank  <= ISA_DatOut[32 +:  8];
                POL_RdPortOfm4ParBank  <= ISA_DatOut[40 +:  8];
                POL_RdPortOfm5ParBank  <= ISA_DatOut[48 +:  8];
            end else if(ISA_CntRdWord == 9) begin
                POL_WrPortOfm_AddrMax <= ISA_DatOut[24 +: 16];
                POL_RdPortMap_AddrMax <= ISA_DatOut[40 +: 16];
                ITF_WrPortMap_AddrMax <= ISA_DatOut[56 +: 16];
                POL_WrPortOfmParBank  <= ISA_DatOut[80 +:  8];
                POL_RdPortMapParBank  <= ISA_DatOut[88 +:  8];
                ITF_WrPortMapParBank  <= ISA_DatOut[96 +:  8];
            end
            if (Pool_CfgVld & Pool_CfgRdy) begin
                Pool_CfgVld <= 1'b0;
            end else if(ISA_CntRdWord == OpNumWord[OpCode]) 
                Pool_CfgVld <= 1'b1;

        end else if (OpCode == OpCode_CTR) begin
                if(ISA_CntRdWord == 1) begin
                    CCUCTR_CfgMod   <= ISA_DatOut[8  +   8];
                    DramCrdAddr     <= ISA_DatOut[16 +: 32];
                    CCUCTR_CfgNip   <= ISA_DatOut[48 +: 16];
                    CCUCTR_CfgNop   <= ISA_DatOut[64 +: 16];
                    CCUCTR_CfgK     <= ISA_DatOut[80 +:  8];
                    DramRdMapAddr   <= ISA_DatOut[88 +: 32];
                end else if( ISA_CntRdWord == 2) begin
                    ITF_WrPortCrdBank <= ISA_DatOut[8  +: 32];
                    CTR_RdPortCrdBank <= ISA_DatOut[40 +: 32];
                    ITF_RdPortMapBank <= ISA_DatOut[72 +: 32];
                end else if( ISA_CntRdWord == 3) begin
                    CTR_WrPortMapBank <= ISA_DatOut[8  +: 32];
                    CTR_WrPortDstBank <= ISA_DatOut[40 +: 32];
                    CTR_RdPortDstBank <= ISA_DatOut[72 +: 32];
                end else if( ISA_CntRdWord == 4) begin
                    CTR_WrPortFmkBank <= ISA_DatOut[8  +: 32];
                    CTR_RdPortFmkBank <= ISA_DatOut[40 +: 32];
                    CTR_RdPortKmkBank <= ISA_DatOut[72 +: 32];
                end else if( ISA_CntRdWord == 5) begin
                    ITF_WrPortCrd_AddrMax <= ISA_DatOut[8  +: 16];
                    CTR_RdPortCrd_AddrMax <= ISA_DatOut[24 +: 16];
                    CTR_WrPortMap_AddrMax <= ISA_DatOut[40 +: 16];
                    ITF_RdPortMap_AddrMax <= ISA_DatOut[56 +: 16];
                    CTR_WrPortDst_AddrMax <= ISA_DatOut[72 +: 16];
                    CTR_RdPortDst_AddrMax <= ISA_DatOut[88 +: 16];
                end else if( ISA_CntRdWord == 6) begin
                    CTR_WrPortFmk_AddrMax <= ISA_DatOut[8  +: 16];
                    CTR_RdPortFmk_AddrMax <= ISA_DatOut[24 +: 16];
                    CTR_RdPortKmk_AddrMax <= ISA_DatOut[40 +: 16];
                end else if ( ISA_CntRdWord == 7) begin 
                    ITF_WrPortCrdParBank <= ISA_DatOut[8  +: 8];
                    CTR_RdPortCrdParBank <= ISA_DatOut[16 +: 8];
                    ITF_RdPortMapParBank <= ISA_DatOut[24 +: 8];
                    CTR_WrPortMapParBank <= ISA_DatOut[32 +: 8];
                    CTR_WrPortDstParBank <= ISA_DatOut[40 +: 8];
                    CTR_RdPortDstParBank <= ISA_DatOut[48 +: 8];            
                    CTR_WrPortFmkParBank <= ISA_DatOut[56 +: 8];            
                    CTR_RdPortFmkParBank <= ISA_DatOut[64 +: 8];            
                    CTR_RdPortKmkParBank <= ISA_DatOut[72 +: 8];            
                end
                if(Ctr_CfgVld & Ctr_CfgRdy) 
                    Ctr_CfgVld <= 1'b0;
                else if(ISA_CntRdWord == OpNumWord[OpCode]) 
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


assign CCUGLB_CfgPortBankFlag[NUM_BANK* 0                  +: NUM_BANK] = ITF_WrPortActBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK* 1                  +: NUM_BANK] = ITF_WrPortWgtBank ;  
assign CCUGLB_CfgPortBankFlag[NUM_BANK* 2                  +: NUM_BANK] = ITF_WrPortCrdBank ;  
assign CCUGLB_CfgPortBankFlag[NUM_BANK* 3                  +: NUM_BANK] = ITF_WrPortMapBank ;  
assign CCUGLB_CfgPortBankFlag[NUM_BANK* 4                  +: NUM_BANK] = SYA_WrPortOfmBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK* 5                  +: NUM_BANK] = POL_WrPortOfmBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK* 6                  +: NUM_BANK] = CTR_WrPortDstBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK* 7                  +: NUM_BANK] = CTR_WrPortMapBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK* 8                  +: NUM_BANK] = CTR_WrPortFmkBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*( 0+GLB_NUM_WRPORT) +: NUM_BANK] = ITF_RdPortMapBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*( 1+GLB_NUM_WRPORT) +: NUM_BANK] = ITF_RdPortOfmBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*( 2+GLB_NUM_WRPORT) +: NUM_BANK] = SYA_RdPortActBank ;// SYA_RdPortActBank is 4th Column of SYA_RdPortActBank 
assign CCUGLB_CfgPortBankFlag[NUM_BANK*( 3+GLB_NUM_WRPORT) +: NUM_BANK] = SYA_RdPortWgtBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*( 4+GLB_NUM_WRPORT) +: NUM_BANK] = CTR_RdPortCrdBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*( 5+GLB_NUM_WRPORT) +: NUM_BANK] = CTR_RdPortDstBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*( 6+GLB_NUM_WRPORT) +: NUM_BANK] = CTR_RdPortFmkBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*( 7+GLB_NUM_WRPORT) +: NUM_BANK] = CTR_RdPortKmkBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*( 8+GLB_NUM_WRPORT) +: NUM_BANK] = POL_RdPortMapBank ;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*( 9+GLB_NUM_WRPORT) +: NUM_BANK] = POL_RdPortOfm0Bank;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*(10+GLB_NUM_WRPORT) +: NUM_BANK] = POL_RdPortOfm1Bank;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*(11+GLB_NUM_WRPORT) +: NUM_BANK] = POL_RdPortOfm2Bank;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*(12+GLB_NUM_WRPORT) +: NUM_BANK] = POL_RdPortOfm3Bank;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*(13+GLB_NUM_WRPORT) +: NUM_BANK] = POL_RdPortOfm4Bank;
assign CCUGLB_CfgPortBankFlag[NUM_BANK*(14+GLB_NUM_WRPORT) +: NUM_BANK] = POL_RdPortOfm5Bank;


assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*0                    +: ADDR_WIDTH] = ITF_WrPortAct_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*1                    +: ADDR_WIDTH] = ITF_WrPortWgt_AddrMax;  
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*2                    +: ADDR_WIDTH] = ITF_WrPortCrd_AddrMax;  
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*3                    +: ADDR_WIDTH] = ITF_WrPortMap_AddrMax;  
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*4                    +: ADDR_WIDTH] = SYA_WrPortOfm_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*5                    +: ADDR_WIDTH] = POL_WrPortOfm_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*6                    +: ADDR_WIDTH] = CTR_WrPortDst_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*7                    +: ADDR_WIDTH] = CTR_WrPortMap_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*8                    +: ADDR_WIDTH] = CTR_WrPortFmk_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*( 0+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = ITF_RdPortMap_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*( 1+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = ITF_RdPortOfm_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*( 2+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = SYA_RdPortAct_AddrMax;// SYA_RdPortActBank is 4th Column of SYA_RdPortActBank 
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*( 3+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = SYA_RdPortWgt_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*( 4+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = CTR_RdPortCrd_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*( 5+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = CTR_RdPortDst_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*( 6+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = CTR_RdPortFmk_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*( 7+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = CTR_RdPortKmk_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*( 8+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = POL_RdPortMap_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*( 9+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = POL_RdPortOfm0_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(10+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = POL_RdPortOfm1_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(11+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = POL_RdPortOfm2_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(12+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = POL_RdPortOfm3_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(13+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = POL_RdPortOfm4_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(14+GLB_NUM_WRPORT)  +: ADDR_WIDTH] = POL_RdPortOfm5_AddrMax;

assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*0                   +: ($clog2(MAXPAR) + 1)] = ITF_WrPortActParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*1                   +: ($clog2(MAXPAR) + 1)] = ITF_WrPortWgtParBank;  
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*2                   +: ($clog2(MAXPAR) + 1)] = ITF_WrPortCrdParBank;  
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*3                   +: ($clog2(MAXPAR) + 1)] = ITF_WrPortMapParBank;  
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*4                   +: ($clog2(MAXPAR) + 1)] = SYA_WrPortOfmParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*5                   +: ($clog2(MAXPAR) + 1)] = POL_WrPortOfmParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*6                   +: ($clog2(MAXPAR) + 1)] = CTR_WrPortDstParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*7                   +: ($clog2(MAXPAR) + 1)] = CTR_WrPortMapParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*8                   +: ($clog2(MAXPAR) + 1)] = CTR_WrPortFmkParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*( 0+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = ITF_RdPortMapParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*( 1+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = ITF_RdPortOfmParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*( 2+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = SYA_RdPortActParBank;// SYA_RdPortActBank is 4th Column of SYA_RdPortActBank 
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*( 3+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = SYA_RdPortWgtParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*( 4+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = CTR_RdPortCrdParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*( 5+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = CTR_RdPortDstParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*( 6+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = CTR_RdPortFmkParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*( 7+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = CTR_RdPortKmkParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*( 8+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = POL_RdPortMapParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*( 9+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = POL_RdPortOfm0ParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*(10+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = POL_RdPortOfm1ParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*(11+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = POL_RdPortOfm2ParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*(12+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = POL_RdPortOfm3ParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*(13+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = POL_RdPortOfm4ParBank;
assign CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*(14+GLB_NUM_WRPORT) +: ($clog2(MAXPAR) + 1)] = POL_RdPortOfm5ParBank;

// Cooresponding to every Port
assign Conv_CfgRdy = SYACCU_CfgRdy & GLBCCU_CfgRdy[0] & GLBCCU_CfgRdy[1] & GLBCCU_CfgRdy[4] &  GLBCCU_CfgRdy[10] &  GLBCCU_CfgRdy[11] &  GLBCCU_CfgRdy[12];
assign CCUSYA_CfgVld = Conv_CfgVld & SYACCU_CfgRdy;
assign CCUGLB_CfgVld[ 0] = Conv_CfgVld & GLBCCU_CfgRdy[ 0];
assign CCUGLB_CfgVld[ 1] = Conv_CfgVld & GLBCCU_CfgRdy[ 1];
assign CCUGLB_CfgVld[ 4] = Conv_CfgVld & GLBCCU_CfgRdy[ 4];
assign CCUGLB_CfgVld[10] = Conv_CfgVld & GLBCCU_CfgRdy[10];
assign CCUGLB_CfgVld[11] = Conv_CfgVld & GLBCCU_CfgRdy[11];
assign CCUGLB_CfgVld[12] = Conv_CfgVld & GLBCCU_CfgRdy[12];

assign Pool_CfgRdy = POLCCU_CfgRdy & GLBCCU_CfgRdy[3] & GLBCCU_CfgRdy[5] & GLBCCU_CfgRdy[17] & GLBCCU_CfgRdy[18 +: POOL_CORE];
assign CCUPOL_CfgVld = Pool_CfgVld & POLCCU_CfgRdy; 
assign CCUGLB_CfgVld[ 3] = Pool_CfgVld & GLBCCU_CfgRdy[ 3];
assign CCUGLB_CfgVld[ 5] = Pool_CfgVld & GLBCCU_CfgRdy[ 5];
assign CCUGLB_CfgVld[17] = Pool_CfgVld & GLBCCU_CfgRdy[17];
assign CCUGLB_CfgVld[18 +: POOL_CORE] = Pool_CfgVld & GLBCCU_CfgRdy[18 +: POOL_CORE];

assign Ctr_CfgRdy = CTRCCU_CfgRdy & GLBCCU_CfgRdy[2] & GLBCCU_CfgRdy[6] & GLBCCU_CfgRdy[7] & GLBCCU_CfgRdy[8] & GLBCCU_CfgRdy[9] & GLBCCU_CfgRdy[13] & GLBCCU_CfgRdy[14] & GLBCCU_CfgRdy[15] & GLBCCU_CfgRdy[16];
assign CCUCTR_CfgVld = Ctr_CfgVld & CTRCCU_CfgRdy;
assign CCUGLB_CfgVld[ 2] = Ctr_CfgVld & GLBCCU_CfgRdy[ 2];
assign CCUGLB_CfgVld[ 6] = Ctr_CfgVld & GLBCCU_CfgRdy[ 6];
assign CCUGLB_CfgVld[ 7] = Ctr_CfgVld & GLBCCU_CfgRdy[ 7];
assign CCUGLB_CfgVld[ 8] = Ctr_CfgVld & GLBCCU_CfgRdy[ 8];
assign CCUGLB_CfgVld[ 9] = Ctr_CfgVld & GLBCCU_CfgRdy[ 9];
assign CCUGLB_CfgVld[13] = Ctr_CfgVld & GLBCCU_CfgRdy[12];
assign CCUGLB_CfgVld[14] = Ctr_CfgVld & GLBCCU_CfgRdy[13];
assign CCUGLB_CfgVld[15] = Ctr_CfgVld & GLBCCU_CfgRdy[15];
assign CCUGLB_CfgVld[16] = Ctr_CfgVld & GLBCCU_CfgRdy[16];


assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*0 +: DRAM_ADDR_WIDTH] = 0  ; // ISA
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*1 +: DRAM_ADDR_WIDTH] = DramActAddr  ; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*2 +: DRAM_ADDR_WIDTH] = DramWgtAddr  ; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*3 +: DRAM_ADDR_WIDTH] = DramCrdAddr  ;//
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*4 +: DRAM_ADDR_WIDTH] = DramWrMapAddr; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*5 +: DRAM_ADDR_WIDTH] = DramRdMapAddr; // Read
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*6 +: DRAM_ADDR_WIDTH] = DramOfmAddr  ; // Read

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================


PISO#(
    .DATA_IN_WIDTH ( SRAM_WIDTH ),
    .DATA_OUT_WIDTH ( PORT_WIDTH )
)u_PISO_ISAIN(
    .CLK          ( clk                        ),
    .RST_N        ( rst_n                      ),
    .IN_VLD       ( ITFCCU_DatVld & CCUITF_DatRdy ),
    .IN_LAST      ( 1'b0 ),
    .IN_DAT       ( ITFCCU_Dat ),
    .IN_RDY       ( PISO_ISAInRdy                ),
    .OUT_DAT      ( PISO_ISAOut                     ), // On-chip output to Off-chip 
    .OUT_VLD      ( PISO_ISAOutVld                  ),
    .OUT_LAST     (                    ),
    .OUT_RDY      ( PISO_ISAOutRdy                  )
);


RAM#(
    .SRAM_BIT     ( PORT_WIDTH   ),
    .SRAM_BYTE    ( 1            ),
    .SRAM_WORD    ( ISA_SRAM_WORD),
    .CLOCK_PERIOD ( CLOCK_PERIOD )
)u_RAM_ISA(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .addr_r       ( ISA_RdAddr[0 +: ISA_SRAM_DEPTH_WIDTH]   ),
    .addr_w       ( ISA_WrAddr[0 +: ISA_SRAM_DEPTH_WIDTH]   ),
    .read_en      ( ISA_RdEn     ),
    .write_en     ( ISA_WrEn     ),
    .data_in      ( PISO_ISAOut   ),
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
