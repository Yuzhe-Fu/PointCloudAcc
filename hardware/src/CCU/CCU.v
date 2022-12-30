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
    parameter OPNUM                 = 28, // 4(module) + 9(GLBWR) + (10 + 5)(GLBRD(POOL_CORE*6))

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
    output reg [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)*NUM_BANK  -1 : 0] CCUGLB_CfgPortBankFlag ,
    output reg [ADDR_WIDTH*(GLB_NUM_RDPORT+GLB_NUM_WRPORT)  -1 : 0] CCUGLB_CfgPortNum, 
    output reg [($clog2(MAXPAR) + 1)*(GLB_NUM_RDPORT+GLB_NUM_WRPORT)     -1 : 0] CCUGLB_CfgPortParBank,  
    output reg [GLB_NUM_RDPORT+GLB_NUM_WRPORT                  -1 : 0] CCUGLB_CfgPortLoop

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam OPCODE_WIDTH = 8;
localparam ISA_SRAM_DEPTH_WIDTH = $clog2(ISA_SRAM_WORD);

localparam IDLE     = 4'b0000;
localparam RD_ISA   = 4'b0001;
localparam IDLE_CFG = 4'b0010;
localparam NETFNH      = 4'b0011;
// localparam ARRAY_CFG= 4'b1000; // 0

// localparam OpCode_TOP             = 128 + 0;
// localparam OpCode_SYA             = 128 + 1;
// localparam OpCode_POL             = 128 + 2;
// localparam OpCode_CTR             = 128 + 3;
// localparam OpCode_GLBWRIDX_ITFACT = 128 + 4 + 0;
// localparam OpCode_GLBWRIDX_ITFWGT = 128 + 4 + 1;
// localparam OpCode_GLBWRIDX_ITFCRD = 128 + 4 + 2;
// localparam OpCode_GLBWRIDX_ITFMAP = 128 + 4 + 3;
// localparam OpCode_GLBWRIDX_SYAOFM = 128 + 4 + 4;
// localparam OpCode_GLBWRIDX_POLOFM = 128 + 4 + 5;
// localparam OpCode_GLBWRIDX_CTRDST = 128 + 4 + 6;
// localparam OpCode_GLBWRIDX_CTRMAP = 128 + 4 + 7;
// localparam OpCode_GLBWRIDX_CTRFMK = 128 + 4 + 8; // FPS Writes Mask
// localparam OpCode_GLBRDIDX_ITFMAP = 128 + 4 + GLB_NUM_WRPORT + 0;
// localparam OpCode_GLBRDIDX_ITFOFM = 128 + 4 + GLB_NUM_WRPORT + 1;
// localparam OpCode_GLBRDIDX_SYAACT = 128 + 4 + GLB_NUM_WRPORT + 2;
// localparam OpCode_GLBRDIDX_SYAWGT = 128 + 4 + GLB_NUM_WRPORT + 3;
// localparam OpCode_GLBRDIDX_CTRCRD = 128 + 4 + GLB_NUM_WRPORT + 4;
// localparam OpCode_GLBRDIDX_CTRDST = 128 + 4 + GLB_NUM_WRPORT + 5;
// localparam OpCode_GLBRDIDX_CTRFMK = 128 + 4 + GLB_NUM_WRPORT + 6; // FPS Read MASK
// localparam OpCode_GLBRDIDX_CTRKMK = 128 + 4 + GLB_NUM_WRPORT + 7; // KNN Read MASK
// localparam OpCode_GLBRDIDX_POLMAP = 128 + 4 + GLB_NUM_WRPORT + 8;
// localparam OpCode_GLBRDIDX_POLOFM = 128 + 4 + GLB_NUM_WRPORT + 9; // + 5(POOL_CORE)
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
reg [OPCODE_WIDTH                   -1 : 0] StateCode[0 : OPNUM -1];
reg [DRAM_ADDR_WIDTH                   -1 : 0] DramAddr[0 : GLB_NUM_WRPORT+GLB_NUM_RDPORT -1];

