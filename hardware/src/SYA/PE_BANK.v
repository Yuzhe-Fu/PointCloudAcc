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
module PE_BANK #(
    parameter ACT_WIDTH = 8,
    parameter WGT_WIDTH = 8,
    parameter CHN_WIDTH = 16,
    parameter NUM_ROW   = 16,
    parameter NUM_COL   = 16,
    parameter PSUM_WIDTH = ACT_WIDTH + WGT_WIDTH + CHN_WIDTH
  )(
    input                                       clk,
    input                                       rst_n,

    input  [NUM_COL*NUM_ROW             -1 : 0] En,
    input  [NUM_COL*NUM_ROW             -1 : 0] Reset,

    input  [NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] InAct_W,
    input  [NUM_COL -1 : 0][WGT_WIDTH   -1 : 0] InWgt_N,
    output [NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] OutAct_E,
    output [NUM_COL -1 : 0][WGT_WIDTH   -1 : 0] OutWgt_S,
    output [NUM_ROW -1 : 0][NUM_COL -1 : 0][PSUM_WIDTH   -1 : 0] OutPsum

  );
wire [NUM_ROW -1:0][NUM_COL -1:0][WGT_WIDTH -1 : 0] Bank_OutWgt_S;
wire [NUM_ROW -1:0][NUM_COL -1:0][WGT_WIDTH -1 : 0] Bank_InWgt_N;

assign {OutWgt_S, Bank_InWgt_N}                 = {Bank_OutWgt_S, InWgt_N};

PE_ROW #(
    .ACT_WIDTH       ( ACT_WIDTH ),
    .WGT_WIDTH       ( WGT_WIDTH ),
    .CHN_WIDTH       ( CHN_WIDTH ),
    .NUM_PE          ( NUM_COL   )
)u_PE_ROW [NUM_ROW -1 : 0] (
    .clk       ( clk            ),
    .rst_n     ( rst_n          ),
    .En        ( En             ),
    .Reset     ( Reset          ),
    .InAct_W   ( InAct_W        ),
    .InWgt_N   ( Bank_InWgt_N   ),
    .OutAct_E  ( OutAct_E       ),
    .OutWgt_S  ( Bank_OutWgt_S  ),
    .OutPsum   ( OutPsum        )
);

endmodule
