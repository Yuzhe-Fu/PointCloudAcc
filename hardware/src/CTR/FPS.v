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
    parameter DISTSQR_WIDTH     =  $clog2( CRD_WIDTH*2*$clog2(CRD_DIM) )
    )(
    input                               clk  ,
    input                               rst_n,

    // Configure
    input                               CCUCTR_Rst,
    input                               CCUCTR_CfgVld,
    output                              FPSCCU_CfgRdy,
    input [IDX_WIDTH            -1 : 0] CCUCTR_CfgNip,
    input [IDX_WIDTH            -1 : 0] CCUCTR_CfgNop,

    // Fetch Crd
    output [IDX_WIDTH           -1 : 0] FPSGLB_CrdAddr,   
    output                              FPSGLB_CrdAddrVld, 
    input                               GLBFPS_CrdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0 ]GLBFPS_Crd,        
    input                               GLBFPS_CrdVld,     
    output                              FPSGLB_CrdRdy,

    // Fetch Dist and Idx of FPS
    output [IDX_WIDTH           -1 : 0] CTRGLB_DistRdAddr, 
    output                              CTRGLB_DistRdAddrVld,
    input                               GLBCTR_DistRdAddrRdy,
    input  [DISTSQR_WIDTH+IDX_WIDTH-1 : 0] GLBCTR_DistIdx,    
    input                               GLBCTR_DistIdxVld,    
    output                              CTRGLB_DistIdxRdy,    

    output [IDX_WIDTH           -1 : 0] CTRGLB_DistWrAddr,
    output [DISTSQR_WIDTH+IDX_WIDTH-1 : 0] CTRGLB_DistIdx,   
    output reg                          CTRGLB_DistIdxVld,
    input                               GLBCTR_DistIdxRdy,

    output reg [2**IDX_WIDTH    -1 : 0] FPSPSS_Mask,
    output reg                          FPSPSS_MaskVld,
    input                               PSSFPS_MaskRdy
      
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

reg                             LopLast_s2;
reg                             LopLast_s1;
reg                             FPSGLB_CrdAddr_s1;
reg [IDX_WIDTH          -1 : 0] LopIdx_s2;
reg [IDX_WIDTH          -1 : 0] LopIdx_s1;

wire                            CpLast;

wire                            LopLast;

wire [IDX_WIDTH         -1 : 0] LopIdx;

reg [2**IDX_WIDTH       -1 : 0] Mask_LastLy;
wire [2**IDX_WIDTH      -1 : 0] Mask_Loop;
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE :  if(FPSCCU_CfgRdy & CCUCTR_CfgVld)
                    next_state <= CP; //
                else
                    next_state <= IDLE;
        CP:     if( 1'b1)
                    next_state <= LP;
                else
                    next_state <= CP;
        LP:     if ( LopLast ) begin
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

//=====================================================================================================================
// Logic Design: PIPE0: Addr Gen
//=====================================================================================================================

wire INC_CntCp;
counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u0_counter_CntCp(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( CCUCTR_Rst     ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}),
    .INC       ( INC_CntCp      ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}),
    .MAX_COUNT ( CCUCTR_CfgNop  ),
    .OVERFLOW  ( CpLast               ),
    .UNDERFLOW (                ),
    .COUNT     (    )
);
assign INC_CntCp    =  LopLast_s2;

