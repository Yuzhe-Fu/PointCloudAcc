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
module FPS #(
    parameter SRAM_WIDTH        = 256,
    parameter IDX_WIDTH         = 10,
    parameter CRD_WIDTH         = 16,
    parameter CRD_DIM           = 3, 
    parameter NUM_LAYER         = 8,
    parameter DISTSQR_WIDTH     =  $clog2( CRD_WIDTH*2*$clog2(CRD_DIM) ),
    parameter MASK_ADDR_WIDTH   = $clog2(2**IDX_WIDTH*NUM_LAYER/SRAM_WIDTH),
    parameter DISTCRDLLA_WIDTH  = DISTSQR_WIDTH+CRD_WIDTH*CRD_DIM+IDX_WIDTH
    )(
    input                               clk  ,
    input                               rst_n,

    // Configure
    input                               CCUFPS_Rst,
    input                               CCUFPS_CfgVld,
    output                              FPSCCU_CfgRdy,
    input  [IDX_WIDTH           -1 : 0] CCUFPS_CfgNip,
    input  [IDX_WIDTH           -1 : 0] CCUFPS_CfgNop,
                    
    output [IDX_WIDTH           -1 : 0] FPSGLB_DistCrdLLARdAddr, // Linked link Address
    output                              FPSGLB_DistCrdLLARdAddrVld,
    input                               GLBFPS_LLADistRdAddrRdy,
    input  [DISTCRDLLA_WIDTH    -1 : 0] GLBFPS_DistCrdLLARdDat,    
    input                               GLBFPS_DistCrdLLARdDatVld,    
    output                              FPSGLB_DistCrdLLARdDatRdy,    

    output [IDX_WIDTH           -1 : 0] FPSGLB_DistCrdLLAWrAddr,
    output [DISTCRDLLA_WIDTH    -1 : 0] FPSGLB_DistCrdLLAWrDat,   
    output reg                          FPSGLB_DistCrdLLAWrDatVld,
    input                               GLBFPS_DistCrdLLAWrDatRdy,

    // Output Mask Bit
    output  [MASK_ADDR_WIDTH    -1 : 0] FPSGLB_MaskWrAddr,
    output reg[SRAM_WIDTH       -1 : 0] FPSGLB_MaskWrBitEn,
    output                              FPSGLB_MaskWrDatVld,
    output reg[SRAM_WIDTH       -1 : 0] FPSGLB_MaskWrDat,
    input                               GLBFPS_MaskWrDatRdy  // Not Used

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE   = 3'b000;
localparam CP     = 3'b001;
localparam LP     = 3'b010;
localparam FNH    = 3'b011;


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg [IDX_WIDTH          -1 : 0] FPS_MaxIdx;
reg [CRD_WIDTH*CRD_DIM  -1 : 0] FPS_MaxCrd;
reg [CRD_WIDTH*CRD_DIM  -1 : 0] FPS_CpCrd;
wire                            FPS_UpdMax;
wire[IDX_WIDTH          -1 : 0] FPS_PsIdx;
reg [DISTSQR_WIDTH      -1 : 0] FPS_MaxDist;
wire[DISTSQR_WIDTH      -1 : 0] FPS_PsDist;

reg [DISTSQR_WIDTH      -1 : 0] FPS_LastPsDist_s2; 
reg [IDX_WIDTH          -1 : 0] FPS_LastPsIdx_s2;

reg [CRD_WIDTH*CRD_DIM  -1 : 0] LopCrd_s2;
wire[IDX_WIDTH          -1 : 0] CntCp;  

wire[DISTSQR_WIDTH      -1 : 0] LopDist_s2;

reg                             LopCntLast_s2;
reg                             LopCntLast_s1;
reg                             FPSGLB_CrdAddr_s1;
reg [IDX_WIDTH          -1 : 0] LopPntIdx_s2;
reg [IDX_WIDTH          -1 : 0] LopPntIdx_s1;

wire                            CpLast;

wire                            LopCntLast;

wire [IDX_WIDTH         -1 : 0] LopCnt;
reg                             MaskLoop;
wire [NUM_LAYER         -1 : 0] PreLyrMask;
reg  [$clog2(NUM_LAYER) -1 : 0] FPSLyIdx;
reg  [$clog2(SRAM_WIDTH/NUM_LAYER) -1 : 0] MaskRAMByteIdx;
wire [$clog2(NUM_LAYER) -1 : 0] MaskRAMBitIdx;
genvar gv_i;
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE :  if(FPSCCU_CfgRdy & CCUFPS_CfgVld)
                    next_state <= CP; //
                else
                    next_state <= IDLE;
        CP:     if( 1'b1)
                    next_state <= LP;
                else
                    next_state <= CP;
        LP:     if ( LopCntLast ) begin
                    if ( CpLast )
                        next_state <= FNH;
                    else //
                        next_state <= CP;
                end
                else
                    next_state <= LP;
        FNH:    next_state <= IDLE;
        default: next_state <= IDLE;
    endcase
end
always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

assign FPSCCU_CfgRdy = state==IDLE;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        FPSLyIdx <= -1;
    end else if(CCUFPS_Rst) begin
        FPSLyIdx <= -1;
    end else if(FPSCCU_CfgRdy & CCUFPS_CfgVld) begin
        FPSLyIdx <= FPSLyIdx + 1;
    end
end

wire INC_CntCp;
counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u0_counter_CntCp(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( CCUFPS_Rst     ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}),
    .INC       ( state == LP && next_state == CP      ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}),
    .MAX_COUNT ( CCUFPS_CfgNop -1 ),
    .OVERFLOW  ( CpLast         ),
    .UNDERFLOW (                ),
    .COUNT     ( CpCnt   )
);

