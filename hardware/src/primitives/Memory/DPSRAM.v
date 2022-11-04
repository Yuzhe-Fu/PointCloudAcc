module DPSRAM #(
    parameter SRAM_DEPTH_BIT= 6,
    parameter SRAM_DEPTH    = 2 ** SRAM_DEPTH_BIT,
    parameter SRAM_WIDTH    = 28,
    parameter INIT_IF       = "no",
    parameter INIT_FILE     = ""
)(
    input                           clk,
    input [SRAM_DEPTH_BIT   -1 : 0] addr_r,
    input [SRAM_DEPTH_BIT   -1 : 0] addr_w,
    input                           read_en,
    input                           write_en,
    input [SRAM_WIDTH       -1 : 0] data_in,
    output reg [SRAM_WIDTH  -1 : 0] data_out
);

reg [SRAM_WIDTH  - 1 : 0]mem[0 : SRAM_DEPTH - 1];

// ******************************************************************
// INSTANTIATIONS
// ******************************************************************
initial begin
  if (INIT_IF == "yes") begin
    $readmemh(INIT_FILE, mem, 0, SRAM_DEPTH-1);
  end
end

always @(posedge clk) begin
    if (read_en) begin
        data_out <= mem[addr_r];
    end
end

always @(posedge clk) begin
    if (write_en) begin
        mem[addr_w] <= data_in;            
    end
end

endmodule
