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
    parameter NUM_PE     = 16,
    parameter QNT_WIDTH  = 20,
    parameter ACT_WIDTH  = 8,
    parameter WGT_WIDTH  = 8,
    parameter PSUM_WIDTH = ACT_WIDTH+WGT_WIDTH+10,
    parameter FM_WIDTH   = ACT_WIDTH
  )(
    input                            clk,
    input                            rst_n,
    
    input  [QNT_WIDTH          -1:0] quant_scale,
    input  [ACT_WIDTH          -1:0] quant_shift,
    input  [ACT_WIDTH          -1:0] quant_zero_point,

    input                            in_vld_left,
    input                            in_rdy_left,

    output [FM_WIDTH           -1:0] out_fm,
    
    input  [ACT_WIDTH          -1:0] in_act_left,
    output [ACT_WIDTH          -1:0] out_act_right,
    
    input  [WGT_WIDTH*NUM_PE   -1:0] in_wgt_above,
    output [WGT_WIDTH*NUM_PE   -1:0] out_wgt_below,

    input                            in_acc_reset_left,
    output                           out_acc_reset_right

  );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam DMUL_WIDTH = ACT_WIDTH*WGT_WIDTH;

wire [NUM_PE -1:0][PSUM_WIDTH -1:0] row_out_sum;
reg  [PSUM_WIDTH -1:0] out_sum_pick;
wire [PSUM_WIDTH -1:0] out_sum_reg0;
wire [FM_WIDTH   -1:0] out_sum_qnt8 = (out_sum_reg0*quant_scale)>>quant_shift +quant_zero_point;
wire [FM_WIDTH   -1:0] out_sum_reg1;

wire [NUM_PE -1:0][ACT_WIDTH  -1:0] row_out_act;
wire [NUM_PE -1:0][ACT_WIDTH  -1:0] row_din_act = {row_out_act[NUM_PE-1:1], in_act_left};
reg  [NUM_PE -1:0] row_din_vld;
wire [NUM_PE -1:0] row_din_ena = row_din_vld & {NUM_PE{in_rdy_left}};

wire [NUM_PE -1:0][WGT_WIDTH  -1:0] row_din_wgt = in_wgt_above;
wire [NUM_PE -1:0][WGT_WIDTH  -1:0] row_out_wgt;

wire [NUM_PE -1:0] row_out_acc_reset;
wire [NUM_PE -1:0] row_din_acc_reset = {row_out_acc_reset[NUM_PE-1:1], in_acc_reset_left};

integer i;
always @ ( * )begin
  out_sum_pick = 'd0;
  for( i = 0; i < NUM_PE; i = i + 1 )begin
    if( row_din_acc_reset[i] )
      out_sum_pick = row_out_sum[i];
  end
end

always @ ( posedge clk or negedge rst_n )begin
if( ~rst_n )
  row_din_vld <= 'd0;
else if( in_rdy_left )
  row_din_vld <= {row_din_vld[NUM_PE -2:0], in_vld_left};
end

CPM_REG_E #( PSUM_WIDTH ) OUT_REG0 ( clk, rst_n, in_rdy_left, out_sum_pick, out_sum_reg0);
CPM_REG_E #( FM_WIDTH   ) OUT_REG1 ( clk, rst_n, in_rdy_left, out_sum_qnt8, out_sum_reg1);


    PE #(
      .ACT_WIDTH           ( ACT_WIDTH         ),
      .WGT_WIDTH           ( WGT_WIDTH         ),
      .PSUM_WIDTH          ( PSUM_WIDTH        )
    ) PE_U_I [NUM_PE -1:0](  
                           
      .clk                 ( clk               ),
      .rst_n               ( rst_n             ),
                                              
      .in_en_left          ( row_din_ena       ),
      .out_sum             ( row_out_sum       ),
                                              
      .in_act_left         ( row_din_act       ),
      .out_act_right       ( row_out_act       ),
                                              
      .in_wgt_above        ( row_din_wgt       ),
      .out_wgt_below       ( row_out_wgt       ),
                           
      .in_acc_reset_left   ( row_din_acc_reset ),
      .out_acc_reset_right ( row_out_acc_reset )
    );

assign out_fm = out_sum_reg1;
assign out_act_right = row_out_act[NUM_PE -1];
assign out_wgt_below = row_out_wgt;
assign out_acc_reset_right = row_out_acc_reset[NUM_PE -1];

endmodule