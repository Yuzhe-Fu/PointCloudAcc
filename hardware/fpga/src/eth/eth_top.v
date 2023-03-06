`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 		UESTCOC
// Engineer: 		Deam
// 
// Create Date: 
// Design Name:     
// Module Name:     eth_top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 


/*

	用于UDP传输数据，
	在发送操作时：若不知道到对方的MAC地址，则填写0，
		此时会去查本地mac表，若查询失败需要ARP请求对方IP地址，
		在获取到对方的mac地址后在把数据传输出去，同时把对方的mac地址缓存在本地中。
	在接收操作时：
		会更新对方的mac地址 至本地中。

*/
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module eth_top #(
	parameter			ARP_CACHE_EN	= 1 // 开启ARP地址缓存
)(	
	input				sys_clk			,
	input				reset_n			,
	input				gmii_rxen		,
	input	[7:0]		gmii_rxdat		,
	output				gmii_txen		,
	output	[7:0]		gmii_txdat		,	
	output				gmii_tlast		,	
	
	input	[31:0]	 	local_ip		, // 本机IP
	input	[47:0]	 	local_mac		, // 本机mac
	input	[31:0]	 	dest_ip			, // 目的IP
	input	[47:0]	 	dest_mac		, // 目的mac  目前mac为 0时自动arp请求mac地址 
	
    input               tx_start_en 	, //以太网开始发送信号
    input   [15:0] 		tx_byte_num 	, //以太网发送的有效字节数 单位:byte  
    input   [31:0] 		tx_data     	, //以太网待发送数据  
	output				tx_data_req		, //以太网发送数据请求
	output              tx_data_done    , //以太网发送完成信号
	output	reg			tx_start_err	, //发送数据无响应 只有对方mac未知时生效
	
	output				rxd_pkt_done	,
	output				rxd_wr_en		,
	output	[31:0]		rxd_wr_data		,
	output	[15:0]		rxd_wr_byte_num		
);


localparam	IDLE		= 4'd1;
localparam	TX_DATA		= 4'd2;
localparam	TX_ARP		= 4'd3;
localparam	LOOK_DES_MAC= 4'd4;

reg [3:0]	fsm_sta;
reg 		udp_tx_start;

wire 		lookup_done;
wire [47:0]	lookup_mac ;
reg  [47:0]	dest_mac_f;
wire [31:0]	arp_recv_ip;
wire [47:0] arp_recv_mac;
reg  [23:0]	wait_time;

wire 		arp_rx_done;
wire 		arp_rx_type;	 //ARP接收类型 0:请求  1:应答
wire 		arp_tx_done;
wire 		arp_tx_en;
wire 		arp_tx_type;
wire 		arp_gmii_txen;
wire [7:0]	arp_gmii_txd;


// fsm
always @(posedge sys_clk or negedge reset_n) begin
	if(reset_n == 1'b0 ) begin
		fsm_sta 		<= IDLE;
		udp_tx_start	<= 0;
		dest_mac_f 		<= 0;
		wait_time 		<= 0;
		tx_start_err	<= 0;
	end
	else begin
		case(fsm_sta)
			IDLE:begin
				if(tx_start_en ) 
					if(dest_mac != 0) begin
						fsm_sta	  	<= TX_DATA;
						dest_mac_f	<= dest_mac;
					end
					else 
						fsm_sta		<= LOOK_DES_MAC;
				else 
					fsm_sta	<= IDLE;
				udp_tx_start	<= 0;
				wait_time		<= 0;
				tx_start_err	<= 0;
			end
			TX_DATA:begin
				udp_tx_start	<= 1;
				fsm_sta			<= IDLE;	
			end
			LOOK_DES_MAC:begin
				if(lookup_done) begin
					if(lookup_mac == 0) 		// 没有该mac记录，arp 请求
						fsm_sta		<= TX_ARP;
					else begin
						fsm_sta		<= TX_DATA;
						dest_mac_f 	<= lookup_mac;
					end
				end
			end
			TX_ARP:begin
				wait_time	<= wait_time + 1;
				if(arp_rx_done && arp_rx_type && arp_recv_ip == dest_ip) begin // 收到arp应答
					fsm_sta		<= TX_DATA;	
					dest_mac_f	<= arp_recv_mac;
				end
				else if(wait_time >= 50000) begin // 傻叉不回复
					fsm_sta		<= IDLE;
					tx_start_err<= 1;
				end
				else
					fsm_sta		<= TX_ARP;
			end
			default:;
		endcase
	end
end

/****************************************************/
//ARP module
arp_top    arp_top_inst   (
    .rst_n         		(reset_n  		),
    .gmii_rxc      		(sys_clk		),
    .gmii_rxdv    		(gmii_rxen 		),
    .gmii_rxd      		(gmii_rxdat		),
    .gmii_txc      		(sys_clk		),
    .gmii_txen    		(arp_gmii_txen 	),
    .gmii_txd      		(arp_gmii_txd	),		
	
    .arp_rx_done   		(arp_rx_done	),//ARP接收完成信号
    .arp_rx_type   		(arp_rx_type	),//ARP接收类型 0:请求  1:应答
    // .source_mac    		(source_mac    	),//接收到目的MAC地址
    .source_mac    		(arp_recv_mac    	),//接收到目的MAC地址
    // .source_ip     		(source_ip     	),//接收到目的IP地址 
    .source_ip     		(arp_recv_ip     	),//接收到目的IP地址 
	.local_mac			(local_mac		),//本机mac
	.local_ip			(local_ip		),//本机IP
    .arp_tx_en     		(arp_tx_en  	),//ARP发送使能信号
    .arp_tx_type   		(arp_tx_type	),//ARP发送类型 0:请求  1:应答
    .destination_mac	(dest_mac		),//发送的目标MAC地址
    .desination_ip		(dest_ip		),//发送的目标IP地址
    .tx_done      	 	(arp_tx_done	)
);

// 缓存 ARP 地址信息
// 若查询mac 地址不存在。自动申请arp请求
generate if(ARP_CACHE_EN) begin
arp_cache #(
	// .DE_IP0		({8'd192,8'd168,8'd1,8'd123}),
	// .DE_MAC0	(48'h123456789abc			),
	.DE_IP0		(0),
	.DE_MAC0	(0							),
	.NUM		(5							)
)u_arp_cache(
	.sys_clk	(sys_clk					),
	.reset_n	(reset_n					),
	.lookup_en	((fsm_sta == LOOK_DES_MAC)	),	// 查询使能
	.lookup_ip	(dest_ip					),  // 查询IP
	.lookup_mac	(lookup_mac					),	// 返回MAC 不存在mac返回0
	.lookup_done(lookup_done				),	// 查询完成
	
	// .store_en	(arp_rx_done & ~arp_rx_type	),
	.store_en	(arp_rx_done 				),
	.store_ip	(arp_recv_ip				),
	.store_mac	(arp_recv_mac				)
);
end endgenerate

/****************************************************/
wire			udp_gmii_txen;
// wire			rxd_pkt_done;
// wire			rxd_wr_en;
// wire	[31:0]	rxd_wr_data;
// wire	[15:0]	rxd_wr_byte_num;
wire	[7:0]	udp_gmii_txd;

//UDP module
udp_top  udp_top_inst(
    .rst_n         		(reset_n			),  
    .gmii_rxc      		(sys_clk			),           
    .gmii_rxdv     		(gmii_rxen			),         
    .gmii_rxd      		(gmii_rxdat			),                   
    .gmii_txc      		(sys_clk 			), 
    .gmii_txen     		(udp_gmii_txen		),         
    .gmii_txd      		(udp_gmii_txd		), 
    .rxd_pkt_done  		(rxd_pkt_done		),  //以太网单包数据接收完成信号    
    .rxd_wr_en     		(rxd_wr_en			),  //以太网接收的数据使能信号    
    .rxd_wr_data   		(rxd_wr_data		),  //以太网接收的数据       
    .rxd_wr_byte_num  	(rxd_wr_byte_num	),  //以太网接收的有效字节数 单位:byte 
	
    .tx_start_en  		(udp_tx_start		),  //以太网开始发送信号      
    .tx_data      		(tx_data			),  //以太网待发送数据          
    .tx_byte_num  		(tx_byte_num		),  //以太网发送的有效字节数 单位:byte 
    .tx_request        	(tx_data_req		), 	//读数据请求信号              
	.local_mac			(local_mac			), // 本机mac
	.local_ip			(local_ip			), // 本机IP		
    .destination_mac    (dest_mac_f			),
    .destination_ip     (dest_ip			),    
    .tx_done      		(tx_data_done		)	//以太网发送完成信号        
); 

// eth rx tx control
eth_ctrl eth_ctrl_inst(
    .clk           		(sys_clk			),
    .rst_n         		(reset_n			),
    .arp_rx_done   		(arp_rx_done   		),
    .arp_rx_type   		(arp_rx_type   		),
	
	.tx_start_en		(lookup_done		),
	.tx_des_mac			(lookup_mac			),
	
    .arp_tx_en     		(arp_tx_en     		),//ARP发送使能信号
    .arp_tx_type   		(arp_tx_type   		),//ARP发送类型 0:请求  1:应答
    .arp_tx_done   		(arp_tx_done   		),
	
    .arp_gmii_txen 		(arp_gmii_txen		),
    .arp_gmii_txd  		(arp_gmii_txd  		),
    .udp_gmii_txen 		(udp_gmii_txen		),
    .udp_gmii_txd  		(udp_gmii_txd  		),              
    .gmii_txen     		(gmii_txen 			),
    .gmii_txd      		(gmii_txdat			),
    .gmii_tlast    		(gmii_tlast			)
);
	
	
endmodule
