// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : zhouchch@pku.edu.cn
// File   : divider_even.v
// Create : 2020-07-21 21:28:06
// Revise : 2020-07-21 21:28:49
// Editor : sublime text3, tab size (4)
// -----------------------------------------------------------------------------
//rtl
module divider_even(
    clk,
    rst_n,
    clk_div
);
    input clk;
    input rst_n;
    output clk_div;
    reg clk_div;

    parameter NUM_DIV = 6;
    reg    [3:0] cnt;

always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        cnt     <= 4'd0;
        clk_div    <= 1'b0;
    end
    else if(cnt < NUM_DIV / 2 - 1) begin
        cnt     <= cnt + 1'b1;
        clk_div    <= clk_div;
    end
    else begin
        cnt     <= 4'd0;
        clk_div    <= ~clk_div;
    end
 endmodule