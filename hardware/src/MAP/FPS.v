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
    parameter MASK_ADDR_WIDTH = $clog2(2**IDX_WIDTH*NUM_LAYER/SRAM_WIDTH)
    )(
    input                               clk  ,
    input                               rst_n,

    // Configure
    input                               CCUFPS_Rst,
    input                               CCUFPS_CfgVld,
    output                              FPSCCU_CfgRdy,
    input [IDX_WIDTH            -1 : 0] CCUFPS_CfgNip,
    input [IDX_WIDTH            -1 : 0] CCUFPS_CfgNop,

    // Fetch Crd
    output [IDX_WIDTH           -1 : 0] FPSGLB_CrdAddr,   
    output                              FPSGLB_CrdAddrVld, 
    input                               GLBFPS_CrdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0 ]GLBFPS_Crd,        
    input                               GLBFPS_CrdVld,     
    output                              FPSGLB_CrdRdy,

    // Fetch Dist and Idx of FPS
    output [IDX_WIDTH           -1 : 0] FPSGLB_DistRdAddr, 
    output                              FPSGLB_DistRdAddrVld,
    input                               GLBFPS_DistRdAddrRdy,
    input  [DISTSQR_WIDTH+IDX_WIDTH-1 : 0] GLBFPS_DistIdx,    
    input                               GLBFPS_DistIdxVld,    
    output                              FPSGLB_DistIdxRdy,    

    output [IDX_WIDTH           -1 : 0] FPSGLB_DistWrAddr,
    output [DISTSQR_WIDTH+IDX_WIDTH-1 : 0] FPSGLB_DistIdx,   
    output reg                          FPSGLB_DistIdxVld,
    input                               GLBFPS_DistIdxRdy,

    // Output Mask Bit
    output  [MASK_ADDR_WIDTH    -1 : 0] FPSGLB_MaskWrAddr,
    output reg[SRAM_WIDTH       -1 : 0] FPSGLB_MaskWrBitEn,
    output                              FPSGLB_MaskWrDatVld,
    output reg [SRAM_WIDTH      -1 : 0] FPSGLB_MaskWrDat,
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
    .MAX_COUNT ( CCUFPS_CfgNop  ),
    .OVERFLOW  ( CpLast         ),
    .UNDERFLOW (                ),
    .COUNT     (    )
);

//=====================================================================================================================
// Logic Design: Stage0
//=====================================================================================================================

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
    .MAX_COUNT ( CCUFPS_CfgNip -1   ),
    .OVERFLOW  ( LopCntLast     ),
    .UNDERFLOW (                    ),
    .COUNT     ( LopCnt             )
);

assign rdy_s0 = arready;
assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0 = handshake_s1 | ~vld_s0;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        vld_s0 <= 0;
    end else if( ena_s0) begin
        vld_s0 <= next_state == LP;
    end
end

assign INC_LopCnt = handshake_s0; // After being fetched by the next stage

//=====================================================================================================================
// Logic Design: Stage1: Addr Gen
//=====================================================================================================================



RAM_HS#(
    .SRAM_BIT     ( IDX_WIDTH ),
    .SRAM_BYTE    ( 1 ),
    .SRAM_WORD    ( IDX_WIDTH ),
    .CLOCK_PERIOD ( CLOCK_PERIOD )
)u_RAM_HS_AddrLL( // Linked List
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .wvalid       ( wvalid       ),
    .wready       ( wready       ),
    .waddr        ( waddr        ),
    .wdata        ( wdata        ),
    .arvalid      ( vld_s0      ),
    .arready      ( arready      ),
    .araddr       ( LopCnt       ),
    .rvalid       ( vld_s1),
    .rready       ( rdy_s1       ),
    .rdata        ( LopPntIdx)
);

assign rdy_s1 = GLBFPS_CrdAddrRdy & GLBFPS_DistRdAddrRdy;
assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1 = handshake_s1 | ~vld_s1;

assign FPSGLB_CrdAddr = LopPntIdx;
assign FPSGLB_CrdAddrVld = handshake_s1; //(state == LP & MaskLoop) | FPSLyIdx == 0;// First layer not use mask

assign FPSGLB_DistRdAddr    = LopPntIdx;
assign FPSGLB_DistRdAddrVld = handshake_s1;

always @(posedge clk or negedge rst_n) begin: Pipe1
    if(!rst_n) begin
        { LopCntLast_s1} <= 0;
    end else if (ena_s1) begin
        {LopCntLast_s1} <= {LopCntLast};
    end
end

//=====================================================================================================================
// Logic Design: Stage2: Use
//=====================================================================================================================
// Upper stage
assign FPSGLB_CrdRdy        = ena_s2;
assign FPSGLB_DistIdxRdy    = ena_s2;

// next stage
assign rdy_s2 = GLBFPS_DistIdxRdy & GLBFPS_MaskWrDatRdy;
assign handshake_s2 = rdy_s2 & vld_s2;
assign ena_s2 = handshake_s2 | ~vld_s2;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        vld_s2 <= 0;
    end else if( ena_s2) begin
        vld_s2 <= GLBFPS_CrdVld & GLBFPS_DistIdxVld;
    end
end

EDC#(
    .CRD_WIDTH ( CRD_WIDTH  ),
    .CRD_DIM   ( CRD_DIM    )
)u_EDC(
    .Crd0      ( FPS_CpCrd      ),
    .Crd1      ( GLBFPS_Crd     ),
    .DistSqr   ( LopDist    )
);
assign FPS_LastPsIdx = GLBFPS_DistIdx[0 +: IDX_WIDTH];
assign FPS_LastPsDist = GLBFPS_DistIdx[IDX_WIDTH +: DISTSQR_WIDTH];


// Write back (Update) DistIdx
assign {FPS_PsDist, FPS_PsIdx} = FPS_LastPsDist > LopDist ? {LopDist, LopPntIdx_s2} : {FPS_LastPsDist, FPS_LastPsIdx};

assign FPS_UpdMax = FPS_MaxDist < FPS_PsDist;
assign {FPS_MaxDist_, FPS_MaxCrd_, FPS_MaxIdx_} <= FPS_UpdMax ? {FPS_PsDist, GLBFPS_Crd, FPS_PsIdx} : {FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx};


// Reg Update
always @(posedge clk or negedge rst_n) begin: Pipe2_LopCrd_s2
    if(!rst_n) begin
        {FPSGLB_DistIdx, FPSGLB_DistWrAddr, LopPntIdx_s2} <= 0;
    end else if (ena_s2) begin
        {FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx, FPSGLB_DistIdx, FPSGLB_DistWrAddr, LopPntIdx_s2, LopCntLast_s2} <= {FPS_MaxDist_, FPS_MaxCrd_, FPS_MaxIdx_, FPS_PsDist, FPS_PsIdx, FPS_PsIdx, LopPntIdx_s1, LopCntLast_s1};
    end
end
assign FPSGLB_DistIdxVld = vld_s2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        FPS_CpCrd <= 0;
    end else if (ena_s2 & LopCntLast_s1) begin
        FPS_CpCrd <= FPS_MaxCrd_;
    end
end

// Write back (Update) Mask
assign FPSGLB_MaskWrAddr = FPS_MaxIdx >> $clog2(SRAM_WIDTH/NUM_LAYER);
assign FPSGLB_MaskWrDatVld = vld_s2 & LopCntLast_s2;

assign MaskRAMBitIdx = FPSLyIdx % (SRAM_WIDTH/NUM_LAYER);
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
