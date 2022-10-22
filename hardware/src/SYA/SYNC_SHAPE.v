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
module SYNC_SHAPE #(
    parameter ACT_WIDTH  = 8,
    parameter SRAM_WIDTH = 256,
    parameter NUM_BANK   = 4,
    parameter NUM_ROW    = 16,
    parameter NUM_OUT    = NUM_BANK
  )(
    input                                         clk,
    input                                         rst_n,
    
    input  [NUM_ROW*NUM_BANK*ACT_WIDTH     -1:0]  din_data, 
    input  [NUM_ROW*NUM_BANK               -1:0]  din_data_vld,
    output [NUM_ROW*NUM_BANK               -1:0]  din_data_rdy,
    
    output [NUM_OUT*SRAM_WIDTH/2           -1:0]  out_data,
    output [NUM_OUT                        -1:0]  out_data_vld,
    input  [NUM_OUT                        -1:0]  out_data_rdy

  );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam ADD_DEPTH = NUM_ROW;
localparam ADD_WIDTH = $clog2(ADD_DEPTH);
localparam OUT_DEPTH = 4;
localparam OUT_WIDTH = $clog2(OUT_DEPTH);

wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1:0] pkg_act = din_data;
wire [NUM_BANK -1:0][NUM_ROW -1:0] din_data_en = din_data_vld & din_data_rdy;
wire [NUM_OUT  -1:0] out_data_en = out_data_vld & out_data_rdy;

reg  [NUM_BANK -1:0][ADD_WIDTH -1:0] pkg_act_cnt;
wire [NUM_BANK -1:0][ADD_WIDTH -1:0] pkg_add_cnt = pkg_act_cnt;
reg  [NUM_BANK -1:0][ADD_WIDTH -1:0] pkg_out_cnt;

reg  [NUM_BANK -1:0][NUM_ROW -1:0][ADD_WIDTH -1:0] pe_sync_radd;
reg  [NUM_BANK -1:0][NUM_ROW -1:0][ADD_WIDTH -1:0] pe_sync_wadd;
reg  [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH -1:0] pe_sync_data;
wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH -1:0] pe_sync_dout;
reg  [NUM_BANK -1:0] pe_sync_rena, pe_sync_rena_d;
reg  [NUM_BANK -1:0] pe_sync_wena;
reg  [NUM_BANK -1:0] pe_sync_ok;

wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH -1:0] pe_fifo_data = pe_sync_dout;
wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH -1:0] pe_fifo_dout;
wire [NUM_BANK -1:0][OUT_WIDTH :0] pe_fifo_cnt;
reg  [NUM_BANK -1:0] pe_fifo_wena;
reg  [NUM_BANK -1:0] pe_fifo_rena;
wire [NUM_BANK -1:0] pe_fifo_full;
wire [NUM_BANK -1:0] pe_fifo_empty;

reg  [NUM_BANK -1:0][NUM_ROW -1:0] pe_sync_rena_s;
reg  [NUM_BANK -1:0][NUM_ROW -1:0] pe_sync_wena_s;
RAM #( .SRAM_WORD( 2**ADD_WIDTH ), .SRAM_BIT( ACT_WIDTH ), .SRAM_BYTE(1)) PE_SHAPE_RAM_U [NUM_BANK*NUM_ROW-1:0] ( clk, rst_n, pe_sync_radd, pe_sync_wadd, pe_sync_rena_s, pe_sync_wena_s, pe_sync_data, pe_sync_dout);

CPM_FIFO #( .DATA_WIDTH( NUM_ROW*ACT_WIDTH ), .ADDR_WIDTH( OUT_WIDTH ) ) SHAPE_OUT_FIFO[NUM_BANK-1:0] ( clk, rst_n, 1'd0, pe_fifo_wena, pe_fifo_rena, pe_fifo_data, pe_fifo_dout, pe_fifo_empty, pe_fifo_full, pe_fifo_cnt);

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
genvar gen_i, gen_j;
generate
  for( gen_i=0 ; gen_i < NUM_BANK; gen_i = gen_i+1 ) begin : BANK_BLOCK
  
    always @ ( posedge clk or negedge rst_n )begin
    if( ~rst_n )
      pkg_act_cnt[gen_i] <= 'd0;
    else if( &din_data_en[gen_i] )
      pkg_act_cnt[gen_i] <= pkg_act_cnt[gen_i] + 'd1;
    end
  
    always @ ( posedge clk or negedge rst_n )begin
    if( ~rst_n )
      pkg_out_cnt[gen_i] <= 'd0;
    else if( out_data_en[gen_i] )
      pkg_out_cnt[gen_i] <= pkg_out_cnt[gen_i] + 'd1;
    end

    always @ ( posedge clk or negedge rst_n )begin
    if( ~rst_n )
      pe_sync_rena_d[gen_i] <= 'd0;
    else
      pe_sync_rena_d[gen_i] <= pe_sync_rena[gen_i];
    end

    always @ ( posedge clk or negedge rst_n )begin
    if( ~rst_n )
      pe_sync_ok[gen_i] <= 'd0;
    else if( &pkg_act_cnt[gen_i] && &din_data_en[gen_i] )
      pe_sync_ok[gen_i] <= 'd1;
    else if( &pkg_out_cnt[gen_i] && &out_data_en[gen_i] )
      pe_sync_ok[gen_i] <= 'd0;
    end
  
    always @ ( * )begin
      pe_sync_wena[gen_i] = &din_data_en[gen_i];
      pe_sync_rena[gen_i] = pe_sync_ok[gen_i] && pe_fifo_cnt[gen_i] < 'd0 ? {NUM_ROW{1'd1}} : {NUM_ROW{1'd0}};
    end

    always @ ( * )begin
      pe_fifo_wena[gen_i] = pe_sync_rena_d[gen_i];
      pe_fifo_rena[gen_i] = out_data_rdy[gen_i];
    end
  
    always @ ( * )begin
      pe_sync_rena_s[gen_i] = {NUM_ROW{pe_fifo_rena[gen_i]}};
      pe_sync_wena_s[gen_i] = {NUM_ROW{pe_fifo_wena[gen_i]}};
    end
    
    for( gen_j=0 ; gen_j < NUM_ROW; gen_j = gen_j+1 ) begin : ROW_BLOCK
    
        always @ ( * )begin
          pe_sync_wadd[gen_i][gen_j] = pkg_act_cnt[gen_i] +gen_j;
          pe_sync_radd[gen_i][gen_j] = pkg_out_cnt[gen_i];
        end
    
    end
    
  
    assign out_data_vld[gen_i] = ~pe_fifo_empty[gen_i];
    assign din_data_rdy[gen_i*NUM_ROW +:NUM_ROW] = &pkg_act_cnt[gen_i] ? {NUM_ROW{1'd0}} : {NUM_ROW{1'd1}};
  
end
endgenerate

always @ ( * )begin
  pe_sync_data = pkg_act;
end



//=====================================================================================================================
// Logic Design :
//=====================================================================================================================

assign in_data_rdy = out_data_rdy;
assign out_data = pe_fifo_dout;


endmodule

module PE_REG_E #(
    parameter DW = 8
) (
    input            Clk   ,
    input            Rstn  ,
    input            Enable,

    input  [DW -1:0] DataIn,
    output [DW -1:0] DataOut
);
  reg [DW -1:0] data_out;
  assign DataOut = data_out;
  always @ ( posedge Clk or negedge Rstn )begin
    if( ~Rstn )
      data_out <= 'd0;
    else if( Enable )
      data_out <= DataIn;
  end
endmodule