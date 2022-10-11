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
    input  [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE    -1 : 0] GLBMIF_Fm     ,
    input  [POOL_CORE                               -1 : 0] GLBMIF_FmVld  ,
    output [POOL_CORE                               -1 : 0] MIFGLB_FmRdy  ,
    output reg [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE-1 : 0] MIFPOL_Fm     ,
    output reg [POOL_CORE                           -1 : 0] MIFPOL_FmVld  ,
    input  [POOL_CORE                               -1 : 0] MIFPOL_FmRdy   

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

wire [$clog2(POOL_CORE)         -1 : 0] PolCoreIdx  [0 : POOL_CORE-1];
wire [ACT_WIDTH*POOL_COMP_CORE  -1 : 0] Ofm         [0 : POOL_CORE-1];
reg [POOL_CORE     -1 : 0] MIFMIFC_FmRdy
wire [POOL_CORE     -1 : 0] MIFCMIF_FmVld;

integer j;

genvar i;

//=====================================================================================================================
// Logic Design : 
//=====================================================================================================================

generate
    for(i=0; i<POOL_CORE; i=i+1) begin
        wire [$clog2(POOL_CORE) + ACT_WIDTH*POOL_COMP_CORE-1 : 0] MIFCMIF_Fm;
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
            .GLBMIF_Fm      ( GLBMIF_Fm[(ACT_WIDTH*POOL_COMP_CORE)*i +: (ACT_WIDTH*POOL_COMP_CORE)]      ),
            .GLBMIF_FmVld   ( GLBMIF_FmVld[i]   ),
            .MIFGLB_FmRdy   ( MIFGLB_FmRdy[i]   ),
            .MIFCMIF_Fm      ( MIFCMIF_Fm      ),
            .MIFCMIF_FmVld   ( MIFCMIF_FmVld[j]   ),
            .MIFMIFC_FmRdy   ( MIFMIFC_FmRdy[j]   )
        );
        assign {PolCoreIdx[i], Ofm[i]} = MIFCMIF_Fm;

        //  ==========================
        always @(*) begin
            MIFPOL_Fm[(ACT_WIDTH*POOL_COMP_CORE)*i +: (ACT_WIDTH*POOL_COMP_CORE)] = 0;
            MIFPOL_FmVld[i] = 0;
            for(j=0; j<POOL_CORE; j=j+1) begin // Loop MIFC
                if(PolCoreIdx[j]=i & MIFCMIF_FmVld[j]) begin
                    MIFPOL_Fm[i] = Ofm[j];
                    MIFPOL_FmVld[i] = 1'b1;
                    MIFMIFC_FmRdy[j] = MIFPOL_FmRdy[i]; // ?????????????????????????????????????????????????????
                end
            end
        end

    end 
endgenerate

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

endmodule
