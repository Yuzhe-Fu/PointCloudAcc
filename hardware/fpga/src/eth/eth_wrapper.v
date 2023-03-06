`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:     eth_wrapper
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

module   eth_wrapper ( 
	input					i_sys_clk,
	input					i_reset_n,
	
    input            		gtrefclk_p,            // Differential +ve of reference clock for MGT: very high quality.
    input            		gtrefclk_n,            // Differential -ve of reference clock for MGT: very high quality.
    output           		rxuserclk2,
    output           		txp,                   // Differential +ve of serial transmission from PMA to PMD.
    output           		txn,                   // Differential -ve of serial transmission from PMA to PMD.
    input            		rxp,                   // Differential +ve for serial reception from PMD to PMA.
    input            		rxn,                   // Differential -ve for serial reception from PMD to PMA.	

	input	[31:0]	 		local_ip		, // 本机IP
	input	[47:0]	 		local_mac		, // 本机mac
	input	[31:0]	 		dest_ip			, // 目的IP
	input	[47:0]	 		dest_mac		, // 目的mac  
    input               	tx_start_en 	, //以太网开始发送信号
    input   [15:0] 			tx_byte_num 	, //以太网发送的有效字节数 单位:byte  
    input   [31:0] 			tx_data     	, //以太网待发送数据  
	output					tx_data_req		, //以太网发送数据请求
	output              	tx_data_done    , //以太网发送完成信号
	output					tx_start_err	, //发送数据无响应 只有对方mac未知时生效
		
	output					rxd_pkt_done	,
	output					rxd_wr_en		,
	output	[31:0]			rxd_wr_data		,
	output	[15:0]			rxd_wr_byte_num		
);

wire [7 : 0] 	rx_axis_mac_tdata		;
wire			rx_axis_mac_tvalid      ;
wire			rx_axis_mac_tlast       ;
wire			rx_axis_mac_tuser       ;

wire [7 : 0] 	tx_axis_mac_tdata		;
wire			tx_axis_mac_tvalid      ;
wire			tx_axis_mac_tlast       ;
// wire			tx_axis_mac_tuser       ;

wire 			phy_mdc;
wire 			phy_mdio_i;
wire 			phy_mdio_o;
wire 			sgmii_clk_en;

wire 	[7:0]	gmii_txd    ;
wire 			gmii_tx_en  ;
wire 			gmii_tx_er  ;
wire 	[7:0]	gmii_rxd    ;
wire 			gmii_rx_dv  ;
wire 			gmii_rx_er  ;

gig_ethernet_pcs_pma_0_wrapper u_pcs_pma  (

      // An independent clock source used as the reference clock for an
      // IDELAYCTRL (if present) and for the main GT transceiver reset logic.
      // This example design assumes that this is of frequency 200MHz.
     .independent_clock	(i_sys_clk	),

      // Tranceiver Interface
      //---------------------

     .gtrefclk_p			(gtrefclk_p		),            // Differential +ve of reference clock for MGT: very high quality.
     .gtrefclk_n			(gtrefclk_n		),            // Differential -ve of reference clock for MGT: very high quality.
     .rxuserclk2			(rxuserclk2		),
     .txp					(txp			),                   // Differential +ve of serial transmission from PMA to PMD.
     .txn					(txn			),                   // Differential -ve of serial transmission from PMA to PMD.
     .rxp					(rxp			),                   // Differential +ve for serial reception from PMD to PMA.
     .rxn					(rxn			),                   // Differential -ve for serial reception from PMD to PMA.

      // GMII Interface (client MAC <=> PCS)
      //------------------------------------
      .sgmii_clk_en        (sgmii_clk_en	),  // Clock for client MAC 
      .gmii_txd            (gmii_txd   		), // Transmit data from client MAC.
      .gmii_tx_en          (gmii_tx_en 		), // Transmit control signal from client MAC.
      .gmii_tx_er          (gmii_tx_er 		), // Transmit control signal from client MAC.
      .gmii_rxd            (gmii_rxd   		), // Received Data to client MAC.
      .gmii_rx_dv          (gmii_rx_dv 		), // Received control signal to client MAC.
      .gmii_rx_er          (gmii_rx_er 		), // Received control signal to client MAC.
      // Management: Alternative to MDIO Interface
      //------------------------------------------

     .mdc					(phy_mdc		),                   // Management Data Clock
     .mdio_i				(phy_mdio_i		),                // Management Data In
     .mdio_o				(phy_mdio_o		),                // Management Data Out
     .mdio_t				(				),                // Management Data Tristate
     .phyaddr				(5'h5			),
     .configuration_vector	(5'b00000		),  // Alternative to MDIO interface.
     .configuration_valid	(1'b0			),   // Validation signal for Config vector
							
     .an_interrupt			(				),          // Interrupt to processor to signal that Auto-Negotiation has completed
     .an_adv_config_vector	(16'h0			),  // Alternate interface to program REG4 (AN ADV)
     .an_adv_config_val		(1'b0			),     // Validation signal for AN ADV
     .an_restart_config		(1'b0			),     // Alternate signal to modify AN restart bit in REG0

      // Speed Control
      //--------------
      .speed_is_10_100		(speed_is_10_100	),       // Core should operate at either 10Mbps or 100Mbps speeds
      .speed_is_100			(speed_is_100		),          // Core should operate at 100Mbps speed


      // General IO's
      //-------------
      .status_vector		(),         // Core status.
      .reset				(~i_reset_n		),                 // Asynchronous reset for entire core.
      .signal_detect		(1'b1			)          // Input from PMD to indicate presence of optical input.

);

tri_mode_ethernet_mac_0 u_tri_mode_ethernet_mac_0 (
  .s_axi_aclk			(i_sys_clk			),                      // input wire s_axi_aclk
  .s_axi_resetn			(i_reset_n			),                  // input wire s_axi_resetn
  .gtx_clk				(rxuserclk2			),                            // input wire gtx_clk
  .glbl_rstn			(i_reset_n			),                        // input wire glbl_rstn
  .rx_axi_rstn			(i_reset_n			),                    // input wire rx_axi_rstn
  .tx_axi_rstn			(i_reset_n			),                    // input wire tx_axi_rstn
  
  // .rx_statistics_vector(rx_statistics_vector),  // output wire [27 : 0] rx_statistics_vector
  // .rx_statistics_valid(rx_statistics_valid),    // output wire rx_statistics_valid
  .rx_mac_aclk			(					),                    // output wire rx_mac_aclk
  .rx_reset				(					),                          // output wire rx_reset
  .rx_axis_mac_tdata	(rx_axis_mac_tdata	),        // output wire [7 : 0] rx_axis_mac_tdata
  .rx_axis_mac_tvalid	(rx_axis_mac_tvalid	),      // output wire rx_axis_mac_tvalid
  .rx_axis_mac_tlast	(rx_axis_mac_tlast	),        // output wire rx_axis_mac_tlast
  .rx_axis_mac_tuser	(rx_axis_mac_tuser	),        // output wire rx_axis_mac_tuser
  .tx_ifg_delay			('b0				),                  // input wire [7 : 0] tx_ifg_delay
  // .tx_statistics_vector(tx_statistics_vector),  // output wire [31 : 0] tx_statistics_vector
  // .tx_statistics_valid(tx_statistics_valid),    // output wire tx_statistics_valid
  .tx_mac_aclk			(					),                    // output wire tx_mac_aclk
  .tx_reset				(					),                          // output wire tx_reset
  .tx_axis_mac_tdata	(tx_axis_mac_tdata	),        // input wire [7 : 0] tx_axis_mac_tdata
  .tx_axis_mac_tvalid	(tx_axis_mac_tvalid	),      // input wire tx_axis_mac_tvalid
  .tx_axis_mac_tlast	(tx_axis_mac_tlast	),        // input wire tx_axis_mac_tlast
  .tx_axis_mac_tuser	(1'b0				),        // input wire [0 : 0] tx_axis_mac_tuser
  .tx_axis_mac_tready	(tx_axis_mac_tready	),      // output wire tx_axis_mac_tready
  .pause_req			(1'b0				),                        // input wire pause_req
  .pause_val			(16'h0000			),                        // input wire [15 : 0] pause_val
  .clk_enable			(sgmii_clk_en		),                      // input wire clk_enable
  .speedis100			(speed_is_100		),                      // output wire speedis100
  .speedis10100			(speed_is_10_100	),                  // output wire speedis10100
  .gmii_txd				(gmii_txd			),                          // output wire [7 : 0] gmii_txd
  .gmii_tx_en			(gmii_tx_en			),                      // output wire gmii_tx_en
  .gmii_tx_er			(gmii_tx_er			),                      // output wire gmii_tx_er
  .gmii_rxd				(gmii_rxd			),                          // input wire [7 : 0] gmii_rxd
  .gmii_rx_dv			(gmii_rx_dv			),                      // input wire gmii_rx_dv
  .gmii_rx_er			(gmii_rx_er			),                      // input wire gmii_rx_er
  .mdio_t				(					),                              // output wire mdio_t
  .mdio_i				(phy_mdio_o			),                              // input wire mdio_i
  .mdio_o				(phy_mdio_i			),                              // output wire mdio_o
  .mdc					(phy_mdc			)  ,                                  // output wire mdc
  .s_axi_awaddr('b0),                  // input wire [11 : 0] s_axi_awaddr
  .s_axi_awvalid('b0),                // input wire s_axi_awvalid
  // .s_axi_awready(s_axi_awready),                // output wire s_axi_awready
  .s_axi_wdata('b0),                    // input wire [31 : 0] s_axi_wdata
  .s_axi_wvalid('b0),                  // input wire s_axi_wvalid
  // .s_axi_wready(s_axi_wready),                  // output wire s_axi_wready
  // .s_axi_bresp(s_axi_bresp),                    // output wire [1 : 0] s_axi_bresp
  // .s_axi_bvalid(s_axi_bvalid),                  // output wire s_axi_bvalid
  .s_axi_bready('b1),                  // input wire s_axi_bready
  .s_axi_araddr('b0),                  // input wire [11 : 0] s_axi_araddr
  .s_axi_arvalid('b0),                // input wire s_axi_arvalid
  // .s_axi_arready(s_axi_arready),                // output wire s_axi_arready
  // .s_axi_rdata(s_axi_rdata),                    // output wire [31 : 0] s_axi_rdata
  // .s_axi_rresp(s_axi_rresp),                    // output wire [1 : 0] s_axi_rresp
  // .s_axi_rvalid(s_axi_rvalid),                  // output wire s_axi_rvalid
  .s_axi_rready('b1)                 // input wire s_axi_rready
  // .mac_irq(mac_irq)                            // output wire mac_irq
);

eth_top u_eth_top(
	.sys_clk			(rxuserclk2			),
	.reset_n			(i_reset_n			),
	.gmii_rxen			(rx_axis_mac_tvalid	),
	.gmii_rxdat			(rx_axis_mac_tdata	),
	.gmii_txen			(tx_axis_mac_tvalid	),
	.gmii_txdat			(tx_axis_mac_tdata	),	
	.gmii_tlast			(tx_axis_mac_tlast	),	
	
	.local_ip			(local_ip			), // 本机IP
	.local_mac			(local_mac			), // 本机mac
	.dest_ip			(dest_ip			), // 目的IP
	.dest_mac			(dest_mac			), // 目的mac 
			
    .tx_start_en 		(tx_start_en 		), //以太网开始发送信号
    .tx_byte_num 		(tx_byte_num 		), //以太网发送的有效字节数 单位:byte  
    .tx_data     		(tx_data     		), //以太网待发送数据  
	.tx_data_req		(tx_data_req		), //以太网发送数据请求
	.tx_data_done   	(tx_data_done   	), //以太网发送完成信号
	.tx_start_err		(tx_start_err		), //发送数据无响应 只有对方mac未知时生效
	                     
	.rxd_pkt_done		(rxd_pkt_done		),
	.rxd_wr_en			(rxd_wr_en			),
	.rxd_wr_data		(rxd_wr_data		),
	.rxd_wr_byte_num	(rxd_wr_byte_num	)	
);
endmodule