counter#( // Pipe S0
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_LopIdx(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CntCp | CCUCTR_Rst   ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
    .INC       ( INC_LopIdx         ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
    .MAX_COUNT ( CCUCTR_CfgNip     ),
    .OVERFLOW  ( LopLast     ),
    .UNDERFLOW (                    ),
    .COUNT     ( LopIdx             )
);

// DistIdx is same with Crd
assign CTRGLB_DistRdAddr    = FPSGLB_CrdAddr;
assign CTRGLB_DistRdAddrVld = FPSGLB_CrdAddrVld;

assign INC_LopIdx = (FPSGLB_CrdAddrVld & GLBFPS_CrdAddrRdy & CTRGLB_DistRdAddrVld & GLBCTR_DistRdAddrRdy) |  (!FPSGLB_CrdAddrVld & !CTRGLB_DistRdAddrVld);

assign FPSGLB_CrdAddr = LopIdx;
assign FPSGLB_CrdAddrVld = state == LP & Mask_Loop[FPSGLB_CrdAddr];

assign Mask_Loop = Mask_LastLy & !FPSPSS_Mask;

//=====================================================================================================================
// Logic Design: PIPE1: DatIn
//=====================================================================================================================

always @(posedge clk or negedge rst_n) begin: Pipe1
    if(!rst_n) begin
        {FPSGLB_CrdAddr_s1, LopLast_s1} <= 0;
    end else if (FPSGLB_CrdAddrVld & GLBFPS_CrdAddrRdy) begin
        {FPSGLB_CrdAddr_s1, LopLast_s1} <= {FPSGLB_CrdAddr, LopLast};
    end
end
//=====================================================================================================================
// Logic Design: PIPE2: DatUse
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin: Pipe2_LopCrd_s2
    if(!rst_n) begin
        {LopCrd_s2, LopIdx_s2, LopLast_s2} <= 0;
    end else if (GLBFPS_CrdVld & FPSGLB_CrdRdy) begin
        {LopCrd_s2, LopIdx_s2, LopLast_s2} <= {GLBFPS_Crd, FPSGLB_CrdAddr_s1, LopLast_s1};
    end
end

always @(posedge clk or negedge rst_n) begin: Pipe2_FPS_LastPsDist_s2
    if(!rst_n) begin
        {FPS_LastPsDist_s2, FPS_LastPsIdx_s2} <= 0;
    end else if (GLBCTR_DistIdxVld & CTRGLB_DistIdxRdy) begin
        {FPS_LastPsDist_s2, FPS_LastPsIdx_s2} <= GLBCTR_DistIdx;
    end
end

assign {FPS_PsDist, FPS_PsIdx} = FPS_LastPsDist_s2 > LopDist_s2 ? {LopDist_s2, LopIdx_s2} : {FPS_LastPsDist_s2, FPS_LastPsIdx_s2};

// DistIdx is same with Crd
assign CTRGLB_DistIdxRdy    = FPSGLB_CrdRdy;

// Back Pressure
assign FPSGLB_CrdRdy = !CTRGLB_DistIdxVld | GLBCTR_DistIdxRdy; // PIPE2's Dist is invalid or WrRdy; 

// Write back (Update)
assign CTRGLB_DistWrAddr = FPS_PsIdx;
assign CTRGLB_DistIdx = {FPS_PsDist, FPS_PsIdx};
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        CTRGLB_DistIdxVld <= 0;
    end else if (GLBCTR_DistIdxVld & CTRGLB_DistIdxRdy) begin
        CTRGLB_DistIdxVld <= 1'b1;
    end else if (CTRGLB_DistIdxVld & GLBCTR_DistIdxRdy) begin
        CTRGLB_DistIdxVld <= 1'b0;
    end
end

EDC#(
    .CRD_WIDTH ( CRD_WIDTH  ),
    .CRD_DIM   ( CRD_DIM    )
)u_EDC(
    .Crd0      ( FPS_CpCrd      ),
    .Crd1      ( LopCrd_s2     ),
    .DistSqr   ( LopDist_s2    )
);
//=====================================================================================================================
// Logic Design: PIPE3: Update
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        FPSPSS_Mask <= 0;
    end else if (LopLast_s2 ) begin
        FPSPSS_Mask[FPS_MaxIdx] <= 1'b1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        FPSPSS_MaskVld <= 0;
    end else if (LopLast_s2 ) begin
        FPSPSS_MaskVld <= 1'b1;
    end else if (FPSPSS_MaskVld & PSSFPS_MaskRdy ) begin
        FPSPSS_MaskVld <= 1'b0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        FPS_CpCrd <= 0;
    end else if (LopLast_s2 ) begin
        FPS_CpCrd <= FPS_MaxCrd;
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        {FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx} <= 0;
    end else if (FPS_UpdMax ) begin
        {FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx} <= {FPS_PsDist, LopCrd_s2, FPS_PsIdx};
    end
end

assign FPS_UpdMax = FPS_MaxDist < FPS_PsDist;


//=====================================================================================================================
// Logic Design: PIPE4: 
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        Mask_LastLy <= {(2**IDX_WIDTH){1'b1}};
    end else if ( state==FNH ) begin
        Mask_LastLy <= FPSPSS_Mask;
    end
end


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================




endmodule
