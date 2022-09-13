`timescale 1ns/1ps
`include "../source/include/dw_params_presim.vh"
module unpacker_left #(
// ******************************************************************
// Parameters
// ******************************************************************
  parameter integer IN_WIDTH        = 128,
  parameter integer OUT_WIDTH       = 64
)
// ******************************************************************
// IO
// ******************************************************************
(
  input  wire                                         clk,
  input  wire                                         rst_n,
  input  wire                                         Reset,
  output wire                                         Packed_RdyWr, //req
  input  wire  [ IN_WIDTH             -1 : 0 ]        Packed_DatWr,
  input  wire                                         Packed_EnWr, //enable
  input  wire                                         Unpacked_EnRd,//req level
  //output reg                                          Unpacked_ValRd, //valid
  output                                                 Unpacked_RdyRd,
  output reg  [ OUT_WIDTH            -1 : 0 ]        Unpacked_DatRd
);
reg rd_valid;

  function integer ceil_a_by_b1;
input integer a;
input integer b;
integer c;
begin
  c = a < b ? 1 : a % b == 0 ? a/b : a/b+1;
  ceil_a_by_b1 = c;
end
endfunction
localparam MAX_READS = ceil_a_by_b1(IN_WIDTH, OUT_WIDTH);
localparam READ_COUNT_W = `C_LOG_2(MAX_READS+1);

reg [READ_COUNT_W-1:0] rd_count;

reg [IN_WIDTH-1:0] data;

always @(posedge clk or negedge rst_n)
  if (!rst_n)
    rd_count <= MAX_READS;
  else if( Reset )
    rd_count <= MAX_READS;
  else if (Packed_EnWr)
    rd_count <= 0;
  else if (Unpacked_EnRd)
    rd_count <= rd_count + 1'b1;

//assign Packed_RdyWr = rd_count == 0 && Packed_EnWr;
assign Packed_RdyWr = rd_count == MAX_READS ;

always @(posedge clk or negedge rst_n)
  if (!rst_n)
    data <= 0;
  else if (Unpacked_EnRd)
    data <= data << OUT_WIDTH;
  else if (Packed_EnWr)
    data <= Packed_DatWr;

assign Unpacked_RdyRd = rd_count != MAX_READS;
always @(posedge clk or negedge rst_n)
  if (!rst_n)
    Unpacked_DatRd <= 0;
  else if (Unpacked_EnRd)
    Unpacked_DatRd <= data[IN_WIDTH-1 -: OUT_WIDTH];


endmodule
