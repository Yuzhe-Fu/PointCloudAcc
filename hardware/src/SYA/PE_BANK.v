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
    parameter NUM_ROW    = 16,
    parameter NUM_COL    = 16,
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

    output [FM_WIDTH*NUM_ROW  -1:0]  out_fm,
    
    input  [ACT_WIDTH*NUM_ROW -1:0]  in_act_left, 
    output [ACT_WIDTH*NUM_ROW -1:0]  out_act_right,
    
    input  [WGT_WIDTH*NUM_COL -1:0]  in_wgt_above, 
    output [WGT_WIDTH*NUM_COL -1:0]  out_wgt_below,

    input                            in_acc_reset_left,
    output                           out_acc_reset_below,
    output                           out_acc_reset_right

  );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam DMUL_WIDTH = ACT_WIDTH*WGT_WIDTH;

wire [NUM_ROW -1:0][FM_WIDTH   -1:0] row_out_fm;

wire [NUM_ROW -1:0][ACT_WIDTH  -1:0] row_out_act;
wire [NUM_ROW -1:0][ACT_WIDTH  -1:0] row_din_act = in_act_left;

wire [NUM_ROW -1:0][NUM_COL -1:0][WGT_WIDTH  -1:0] row_out_wgt;
wire [NUM_ROW -1:0][NUM_COL -1:0][WGT_WIDTH  -1:0] row_din_wgt = {row_out_wgt[NUM_ROW -2:0], in_wgt_above};

reg  [NUM_ROW -1:0] row_din_vld;
wire [NUM_ROW -1:0] row_din_rdy = {NUM_ROW{in_rdy_left}};

wire [NUM_ROW -1:0] row_out_acc_reset;
reg  [NUM_ROW -1:0] row_din_acc_reset;

always @ ( posedge clk or negedge rst_n )begin
  if( ~rst_n )
    row_din_acc_reset <= 'd0;
  else if( in_rdy_left )
    row_din_acc_reset <= {row_din_acc_reset[NUM_ROW-2:0], in_acc_reset_left};
end

always @ ( posedge clk or negedge rst_n )begin
if( ~rst_n )
  row_din_vld <= 'd0;
else if( in_rdy_left )
  row_din_vld <= {row_din_vld[NUM_ROW -2:0], in_vld_left};
end

    PE_ROW #(
      .NUM_PE               ( NUM_COL           ),
      .QNT_WIDTH            ( QNT_WIDTH         ),
      .ACT_WIDTH            ( ACT_WIDTH         ),
      .WGT_WIDTH            ( WGT_WIDTH         ),
      .PSUM_WIDTH           ( PSUM_WIDTH        ),
      .FM_WIDTH             ( FM_WIDTH          )
    ) PE_ROW_U_I [NUM_ROW -1:0](
    
      .clk                  ( clk               ),
      .rst_n                ( rst_n             ),
                            
      .quant_scale          ( quant_scale       ),
      .quant_shift          ( quant_shift       ),
      .quant_zero_point     ( quant_zero_point  ),
                            
      .in_vld_left          ( row_din_vld       ),
      .in_rdy_left          ( row_din_rdy       ),
      
      .out_fm               ( row_out_fm        ),
                            
      .in_act_left          ( row_din_act       ),
      .out_act_right        ( row_out_act       ),
                            
      .in_wgt_above         ( row_din_wgt       ),
      .out_wgt_below        ( row_out_wgt       ),
                            
      .in_acc_reset_left    ( row_din_acc_reset ),
      .out_acc_reset_right  ( row_out_acc_reset )
    );

assign out_act_right = row_out_act;
assign out_wgt_below = row_out_wgt[NUM_ROW -1];
assign out_acc_reset_right = row_out_acc_reset[0];
assign out_acc_reset_below = row_din_acc_reset[NUM_ROW-1];
assign out_fm = row_out_fm;

endmodule