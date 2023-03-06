`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:     pc_recv_send_top
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

module   pc_recv_send_top #(
	parameter	SYS_FRE 		= 100
)( 
	input					clk_in1_p,
	input					clk_in1_n,
	input					i_reset,
	
	input					i_usart_rx,
	output					o_usart_tx,
	
    input            		gtrefclk_p,            // Differential +ve of reference clock for MGT: very high quality.
    input            		gtrefclk_n,            // Differential -ve of reference clock for MGT: very high quality.
    output           		txp,                   // Differential +ve of serial transmission from PMA to PMD.
    output           		txn,                   // Differential -ve of serial transmission from PMA to PMD.
    input            		rxp,                   // Differential +ve for serial reception from PMD to PMA.
    input            		rxn,                   // Differential -ve for serial reception from PMD to PMA.	
	output [13:0]		DDR3_0_addr,
	output [2:0]		DDR3_0_ba,
	output 				DDR3_0_cas_n,
	output [0:0]		DDR3_0_ck_n,
	output [0:0]		DDR3_0_ck_p,
	output [0:0]		DDR3_0_cke,
	output [0:0]		DDR3_0_cs_n,
	output [7:0]		DDR3_0_dm,
	inout [63:0]		DDR3_0_dq,
	inout [7:0]			DDR3_0_dqs_n,
	inout [7:0]			DDR3_0_dqs_p,
	output [0:0]		DDR3_0_odt,
	output 				DDR3_0_ras_n,
	output 				DDR3_0_reset_n,
	output 				DDR3_0_we_n,	

	input				abh_clk,
	input				ahb_rstn,
	input	[31:0]		ahb_haddr,
	input	[2:0]		ahb_hburst,
	input	[3:0]		ahb_hprot,
	output	[31:0]		ahb_hrdata,
	input				ahb_hready_in,
	output				ahb_hready_out,
	output				ahb_hresp,
	input	[2:0]		ahb_hsize,
	input	[1:0]		ahb_htrans,
	input	[63:0]		ahb_hwdata,
	input				ahb_hwrite,
	input				ahb_sel,

    output		        nul,
    output              i_reset_n,
    output              clk_10m,
    output              clk_100m,
    output              clk_125m,
    output              clk_200m

);

// wire clk_100m;
// wire clk_200m;
// wire clk_125m;
wire pll_lock;
// wire i_reset_n;
wire ui_rst;
wire ui_clk;

clk_wiz_0 u_mmcm(
    // Clock out ports
    .clk_out1	(clk_100m	),     // output clk_out1
    .clk_out2	(clk_200m	),     // output clk_out2
    .clk_out3	(clk_10m	),     // output clk_out2
   
    .reset		(i_reset	), // input reset
    .locked		(pll_lock	),       // output locked
 
    .clk_in1_p	(clk_in1_p	),    // input clk_in1_p
    .clk_in1_n	(clk_in1_n	)
);   

reg [8:0] delay_lock;

always @(posedge clk_100m ) begin
	if(!i_reset_n) 
		delay_lock <= 0;
	else if(pll_lock)
		delay_lock <= delay_lock[8] ? delay_lock : delay_lock + 1;
	else 
		delay_lock <= 0;
end
	
assign i_reset_n = delay_lock[8];
// assign i_sys_clk = clk_125m	;

/***********************************************/
wire		uart_tx_en;
wire		uart_tx_busy;
wire [7:0]	uart_tx_data;

usart_ctrl_v1 #(
	.SYS_FRE 			(125			),
	.USART_BPS			(115200			), 
	.CHACK_WAY			(0				)  // 0 无校验 1：奇校验 2：偶校验 
)u_usart_ctrl_v1( 		
	.i_sys_clk			(clk_125m		),
	.i_reset_n			(i_reset_n		),
	// TX
	.i_tx_start			(uart_tx_en		),
	.i_tx_data			(uart_tx_data	),
	.o_usart_tx			(o_usart_tx		),
	.o_tx_busy			(uart_tx_busy	),
	.o_tx_done			(),
	// RX
	.i_usart_rx			(i_usart_rx		),
	.o_rx_data			(uart_rx_data	),
	.o_rx_err			(),
	.o_rx_busy			(),
	.o_rx_done			(uart_rx_valid	)   
);

wire [1:0]	uart_st;
wire [31:0]	uart_addr;
wire [31:0]	uart_len;

wire [1:0]	eth_st;
wire [31:0]	eth_addr;
wire [31:0]	eth_len;

wire [31:0]	src_ip;
wire [31:0]	des_ip;
wire [47:0]	src_mac;
wire [47:0]	des_mac;
reg 		uart_rxdat_enable;
reg 		uart_rxdat_done;

user_cmd_pro u_user_cmd_pro( 
	.i_sys_clk			(clk_125m		),
	.i_reset_n			(i_reset_n 		),

// 数据接收	
	.i_rx_valid			(uart_rx_valid	),
	.i_rx_data			(uart_rx_data	),

// config regs 	
	.o_uart_addr		(uart_addr		),
	.o_uart_len			(uart_len		),
	.o_uart_st          (uart_st      	),
	
	.o_eth_addr			(eth_addr		),
	.o_eth_len	        (eth_len		),
	.o_eth_st	        (eth_st			),
	.o_src_ip			(src_ip			),
	.o_src_mac          (src_mac		),
	.o_des_ip	        (des_ip			),
	.o_des_mac          (des_mac 		)
);

wire 		eth_rx_valid;
wire 		eth_rx_done;
wire [31:0]	eth_rx_data;

wire 		eth_tx_valid;
wire 		eth_tx_st;
wire 		eth_tx_done;
wire [31:0]	eth_tx_data;
wire [31:0]	eth_tx_len;

eth_wrapper u_eth_wrapper( 
	.i_sys_clk				(clk_100m		),
	.i_reset_n				(i_reset_n		),
	
    .gtrefclk_p				(gtrefclk_p		), // Differential +ve of reference clock for MGT: very high quality.
    .gtrefclk_n				(gtrefclk_n		), // Differential -ve of reference clock for MGT: very high quality.
    .rxuserclk2				(clk_125m		),
	.txp					(txp			), // Differential +ve of serial transmission from PMA to PMD.
    .txn					(txn			), // Differential -ve of serial transmission from PMA to PMD.
    .rxp					(rxp			), // Differential +ve for serial reception from PMD to PMA.
    .rxn					(rxn			), // Differential -ve for serial reception from PMD to PMA.	
 
	.local_ip				(src_ip			), // 本机IP
	.local_mac				(src_mac		), // 本机mac
	.dest_ip				(des_ip			), // 目的IP
	.dest_mac				(des_mac		), // 目的mac  目前mac为 0时自动arp请求mac地址 
 
	.tx_start_en 			(eth_tx_st		), //以太网开始发送信号
    .tx_byte_num 			(eth_tx_len		), //以太网发送的有效字节数 单位:byte  
    .tx_data     			(eth_tx_data	), //以太网待发送数据  
	.tx_data_req			(eth_tx_valid	), //以太网发送数据请求
	.tx_data_done   		(eth_tx_done	), //以太网发送完成信号
	.tx_start_err			(				), //发送数据无响应 只有对方mac未知时生效
	
	.rxd_pkt_done			(				),
	.rxd_wr_en				(eth_rx_valid	),
	.rxd_wr_data			(eth_rx_data	),
	.rxd_wr_byte_num		(eth_rx_done	)	
);

/***********************************************/
wire 			wr0_req;
wire 			wr0_ack;
wire 	[31:0]	wr0_addr;
wire 	[31:0]	wr0_len;
wire 	[31:0]	wr0_data;
wire 			wr0_data_req;
wire 			wr0_req_done;
wire 			wr0_data_ready;

wire 			rd0_req;
wire 			rd0_ack;
wire 	[31:0]	rd0_addr;
wire 	[31:0]	rd0_len;
wire 	[31:0]	rd0_data;
wire 			rd0_data_valid;
wire 			rd0_req_done;
wire 			rd0_data_ready;

wire 			wr1_req;
wire 			wr1_ack;
wire 	[31:0]	wr1_addr;
wire 	[31:0]	wr1_len;
wire 	[31:0]	wr1_data;
wire 			wr1_data_req;
wire 			wr1_req_done;
wire 			wr1_data_ready;

wire 			rd1_req;
wire 			rd1_ack;
wire 	[31:0]	rd1_addr;
wire 	[31:0]	rd1_len;
wire 	[31:0]	rd1_data;
wire 			rd1_data_valid;
wire 			rd1_req_done;
wire 			rd1_data_ready;

bd_ddr_wrapper(
	.AHB_INTERFACE_0_haddr			(ahb_haddr			),
    .AHB_INTERFACE_0_hburst         (ahb_hburst     	),
    .AHB_INTERFACE_0_hprot          (ahb_hprot      	),
    .AHB_INTERFACE_0_hrdata         (ahb_hrdata     	),
    .AHB_INTERFACE_0_hready_in      (ahb_hready_in  	),
    .AHB_INTERFACE_0_hready_out     (ahb_hready_out 	),
    .AHB_INTERFACE_0_hresp          (ahb_hresp      	),
    .AHB_INTERFACE_0_hsize          (ahb_hsize      	),
    .AHB_INTERFACE_0_htrans         (ahb_htrans     	),
    .AHB_INTERFACE_0_hwdata         (ahb_hwdata     	),
    .AHB_INTERFACE_0_hwrite         (ahb_hwrite     	),
    .AHB_INTERFACE_0_sel            (ahb_sel        	),
    .s_ahb_hclk_0                   (abh_clk			),
    .ahb_hresetn                    (ahb_rstn			),
	
    .DDR3_0_addr                    (DDR3_0_addr       ),
    .DDR3_0_ba                      (DDR3_0_ba         ),
    .DDR3_0_cas_n                   (DDR3_0_cas_n      ),
    .DDR3_0_ck_n                    (DDR3_0_ck_n       ),
    .DDR3_0_ck_p                    (DDR3_0_ck_p       ),
    .DDR3_0_cke                     (DDR3_0_cke        ),
    .DDR3_0_cs_n                    (DDR3_0_cs_n       ),
    .DDR3_0_dm                      (DDR3_0_dm         ),
    .DDR3_0_dq                      (DDR3_0_dq         ),
    .DDR3_0_dqs_n                   (DDR3_0_dqs_n      ),
    .DDR3_0_dqs_p                   (DDR3_0_dqs_p      ),
    .DDR3_0_odt                     (DDR3_0_odt        ),
    .DDR3_0_ras_n                   (DDR3_0_ras_n      ),
    .DDR3_0_reset_n                 (DDR3_0_reset_n    ),
    .DDR3_0_we_n                    (DDR3_0_we_n       ),
    .busy_0                         (					),
    .busy_1                         (					),
    .error_reg_0                    (					),
    .error_reg_1                    (					),
    .init_calib_complete_0          (					),
	
	.ui_clk							(ui_clk				),
	.ui_rst							(ui_rst				),
		
    .rd_ack_0                       (rd0_ack			), // output
    .rd_addr_0                      (rd0_addr			),
    .rd_data_0                      (rd0_data			),
    .rd_data_ready_0                (rd0_data_ready		), // input
    .rd_data_valid_0                (rd0_data_valid		), // output
    .rd_len_0                       (rd0_len			),
    .rd_req_0                       (rd0_req			), // input
    .rd_req_done_0                  (rd0_req_done		), // output
    .rd_ack_1                       (rd1_ack			),
    .rd_addr_1                      (rd1_addr			),
    .rd_data_1                      (rd1_data			),
    .rd_data_ready_1                (rd1_data_ready		),
    .rd_data_valid_1                (rd1_data_valid		),
    .rd_len_1                       (rd1_len			),
    .rd_req_1                       (rd1_req			),
    .rd_req_done_1                  (rd1_req_done		),
	
    .sys_clk_i_0                    (clk_200m			),
    .sys_rst_0                      (i_reset_n			),
	
    .wr_ack_0                       (wr0_ack			), // output
    .wr_addr_0                      (wr0_addr			),
    .wr_data_0                      (wr0_data			),
    .wr_data_ready_0                (wr0_data_ready		), // input
    .wr_data_req_0                  (wr0_data_req		), // output
    .wr_len_0                       (wr0_len			),
    .wr_req_0                       (wr0_req			), // input
    .wr_req_done_0                  (wr0_req_done		), // output
    .wr_ack_1                       (wr1_ack			),
    .wr_addr_1                      (wr1_addr			),
    .wr_data_1                      (wr1_data			),
    .wr_data_ready_1                (wr1_data_ready		),
    .wr_data_req_1                  (wr1_data_req		),
    .wr_len_1                       (wr1_len			),
    .wr_req_1                       (wr1_req			),
    .wr_req_done_1                  (wr1_req_done		)
);
	
uart_dma_top #(
	.SYS_FRE 						(SYS_FRE			)
)u_uart_dma_top( 			
	.i_sys_clk						(clk_125m			),
	.i_reset_n						(i_reset_n			),
				
	.i_uart_st						(uart_st			), // 【0】启动  eth_start【1】  0：wr  1：rd		
	.i_uart_addr					(uart_addr			),
	.i_uart_len						(uart_len			),
				
	.i_rx_valid						(uart_rx_valid		),
	.i_rx_data						(uart_rx_data		),
	.o_tx_start						(uart_tx_en			),
	.i_tx_busy						(uart_tx_busy		),
	.o_tx_data						(uart_tx_data		),
			
// dma			
	.dma_clk						(ui_clk				),
	.dma_rstn						(~ui_rst			),
				
	.wr_req							(wr0_req			),
	.wr_ack                 		(wr0_ack			),
	.wr_addr                		(wr0_addr			),
	.wr_len                 		(wr0_len			),
	.wr_data                		(wr0_data			),
	.wr_data_req            		(wr0_data_req		),
	.wr_req_done            		(wr0_req_done		),
	.wr_data_ready          		(wr0_data_ready		),
				
	.rd_req							(rd0_req		 	),
	.rd_ack                 		(rd0_ack          	),
	.rd_addr                		(rd0_addr         	),
	.rd_len                 		(rd0_len          	),
	.rd_data                		(rd0_data         	),
	.rd_data_valid          		(rd0_data_valid   	),
	.rd_req_done	        		(rd0_req_done	 	),
	.rd_data_ready          		(rd0_data_ready   	)
		
	// input					error_reg,
	// input					busy
//	
);

eth_dma_top u_eth_dma_top( 
	.i_sys_clk						(clk_125m			),
	.i_reset_n						(i_reset_n			),
					
	.i_eth_st						(eth_st				), // 【0】启动  eth_start【1】  0：wr  1：rd		
	.i_eth_addr						(eth_addr			),
	.i_eth_len						(eth_len			),
				
	.i_rx_valid						(eth_rx_valid		),
	.i_rx_done						(eth_rx_done		),
	.i_rx_data						(eth_rx_data		),
					
	.i_tx_data_req					(eth_tx_valid		),	
	.i_tx_data_done					(eth_tx_done		),
	.o_tx_data						(eth_tx_data		),
	.o_tx_len						(eth_tx_len			),
	.o_tx_start						(eth_tx_st			),
				
// dma				
	.dma_clk						(ui_clk				),
	.dma_rstn						(~ui_rst			),
				
	.wr_req							(wr1_req			),
	.wr_ack							(wr1_ack			),
	.wr_addr						(wr1_addr			),
	.wr_len							(wr1_len			),
	.wr_data						(wr1_data			),
	.wr_data_req					(wr1_data_req		),
	.wr_req_done					(wr1_req_done		),
	.wr_data_ready					(wr1_data_ready		),
					
	.rd_req							(rd1_req			),
	.rd_ack             			(rd1_ack          	),
	.rd_addr            			(rd1_addr         	),
	.rd_len             			(rd1_len          	),
	.rd_data            			(rd1_data         	),
	.rd_data_valid      			(rd1_data_valid   	),
	.rd_req_done	    			(rd1_req_done	 	),
	.rd_data_ready      			(rd1_data_ready   	)
		
	// input					error_reg,
	// input					busy		
);


endmodule

