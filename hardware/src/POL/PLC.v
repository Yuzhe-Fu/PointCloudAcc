
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
// `include "../source/include/dw_params_presim.vh"
module PLC #(
    parameter IDX_WIDTH             = 10,
    parameter ACT_WIDTH             = 8,
    parameter POOL_COMP_CORE        = 64,
    parameter POOL_MAP_DEPTH_WIDTH  = 5
    )(
    input                                       clk           ,
    input                                       rst_n         ,

    input                                       POLPLC_Rst    ,
    input       [POOL_MAP_DEPTH_WIDTH   -1 : 0] POLPLC_CfgK   ,
    input                                       POLPLC_IdxVld ,
    input       [IDX_WIDTH              -1 : 0] POLPLC_Idx    ,
    output                                      PLCPOL_IdxRdy ,
    output                                      PLCPOL_AddrVld,
    output      [IDX_WIDTH              -1 : 0] PLCPOL_Addr   ,
    input                                       POLPLC_AddrRdy,

    input       [ACT_WIDTH*POOL_COMP_CORE-1 : 0]POLPLC_Ofm     ,
    input                                       POLPLC_OfmVld  ,
    output                                      PLCPOL_OfmRdy  ,
    output      [ACT_WIDTH*POOL_COMP_CORE-1 : 0]PLCPOL_Ofm   ,
    output                                      PLCPOL_OfmVld,
    input                                       POLPLC_OfmRdy

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                                CpOfmInLast;
wire                                overflow;
wire                                inc_addr;
wire                                clear_addr;
wire                                empty;
wire                                full;
wire [POOL_MAP_DEPTH_WIDTH  -1 : 0] MAX_COUNT;

//=====================================================================================================================
// Logic Design 2: Addr Gen.
//=====================================================================================================================

assign CpOfmInLast  = overflow; //
assign inc_addr   = POLPLC_OfmVld & POLPLC_OfmRdy;

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

PCC#(
    .NUM_MAX    ( POOL_COMP_CORE),
    .DATA_WIDTH ( ACT_WIDTH     )
)U1_PLCC(
    .clk       ( clk            ),
    .rst_n     ( rst_n          ),
    .Rst       ( POLPLC_Rst            ),
    .DatInVld  ( POLPLC_OfmVld  ),
    .DatInLast ( CpOfmInLast    ),
    .DatIn     ( POLPLC_Ofm      ),
    .DatInRdy  ( PLCPOL_OfmRdy   ),
    .DatOutVld ( PLCPOL_OfmVld   ),
    .DatOut    ( PLCPOL_Ofm      ),
    .DatOutRdy ( POLPLC_OfmRdy   )
);

assign MAX_COUNT = POLPLC_CfgK-1;

counter#(
    .COUNT_WIDTH ( POOL_MAP_DEPTH_WIDTH )
)u_counter(
    .CLK       ( clk        ),
    .RESET_N   ( rst_n      ),
    .CLEAR     ( POLPLC_Rst ),
    .DEFAULT   ( {POOL_MAP_DEPTH_WIDTH{1'b0}} ),
    .INC       ( inc_addr   ),
    .DEC       ( 1'b0       ),
    .MIN_COUNT ( {POOL_MAP_DEPTH_WIDTH{1'b0}} ),
    .MAX_COUNT ( MAX_COUNT  ),
    .OVERFLOW  ( overflow   ),
    .UNDERFLOW (            ),
    .COUNT     (            )
);

FIFO_FWFT#(
    .INIT       ( "init.mif" ),
    .DATA_WIDTH ( IDX_WIDTH ),
    .ADDR_WIDTH ( POOL_MAP_DEPTH_WIDTH ),
    .INITIALIZE_FIFO ( "no" )
)u_FIFO_FWFT(
    .clk        ( clk                           ),
    .Reset      ( POLPLC_Rst                    ),
    .rst_n      ( rst_n                         ),
    .push       ( POLPLC_IdxVld &  PLCPOL_IdxRdy),
    .pop        ( PLCPOL_AddrVld & POLPLC_AddrRdy),
    .data_in    ( POLPLC_Idx                    ),
    .data_out   ( PLCPOL_Addr                   ),
    .empty      ( empty                         ),
    .full       ( full                          ),
    .fifo_count (                               )
);
assign PLCPOL_AddrVld = !empty;
assign PLCPOL_IdxRdy  = !full;


endmodule