//=====================================================================================================================
// Logic Design: Stage0
//=====================================================================================================================

// Combinational Logic
assign INC_LopCnt = handshake_s0; // After being fetched by the next stage

// HandShake
assign rdy_s0 = GLBFPS_LLADistRdAddrRdy;
assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0 = handshake_s1 | ~vld_s0;

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        vld_s0 <= 0;
    end else if( ena_s0) begin
        vld_s0 <= next_state == LP;
    end
end
counter#( // Pipe S0
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_LopIdx(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CntCp | CCUFPS_Rst   ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
    .INC       ( INC_LopCnt         ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
    .MAX_COUNT ( (CCUFPS_CfgNip - (CpCnt+1)) -1  ),
    .OVERFLOW  ( LopCntLast     ),
    .UNDERFLOW (                    ),
    .COUNT     ( LopCnt             )
);

//=====================================================================================================================
// Logic Design: Stage1: DistCrdLLA Gen
//=====================================================================================================================
// Combinational Logic
assign LopPntIdx = FPSLyIdx == 0?  LopCnt : GLBFPS_DistCrdLLARdDat[0 +: IDX_WIDTH];
assign FPSGLB_DistCrdLLARdAddr = LopPntIdx;
assign FPSGLB_DistCrdLLARdAddrVld = handshake_s0;

// HandShake
assign FPSGLB_DistCrdLLARdDatRdy = rdy_s1;
assign rdy_s1 = ena_s2;
assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1 = handshake_s1 | ~vld_s1;

// Reg Update
assign vld_s1 = GLBFPS_DistCrdLLARdDatVld;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {LopPntIdx_s1, FPSLyIdx_s1, LopCntLast_s1} <= 0;
    end else if (ena_s1) begin
        {LopPntIdx_s1, FPSLyIdx_s1, LopCntLast_s1} <= 
        {LopPntIdx, FPSLyIdx, LopCntLast};
    end
end

//=====================================================================================================================
// Logic Design: Stage2: Max Gen
//=====================================================================================================================
// Combinational Logic
assign FPS_LastPsDist = GLBFPS_DistCrdLLARdDat[CRD_WIDTH*CRD_DIM + IDX_WIDTH +: DISTSQR_WIDTH];
assign LopPntCrd = GLBFPS_DistCrdLLARdDat[IDX_WIDTH +: CRD_WIDTH*CRD_DIM];


EDC#(
    .CRD_WIDTH ( CRD_WIDTH  ),
    .CRD_DIM   ( CRD_DIM    )
)u_EDC(
    .Crd0      ( FPS_CpCrd      ),
    .Crd1      ( LopPntCrd     ),
    .DistSqr   ( LopDist    )
);

assign FPS_PsDist = FPS_LastPsDist > LopDist ? LopDist : FPS_LastPsDist;

assign FPS_UpdMax = FPS_MaxDist < FPS_PsDist;
assign {FPS_MaxDist_, FPS_MaxCrd_, FPS_MaxIdx_} <= FPS_UpdMax ? {FPS_PsDist, LopPntCrd, LopPntIdx_s1} : {FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx};

// HandShake
assign rdy_s2 = GLBFPS_MaskWrDatRdy & GLBFPS_DistCrdLLAWrRdy;
assign handshake_s2 = rdy_s2 & vld_s2;
assign ena_s2 = handshake_s2 | ~vld_s2;

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {FPS_CpCrd, FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx, FPS_PsDist_s2, LopPntIdx_s2, FPSLyIdx_s2, LopCntLast_s2, vld_s2} <= 0;
    end else if (ena_s2) begin
        {FPS_CpCrd, FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx, FPS_PsDist_s2, LopPntIdx_s2, FPSLyIdx_s2, LopCntLast_s2, vld_s2} <= 
        {(LopCntLast_s1 | CpCnt_s1==0)? FPS_MaxCrd_ : FPS_CpCrd, FPS_MaxCrd_, FPS_MaxIdx_, FPS_PsDist, LopPntIdx_s1, FPSLyIdx_s1, LopCntLast_s1, GLBFPS_DistCrdLLARdDatVld}; ?????????????
    end
end

//=====================================================================================================================
// Logic Design: Out
//=====================================================================================================================

// Combinational Logic
assign FPSGLB_DistCrdLLAWrDatVld = handshake_s2;
assign {FPSGLB_DistCrdLLAWrDat, FPSGLB_DistCrdLLAWrAddr}= {FPS_PsDist_s2, LopPntIdx_s2}; ???????????????

// Write back (Update) Mask
assign FPSGLB_MaskWrAddr = FPS_MaxIdx >> $clog2(SRAM_WIDTH/NUM_LAYER);
assign FPSGLB_MaskWrDatVld = vld_s2 & LopCntLast_s2;

assign MaskRAMBitIdx = FPSLyIdx_s2 % (SRAM_WIDTH/NUM_LAYER);
assign MaskByteIdx = FPS_MaxIdx / NUM_LAYER;
assign MaskRAMByteIdx = MaskByteIdx[0 +: $clog2((SRAM_WIDTH/NUM_LAYER))];

always @(*) begin
    FPSGLB_MaskWrBitEn = {SRAM_WIDTH{1'b0}};
    FPSGLB_MaskWrDat = {SRAM_WIDTH{1'b0}};
    // Only write/update FPS_MaxIdx's
    FPSGLB_MaskWrBitEn[MaskRAMBitIdx + NUM_LAYER*MaskRAMByteIdx] = 1'b1;
    // Mask of FPS_MaxIdx set to 1: remained in the current layer
    FPSGLB_MaskWrDat[MaskRAMBitIdx + NUM_LAYER*MaskRAMByteIdx] = 1'b1; 
end


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================




endmodule
