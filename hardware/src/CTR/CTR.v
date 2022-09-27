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
`include "../source/include/dw_params.vh"
module CTR #(
    parameter NUM_PEB         = 16,
    parameter FIFO_ADDR_WIDTH = 6  
    )(
    input                               clk                     ,
    input                               rst_n                   ,

    // Configure
input CCUCTR_Rst

input CCUCTR_CfgVld
output CTRCCU_CfgRdy
input CCUCTR_CfgMod
input CCUCTR_CfgNip
input CCUCTR_CfgNop
input CCUCTR_CfgK  

output CTRGLB_CrdAddr    
output CTRGLB_CrdAddrVld 
input  GLBCTR_CrdAddrRdy 
input  GLBCTR_Crd        
input  GLBCTR_CrdVld     
output GLBCTR_CrdRdy     
output CTRGLB_DistAddr   
output CTRGLB_DistAddrVld
input  CTRGLB_DistAddrRdy
input  GLBCTR_Dist       
input  GLBCTR_DistVld    
output GLBCTR_DistRdy    
output CTRGLB_Idx        
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
wire                                start_cmp     ;
wire [ 6                    -1 : 0] MEM_CCUGB_block[ 0 : NUM_PEB -1 ];
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE : if( )
                    next_state <= CP; //A network config a time
                else
                    next_state <= IDLE;
        CP: if( CTRGLB_CrdVld & GLBCTR_CrdAddrRdy)
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

//=====================================================================================================================
// Logic Design 2: Addr Gen.
//=====================================================================================================================


always @(posedge clk or rst_n) begin
    if(!rst_n) begin
        
    end else if (GLBCTR_CrdVld & GLBCTR_CrdRdy & state == CP) begin
        CpCrd <= GLBCTR_Crd;
    end
end

always @(posedge clk or rst_n) begin
    if(!rst_n) begin
        
    end else if (GLBCTR_CrdVld & GLBCTR_CrdRdy & state == LP) begin
        LopCrd <= GLBCTR_Crd;
    end
end

assign CTRGLB_CrdAddr = state == CP ? CTRPSS_CpIdx : CTRPSS_LopIdx;
assign CTRGLB_CrdVld = state == CP | state == LP;

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
    .Crd0      ( CpCrd      ),
    .Crd1      ( LopCrd      ),
    .DistSqr   ( LopDist   )
);


endmodule
