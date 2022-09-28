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
module CTR #(
    parameter SRAM_WIDTH        = 256,
    parameter IDX_WIDTH         = 10,
    parameter K_WIDTH = 5,
    parameter CRD_WIDTH         = 16,
    parameter CRD_DIM           = 3, 
    parameter DIST_WIDTH =  $clog2( CRD_WIDTH*2*$clog(CRD_DIM) )
    )(
    input                               clk                     ,
    input                               rst_n                   ,

    // Configure
    input CCUCTR_Rst,

    input           CCUCTR_CfgVld,
    output CTRCCU_CfgRdy,
    input  CCUCTR_CfgMod,
    input [IDX_WIDTH    -1 : 0] CCUCTR_CfgNip,
    input [IDX_WIDTH    -1 : 0] CCUCTR_CfgNop,
    input [K_WIDTH  `   -1 : 0] CCUCTR_CfgK , 

    output [IDX_WIDTH    -1 : 0] CTRGLB_CrdAddr ,   
    output CTRGLB_CrdAddrVld, 
    input  GLBCTR_CrdAddrRdy ,
    input  [SRAM_WIDTH  -1 : 0 ]GLBCTR_Crd,        
    input  GLBCTR_CrdVld     
    output CTRGLB_CrdRdy     
    output [IDX_WIDTH    -1 : 0] CTRGLB_DistAddr   // FPS
    output CTRGLB_DistAddrVld
    input  GLBCTR_DistAddrRdy
    input  [DIST_WIDTH, IDX_WIDTH] GLBCTR_DistIdx       // // FPS
    input  GLBCTR_DistIdxVld    
    output CTRGLB_DistIdxRdy    
    output [SRAM_WIDTH  -1 : 0 ] CTRGLB_Idx    // KNN    
    output CTRGLB_IdxVld     
    input  CTRGLB_IdxRdy     

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE    = 3'b000;
localparam CFG     = 3'b001;
localparam CMP     = 3'b010;
localparam STOP    = 3'b011;
localparam WAITGBF = 3'b100;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE : if(CTRCCU_CfgRdy & CCUCTR_CfgVld)
                    next_state <= CP; //A network config a time
                else
                    next_state <= IDLE;
        CP: if( CTRGLB_CrdAddrVld & GLBCTR_CrdAddrRdy)
                    next_state <= LP;
                else
                    next_state <= CFG;
        LP: if( CTRPSS_LopLast) /// CMP_FRM CMP_PAT CMP_...
                    next_state <= CP;
                else
                    next_state <= LP;
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

assign CTRCCU_CfgRdy = state==IDLE;
//=====================================================================================================================
// Logic Design 1: FPS
//=====================================================================================================================

always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        CTRPSS_Mask <= 0;
    end else if (CTRPSS_LopLast ) begin
        CTRPSS_Mask[FPS_LopIdx] <= 1'b1;
    end
end

always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        CTRPSS_MaskVld <= 0;
    end else if (CTRPSS_LopLast ) begin
        CTRPSS_MaskVld <= 1'b1;
    end else if (CTRPSS_MaskVld & PSSCTR_MaskRdy ) begin
        CTRPSS_MaskVld <= 1'b0;
    end
end

always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        FPS_CpCrd <= 0;
    end else if (CTRPSS_LopLast ) begin
        FPS_CpCrd <= MaxCrd;
    end
end


always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        {MaxCrd, FPS_LopIdx} <= 0;
    end else if (update_max ) begin
        {MaxCrd, FPS_LopIdx} <= {ps_idx, CTRGLB_CrdAddr;
    end
end

always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        max_dist <= 0;
    end else if (update_max ) begin
        max_dist <= ps_dist;
    end
end

assign update_max = max_dist < ps_dist;

//=====================================================================================================================
// Logic Design 1: FPS
//=====================================================================================================================

assign {lps_dist, lps_idx } = GLBCTR_DistIdx;
assign {ps_dist, ps_idx} = lps_dist > LopDist ? {LopDist, FPS_LopIdx} : GLBCTR_DistIdx;

assign CTRGLB_DistAddr = CTRGLB_CrdAddr;
assign CTRGLB_DistAddrVld = !CCUCTR_CfgMod & CTRGLB_CrdAddrVld;

assign CTRGLB_DistIdxRdy = !CCUCTR_CfgMod & GLBCTR_CrdRdy;

//=====================================================================================================================
// Logic Design 2: KNN
//=====================================================================================================================


always @(posedge clk or rst_n) begin
    if(!rst_n) begin
        KNN_CpCrd <= 0;
    end else if (GLBCTR_CrdVld & GLBCTR_CrdRdy) begin
        KNN_CpCrd <= GLBCTR_Crd;
    end
end

always @(posedge clk or rst_n) begin
    if(!rst_n) begin
        LopCrd <= 0;
    end else if (GLBCTR_CrdVld & GLBCTR_CrdRdy) begin
        LopCrd <= GLBCTR_Crd;
    end
end

assign CTRGLB_CrdAddr = state == CP ? CTRPSS_CpIdx : CTRPSS_LopIdx;
assign CTRGLB_CrdAddrVld = CCUCTR_CfgMod ? (state == CP | state == LP) : ;state == LP

always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        GLBCTR_CrdRdy <= 1'b0;
    end else if (CTRGLB_CrdAddrVld & GLBCTR_CrdAddrRdy ) begin
        GLBCTR_CrdRdy <= 1'b1
    end else if (GLBCTR_CrdVld & GLBCTR_CrdRdy ) begin
        GLBCTR_CrdRdy <= 1'b0;
    end
end
//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

PSS#(
    .SORT_LEN_WIDTH  ( 5 ),
    .IDX_WIDTH       ( 10 ),
    .DIST_WIDTH      ( 17 ),
    .NUM_SORT_CORE   ( 8 ),
    .SRAM_WIDTH      ( 256 )
)u_PSS(
    .CTRPSS_LopLast  ( CTRPSS_LopLast  ),
    .CTRPSS_Rst      ( CTRPSS_Rst      ),
    .CTRPSS_Mask     ( CTRPSS_Mask     ),
    .CTRPSS_MaskVld  ( CTRPSS_MaskVld  ),
    .PSSCTR_MaskRdy  ( PSSCTR_MaskRdy  ),
    .CTRPSS_CpIdx    ( CTRPSS_CpIdx    ),
    .CTRPSS_Lop      ( CTRPSS_Lop      ),// {idx, dist}
    .CTRPSS_LopVld   ( CTRPSS_LopVld   ),
    .PSSCTR_LopRdy   ( PSSCTR_LopRdy   ),
    .PSSCTR_Idx      ( CTRGLB_Idx      ),
    .PSSCTR_IdxVld   ( CTRGLB_IdxVld   ),
    .PSSCTR_IdxRdy   ( CTRGLB_IdxRdy   )
);

counter#(
    .COUNT_WIDTH ( 3 )
)u0_counter_CTRPSS_CpIdx(
    .CLK       ( clk       ),
    .RESET_N   ( rst_n   ),
    .CLEAR     ( CCUCTR_Rst     ),
    .DEFAULT   ( 0   ),
    .INC       ( INC       ),
    .DEC       ( 1'b0       ),
    .MIN_COUNT ( 0 ),
    .MAX_COUNT ( CCUCTR_CfgNip ),
    .OVERFLOW  (   ),
    .UNDERFLOW (  ),
    .COUNT     ( CTRPSS_CpIdx     )
);
assign INC = CTRPSS_LopLast;

counter#(
    .COUNT_WIDTH ( 3 )
)u1_counter_LopIdx(
    .CLK       ( clk       ),
    .RESET_N   ( rst_n   ),
    .CLEAR     ( INC     ),
    .DEFAULT   ( 0   ),
    .INC       ( INC_LopIdx       ),
    .DEC       ( 1'b0       ),
    .MIN_COUNT ( 0 ),
    .MAX_COUNT ( CCUCTR_CfgNip ),
    .OVERFLOW  ( CTRPSS_LopLast  ),
    .UNDERFLOW (  ),
    .COUNT     ( CTRPSS_LopIdx     )
);
assign INC_LopIdx = CTRPSS_LopVld & CTRGLB_IdxRdy;

EDC#(
    .CRD_WIDTH ( 16 ),
    .CRD_DIM   ( 3 )
)u_EDC(
    .Crd0      ( CCUCTR_CfgMod ? KNN_CpCrd : FPS_CpCrd      ),
    .Crd1      ( LopCrd      ),
    .DistSqr   ( LopDist   )
);


endmodule
