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
module MIF #(
    parameter POOL_CORE     = 6,
    parameter POOL_COMP_CORE= 64,
    parameter IDX_WIDTH     = 10,
    parameter ACT_WIDTH     = 8
    )(
    input                               clk                     ,
    input                               rst_n                   ,
    input                               POLMIF_Rst,
    // Configure
    input  [POOL_CORE                               -1 : 0] POLMIF_AddrVld,
    input  [IDX_WIDTH*POOL_CORE                     -1 : 0] POLMIF_Addr   ,
    output [POOL_CORE                               -1 : 0] MIFPOL_Rdy    ,
    output [POOL_CORE                               -1 : 0] MIFGLB_AddrVld,
    output [IDX_WIDTH*POOL_CORE                     -1 : 0] MIFGLB_Addr   ,
    input  [POOL_CORE                               -1 : 0] GLBMIF_AddrRdy,
    input  [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE    -1 : 0] GLBMIF_Ofm     ,
    input  [POOL_CORE                               -1 : 0] GLBMIF_OfmVld  ,
    output [POOL_CORE                               -1 : 0] MIFGLB_OfmRdy  ,
    output [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE    -1 : 0] MIFPOL_Ofm     ,
    output [POOL_CORE                               -1 : 0] MIFPOL_OfmVld  ,
    input  [POOL_CORE                               -1 : 0] MIFPOL_OfmRdy   

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

wire [$clog2(POOL_CORE)         -1 : 0] PolCoreIdx  [0 : POOL_CORE-1];
wire [ACT_WIDTH*POOL_COMP_CORE  -1 : 0] Ofm         [0 : POOL_CORE-1];
wire [POOL_CORE     -1 : 0] MIFMIC_OfmRdy;
wire [POOL_CORE     -1 : 0] MICMIF_OfmVld;


genvar gv_i;
genvar gv_j;
//=====================================================================================================================
// Logic Design : 
//=====================================================================================================================

generate
    for(gv_i=0; gv_i<POOL_CORE; gv_i=gv_i+1) begin
        wire [$clog2(POOL_CORE) + ACT_WIDTH*POOL_COMP_CORE-1 : 0] MICMIF_Ofm;
        wire [$clog2(POOL_CORE)                           -1 : 0] ArbIdx_MICMIF_OfmVld;

        MIC#(
            .POOL_CORE      ( POOL_CORE ),
            .POOL_COMP_CORE ( POOL_COMP_CORE ),
            .IDX_WIDTH      ( IDX_WIDTH ),
            .ACT_WIDTH      ( ACT_WIDTH )
        )u_MIC(
            .clk            ( clk            ),
            .rst_n          ( rst_n          ),
            .MIFMIC_Rst     ( POLMIF_Rst     ),
            .POLMIF_AddrVld ( POLMIF_AddrVld ),
            .POLMIF_Addr    ( POLMIF_Addr    ),
            .MIFPOL_Rdy     ( MIFPOL_Rdy     ),
            .MIFGLB_AddrVld ( MIFGLB_AddrVld[gv_i] ),
            .MIFGLB_Addr    ( MIFGLB_Addr[IDX_WIDTH*gv_i +: IDX_WIDTH]    ),
            .GLBMIF_AddrRdy ( GLBMIF_AddrRdy[gv_i] ),
            .GLBMIF_Ofm      ( GLBMIF_Ofm[(ACT_WIDTH*POOL_COMP_CORE)*gv_i +: (ACT_WIDTH*POOL_COMP_CORE)]      ),
            .GLBMIF_OfmVld   ( GLBMIF_OfmVld[gv_i]   ),
            .MIFGLB_OfmRdy   ( MIFGLB_OfmRdy[gv_i]   ),
            .MICMIF_Ofm      ( MICMIF_Ofm      ),
            .MICMIF_OfmVld   ( MICMIF_OfmVld[gv_i]   ),
            .MIFMIC_OfmRdy   ( MIFMIC_OfmRdy[gv_i]   )
        );
        assign {PolCoreIdx[gv_i], Ofm[gv_i]} = MICMIF_Ofm;

        //  ==========================
        assign MIFPOL_OfmVld[gv_i] = |MICMIF_OfmVld & ArbIdx_MICMIF_OfmVld ==gv_i;
        assign MIFPOL_Ofm = Ofm[ArbIdx_MICMIF_OfmVld];

        for(gv_j=0; gv_j<POOL_CORE; gv_j=gv_j+1) begin
            assign MIFMIC_OfmRdy[gv_j] = gv_j==ArbIdx_MICMIF_OfmVld ? MIFPOL_OfmRdy[gv_i] : 0;
        end 
        
        prior_arb#(
            .REQ_WIDTH ( POOL_CORE )
        )u_prior_arb_ArbIdx_MICMIF_OfmVld(
            .req ( MICMIF_OfmVld ),
            .gnt (  ),
            .arb_port  ( ArbIdx_MICMIF_OfmVld  )
        );


    end 
endgenerate

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

endmodule
