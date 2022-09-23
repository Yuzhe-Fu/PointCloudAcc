// 自己使用深度为2的FIFO(最小地址位宽为1）
// 优：实现握手协议时序路径完全断开（全打拍）
// 缺：深度为2，资源使用较多，且无直通，最少需要一个周期延时

module HS_PIPE_FIFO #(
	parameter DATA_WIDTH = 8)
(
	input clk,
	input rst_n,
	
	input [DATA_WIDTH   -1 : 0] DatIn,
	input 			            DatInVld,
	output			            DatInRdy,
	
	output[DATA_WIDTH   -1 : 0] DatOut,
	output			            DatOutVld,
	input			            DatOutRdy
);
wire empty, full;


fifo_fwft#(
    .INIT       ( "init.mif" ),
    .DATA_WIDTH ( DATA_WIDTH ),
    .ADDR_WIDTH ( 1          ),
    .INITIALIZE_FIFO ( "no" )
)u_fifo_fwft(
    .clk        ( clk                   ),
    .Reset      ( 1'b0                  ),
    .rst_n      ( rst_n                 ),
    .push       ( DatInVld & DatInRdy   ),
    .pop        ( DatOutVld & DatOutRdy ),
    .data_in    ( DatIn                 ),
    .data_out   ( DatOut                ),
    .empty      ( empty                 ),
    .full       ( full                  ),
    .fifo_count (                       )
);

assign DatInRdy = !full;
assign DatOutVld = !empty;