module RAM_REG #(
    parameter SRAM_ADDR_WIDTH   = 10,
    parameter SRAM_WIDTH        = 64,
    parameter SRAM_DEPTH        = 2 ** SRAM_ADDR_WIDTH
)(
input                           clk,
input                           read_en,
input                           write_en,
input [SRAM_ADDR_WIDTH  -1 : 0] addr_r,
input [SRAM_ADDR_WIDTH  -1 : 0] addr_w,
input [SRAM_WIDTH       -1 : 0] data_in,
output reg [SRAM_WIDTH - 1 : 0] data_out
);

reg [SRAM_WIDTH - 1 : 0]mem[0 : SRAM_DEPTH - 1];

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
