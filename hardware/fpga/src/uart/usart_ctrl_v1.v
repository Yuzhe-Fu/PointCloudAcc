`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:    usart_ctrl_v1
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
/*
	默认采用16倍的采样率
	
*/
// Dependencies: 
//
// Revision: 1.01
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module  usart_ctrl_v1 #(
	parameter	SYS_FRE 		= 50,
	parameter	USART_BPS		= 115200, 
	parameter	CHACK_WAY		= 0  // 0 无校验 1：奇校验 2：偶校验 
)( 
	input					i_sys_clk,
	input					i_reset_n,
	// TX
	input					i_tx_start,
	input		[7:0]		i_tx_data,
	output					o_usart_tx,
	output					o_tx_busy,
	output					o_tx_done,
	// RX
	input					i_usart_rx,
	output		[7:0]		o_rx_data,
	output		 			o_rx_err,
	output					o_rx_busy,
	output					o_rx_done
);

wire bps_clk;

usart_bps_clk_gen #(
	.SYS_FRE 		(SYS_FRE	),
	.USART_BPS		(USART_BPS	)
)usart_bps_clk( 
	.i_sys_clk		(i_sys_clk	),
	.i_reset_n		(i_reset_n	),
	.o_bps_clk		(bps_clk	)
);


usart_tx_v1 #(
	.SYS_FRE		(SYS_FRE	),
	.CHACK_WAY		(CHACK_WAY	)
)usart_tx(
	.i_sys_clk		(i_sys_clk	),
	.i_bps_en		(bps_clk	),
	.i_reset_n		(i_reset_n	),
	.i_start		(i_tx_start	),
	.i_data			(i_tx_data	),
	.o_usart_tx		(o_usart_tx	),
	.o_busy			(o_tx_busy	),
	.o_done			(o_tx_done	)
);

usart_rx_v1 #(
	.SYS_FRE		(SYS_FRE	),
	.CHACK_WAY		(CHACK_WAY	)
)usart_rx( 
	.i_sys_clk		(i_sys_clk	),
	.i_bps_en		(bps_clk	),
	.i_reset_n		(i_reset_n	),
	
	.i_usart_rx		(i_usart_rx	),
	.o_data			(o_rx_data	),
	.o_err			(o_rx_err	),
	.o_busy			(o_rx_busy	),
	.o_done			(o_rx_done	)
);

endmodule