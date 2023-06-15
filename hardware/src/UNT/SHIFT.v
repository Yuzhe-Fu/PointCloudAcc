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
module SHIFT #(
    parameter DATA_WIDTH= 8,
    parameter WIDTH     = 32,// Number of Input data
    parameter ADDR_WIDTH= 5, // Depth of shift buffer 2**ADDR_WIDTH MUST >= WIDTH because loop write and read
    parameter DEPTH     = 2**ADDR_WIDTH
  )(
    input                                       clk             ,
    input                                       rst_n           ,
    input                                       Rst             , 

    input  [WIDTH    -1 : 0][DATA_WIDTH -1 : 0] shift_din       , 
    input                                       shift_din_vld   ,
    input                                       shift_din_last  ,
    output                                      shift_din_rdy   ,
    
    output [WIDTH   -1 : 0][DATA_WIDTH  -1 : 0] shift_dout      ,
    output                                      shift_dout_vld  ,
    input                                       shift_dout_rdy  ,

    output reg [ADDR_WIDTH + 1              -1 : 0] fifo_count      
  );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
genvar gen_j;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg     [ADDR_WIDTH     -1 : 0] wr_pointer;
reg     [ADDR_WIDTH     -1 : 0] rd_pointer;
wire                            empty;
wire                            full;
wire                            push;
wire                            pop;

wire    [WIDTH          -1 : 0][ADDR_WIDTH  -1 : 0] waddr;
wire    [WIDTH          -1 : 0][ADDR_WIDTH  -1 : 0] araddr;
wire                            arvalid;
wire                            wvalid;
wire                            rvalid;
wire                            rready;
//=====================================================================================================================
// Logic Design : FIFO Control
//=====================================================================================================================
always @ (posedge clk or negedge rst_n)begin : FIFO_COUNTER
    if (!rst_n) begin
        fifo_count <= WIDTH;
    end else if( Rst) begin
        fifo_count <= WIDTH;
    end else if (push && (!pop||pop&&empty) && !full)
        fifo_count <= fifo_count + 1;
    else if (pop && (!push||push&&full) && !empty)
        fifo_count <= fifo_count - 1;
end

always @ (posedge clk or negedge rst_n) begin : WRITE_PTR
    if (!rst_n) begin
        wr_pointer <= 0;
    end else if( Rst )begin
        wr_pointer <= 0;
    end else if (push && !full) begin
        wr_pointer <= wr_pointer + 1;
    end
end

always @ (posedge clk or negedge rst_n) begin : READ_PTR
    if (!rst_n) begin
        rd_pointer <= 0;
    end else if( Rst )begin
        rd_pointer <= 0;
    end else if (pop && !empty) begin
        rd_pointer <= rd_pointer + 1;
    end
end

// !empty: cache 1 data, can output 1 data; because of loop write and read
assign empty = fifo_count <= (shift_din_last? 0 : WIDTH -1); 
assign full  = fifo_count - WIDTH >= DEPTH;// !FULL: 
assign push  = wvalid;
assign pop   = arvalid;

//=====================================================================================================================
// Logic Design : DPRAM
//=====================================================================================================================
assign wvalid               = shift_din_vld & shift_din_rdy;
assign shift_din_rdy        = !full | shift_dout_rdy; // write and read simultaneously

assign arvalid              = !empty & ( (&rvalid) & rready | ~(&rvalid) );
assign shift_dout_vld       = rvalid;
assign rready               = shift_dout_rdy;

for( gen_j=0 ; gen_j < WIDTH; gen_j = gen_j+1 ) begin : ROW_BLOCK
    assign waddr[gen_j]  = wr_pointer -gen_j;
    assign araddr[gen_j] = rd_pointer;
end

assign wvalid_array = shift_din_vld & wvalid; // Write a part
RAM_HS#(
    .SRAM_BIT     ( DATA_WIDTH  ),
    .SRAM_BYTE    ( 1           ),
    .SRAM_WORD    ( DEPTH       ),
    .DUAL_PORT    ( 1           )
)u_DPRAM_HS [WIDTH     -1 : 0](
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .wvalid       ( wvalid_array ),
    .wready       (              ),
    .waddr        ( waddr        ),
    .wdata        ( shift_din    ),
    .arvalid      ( {WIDTH{arvalid}}),
    .arready      (              ),
    .araddr       ( araddr       ),
    .rvalid       ( rvalid       ),
    .rready       ( {WIDTH{rready}}),
    .rdata        ( shift_dout)
);

endmodule
