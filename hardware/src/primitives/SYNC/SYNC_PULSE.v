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
module SYNC_PULSE(
    input   in_rst_n,
    input   in_clk  ,
    input   in_pulse,
    input   out_rst_n,
    input   out_clk  ,
    output  out_pulse

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg R_in_change;
//=====================================================================================================================
// Logic Design: FSM
//=====================================================================================================================

always @(posedge in_clk or negedge in_rst_n) begin
    if (!in_rst_n)
        R_in_change <= 0;
    else if (in_pulse)
        R_in_change <= ~R_in_change;
end

reg [2:0] R_out_change;
always @(posedge out_clk or negedge out_rst_n) begin
    if (!out_rst_n)
        R_out_change <= 0;
    else
        R_out_change <= {R_out_change[1:0], R_in_change};
end

// Here XOR is used to generate pulse.
assign out_pulse = R_out_change[1] ^ R_out_change[2];

endmodule
