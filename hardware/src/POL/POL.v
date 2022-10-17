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

module POL #(
    parameter IDX_WIDTH             = 10,
    parameter ACT_WIDTH             = 8,
    parameter POOL_COMP_CORE        = 64,
    parameter POOL_MAP_DEPTH_WIDTH  = 5,
    parameter POOL_CORE             = 6,
    parameter CHN_WIDTH             = 12,
    parameter SRAM_WIDTH            = 256
    )(
    input                               clk                     ,
    input                               rst_n                   ,

    // Configure
    input                                                   CCUPOL_Rst,
    input                                                   CCUPOL_CfgVld,
    output                                                  POLCCU_CfgRdy,
    input  [POOL_MAP_DEPTH_WIDTH                    -1 : 0] CCUPOL_CfgK  , // 24
    input  [IDX_WIDTH                               -1 : 0] CCUPOL_CfgNip, // 1024
    input  [CHN_WIDTH                               -1 : 0] CCUPOL_CfgChi, // 64
    input                                                   GLBPOL_MapVld ,
    input  [SRAM_WIDTH                              -1 : 0] GLBPOL_Map    ,
    output                                                  POLGLB_MapRdy ,
    output [POOL_CORE                               -1 : 0] POLGLB_AddrVld,
    output [IDX_WIDTH*POOL_CORE                     -1 : 0] POLGLB_Addr  ,
    input  [POOL_CORE                               -1 : 0] GLBPOL_AddrRdy,
    input  [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE    -1 : 0] GLBPOL_Ofm     ,
    input  [POOL_CORE                               -1 : 0] GLBPOL_OfmVld   ,
    output [POOL_CORE                               -1 : 0] POLGLB_OfmRdy  ,
    output reg[(ACT_WIDTH*POOL_COMP_CORE)           -1 : 0] POLGLB_Ofm     ,
    output reg                                              POLGLB_OfmVld  ,
    input                                                   GLBPOL_OfmRdy   
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [POOL_CORE                             -1 : 0] PLCPOL_IdxRdy;
wire [POOL_CORE                             -1 : 0] PLCPOL_AddrVld;
wire [IDX_WIDTH*POOL_CORE                   -1 : 0] PLCPOL_Addr;
wire [POOL_CORE                             -1 : 0] POLPLC_AddrRdy;
wire [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE  -1 : 0] POLPLC_Ofm;
wire [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE  -1 : 0] PLCPOL_Ofm;

wire [POOL_CORE                             -1 : 0] POLPLC_OfmVld;
wire [POOL_CORE                             -1 : 0] PLCPOL_OfmRdy;

wire [POOL_CORE                             -1 : 0] PLCPOL_OfmVld;
reg [POOL_CORE                              -1 : 0] POLPLC_OfmRdy;


//=====================================================================================================================
// Logic Design 
//=====================================================================================================================


genvar i;
generate
    for(i=0; i<POOL_CORE; i=i+1) begin
        wire POLPLC_IdxVld;
        wire [IDX_WIDTH     -1 : 0] POLPLC_Idx;


        PLC#(
            .IDX_WIDTH      ( IDX_WIDTH ),
            .ACT_WIDTH      ( ACT_WIDTH ),
            .POOL_COMP_CORE ( POOL_COMP_CORE ),
            .POOL_MAP_DEPTH_WIDTH ( POOL_MAP_DEPTH_WIDTH )
        )u_PLC(
            .clk            ( clk            ),
            .rst_n          ( rst_n          ),
            .POLPLC_CfgK    ( CCUPOL_CfgK    ),
            .POLPLC_IdxVld  ( POLPLC_IdxVld  ),
            .POLPLC_Idx     ( POLPLC_Idx     ),
            .PLCPOL_IdxRdy  ( PLCPOL_IdxRdy[i]  ),
            .PLCPOL_AddrVld ( PLCPOL_AddrVld[i] ),
            .PLCPOL_Addr    ( PLCPOL_Addr[IDX_WIDTH*i +: IDX_WIDTH]    ),
            .POLPLC_AddrRdy ( POLPLC_AddrRdy[i] ),
            .POLPLC_Ofm      ( POLPLC_Ofm[(ACT_WIDTH*POOL_COMP_CORE)*i +: ACT_WIDTH*POOL_COMP_CORE]      ),
            .POLPLC_OfmVld   ( POLPLC_OfmVld[i]   ),
            .PLCPOL_OfmRdy   ( PLCPOL_OfmRdy[i]   ),
            .PLCPOL_Ofm      ( PLCPOL_Ofm [(ACT_WIDTH*POOL_COMP_CORE)*i +: ACT_WIDTH*POOL_COMP_CORE]     ),
            .PLCPOL_OfmVld   ( PLCPOL_OfmVld[i]   ),
            .POLPLC_OfmRdy   ( POLPLC_OfmRdy[i]   ) 
        );
        assign POLPLC_Idx = GLBPOL_Map[IDX_WIDTH*i +: IDX_WIDTH];
        assign POLPLC_IdxVld = GLBPOL_MapVld;
    end
endgenerate

assign POLGLB_MapRdy = &PLCPOL_IdxRdy;

integer  j;
always @(*) begin
    POLGLB_Ofm = 0;
    POLGLB_OfmVld = 0;
    POLPLC_OfmRdy = 0;
    for(j=0; j<POOL_CORE; j=j+1) begin
        if(PLCPOL_OfmVld[j]) begin
            POLGLB_Ofm = PLCPOL_Ofm[(ACT_WIDTH*POOL_COMP_CORE)*j +: ACT_WIDTH*POOL_COMP_CORE];
            POLGLB_OfmVld = 1'b1;
            POLPLC_OfmRdy[j] = GLBPOL_OfmRdy;
        end
    end
end


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================
MIF#(
    .POOL_CORE      ( POOL_CORE ),
    .POOL_COMP_CORE ( POOL_COMP_CORE ),
    .IDX_WIDTH      ( IDX_WIDTH ),
    .ACT_WIDTH      ( ACT_WIDTH )
)u_MIF(
    .clk            ( clk            ),
    .rst_n          ( rst_n          ),
    .POLMIF_AddrVld ( PLCPOL_AddrVld ),
    .POLMIF_Addr    ( PLCPOL_Addr    ),
    .MIFPOL_Rdy     ( POLPLC_AddrRdy ),
    .MIFGLB_AddrVld ( POLGLB_AddrVld ),
    .MIFGLB_Addr    ( POLGLB_Addr    ),
    .GLBMIF_AddrRdy ( GLBPOL_AddrRdy ),
    .GLBMIF_Ofm      ( GLBPOL_Ofm      ),
    .GLBMIF_OfmVld   ( GLBPOL_OfmVld   ),
    .MIFGLB_OfmRdy   ( POLGLB_OfmRdy   ),
    .MIFPOL_Ofm      ( POLPLC_Ofm      ),
    .MIFPOL_OfmVld   ( POLPLC_OfmVld   ),
    .MIFPOL_OfmRdy   ( PLCPOL_OfmRdy   )
);



endmodule
