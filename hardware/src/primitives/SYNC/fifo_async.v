// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : zhouchch@pku.edu.cn
// File   : fifo_async.v
// Create : 2020-07-21 21:08:57
// Revise : 2020-07-21 21:22:50
// Editor : sublime text3, tab size (2)
// -----------------------------------------------------------------------------
// https://blog.csdn.net/alangaixiaoxiao/article/details/81432144
// 1. ptr -> gray: >> ^ xor yihuo
// 2. empty -> gray ==; full. addr_width -: 2 ~, other ==;
module fifo_async#(
  parameter   data_width = 16,
  parameter   addr_width = 8,
  parameter   data_depth = 1 << addr_width
                
) (
  input                           rst_n,
  input                           wr_clk,
  input                           wr_en,
  input      [data_width-1:0]     din,         
  input                           rd_clk,
  input                           rd_en,
  output reg                      valid,
  output reg [data_width-1:0]     dout,
  output                          empty,
  output                          full              
);
reg    [addr_width:0]    wr_addr_ptr;
reg    [addr_width:0]    rd_addr_ptr;
wire   [addr_width-1:0]  wr_addr;
wire   [addr_width-1:0]  rd_addr;

wire   [addr_width:0]    wr_addr_gray;
reg    [addr_width:0]    wr_addr_gray_d1;
reg    [addr_width:0]    wr_addr_gray_d2;
wire   [addr_width:0]    rd_addr_gray;
reg    [addr_width:0]    rd_addr_gray_d1;
reg    [addr_width:0]    rd_addr_gray_d2;


reg [data_width-1:0] fifo_ram [data_depth-1:0];

//=========================================================write fifo 
always@(posedge wr_clk )
    begin
       if(wr_en && (~full))
          fifo_ram[wr_addr] <= din;
       else
          fifo_ram[wr_addr] <= fifo_ram[wr_addr];
    end   
  
   
//========================================================read_fifo
always@(posedge rd_clk or negedge rst_n)
   begin
      if(!rst_n)
         begin
            dout <= 'h0;
            valid <= 1'b0;
         end
      else if(rd_en && (~empty))
         begin
            dout <= fifo_ram[rd_addr];
            valid <= 1'b1;
         end
      else
         begin
            dout <=   'h0;
            valid <= 1'b0;
         end
   end
assign wr_addr = wr_addr_ptr[addr_width-1-:addr_width];
assign rd_addr = rd_addr_ptr[addr_width-1-:addr_width];
//===========================================================
always@(posedge wr_clk or negedge rst_n)
   begin
    if( !rst_n ) begin
      rd_addr_gray_d1 <= 0;
      rd_addr_gray_d2 <= 0;
    end else begin
      rd_addr_gray_d1 <= rd_addr_gray;
      rd_addr_gray_d2 <= rd_addr_gray_d1;
    end
   end
always@(posedge wr_clk or negedge rst_n)
   begin
      if(!rst_n)
         wr_addr_ptr <= 'h0;
      else if(wr_en && (~full))
         wr_addr_ptr <= wr_addr_ptr + 1;
      else 
         wr_addr_ptr <= wr_addr_ptr;
   end
//=========================================================rd_clk
always@(posedge rd_clk or negedge rst_n)
      begin
        if( !rst_n ) begin
          wr_addr_gray_d1 <= 0;
          wr_addr_gray_d2 <= 0;
        end else begin
         wr_addr_gray_d1 <= wr_addr_gray;
         wr_addr_gray_d2 <= wr_addr_gray_d1;
       end
      end
always@(posedge rd_clk or negedge rst_n)
   begin
      if(!rst_n)
         rd_addr_ptr <= 'h0;
      else if(rd_en && (~empty))
         rd_addr_ptr <= rd_addr_ptr + 1;
      else 
         rd_addr_ptr <= rd_addr_ptr;
   end

//========================================================== translation gary code
assign wr_addr_gray = (wr_addr_ptr >> 1) ^ wr_addr_ptr;
assign rd_addr_gray = (rd_addr_ptr >> 1) ^ rd_addr_ptr;

assign full = (wr_addr_gray == {~(rd_addr_gray_d2[addr_width-:2]),rd_addr_gray_d2[addr_width-2:0]}) ;
assign empty = ( rd_addr_gray == wr_addr_gray_d2 );

// =====================================================================

endmodule
