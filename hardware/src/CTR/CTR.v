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
    parameter SORT_LEN_WIDTH    = 5,
    parameter CRD_WIDTH         = 16,
    parameter CRD_DIM           = 3, 
    parameter DISTSQR_WIDTH     =  $clog2( CRD_WIDTH*2*$clog(CRD_DIM) ),
    parameter NUM_SORT_CORE     = 8
    )(
    input                               clk  ,
    input                               rst_n,

    // Configure
    input                               CCUCTR_Rst,
    input                               CCUCTR_CfgVld,
    output                              CTRCCU_CfgRdy,
    input                               CCUCTR_CfgMod,
    input [IDX_WIDTH            -1 : 0] CCUCTR_CfgNip,
    input [IDX_WIDTH            -1 : 0] CCUCTR_CfgNop,
    input [SORT_LEN_WIDTH              -1 : 0] CCUCTR_CfgK, 

    // Fetch Crd
    output [IDX_WIDTH           -1 : 0] CTRGLB_CrdAddr,   
    output                              CTRGLB_CrdAddrVld, 
    input                               GLBCTR_CrdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0 ]GLBCTR_Crd,        
    input                               GLBCTR_CrdVld,     
    output                              CTRGLB_CrdRdy,

    // Fetch Dist and Idx of FPS
    output [IDX_WIDTH           -1 : 0] CTRGLB_DistAddr, 
    output                              CTRGLB_DistAddrVld,
    input                               GLBCTR_DistAddrRdy,
    input  [DISTSQR_WIDTH+IDX_WIDTH-1 : 0] GLBCTR_DistIdx,    
    input                               GLBCTR_DistIdxVld,    
    output                              CTRGLB_DistIdxRdy,    

    // Output Map of KNN
    output [SRAM_WIDTH          -1 : 0 ]CTRGLB_Idx,   
    output                              CTRGLB_IdxVld,     
    input                               CTRGLB_IdxRdy     

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
reg [DISTSQR_WIDTH      -1 : 0] FPS_PsDist;

reg [DISTSQR_WIDTH      -1 : 0]FPS_LastPsDist_s2; 
reg [IDX_WIDTH          -1 : 0] FPS_LastPsIdx_s2;

reg [CRD_WIDTH*CRD_DIM  -1 : 0] LopCrd_s2;

wire                            CTRPSS_LopLast_s2;
reg [IDX_WIDTH          -1 : 0] CTRPSS_Mask;
reg                             CTRPSS_MaskVld;   
wire[IDX_WIDTH          -1 : 0] CpIdx;  

wire[DISTSQR_WIDTH      -1 : 0] LopDist_s2;

reg                             LopLast_s2;
reg                             LopLast_s1;
reg [IDX_WIDTH          -1 : 0] LopIdx_s2;
reg [IDX_WIDTH          -1 : 0] LopIdx_s1;

wire                            CpLast;
reg [CRD_WIDTH*CRD_DIM  -1 : 0] KNN_CpCrd_s2
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE :  if(CTRCCU_CfgRdy & CCUCTR_CfgVld)
                    next_state <= CP; //
                else
                    next_state <= IDLE;
        CP:     if( CTRGLB_CrdAddrVld & GLBCTR_CrdAddrRdy)
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
        FNH:    next_state <= IDLE
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
    end else if (LopLast_s2 ) begin
        CTRPSS_Mask[FPS_MaxIdx] <= 1'b1;
    end
end

always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        CTRPSS_MaskVld <= 0;
    end else if (LopLast_s2 ) begin
        CTRPSS_MaskVld <= 1'b1;
    end else if (CTRPSS_MaskVld & PSSCTR_MaskRdy ) begin
        CTRPSS_MaskVld <= 1'b0;
    end
end

always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        FPS_CpCrd <= 0;
    end else if (LopLast_s2 ) begin
        FPS_CpCrd <= FPS_MaxCrd;
    end
end


always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        {FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx} <= 0;
    end else if (FPS_UpdMax ) begin
        {FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx} <= {FPS_PsDist, LopCrd_s2, FPS_PsIdx};
    end
end

assign FPS_UpdMax = FPS_MaxDist < FPS_PsDist;

//=====================================================================================================================
// Logic Design 1: FPS
//=====================================================================================================================

always @(posedge clk or rst_n) begin: Pipe2
    if(!rst_n) begin
        {FPS_LastPsDist_s2, FPS_LastPsIdx_s2} <= 0;
    end else if (GLBCTR_DistIdxVld & CTRGLB_DistIdxRdy) begin
        {FPS_LastPsDist_s2, FPS_LastPsIdx_s2} <= GLBCTR_DistIdx;
    end
end

assign {FPS_PsDist, FPS_PsIdx} = FPS_LastPsDist_s2 > LopDist_s2 ? {LopDist_s2, LopIdx_s2} : {FPS_LastPsDist_s2, FPS_LastPsIdx_s2};

assign CTRGLB_DistAddr = CTRGLB_CrdAddr;
assign CTRGLB_DistAddrVld = !CCUCTR_CfgMod & CTRGLB_CrdAddrVld;

assign CTRGLB_DistIdxRdy = !CCUCTR_CfgMod & GLBCTR_CrdRdy;

