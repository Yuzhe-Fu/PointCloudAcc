`timescale 1ns/1ps
`include "../source/include/dw_params_presim.vh"
module packer_right #(
// ******************************************************************
// Parameters
// ******************************************************************
  parameter integer IN_WIDTH        = 64,
  parameter integer OUT_WIDTH       = 128
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

//assign Unpacked_RdyWr = m_write_ready;
/*reg Unpacked_RdyWr_reg;
always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        Unpacked_RdyWr <= 1;
    end else if ( Packed_EnRd ) begin
        Unpacked_RdyWr <= 1;
    end else if (Packed_RdyRd )begin
       Unpacked_RdyWr <= 0;
    end
end
*/
assign Unpacked_RdyWr = ~Packed_RdyRd;

genvar g;
generate
  if (OUT_NUM_DATA == 1)
  begin
    assign Packed_DatRd = Unpacked_DatWr;
    assign Packed_RdyRd = Unpacked_EnWr;
  end
  else begin
    reg [DATA_COUNT_W:0] dcount;

    always @(posedge clk or negedge rst_n)
    begin
      if (!rst_n )
        dcount <= 0;
      else if( (Packed_EnRd&&~Unpacked_EnWr) || Reset)
          dcount <= 0;
      else if( Packed_EnRd && Unpacked_EnWr )
          dcount <= 1;
      else if (Unpacked_EnWr)
          dcount <= dcount + 1'b1;
    end

    reg [OUT_WIDTH-1:0] data;
    always @(posedge clk or negedge rst_n)
      if (!rst_n)
        data <= 'b0;
      else if (Unpacked_EnWr)
        data <= {Unpacked_DatWr,data} >> IN_WIDTH;

    wire ready;
    assign ready = dcount ==OUT_NUM_DATA;
    assign Packed_RdyRd = ready;// paulse
    assign Packed_DatRd = data;

  end
endgenerate

endmodule
