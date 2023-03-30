`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name:    zhangbo
// Module Name:    tb_eth_top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module tb_eth_top ;

//#############################################
localparam 	SYS_FRE  = 200;

//#############################################
reg i_sys_clk;
reg i_reset_n;

initial begin
	i_sys_clk 	  = 0;
	i_reset_n	  = 0;
	repeat(5) @(posedge i_sys_clk);
	i_reset_n	  = 1;
end

always #(1000/SYS_FRE/2) i_sys_clk = ~i_sys_clk;

/****************************************************/
wire 		gmii0_rxen		;
wire [7:0]	gmii0_rxdat		;
wire 		gmii0_txen		;
wire [7:0]	gmii0_txdat		;
	
reg 		tx0_start_en 	= 0;
reg	[15:0]	tx0_byte_num 	= 0;
reg	[31:0]	tx0_data		= 0;
wire 		tx0_data_req 	;
wire 		tx0_data_done 	;
wire 		tx0_start_err 	;
wire 		rxd0_pkt_done 	;
wire 		rxd0_wr_en 		;
wire [31:0]	rxd0_wr_data 	;
wire [15:0]	rxd0_wr_byte_num;

reg 		tx1_start_en 	= 0;
reg	[15:0]	tx1_byte_num 	= 0;
reg	[31:0]	tx1_data		= 0;
wire 		tx1_data_req 	;
wire 		tx1_data_done 	;
wire 		tx1_start_err 	;
wire 		rxd1_pkt_done 	;
wire 		rxd1_wr_en 		;
wire [31:0]	rxd1_wr_data 	;
wire [15:0]	rxd1_wr_byte_num;


eth_top #(
	.ARP_CACHE_EN		(1							)// 开启ARP地址缓存
)u0_eth_top(		
	.sys_clk			(i_sys_clk					),
	.reset_n			(i_reset_n					),
	.gmii_rxen			(gmii0_rxen					),
	.gmii_rxdat			(gmii0_rxdat				),
	.gmii_txen			(gmii0_txen					),
	.gmii_txdat			(gmii0_txdat				),	
		
	.local_ip			({8'd192,8'd168,8'd1,8'd1}	), // 本机IP
	.local_mac			(48'h123456789abc			), // 本机mac
	.dest_ip			({8'd192,8'd168,8'd1,8'd2}	), // 目的IP
	// .dest_mac			(48'h0123456789ab			), // 目的mac  目前mac为 0时自动arp请求mac地址 
	.dest_mac			(48'h0						), // 目的mac  目前mac为 0时自动arp请求mac地址 
		
    .tx_start_en 		(tx0_start_en 				), //以太网开始发送信号
    .tx_byte_num 		(tx0_byte_num 				), //以太网发送的有效字节数 单位:byte  
    .tx_data     		(tx0_data     				), //以太网待发送数据  
	.tx_data_req		(tx0_data_req				), //以太网发送数据请求
	.tx_data_done		(tx0_data_done				), //以太网发送完成信号
	.tx_start_err		(tx0_start_err				), //发送数据无响应 只有对方mac未知时生效
				
	.rxd_pkt_done		(rxd0_pkt_done				),
	.rxd_wr_en			(rxd0_wr_en					),
	.rxd_wr_data		(rxd0_wr_data				),
	.rxd_wr_byte_num	(rxd0_wr_byte_num			)	
);


eth_top #(
	.ARP_CACHE_EN		(1							)// 开启ARP地址缓存
)u1_eth_top(		
	.sys_clk			(i_sys_clk					),
	.reset_n			(i_reset_n					),
	.gmii_rxen			(gmii0_txen					),
	.gmii_rxdat			(gmii0_txdat				),
	.gmii_txen			(gmii0_rxen					),
	.gmii_txdat			(gmii0_rxdat				),	
		
	.local_ip			({8'd192,8'd168,8'd1,8'd2}	), // 本机IP
	.local_mac			(48'h0123456789ab			), // 本机mac
	.dest_ip			({8'd192,8'd168,8'd1,8'd1}	), // 目的IP
	.dest_mac			(48'h123456789abc			), // 目的mac  目前mac为 0时自动arp请求mac地址 
		
    .tx_start_en 		(tx1_start_en 				), //以太网开始发送信号
    .tx_byte_num 		(tx1_byte_num 				), //以太网发送的有效字节数 单位:byte  
    .tx_data     		(tx1_data     				), //以太网待发送数据  
	.tx_data_req		(tx1_data_req				), //以太网发送数据请求
	.tx_data_done		(tx1_data_done				), //以太网发送完成信号
	.tx_start_err		(tx1_start_err				), //发送数据无响应 只有对方mac未知时生效
				
	.rxd_pkt_done		(rxd1_pkt_done				),
	.rxd_wr_en			(rxd1_wr_en					),
	.rxd_wr_data		(rxd1_wr_data				),
	.rxd_wr_byte_num	(rxd1_wr_byte_num			)	
);

always @(posedge i_sys_clk ) begin
	if(i_reset_n == 1'b0 ) begin
		tx0_data <= 32'h0;
	end
	else if(tx0_data_req)
		tx0_data <= tx0_data + 1;
end

always @(posedge i_sys_clk ) begin
	if(i_reset_n == 1'b0 ) begin
		tx1_data <= 32'h1000_0000;
	end
	else if(tx1_data_req)
		tx1_data <= tx1_data + 1;
end

initial begin
	delay_cycle(20);
	
	eth0_send(11);
	eth0_send(123);
	
end

task eth0_send ;
	input [15:0] a;
	begin
		@(posedge i_sys_clk);
		tx0_byte_num = a;
		tx0_start_en = 1;
		@(posedge i_sys_clk);
		tx0_start_en = 0;
		wait(tx0_data_done);
		@(posedge i_sys_clk);
	end
endtask


task eth1_send ;
	input [15:0] a;
	begin
		@(posedge i_sys_clk);
		tx1_byte_num = a;
		tx1_start_en = 1;
		@(posedge i_sys_clk);
		tx1_start_en = 0;
		wait(tx1_data_done);
	end
endtask
/****************************************************/
/****************************************************/
/****************************************************/

task delay_cycle;
	input [31:0] tim;
	reg	[31:0] buff;
	begin
		buff = 0;
		while	(buff < tim) begin
			@(posedge i_sys_clk);
			buff = buff + 1;
		end
	end
endtask

function integer calc_width(input integer i);
	begin
		calc_width = 0;
		
		while(i>0) begin
			i = i >> 1;
			calc_width = calc_width + 1;
		end
		calc_width = calc_width - 1;
	end
endfunction

endmodule
