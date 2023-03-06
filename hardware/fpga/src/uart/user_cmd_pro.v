`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:     user_cmd_pro
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

module   user_cmd_pro #(
	parameter	SYS_FRE 		= 100
)( 
	input					i_sys_clk,
	input					i_reset_n,
	
	input					i_rx_valid,
	input		[7:0]		i_rx_data,
	
	output	reg	[31:0]		o_uart_addr,
	output	reg	[31:0]		o_uart_len,
	output	reg	[1:0]		o_uart_st,

	output	reg	[31:0]		o_eth_addr	,
	output	reg	[31:0]		o_eth_len	,
	output	reg	[1:0]		o_eth_st	,
	
	output	reg	[31:0]		o_src_ip,	
	output	reg	[47:0]		o_src_mac,	
	output	reg	[31:0]		o_des_ip,	
	output	reg	[47:0]		o_des_mac
);

/*######################################################################*/
`include "regs_define.vh"
/*######################################################################*/

localparam	IDLE	= 0;
localparam	RX_END	= 1;
localparam	RX_CMD	= 2;
localparam	RX_DATA	= 3;

reg [2:0]	fsm_sta;
reg [2:0]	rx_cnt;
reg [07:0]	user_cmd;
reg [31:0]	user_data;
reg 		user_en;

//fsm_1
always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n) begin
		fsm_sta <= IDLE;
		rx_cnt 	<= 0;
		user_data <= 0;
		user_cmd 	<= 0;
		user_en 	<= 0;
	end
	else if(1)begin
		user_en <= 0;
		case(fsm_sta)
			IDLE:begin
				if(i_rx_valid && i_rx_data == "{")
					fsm_sta	<= RX_CMD;
				else 
					fsm_sta <= IDLE;
			end
			RX_CMD:begin
				if(i_rx_valid) begin
					user_cmd <= i_rx_data;
					fsm_sta <= RX_DATA;
				end
				
				rx_cnt 	<= 0;
			end
			RX_DATA:begin
				if(i_rx_valid) begin
					rx_cnt <= rx_cnt + 1;
					case(rx_cnt)
						0: user_data[31:24] <= i_rx_data;
						1: user_data[23:16] <= i_rx_data;
						2: user_data[15:8] <= i_rx_data;
						3:  begin user_data[7:0] <= i_rx_data; fsm_sta <= RX_END; end
						default:;
					endcase
				end
			end
			RX_END:begin
				if(i_rx_valid ) begin
					if(i_rx_data == "}")
						user_en	<= 1;
						
					fsm_sta <= IDLE;
				end				
			end
			default:;
		endcase
	end
end

/***********************************************/
// reg [31:0] eth_addr;
// reg	[31:0] eth_len;
// reg	[1:0]  eth_start;
// reg [31:0] uart_addr;
// reg	[31:0] uart_len;
// reg	[1:0]  uart_start;

always @(posedge i_sys_clk ) begin
	if(!i_reset_n) begin
		o_eth_addr 		<= 0;
		o_eth_len 		<= 0;
		o_eth_st 		<= 0;
		o_uart_addr		<= 0;
		o_uart_len 		<= 0;
		o_uart_st		<= 0;
	end
	else if(user_en ) begin
		case(user_cmd)
			ETH_ADDR 	: o_eth_addr 			<= user_data; // 网口 地址
			ETH_LEN  	: o_eth_len  			<= user_data; // 网口 长度
			ETH_ST 		: o_eth_st				<= user_data;//  网口 eth_start【0】启动  eth_start【1】  0：wr  1：rd
				
			UART_ADDR 	: o_uart_addr			<= user_data; // 串口 地址
			UART_LEN  	: o_uart_len			<= user_data; // 串口 长度
			UART_ST		: o_uart_st		  		<= user_data;//  串口 eth_start【0】启动  eth_start【1】  0：wr  1：rd
				
			SRC_IP 		: o_src_ip			<= user_data;
			SRC_MAC_H 	: o_src_mac[47:16] 	<= user_data;
			SRC_MAC_L 	: o_src_mac[15:00] 	<= user_data;
			DES_IP 		: o_des_ip			<= user_data;
			DES_MAC_H 	: o_des_mac[47:16] 	<= user_data;
			DES_MAC_L 	: o_des_mac[15:00] 	<= user_data;
			
			default:;
		endcase
	end
	else begin
		o_eth_st[0] 	<= 0;
		o_uart_st[0] 	<= 0;
	end
end

// assign o_uart_addr = uart_addr;
// assign o_uart_len = uart_len;
// assign o_uart_st = uart_start;

/***********************************************/




endmodule

