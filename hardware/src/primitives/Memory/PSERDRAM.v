// This is a simple example.
// You can make a your own header file and set its path to settings.
// (Preferences > Package Settings > Verilog Gadget > Settings - User)
//
//      "header": "Packages/Verilog Gadget/template/verilog_header.v"
//
// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : zhouchch@pku.edu.cn
// File   : CCU.v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------
module PSERDRAM (
    input                           clk   ,
    input                           rst_n ,
	
	input  					        arvalid,
	output 					        arready,
	output reg					    rvalid ,
	input					        rready
);
//=====================================================================================================================
// Logic Design
//=====================================================================================================================
wire                ram_renc;
assign ram_renc  = arvalid && arready;
// output
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rvalid <= 1'b0;
    end else if (ram_renc ) begin
        rvalid <= 1'b1;
    end else if (rvalid & rready ) begin
        rvalid <= 1'b0;
    end
end
assign arready = rready | !rvalid;

endmodule
