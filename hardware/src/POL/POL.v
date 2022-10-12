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
    output                                                  POLGLB_AddrVld,
    output [IDX_WIDTH                               -1 : 0] POLGLB_Addr  ,
    input                                                   GLBPOL_AddrRdy,
    input  [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE    -1 : 0] GLBPOL_Fm     ,
    input                                                   GLBPOL_FmVld   ,
    output                                                  POLGLB_FmRdy  ,
    output reg[(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE -1 : 0] POLGLB_Fm     ,
    output reg                                              POLGLB_FmVld  ,
    input                                                   GLBPOL_FmRdy   
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
wire [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE  -1 : 0] POLPLC_Fm;
wire [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE  -1 : 0] PLCPOL_Fm;

wire [POOL_CORE                             -1 : 0] POLPLC_FmVld;
wire [POOL_CORE                             -1 : 0] PLCPOL_FmRdy;

wire [POOL_CORE                             -1 : 0] PLCPOL_FmVld;
reg [POOL_CORE                              -1 : 0] POLPLC_FmRdy;


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
            .POLPLC_Fm      ( POLPLC_Fm[(ACT_WIDTH*POOL_COMP_CORE)*i +: ACT_WIDTH*POOL_COMP_CORE]      ),
            .POLPLC_FmVld   ( POLPLC_FmVld[i]   ),
            .PLCPOL_FmRdy   ( PLCPOL_FmRdy[i]   ),
            .PLCPOL_Fm      ( PLCPOL_Fm [(ACT_WIDTH*POOL_COMP_CORE)*i +: ACT_WIDTH*POOL_COMP_CORE]     ),
            .PLCPOL_FmVld   ( PLCPOL_FmVld[i]   ),
            .POLPLC_FmRdy   ( POLPLC_FmRdy[i]   ) 
        );
        assign POLPLC_Idx = GLBPOL_Map[IDX_WIDTH*i +: IDX_WIDTH];
        assign POLPLC_IdxVld = GLBPOL_MapVld;
    end
endgenerate

assign POLGLB_MapRdy = &PLCPOL_IdxRdy;

integer  j;
always @(*) begin
    POLGLB_Fm = 0;
    POLGLB_FmVld = 0;
    POLPLC_FmRdy = 0;
    for(j=0; j<POOL_CORE; j=j+1) begin
        if(PLCPOL_FmVld[j]) begin
            POLGLB_Fm = PLCPOL_Fm[(ACT_WIDTH*POOL_COMP_CORE)*j +: ACT_WIDTH*POOL_COMP_CORE];
            POLGLB_FmVld = 1'b1;
            POLPLC_FmRdy[j] = GLBPOL_FmRdy;
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
    .GLBMIF_Fm      ( GLBPOL_Fm      ),
    .GLBMIF_FmVld   ( GLBPOL_FmVld   ),
    .MIFGLB_FmRdy   ( POLGLB_FmRdy   ),
    .MIFPOL_Fm      ( POLPLC_Fm      ),
    .MIFPOL_FmVld   ( POLPLC_FmVld   ),
    .MIFPOL_FmRdy   ( PLCPOL_FmRdy   )
);



endmodule
