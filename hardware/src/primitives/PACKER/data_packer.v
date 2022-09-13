`timescale 1ns/1ps
`include "../source/include/dw_params_presim.vh"
module packer #(
// ******************************************************************
// Parameters
// ******************************************************************
  parameter integer IN_WIDTH        = 64,
  parameter integer OUT_WIDTH       = 128,
  parameter integer OP_WIDTH        = 16
)
(
// ******************************************************************
// IO
// ******************************************************************
  input  wire                                               clk,
  input  wire                                               rst_n,
  input   wire                                              Reset,
  input  wire                                               Unpacked_EnWr,
  output                                               Unpacked_RdyWr,
  input  wire  [ IN_WIDTH             -1 : 0 ]    Unpacked_DatWr,
  output wire                                             Packed_RdyRd,
//  input  wire                                         m_write_ready,
  input                                                         Packed_EnRd,
  output wire  [ OUT_WIDTH            -1 : 0 ] Packed_DatRd
);
 function integer ceil_a_by_b;
   input integer a;
   input integer b;
   integer c;
   begin
     c = a < b ? 1 : a % b == 0 ? a/b : a/b+1;
     ceil_a_by_b = c;
   end
 endfunction

localparam integer OUT_NUM_DATA = ceil_a_by_b(OUT_WIDTH, IN_WIDTH);
localparam integer DATA_COUNT_W = `C_LOG_2(OUT_NUM_DATA);
 reg [DATA_COUNT_W:0] dcount;

assign Unpacked_RdyWr = ~(dcount == OUT_NUM_DATA || (dcount ==OUT_NUM_DATA -1 && Unpacked_EnWr));

genvar g;
generate
  if (OUT_NUM_DATA == 1)
  begin
    assign Packed_DatRd = Unpacked_DatWr;
    assign Packed_RdyRd = Unpacked_EnWr;
  end
  else begin
    always @(posedge clk or negedge rst_n)
    begin
      if (!rst_n )
        dcount <= 0;
      else if( Packed_EnRd || Reset) begin
          dcount <= 0;
      end else if (Unpacked_EnWr) begin
          dcount <= dcount + 1'b1;
      end
    end

    reg [OUT_WIDTH-1:0] data;
    always @(posedge clk or negedge rst_n)
      if (!rst_n)
        data <= 'b0;
      else if (Unpacked_EnWr)
        data <= {data,Unpacked_DatWr};

    assign Packed_RdyRd = dcount ==OUT_NUM_DATA;
    assign Packed_DatRd = data;

  end
endgenerate

endmodule
