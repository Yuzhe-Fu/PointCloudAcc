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
    output reg [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE-1 : 0] MIFPOL_Ofm     ,
    output reg [POOL_CORE                           -1 : 0] MIFPOL_OfmVld  ,
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
reg [POOL_CORE     -1 : 0] MIFMIC_OfmRdy;
wire [POOL_CORE     -1 : 0] MICMIF_OfmVld;

integer j;

genvar i;

//=====================================================================================================================
// Logic Design : 
//=====================================================================================================================

generate
    for(i=0; i<POOL_CORE; i=i+1) begin
        wire [$clog2(POOL_CORE) + ACT_WIDTH*POOL_COMP_CORE-1 : 0] MICMIF_Ofm;
        MIC#(
            .POOL_CORE      ( POOL_CORE ),
            .POOL_COMP_CORE ( POOL_COMP_CORE ),
            .IDX_WIDTH      ( IDX_WIDTH ),
            .ACT_WIDTH      ( ACT_WIDTH )
        )u_MIFC(
            .clk            ( clk            ),
            .rst_n          ( rst_n          ),
            .POLMIF_AddrVld ( POLMIF_AddrVld ),
            .POLMIF_Addr    ( POLMIF_Addr    ),
            .MIFPOL_Rdy     ( MIFPOL_Rdy     ),
            .MIFGLB_AddrVld ( MIFGLB_AddrVld[i] ),
            .MIFGLB_Addr    ( MIFGLB_Addr[IDX_WIDTH*i +: IDX_WIDTH]    ),
            .GLBMIF_AddrRdy ( GLBMIF_AddrRdy[i] ),
            .GLBMIF_Ofm      ( GLBMIF_Ofm[(ACT_WIDTH*POOL_COMP_CORE)*i +: (ACT_WIDTH*POOL_COMP_CORE)]      ),
            .GLBMIF_OfmVld   ( GLBMIF_OfmVld[i]   ),
            .MIFGLB_OfmRdy   ( MIFGLB_OfmRdy[i]   ),
            .MICMIF_Ofm      ( MICMIF_Ofm      ),
            .MICMIF_OfmVld   ( MICMIF_OfmVld[i]   ),
            .MIFMIC_OfmRdy   ( MIFMIC_OfmRdy[i]   )
        );
        assign {PolCoreIdx[i], Ofm[i]} = MICMIF_Ofm;

        //  ==========================
        always @(*) begin
            MIFPOL_Ofm[(ACT_WIDTH*POOL_COMP_CORE)*i +: (ACT_WIDTH*POOL_COMP_CORE)] = 0;
            MIFPOL_OfmVld[i] = 0;
            for(j=0; j<POOL_CORE; j=j+1) begin // Loop MIFC
                if(PolCoreIdx[j]==i & MICMIF_OfmVld[j]) begin
                    MIFPOL_Ofm[i] = Ofm[j];
                    MIFPOL_OfmVld[i] = 1'b1;
                    MIFMIC_OfmRdy[j] = MIFPOL_OfmRdy[i]; // ?????????????????????????????????????????????????????
                end
            end
        end

    end 
endgenerate

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

endmodule
