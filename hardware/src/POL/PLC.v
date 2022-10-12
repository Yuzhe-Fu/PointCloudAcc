
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

    input       [POOL_MAP_DEPTH_WIDTH   -1 : 0] POLPLC_CfgK             ,
    input                                       POLPLC_IdxVld ,
    input       [IDX_WIDTH              -1 : 0] POLPLC_Idx    ,
    output                                      PLCPOL_IdxRdy ,
    output                                      PLCPOL_AddrVld,
    output      [IDX_WIDTH              -1 : 0] PLCPOL_Addr   ,
    input                                       POLPLC_AddrRdy,

    input       [ACT_WIDTH*POOL_COMP_CORE-1 : 0]POLPLC_Fm     ,
    input                                       POLPLC_FmVld  ,
    output                                      PLCPOL_FmRdy  ,
    output      [ACT_WIDTH*POOL_COMP_CORE-1 : 0]PLCPOL_Fm   ,
    output                                      PLCPOL_FmVld,
    input                                       POLPLC_FmRdy

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire DatInLast;
wire overflow, inc_addr, clear_addr;
wire empty, full;

//=====================================================================================================================
// Logic Design 2: Addr Gen.
//=====================================================================================================================

assign DatInLast  = overflow; // & &
assign inc_addr   = POLPLC_AddrRdy & PLCPOL_AddrVld;
assign clear_addr = PLCPOL_FmVld  & POLPLC_FmRdy ;

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

PCC#(
    .NUM_MAX    ( POOL_COMP_CORE),
    .DATA_WIDTH ( ACT_WIDTH     )
)U1_PLCC(
    .clk       ( clk            ),
    .rst_n     ( rst_n          ),
    .DatInVld  ( POLPLC_FmVld   ),
    .DatInLast ( DatInLast      ),
    .DatIn     ( POLPLC_Fm      ),
    .DatInRdy  ( PLCPOL_FmRdy   ),
    .DatOutVld ( PLCPOL_FmVld   ),
    .DatOut    ( PLCPOL_Fm      ),
    .DatOutRdy (POLPLC_FmRdy    )
);

counter#(
    .COUNT_WIDTH ( POOL_MAP_DEPTH_WIDTH )
)u_counter(
    .CLK       ( clk        ),
    .RESET_N   ( rst_n      ),
    .CLEAR     ( clear_addr ),
    .DEFAULT   ( 0          ),
    .INC       ( inc_addr   ),
    .DEC       ( 1'b0       ),
    .MIN_COUNT ( 0          ),
    .MAX_COUNT ( POLPLC_CfgK-1        ),
    .OVERFLOW  ( overflow   ),
    .UNDERFLOW (            ),
    .COUNT     (            )
);

FIFO_FWFT#(
    .INIT       ( "init.mif" ),
    .DATA_WIDTH ( IDX_WIDTH ),
    .ADDR_WIDTH ( POOL_MAP_DEPTH_WIDTH ),
    .INITIALIZE_FIFO ( "no" )
)U_FIFO_FWFT(
    .clk        ( clk                           ),
    .Reset      ( 1'b0                          ),
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
