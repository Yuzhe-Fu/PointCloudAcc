//======================================================
// Copyright (C) 2020 By 
// All Rights Reserved
//======================================================
// Module : 
// Author : 
// Contact : 
// Date : 
//=======================================================
// Description :
//========================================================
module PE_ROW #(
    parameter ACT_WIDTH = 8,
    parameter WGT_WIDTH = 8,
    parameter CHN_WIDTH = 16,
    parameter NUM_PE    = 16,
    parameter PSUM_WIDTH = ACT_WIDTH + WGT_WIDTH + CHN_WIDTH
  )(
    input                           clk,
    input                           rst_n,

    input  [NUM_PE          -1 : 0] En,
    input  [NUM_PE          -1 : 0] Reset,

    input  [ACT_WIDTH       -1 : 0] InAct_W,
    input  [WGT_WIDTH*NUM_PE-1 : 0] InWgt_N,
    output [ACT_WIDTH       -1 : 0] OutAct_E,
    output [WGT_WIDTH*NUM_PE-1 : 0] OutWgt_S,
    output [PSUM_WIDTH*NUM_PE-1: 0] OutPsum

  );

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
wire [NUM_PE -1 : 0][ACT_WIDTH  -1 : 0] ROW_OutAct_E;
wire [NUM_PE -1 : 0][ACT_WIDTH  -1 : 0] ROW_InAct_W;

assign {OutAct_E, ROW_InAct_W}              = {ROW_OutAct_E, InAct_W};
PE #(
    .ACT_WIDTH       ( ACT_WIDTH ),
    .WGT_WIDTH       ( WGT_WIDTH ),
    .CHN_WIDTH       ( CHN_WIDTH )
)u_PE [NUM_PE -1 : 0] (
    .clk       ( clk            ),
    .rst_n     ( rst_n          ),
    .En        ( En             ),
    .Reset     ( Reset          ),
    .InAct_W   ( ROW_InAct_W    ),
    .InWgt_N   ( InWgt_N        ),
    .OutAct_E  ( ROW_OutAct_E   ),
    .OutWgt_S  ( OutWgt_S       ),
    .OutPsum   ( OutPsum        )
);

endmodule