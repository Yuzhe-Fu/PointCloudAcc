module CLKREL (
    input sw,
    input rst_n,
    input clk_in,
    output clk_out
);
reg     sw_s1;
reg     sw_s2;

always @(negedge clk_in or negedge rst_n) begin
    if(!rst_n) begin
        sw_s1 <= 0;
        sw_s2 <= 0;
    end else begin
        sw_s1 <= sw;
        sw_s2 <= sw_s1;
    end
end

assign clk_out = clk_in & sw_s2;

endmodule