//=====================================================================================================================
// Logic Design 2: KNN
//=====================================================================================================================

s
always @(posedge clk or rst_n) begin
    if(!rst_n) begin
        KNN_CpCrd_s2 <= 0;
    end else if (GLBCTR_CrdVld & GLBCTR_CrdRdy) begin
        KNN_CpCrd_s2 <= GLBCTR_Crd;
    end
end

always @(posedge clk or rst_n) begin: Pipe2
    if(!rst_n) begin
        {LopCrd_s2, LopIdx_s2, LopLast_s2} <= 0;
    end else if (GLBCTR_CrdVld & GLBCTR_CrdRdy) begin
        {LopCrd_s2, LopIdx_s2, LopLast_s2} <= {GLBCTR_Crd, CTRGLB_CrdAddr_s1, LopLast_s1};
    end
end
always @(posedge clk or rst_n) begin: Pipe1
    if(!rst_n) begin
        {CTRGLB_CrdAddr_s1, LopLast_s1} <= 0;
    end else if (CTRGLB_CrdAddrVld & GLBCTR_CrdAddrRdy) begin
        {CTRGLB_CrdAddr_s1, LopLast_s1} <= {CTRGLB_CrdAddr, LopLast};
    end
end

always @(posedge clk or rst_n) begin
    if(!rst_n) begin
        CTRPSS_LopVld <= 1'b0;
    end else if (GLBCTR_CrdVld & GLBCTR_CrdRdy) begin
        CTRPSS_LopVld <= 1''b1;
    end else if (CTRPSS_LopVld & PSSCTR_LopRdy) begin
        CTRPSS_LopVld <= 1'b0;
    end
end


assign CTRGLB_CrdAddr = state == CP ? CpIdx : LopIdx;
assign CTRGLB_CrdAddrVld = CCUCTR_CfgMod ? (state == CP | state == LP) : state == LP;

assign GLBCTR_CrdRdy = PSSCTR_LopRdy | !CTRPSS_LopVld; // pipe1 of HS: last_ready or current invalid

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================
wire                    PSSCTR_MaskRdy;
PSS#(
    .SORT_LEN_WIDTH  ( SORT_LEN_WIDTH   ),
    .IDX_WIDTH       ( IDX_WIDTH        ),
    .DIST_WIDTH      ( DISTSQR_WIDTH    ),
    .NUM_SORT_CORE   ( NUM_SORT_CORE    ),
    .SRAM_WIDTH      ( SRAM_WIDTH       )
)u_PSS(
    .CTRPSS_LopLast  ( CTRPSS_LopLast_s2  ),
    .CTRPSS_Rst      ( CCUCTR_Rst      ),
    .CTRPSS_Mask     ( CTRPSS_Mask     ),
    .CTRPSS_MaskVld  ( CTRPSS_MaskVld  ),
    .PSSCTR_MaskRdy  ( PSSCTR_MaskRdy  ),
    .CpIdx    ( CpIdx    ),
    .CTRPSS_Lop      ( {LopDist_s2, LopIdx_s2 }),// {idx, dist} 
    .CTRPSS_LopVld   ( CTRPSS_LopVld   ),
    .PSSCTR_LopRdy   ( PSSCTR_LopRdy   ),
    .PSSCTR_Idx      ( CTRGLB_Idx      ),
    .PSSCTR_IdxVld   ( CTRGLB_IdxVld   ),
    .PSSCTR_IdxRdy   ( CTRGLB_IdxRdy   )
);
wire INC_CpIdx;
counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u0_counter_CpIdx(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( CCUCTR_Rst     ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}),
    .INC       ( INC_CpIdx      ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}),
    .MAX_COUNT ( CCUCTR_CfgMod ? CCUCTR_CfgNip : CCUCTR_CfgNop  ),
    .OVERFLOW  ( CpLast               ),
    .UNDERFLOW (                ),
    .COUNT     ( CpIdx   )
);
wire                    LopLast;
assign INC_CpIdx    =  CCUCTR_CfgMod ? LopLast_s2 & (CTRPSS_LopVld & PSSCTR_LopRdy) : LopLast_s2;
assign CTRPSS_LopLast_s2 = LopLast_s2 & CTRPSS_LopVld;

counter#( // Pipe S0
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_LopIdx(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CpIdx | CCUCTR_Rst   ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
    .INC       ( INC_LopIdx         ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
    .MAX_COUNT ( CCUCTR_CfgMod ? CCUCTR_CfgNip :  CCUCTR_CfgNip - CpIdx     ),
    .OVERFLOW  ( LopLast     ),
    .UNDERFLOW (                    ),
    .COUNT     ( LopIdx             )
);
assign INC_LopIdx = CTRGLB_CrdAddrVld & GLBCTR_CrdAddrRdy ;

EDC#(
    .CRD_WIDTH ( CRD_WIDTH  ),
    .CRD_DIM   ( CRD_DIM    )
)u_EDC(
    .Crd0      ( CCUCTR_CfgMod ? KNN_CpCrd_s2 : FPS_CpCrd),
    .Crd1      ( LopCrd_s2     ),
    .DistSqr   ( LopDist_s2    )
);


endmodule
