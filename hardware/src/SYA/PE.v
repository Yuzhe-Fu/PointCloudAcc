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
module PE #(
    parameter ACT_WIDTH = 8,
    parameter WGT_WIDTH = 8,
    parameter CHN_WIDTH = 16,
    parameter PSUM_WIDTH = ACT_WIDTH + WGT_WIDTH + CHN_WIDTH
  )(
    input                           clk,
    input                           rst_n,

    input                           En,
    input                           Reset,

    input [ACT_WIDTH        -1 : 0] InAct_W,
    input [WGT_WIDTH        -1 : 0] InWgt_N,

    output reg[ACT_WIDTH    -1 : 0] OutAct_E,
    output reg [WGT_WIDTH   -1 : 0] OutWgt_S,

    output reg signed [PSUM_WIDTH  -1 : 0] OutPsum

  );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
wire signed [PSUM_WIDTH     -1 : 0] Signed_Mul = $signed(InAct_W) * $signed(InWgt_N);

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        {OutPsum, OutWgt_S, OutAct_E} <= 0;
    end else if(En) begin
        {OutPsum, OutWgt_S, OutAct_E} <= {
            Reset? Signed_Mul : OutPsum + Signed_Mul, InWgt_N, InAct_W};
    end
end

endmodule