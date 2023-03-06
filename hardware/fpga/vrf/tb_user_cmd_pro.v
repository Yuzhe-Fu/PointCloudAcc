`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:      tb_user_cmd_pro 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 1.01
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module  tb_user_cmd_pro ;

/***********************************************/
localparam		SYS_FRE 	= 100;

/***********************************************/
reg i_reset_n,
	i_sys_clk;
	
always #(1000/2/SYS_FRE) i_sys_clk = ~i_sys_clk;

initial begin
	i_sys_clk = 0;
	i_reset_n = 0;
	repeat(10) 
		@(posedge i_sys_clk);
	i_reset_n = 1;
end
 
/***********************************************/
reg 		tx_en = 0;
reg [7:0] 	tx_data = 0;

user_cmd_pro #(
	.SYS_FRE 			(SYS_FRE		)
)uut( 
	.i_sys_clk			(i_sys_clk		),
	.i_reset_n			(i_reset_n		),
	
	.i_rx_valid			(tx_en			),
	.i_rx_data			(tx_data		)
);


task uart_send_char;
	input [7:0] a;
	begin
		@(posedge i_sys_clk);
			tx_en   <= 1;
			tx_data <= a;
		@(posedge i_sys_clk);
			tx_en <= 0;
		@(posedge i_sys_clk);
	end
endtask

task uart_send_str;
	input [7:0]  a;
	input [31:0] b;
	integer i;
	begin
		uart_send_char("{");
		uart_send_char(a);
		uart_send_char(b >> 24);
		uart_send_char(b >> 16);
		uart_send_char(b >> 8);
		uart_send_char(b >> 0);
		uart_send_char("}");
	end
endtask

initial begin
/* 添加仿真代码在这里 */
	repeat(20) 
		@(posedge i_sys_clk);
		
	uart_send_str(3,123456);
	uart_send_str(4,223456);
	uart_send_str(5,1);
	
end


endmodule