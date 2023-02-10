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
    parameter NUM_MODULE            = 5,
    parameter OPNUM                 = NUM_MODULE + GLB_NUM_WRPORT + GLB_NUM_RDPORT + POOL_CORE-1, // 5(module) + 9(GLBWR) + (11 + 5)(GLBRD(POOL_CORE*6))

    parameter MAXPAR                = 32,
    parameter NUM_BANK              = 32,
    parameter ITF_NUM_RDPORT        = 12,
    parameter ITF_NUM_WRPORT        = 14

    )(
    input                               clk                     ,
    input                               rst_n                   ,
    input                                               TOPCCU_start,
    output                                              CCUTOP_NetFnh,

        // Configure
    output [ADDR_WIDTH                          -1 : 0] ITFGLB_RdAddr    ,
    output                                              ITFGLB_RdAddrVld ,
    input                                               GLBITF_RdAddrRdy ,
    input  [SRAM_WIDTH                          -1 : 0] GLBCCU_ISARdDat,             
    input                                               GLBCCU_ISARdDatVld,          
    output                                              CCUGLB_ISARdDatRdy,

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

    output                                              CCUFPS_Rst   ,
    output                                              CCUFPS_CfgVld,
    input                                               FPSCCU_CfgRdy,        
    output  reg [IDX_WIDTH                      -1 : 0] CCUFPS_CfgNip,                    
    output  reg [IDX_WIDTH                      -1 : 0] CCUFPS_CfgNop, 

    output                                              CCUKNN_Rst   ,
    output                                              CCUKNN_CfgVld,
    input                                               KNNCCU_CfgRdy,        
    output  reg [IDX_WIDTH                      -1 : 0] CCUKNN_CfgNip,                    
    output  reg [MAP_WIDTH                      -1 : 0] CCUKNN_CfgK  , 

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
localparam CFG = 4'b0010;
localparam NETFNH   = 4'b0011;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                                        ISA_Full;
wire                                        ISA_Empty;
reg [NUM_LAYER_WIDTH+ISARDWORD_WIDTH-1 : 0] ISA_WrAddr;
reg [OPNUM -1 : 0][(NUM_LAYER_WIDTH+ISARDWORD_WIDTH)-1 : 0] CntMduISARdAddr;
reg [NUM_LAYER_WIDTH+ISARDWORD_WIDTH-1 : 0] ISA_RdAddrMin;
wire                                        ISA_WrEn;
wire                                        ISA_RdEn;
wire [ISARDWORD_WIDTH               -1 : 0] CntISARdWord;
wire[ISARDWORD_WIDTH                -1 : 0] ISA_CntRdWord_d;

wire [PORT_WIDTH                    -1 : 0] GLBCCU_ISARdDat;
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
reg  [$clog2(OPNUM)                  -1 : 0] ArbCfgRdyIdx_s0;
reg                                         CCUTOP_CfgRdy;   
wire                                        CCUTOP_CfgVld;   
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================


reg [4      -1 : 0] state       ;
reg [4      -1 : 0] state_s1       ;
reg [4      -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE    :   if( TOPCCU_start)
                        next_state <= IDLE_CFG; //
                    else
                        next_state <= IDLE;
        IDLE_CFG:   if ( |CfgRdy)
                        next_state <= CFG;
                    else 
                        next_state <= IDLE_CFG;

        CFG:    if (NumLy == CfgNumLy & CfgNumLy != 0)
                        next_state <= NETFNH;
                else if( )
                        next_state <= IDLE_CFG;
                else
                    next_state <= CFG;

        NETFNH     :   next_state <= IDLE;

        default :   if ( state[7] ) begin
                        if (CfgRdy[ArbCfgRdyIdx_s0] & CfgVld [ArbCfgRdyIdx_s0])
                            next_state <= CFG; // Turn back
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
// always @(posedge clk or negedge rst_n) begin
//     if(!rst_n) begin
//         NumLy <= 0;
//     end else if(state ==IDLE) begin
//         NumLy <= 0;
//     end else if(state == NETFNH) begin
//         NumLy <= NumLy + 1;
//     end
// end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        CCUTOP_CfgRdy <= 1'b1;
    end else if(CCUTOP_CfgVld & CCUTOP_CfgRdy) begin // HS
        CCUTOP_CfgRdy <= 1'b0;
    end else if(state == IDLE) begin
        CCUTOP_CfgRdy <= 1'b1;
    end
end

//=====================================================================================================================
// Logic Design 3: Req and Ack of Cfg
//=====================================================================================================================

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        OpNumWord[0] = 1;// localparam TOP = 1;
        OpNumWord[1] = 1;// localparam SYA = 2;
        OpNumWord[2] = 3;// localparam POL = 2;
        OpNumWord[3] = 1;// localparam FPS = 1;
        OpNumWord[4] = 1;// localparam KNN = 1;
        for (int_i =0; int_i < OPNUM;int_i = int_i + 1) begin
            StateCode[int_i] = 8'd128 + int_i; // 8'b1000_0000 + 0
            if (int_i >= 4)
                OpNumWord[int_i] <= 1;
        end

    end
end

// CfgRdy -> Req
assign CfgRdy = { GLBCCU_CfgRdy, KNNCCU_CfgRdy, FPSCCU_CfgRdy,  POLCCU_CfgRdy, SYACCU_CfgRdy & !Debug_TriggerSYACfgHS, CCUTOP_CfgRdy};
prior_arb#(
    .REQ_WIDTH ( OPNUM )
)u_prior_arb_ArbCfgRdyIdx(
    .req ( CfgRdy ),
    .gnt (  ),
    .arb_port  ( ArbCfgRdyIdx  )
);


// Reg Update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ArbCfgRdyIdx_s0 <= 0;
    end else if ( state == IDLE_CFG & next_state == CFG ) begin
        ArbCfgRdyIdx_s0 <= ArbCfgRdyIdx;
    end
end

//=====================================================================================================================
// Logic Design: s1-ISA_RAM Read
//=====================================================================================================================

generate
    for(i=0; i<OPNUM; i=i+1) begin
        wire [ADDR_WIDTH     -1 : 0] MaxCnt= 2**ADDR_WIDTH -1;
        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_CntMduISARdAddr(
            .CLK       ( clk            ),
            .RESET_N   ( rst_n          ),
            .CLEAR     ( state == IDLE  ),
            .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
            .INC       ( (ITFGLB_RdAddrVld & GLBITF_RdAddrRdy) & ArbCfgRdyIdx_s0 == i ),
            .DEC       ( 1'b0           ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
            .MAX_COUNT ( MaxCnt         ),
            .OVERFLOW  (                ),
            .UNDERFLOW (                ),
            .COUNT     ( CntMduISARdAddr[i])
        );
    end
endgenerate

assign ITFGLB_RdAddr = CntMduISARdAddr[ArbCfgRdyIdx_s0];
assign ITFGLB_RdAddrVld = state==CFG & !(Ovf_CntISARdWord & OpCodeMatch);


// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        {ArbCfgRdyIdx_s1, state_s1} <= 0;
    else if (ITFGLB_RdAddrVld & GLBITF_RdAddrRdy)
        {ArbCfgRdyIdx_s1, state_s1} <= {ArbCfgRdyIdx_s0, state};
end

//=====================================================================================================================
// Logic Design: s2
//=====================================================================================================================
assign CCUGLB_ISARdDatRdy = state_s1 == CFG;
assign handshake_s1 = GLBCCU_ISARdDatVld & CCUGLB_ISARdDatRdy;
assign OpCode = GLBCCU_ISARdDatVld? GLBCCU_ISARdDat[0 +: 8] : {8{1'b1}};
assign OpCodeMatch = OpCode == ArbCfgRdyIdx_s1;

wire [ADDR_WIDTH     -1 : 0] MaxCntISARdWord= OpNumWord[ArbCfgRdyIdx_s1] -1;

// Reg Update
counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u_counter_CntISARdWord(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     (                ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
    .INC       ( handshake_s1 & OpCodeMatch ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
    .MAX_COUNT ( MaxCntISARdWord   ),
    .OVERFLOW  ( Ovf_CntISARdWord),
    .UNDERFLOW (                ),
    .COUNT     ( CntISARdWord   )
);

// ISA Decoder
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
        CCUFPS_CfgNip           <= 0;
        CCUFPS_CfgNop           <= 0;
        CCUKNN_CfgNip           <= 0;
        CCUKNN_CfgK             <= 0;
        for(int_i = 0; int_i < GLB_NUM_WRPORT + GLB_NUM_RDPORT; int_i=int_i+1) begin
            // GLB Ports
            CCUGLB_CfgPortBankFlag[NUM_BANK* int_i +: NUM_BANK] <= 'd0;
            CCUGLB_CfgPortNum[ADDR_WIDTH*int_i +: ADDR_WIDTH] <= 'd0;
            CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*int_i +: ($clog2(MAXPAR) + 1)] <= 'd0;
            CCUGLB_CfgPortLoop[int_i] <= 0;
            // GLB read/write DRAM by ITF
            DramAddr[int_i]     <= 'd0;
        end
    end else if ( handshake_s1 & OpCodeMatch) begin
        if ( OpCode == 128 + 0) begin
            {CfgNumLy, Mode} <= GLBCCU_ISARdDat[PORT_WIDTH -1 : 8];

        end else if ( OpCode == 128 + 1) begin
            if (CntISARdWord == 1) begin
                CCUSYA_CfgNip   <= GLBCCU_ISARdDat[8  +: 16];
                CCUSYA_CfgChi   <= GLBCCU_ISARdDat[24 +: 16];
                Cho             <= GLBCCU_ISARdDat[40 +: 16];       
                CCUSYA_CfgScale <= GLBCCU_ISARdDat[56 +: 32];       
                CCUSYA_CfgShift <= GLBCCU_ISARdDat[88 +:  8];
                CCUSYA_CfgZp    <= GLBCCU_ISARdDat[96 +:  8];
                CCUSYA_CfgMod   <= GLBCCU_ISARdDat[104+:  8];
            end

        end else if (OpCode == 128 + 2) begin
            if (CntISARdWord == 1) begin
                CCUPOL_CfgNip   <= GLBCCU_ISARdDat[8  +: 16];
                CCUPOL_CfgChi   <= GLBCCU_ISARdDat[24 +: 16];// 
                CCUPOL_CfgK     <= GLBCCU_ISARdDat[40 +: 16];// 
            end else if(CntISARdWord == 2) begin  
                CCUPOL_AddrMin  <= GLBCCU_ISARdDat[PORT_WIDTH-1 : 8]; // Min BUG with 120 bit
            end else if(CntISARdWord == 3) begin  
                CCUPOL_AddrMax  <= GLBCCU_ISARdDat[PORT_WIDTH-1 : 8];
            end

        end else if (OpCode == 128 + 3) begin
            if(CntISARdWord == 1) begin
                CCUFPS_CfgNip           <= GLBCCU_ISARdDat[8  +: 16];
                CCUFPS_CfgNop           <= GLBCCU_ISARdDat[24 +: 16];
            end
        end else if (OpCode == 128 + 4) begin
            if(CntISARdWord == 1) begin
                CCUKNN_CfgNip           <= GLBCCU_ISARdDat[8  +: 16];
                CCUKNN_CfgK             <= GLBCCU_ISARdDat[24 +: 16];
            end
        end else for(int_i = 0; int_i < GLB_NUM_WRPORT + GLB_NUM_RDPORT; int_i=int_i+1) begin
            if ( OpCode == 128 + NUM_MODULE + int_i) begin
                // GLB Ports
                CCUGLB_CfgPortBankFlag[NUM_BANK*int_i +: NUM_BANK] <= GLBCCU_ISARdDat[8  +: 32];
                CCUGLB_CfgPortNum[ADDR_WIDTH*int_i +: ADDR_WIDTH] <= GLBCCU_ISARdDat[40 +: 16];
                CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*int_i +: ($clog2(MAXPAR) + 1)] <= GLBCCU_ISARdDat[56 +: 8];
                CCUGLB_CfgPortLoop[int_i] <= GLBCCU_ISARdDat[64 +: 4];
                // GLB read/write DRAM by ITF
                DramAddr[int_i]     <= GLBCCU_ISARdDat[68   +: 32];
                end
        end
               
    end
end
genvar i;
generate
    for(i=0; i<OPNUM; i=i+1) begin
        always @(posedge clk or negedge rst_n)  begin
            if (!rst_n) begin
                CfgVld[i] <= 0;
            end else if ( CfgVld[i] & CfgRdy[i] ) begin
                CfgVld[i] <= 0;
            end else if ( state_s1 == CFG & ArbCfgRdyIdx_s1 == i & Ovf_CntISARdWord & handshake_s1 & OpCodeMatch) begin
                CfgVld[i] <= 1'b1;
            end
        end
    end
endgenerate

assign {CCUGLB_CfgVld, CCUKNN_CfgVld, CCUFPS_CfgVld,  CCUPOL_CfgVld, CCUSYA_CfgVld, CCUTOP_CfgVld} = CfgVld;

//=====================================================================================================================
// Logic Design 3: Rst
//=====================================================================================================================
assign CCUSYA_Rst = state == IDLE;
assign CCUPOL_Rst = state == IDLE;
assign CCUFPS_Rst = state == IDLE;
assign CCUKNN_Rst = state == IDLE;
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
MINMAX#(
    .DATA_WIDTH ( (NUM_LAYER_WIDTH+ISARDWORD_WIDTH) ),
    .PORT       ( OPNUM ),
    .MINMAX     ( 0 )
)u_MINMAX(
    .IN         ( CntMduISARdAddr  ),
    .IDX        ( AddrRdMinIdx      ),
    .VALUE      ( ISA_RdAddrMin     )????????????????????????????????
);

//=====================================================================================================================
// Debug :
//=====================================================================================================================

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        Debug_TriggerSYACfgHS <= 0;
    else if (CCUSYA_CfgVld & SYACCU_CfgRdy)
        Debug_TriggerSYACfgHS <= 1;
end

endmodule