reg [NUM_LAYER_WIDTH                -1 : 0] NumLy;
reg [8                              -1 : 0] Mode;

reg [CHN_WIDTH                      -1 : 0] Cho;
wire [$clog2(OPNUM)                  -1 : 0] AddrRdMinIdx;

wire                                        PISO_ISAInRdy;
wire [PORT_WIDTH                    -1 : 0] PISO_ISAOut;
wire                                        PISO_ISAOutVld;
wire                                        PISO_ISAOutRdy;
reg                                         Debug_TriggerSYACfgHS;   
integer                                     int_i;
wire [OPNUM                         -1 : 0] CfgRdy;
reg  [OPNUM                         -1 : 0] CfgVld;
wire [$clog2(OPNUM)                  -1 : 0] ArbCfgRdyIdx;
reg  [$clog2(OPNUM)                  -1 : 0] ArbCfgRdyIdx_d;
reg                                         CCUTOP_CfgRdy;   
wire                                        CCUTOP_CfgVld;   
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================


reg [OPCODE_WIDTH      -1 : 0] state       ;
reg [OPCODE_WIDTH      -1 : 0] next_state  ;
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
                        next_state <= NETFNH;
                    else if ( ISA_Empty )
                        next_state <= RD_ISA;
                    else if ( |CfgRdy ) begin
                            next_state <= StateCode[ArbCfgRdyIdx];
                        end
                    else 
                        next_state <= IDLE_CFG;

        NETFNH     :   next_state <= IDLE;
        default :   if ( state[7] ) begin
                        if (CfgRdy[ArbCfgRdyIdx_d] & CfgVld [ArbCfgRdyIdx_d])
                            next_state <= IDLE_CFG; // Turn back
                        else 
                            next_state <= state; // Hold
                    end else 
                        next_state <= IDLE;
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
// Logic Design: TOP
//=====================================================================================================================
assign CCUTOP_NetFnh = state == NETFNH;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        NumLy <= 0;
    end else if(state ==IDLE) begin
        NumLy <= 0;
    end else if(state == NETFNH) begin // ???????: transfer to network config
        NumLy <= NumLy + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        CCUTOP_CfgRdy <= 1'b1;
    end else if(CCUTOP_CfgVld & CCUTOP_CfgRdy) begin // HS
        CCUTOP_CfgRdy <= 1'b0;
    end else if(state == IDLE) begin // ???????: transfer to network config
        CCUTOP_CfgRdy <= 1'b1;
    end
end

//=====================================================================================================================
// Logic Design 3: ISA RAM Write
//=====================================================================================================================
// Write Path
assign CCUITF_Empty = ISA_Empty;

// ISA_Empty number (only when PISO is empty indicating ITFCCU_Dat witen into ISA_RAM)
assign CCUITF_ReqNum = PISO_ISAOutVld ? 0 : ((ISA_SRAM_WORD - (ISA_WrAddr - ISA_RdAddrMin) )>>1)<<1; // make sure 2times
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
// Logic Design 3: Req and Ack of Cfg
//=====================================================================================================================

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        OpNumWord[0] = 1;// localparam Word_Array = 1;
        OpNumWord[1] = 1;// localparam Word_Conv  = 2;
        OpNumWord[2] = 3;// localparam Word_Pool  = 2;
        OpNumWord[3] = 1;// localparam Word_CTR   = 1;
        for (int_i =0; int_i < OPNUM;int_i = int_i + 1) begin
            StateCode[int_i] = 8'd128 + int_i; // 8'b1000_0000 + 0
            if (int_i >= 4)
                OpNumWord[int_i] <= 1;
        end

    end
end

