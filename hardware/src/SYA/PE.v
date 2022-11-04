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
    parameter PSUM_WIDTH = ACT_WIDTH+WGT_WIDTH+10
  )(
    input                            clk,
    input                            rst_n,

    input                            in_vld_left,
    input                            in_rdy_left,

    output [PSUM_WIDTH        -1:0]  out_sum,
    
    input  [ACT_WIDTH         -1:0]  in_act_left, 
    output [ACT_WIDTH         -1:0]  out_act_right,
    
    input  [WGT_WIDTH         -1:0]  in_wgt_above, 
    output [WGT_WIDTH         -1:0]  out_wgt_below,

    input                            in_acc_reset_left,
    output                           out_acc_reset_right

  );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam DMUL_WIDTH = ACT_WIDTH+WGT_WIDTH;

wire [ACT_WIDTH           -1:0] in_act_left_r;
wire [WGT_WIDTH           -1:0] in_wgt_above_r;
wire in_acc_reset_left_r;

wire [DMUL_WIDTH -1:0] out_mul = in_act_left_r*in_wgt_above_r;
reg  [PSUM_WIDTH -1:0] out_acc;

wire in_en_left = in_vld_left && in_rdy_left;

CPM_REG_E #( ACT_WIDTH ) ACT_REG ( clk, rst_n, in_rdy_left, in_act_left , in_act_left_r);
CPM_REG_E #( WGT_WIDTH ) WGT_REG ( clk, rst_n, in_rdy_left, in_wgt_above, in_wgt_above_r);
CPM_REG_E #( 1         ) RST_REG ( clk, rst_n, in_rdy_left, in_acc_reset_left, in_acc_reset_left_r);

always @ ( posedge clk or negedge rst_n )begin
  if( ~rst_n )
    out_acc <= 'd0;
  else if( in_en_left )
    out_acc <= in_acc_reset_left ? {{(PSUM_WIDTH-DMUL_WIDTH){out_mul[DMUL_WIDTH-1]}},out_mul} : out_acc + out_mul;
end

assign out_sum = out_acc;
assign out_act_right = in_act_left_r;
assign out_wgt_below = in_wgt_above_r;
assign out_acc_reset_right = in_acc_reset_left_r;

endmodule