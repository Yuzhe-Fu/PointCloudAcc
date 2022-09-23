// CSDN打拍系列
// 只对ready打拍，valid有贯通，经验证是对的
// 参考【芯片前端】保持代码手感——握手协议ready打拍时序优化
// https://www.codeleading.com/article/42216260925/

module backward_pipe #(
	parameter WIDTH = 8)
(
	input clk,
	input rst_n,
	
	input [WIDTH -1:0]data_in,
	input 			  data_in_valid,
	output			  data_in_ready,
	
	output[WIDTH -1:0]data_out,
	output			  data_out_valid,
	input			  data_out_ready
);
 
wire out_ready_en = data_in_valid || data_out_ready;
wire out_ready_d  = data_out_ready;
wire out_ready_q;
dffse #(.WIDTH(1), .VALUE(1'b1))
u_out_ready_dffse(
	.clk(clk),
	.rst_n(rst_n),
	.d(out_ready_d),
	.en(out_ready_en),
	.q(out_ready_q)
);
assign data_in_ready  = out_ready_q;

wire 			 data_en = data_in_valid && data_in_ready;
wire [WIDTH -1:0]data_d  = data_in;
wire [WIDTH -1:0]data_q;
dffe #(.WIDTH(WIDTH))
u_in_data_dffe(
	.clk(clk),
	.d(data_d),
	.en(data_en),
	.q(data_q)
);

assign data_out_valid = data_in_valid || (~out_ready_q);
assign data_out       = out_ready_q ? data_in : data_q;


endmodule