// CfgRdy -> Req
assign CfgRdy = { GLBCCU_CfgRdy, CTRCCU_CfgRdy,  POLCCU_CfgRdy, SYACCU_CfgRdy & !Debug_TriggerSYACfgHS, CCUTOP_CfgRdy};
prior_arb#(
    .REQ_WIDTH ( OPNUM )
)u_prior_arb_ArbCfgRdyIdx(
    .req ( CfgRdy ),
    .gnt (  ),
    .arb_port  ( ArbCfgRdyIdx  )
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ArbCfgRdyIdx_d <= 0;
    end else if ( state[7] & !next_state[7] ) begin // Turn back IDLE_CFG-> reset
        ArbCfgRdyIdx_d <= 0;
    end else if ( !state[7] & next_state[7] ) begin // Turn to CFG-> latch
        ArbCfgRdyIdx_d <= ArbCfgRdyIdx;
    end
end

// CfgVld -> Ack
genvar i;
generate
    for(i=0; i<OPNUM; i=i+1) begin
        always @(posedge clk or negedge rst_n)  begin
            if (!rst_n) begin
                CfgVld[i] <= 0;
            end else if ( CfgVld[i] & CfgRdy[i] ) begin
                CfgVld[i] <= 0;
            end else if ( state == StateCode[i] & ISA_CntRdWord == OpNumWord[i]) begin
                CfgVld[i] <= 1'b1;
            end
        end
    end
endgenerate

assign {CCUGLB_CfgVld, CCUCTR_CfgVld,  CCUPOL_CfgVld, CCUSYA_CfgVld, CCUTOP_CfgVld} = CfgVld;

//=====================================================================================================================
// Logic Design: ISA_RAM Read
//=====================================================================================================================

generate
    for(i=0; i<OPNUM; i=i+1) begin
        always @(posedge clk or negedge rst_n)  begin
            if (!rst_n) begin
                ISA_RdAddr_Array[i] <= 0;
            end else if ( state == IDLE ) begin
                ISA_RdAddr_Array[i] <= 0;
            end else if ( ISA_RdEn & state[7] & state[0 +: 7] == i) begin
                ISA_RdAddr_Array[i] <= ISA_RdAddr_Array[i] + 1;
            end
        end
        assign ISA_RdAddr1D[(NUM_LAYER_WIDTH+ISARDWORD_WIDTH)*i +: (NUM_LAYER_WIDTH+ISARDWORD_WIDTH)] = ISA_RdAddr_Array[i];
    end
endgenerate

assign ISA_CntRdWord = state[7] ? ( (ISA_RdEn_d & OpCodeMatch) ? ISA_CntRdWord_d + 1 : ISA_CntRdWord_d ) : 0;
assign OpCodeMatch = state[7] & OpCode == state;
assign ISA_RdEn = state[7] & !(ISA_CntRdWord == OpNumWord[state[0 +: 7]] & OpCodeMatch);
assign ISA_RdAddr = ISA_RdAddr_Array[state[0 +: 7]];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ISA_DatOutVld <= 0;
    end else if ( !next_state[7] ) begin // finish CFG
        ISA_DatOutVld <= 0;
    end else if (ISA_RdEn ) begin
        ISA_DatOutVld <= 1;
    end
end


//=====================================================================================================================
// Logic Design 3: ISA Decoder
//=====================================================================================================================
assign OpCode = ISA_DatOutVld ? ISA_DatOut[0 +: 8] : {8{1'b1}};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        CfgNumLy                <= 0;
        Mode                    <= 0;
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
        for(int_i = 0; int_i < GLB_NUM_WRPORT + GLB_NUM_RDPORT; int_i=int_i+1) begin
            // GLB Ports
            CCUGLB_CfgPortBankFlag[NUM_BANK* int_i +: NUM_BANK] <= 'd0;
            CCUGLB_CfgPortNum[ADDR_WIDTH*int_i +: ADDR_WIDTH] <= 'd0;
            CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*int_i +: ($clog2(MAXPAR) + 1)] <= 'd0;
            CCUGLB_CfgPortLoop[int_i] <= 0;
            // GLB read/write DRAM by ITF
            DramAddr[int_i]     <= 'd0;
        end
    end else if ( ISA_RdEn_d & OpCodeMatch) begin
        if ( OpCode == 128 + 0) begin
            {CfgNumLy, Mode} <= ISA_DatOut[PORT_WIDTH -1 : 8];

        end else if ( OpCode == 128 + 1) begin
            if (ISA_CntRdWord == 1) begin
                CCUSYA_CfgNip   <= ISA_DatOut[8  +: 16];
                CCUSYA_CfgChi   <= ISA_DatOut[24 +: 16];
                Cho             <= ISA_DatOut[40 +: 16];       
                CCUSYA_CfgScale <= ISA_DatOut[56 +: 32];       
                CCUSYA_CfgShift <= ISA_DatOut[88 +:  8];
                CCUSYA_CfgZp    <= ISA_DatOut[96 +:  8];
                CCUSYA_CfgMod   <= ISA_DatOut[104+:  8];
            end

        end else if (OpCode == 128 + 2) begin
            if (ISA_CntRdWord == 1) begin
                CCUPOL_CfgNip   <= ISA_DatOut[8 +: 16];
                CCUPOL_CfgChi   <= ISA_DatOut[24 +: 16];// 
                CCUPOL_CfgK     <= ISA_DatOut[40 +: 16];// 
            end else if(ISA_CntRdWord == 2) begin  
                CCUPOL_AddrMin  <= ISA_DatOut[PORT_WIDTH-1 : 8]; // Min BUG with 120 bit
            end else if(ISA_CntRdWord == 3) begin  
                CCUPOL_AddrMax  <= ISA_DatOut[PORT_WIDTH-1 : 8];
            end

        end else if (OpCode == 128 + 3) begin
            if(ISA_CntRdWord == 1) begin
                CCUCTR_CfgMod   <= ISA_DatOut[8  +   8];
                CCUCTR_CfgNip   <= ISA_DatOut[16 +: 16];
                CCUCTR_CfgNop   <= ISA_DatOut[32 +: 16];
                CCUCTR_CfgK     <= ISA_DatOut[48 +:  8];
            end
        end else for(int_i = 0; int_i < GLB_NUM_WRPORT + GLB_NUM_RDPORT; int_i=int_i+1) begin
            if ( OpCode == 128 + 4 + int_i) begin
                // GLB Ports
                CCUGLB_CfgPortBankFlag[NUM_BANK*int_i +: NUM_BANK] <= ISA_DatOut[8  +: 32];
                CCUGLB_CfgPortNum[ADDR_WIDTH*int_i +: ADDR_WIDTH] <= ISA_DatOut[40 +: 16];
                CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*int_i +: ($clog2(MAXPAR) + 1)] <= ISA_DatOut[56 +: 8];
                CCUGLB_CfgPortLoop[int_i] <= ISA_DatOut[64 +: 4];
                // GLB read/write DRAM by ITF
                DramAddr[int_i]     <= ISA_DatOut[68   +: 32];
                end
        end
               
    end
end


//=====================================================================================================================
// Logic Design 3: Rst
//=====================================================================================================================
assign CCUSYA_Rst = state == IDLE;
assign CCUPOL_Rst = state == IDLE;
assign CCUCTR_Rst = state == IDLE;
assign CCUGLB_Rst = state == IDLE;


//=====================================================================================================================
// Logic Design 4: GLB Control
//=====================================================================================================================

assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*0 +: DRAM_ADDR_WIDTH] = 0            ; // ISA
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*1 +: DRAM_ADDR_WIDTH] = DramAddr[0]; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*2 +: DRAM_ADDR_WIDTH] = DramAddr[1]; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*3 +: DRAM_ADDR_WIDTH] = DramAddr[2];//
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*4 +: DRAM_ADDR_WIDTH] = DramAddr[3]; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*5 +: DRAM_ADDR_WIDTH] = DramAddr[9]; // Read
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*6 +: DRAM_ADDR_WIDTH] = DramAddr[10]; // Read

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

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        Debug_TriggerSYACfgHS <= 0;
    else if (CCUSYA_CfgVld & SYACCU_CfgRdy)
        Debug_TriggerSYACfgHS <= 1;
end

endmodule
