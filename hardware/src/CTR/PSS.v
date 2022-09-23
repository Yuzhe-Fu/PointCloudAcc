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
`include "../source/include/dw_params_presim.vh"
module PSS #(
    parameter SORT_LEN_WIDTH  = 5                 ,
    parameter IDX_WIDTH       = 10                ,
    parameter DIST_WIDTH      = 17                ,
    parameter NUM_SORT_CORE   = 8                 ,
    parameter SRAM_WIDTH      = 256                 

    )(
input                                   CTRPSS_LopLast  ,
input                                   CTRPSS_Rst      ,
input   [2**IDX_WIDTH           -1 : 0] CTRPSS_Mask     ,
input                                   CTRPSS_MaskVld  ,
output                                  PSSCTR_MaskRdy  ,
input   [IDX_WIDTH              -1 : 0] CTRPSS_CpIdx    ,
// input   CTRPSS_CpIdxVld
// output  PSSCTR_CpIdxRdy
input   [IDX_WIDTH+DIST_WIDTH   -1 : 0] CTRPSS_Lop      ,  
input                                   CTRPSS_LopVld   ,  
output                                  PSSCTR_LopRdy   ,  
output  [SRAM_WIDTH             -1 : 0] PSSCTR_Idx      , 
output                                  PSSCTR_IdxVld   , 
input                                   PSSCTR_IdxRdy    
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [NUM_SORT_CORE         -1 : 0] INS_LopRdy;
reg  [$clog2(NUM_SORT_CORE)    : 0] addr;
reg  [2**IDX_WIDTH          -1 : 0] Mask_Array;
//=====================================================================================================================
// Logic Design 2: HandShake
//=====================================================================================================================


//=====================================================================================================================
// Logic Design 1: INSSSC_Idx
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if (CTRPSS_MaskVld & PSSCTR_MaskRdy) begin
        Mask_Array[addr] <= CTRPSS_Mask;
        addr <= addr + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        addr <= 0;
    end else if (CTRPSS_Rst) begin
        addr <= 0;
    end else if (CTRPSS_MaskVld & PSSCTR_MaskRdy) begin
        addr <= addr + 1;
    end
end

assign PSSCTR_MaskRdy = !addr[$clog2(NUM_SORT_CORE)];



//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================
genvar i;
generate
    for(i=0; i<NUM_SORT_CORE; i=i+1) begin
        INS#(
            .SORT_LEN_WIDTH   ( SORT_LEN_WIDTH ),
            .IDX_WIDTH       ( IDX_WIDTH ),
            .DIST_WIDTH      ( DIST_WIDTH )
        )u_INS(
            .clk                 ( clk                 ),
            .rst_n               ( rst_n               ),
            .SSCINS_LopLast      ( CTRPSS_LopLast      ),
            .SSCINS_Lop          ( CTRPSS_Lop          ),
            .SSCINS_LopVld       ( SSCINS_LopVld       ),
            .SSCINS_LopRdy       ( INS_LopRdy[i]       ),
            .INSSSC_Idx          ( INSSSC_Idx          ),
            .INSSSC_IdxVld       ( INSSSC_IdxVld       ),
            .INSSSC_IdxRdy       ( INSSSC_IdxRdy       )
        );

        assign SSCINS_LopVld = Mask_Array[i][CTRPSS_Lop[IDX_WIDTH+DIST_WIDTH -1 -: IDX_WIDTH]];
        
    end
endgenerate

assign PSSCTR_LopRdy = & INS_LopRdy;

PISO#(
    .DATA_IN_WIDTH   ( 384 ), // (32+1)*10 /96 = 330 /96 <= 4
    .DATA_OUT_WIDTH  ( 96  )
)U_PISO(
    .CLK       ( clk       ),
    .RESET_N   ( rst_n      ),
    .ENABLE    ( INSSSC_IdxVld    ),
    .DATA_IN   ( {54'd0 ,{CTRPSS_CpIdx, INSSSC_Idx}}   ),
    .READY     ( INSSSC_IdxRdy     ),
    .DATA_OUT  ( PSSCTR_Idx  ),
    .OUT_VALID ( PSSCTR_IdxVld ),
    .OUT_READY ( PSSCTR_IdxRdy  )
);

endmodule