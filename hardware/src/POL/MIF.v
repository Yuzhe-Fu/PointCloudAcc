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
    input  [IDX_WIDTH*POOL_CORE                     -1 : 0] CCUMIF_AddrMin,
    input  [IDX_WIDTH*POOL_CORE                     -1 : 0] CCUMIF_AddrMax,// Not Included
    // Configure
    input  [POOL_CORE                               -1 : 0] POLMIF_AddrVld,
    input  [IDX_WIDTH*POOL_CORE                     -1 : 0] POLMIF_Addr   ,
    output reg [POOL_CORE                           -1 : 0] MIFPOL_Rdy    ,
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
reg  [POOL_CORE     -1 : 0] MIFMIC_OfmRdy;
wire [POOL_CORE     -1 : 0] MICMIF_OfmVld;
wire [POOL_CORE     -1 : 0] MICMIF_AddrRdy[0 : POOL_CORE -1];
reg [POOL_CORE          -1 : 0] match [0 : POOL_CORE -1];
wire[POOL_CORE          -1 : 0] arbreq[0 : POOL_CORE -1];
wire[$clog2(POOL_CORE)  -1 : 0] PLCArbMICIdx[0 : POOL_CORE -1];

genvar gv_i;
genvar gv_j;
integer int_i;
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
            .CCUMIC_AddrMin ( CCUMIF_AddrMin[IDX_WIDTH*gv_i +: IDX_WIDTH] ),
            .CCUMIC_AddrMax ( CCUMIF_AddrMax[IDX_WIDTH*gv_i +: IDX_WIDTH] ),
            .POLMIC_AddrVld ( POLMIF_AddrVld ),
            .POLMIC_Addr    ( POLMIF_Addr    ),
            .MICMIF_Rdy     ( MICMIF_AddrRdy[gv_i]     ),
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

    end 
endgenerate

always @(*) begin
    MIFPOL_Rdy = 0;
    for(int_i=0; int_i <POOL_CORE; int_i=int_i+1) begin
        MIFPOL_Rdy = MIFPOL_Rdy | (POLMIF_AddrVld & MICMIF_AddrRdy[int_i]);
    end
end


generate
    for(gv_i=0; gv_i<POOL_CORE; gv_i=gv_i + 1) begin
        always @(*) begin
            match[gv_i] = 0;
            for(int_i=0; int_i<POOL_CORE; int_i=int_i+1) begin
                if(PolCoreIdx[int_i]==gv_i) begin
                    match[gv_i][int_i] = 1'b1;
                end 
            end 
        end
        assign arbreq[gv_i] = match[gv_i] & MICMIF_OfmVld;
        prior_arb#(
            .REQ_WIDTH ( POOL_CORE )
        )u_prior_arb_PLCArbMICIdx(
            .req ( arbreq[gv_i] ),
            .gnt (  ),
            .arb_port  ( PLCArbMICIdx[gv_i]  )
        );

        always @(*) begin
            MIFMIC_OfmRdy[gv_i] = 0;
            for(int_i=0; int_i<POOL_CORE; int_i=int_i+1) begin
                if(PLCArbMICIdx[int_i] == gv_i & |arbreq[int_i]) begin
                    MIFMIC_OfmRdy[gv_i] = MIFPOL_OfmRdy[int_i];
                end 
            end 
        end

        assign MIFPOL_OfmVld[gv_i] = |arbreq[gv_i];
        assign MIFPOL_Ofm[(ACT_WIDTH*POOL_COMP_CORE)*gv_i +: (ACT_WIDTH*POOL_COMP_CORE)] = Ofm[PLCArbMICIdx[gv_i]];

    end
endgenerate


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================




endmodule
