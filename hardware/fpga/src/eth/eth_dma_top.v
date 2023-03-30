`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: eth_dma_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module   eth_dma_top #(
	parameter	SYS_FRE 		= 100
)( 
	input					i_sys_clk,
	input					i_reset_n,
	
	input		[1:0]		i_eth_st, // 【0】启动  eth_start【1】  0：wr  1：rd		
	input		[31:0]		i_eth_addr,
	input		[31:0]		i_eth_len,

	input					i_rx_valid,
	input					i_rx_done,
	input		[31:0]		i_rx_data,
	
	input					i_tx_data_req,
	input					i_tx_data_done,
	output		[31:0]		o_tx_data,
	output	reg	[31:0]		o_tx_len,
	output	reg				o_tx_start,
	
// dma	
	input					dma_clk,
	input					dma_rstn,
	
	output	reg				wr_req,
	input					wr_ack,
	output	[31:0]			wr_addr,
	output	[31:0]			wr_len,
	output	[31:0]			wr_data,
	input					wr_data_req,
	input					wr_req_done,
	output	reg				wr_data_ready,
		
	output	reg				rd_req,
	input					rd_ack,
	output	[31:0]			rd_addr,
	output	[31:0]			rd_len,
	input	[31:0]			rd_data,
	input	 				rd_data_valid,
	input					rd_req_done,	
	output					rd_data_ready,
		
	input					error_reg,
	input					busy		
);

/***********************************************/
// 时钟域处理
wire [65:0] sfifo_dout;
reg 		sfifo_rden;
wire 		sfifo_empty;

fifo_w66r66 u_fifo_w66r66 (
  .rst		(~i_reset_n			),        // input wire rst
  .wr_clk	(i_sys_clk			),  // input wire wr_clk
  .wr_en	(i_eth_st[0]		),    // input wire wr_en
  .din		({i_eth_st, i_eth_addr,i_eth_len}		),        // input wire [7 : 0] din
  
  .rd_clk	(dma_clk		),  // input wire rd_clk
  .rd_en	(sfifo_rden		),    // input wire rd_en
  .dout		(sfifo_dout		),      // output wire [31 : 0] dout
  .full		(				),      // output wire full
  .empty	(sfifo_empty	)    // output wire empty
);

/***********************************************/
reg 	eth_rxdat_enable;
wire 	eth_rxdat_done;

always @(posedge i_sys_clk ) begin
	if(!i_reset_n) 
		eth_rxdat_enable <= 0;
	else if(i_eth_st[0] && !i_eth_st[1]) begin  // wr
		eth_rxdat_enable <= 1;
	end
	else if(eth_rxdat_done)
		eth_rxdat_enable <= 0;
	else 
		;
end

/***********************************************/
reg [31:0] eth_rx_data_cnt;

always @(posedge i_sys_clk ) begin
	if(!i_reset_n) 
		eth_rx_data_cnt <= 0;
	else if(eth_rxdat_enable)
		if(i_rx_valid)
			eth_rx_data_cnt <= eth_rx_data_cnt + 4;
		else 
			;
	else 
		eth_rx_data_cnt <= 0;
end

assign eth_rxdat_done = eth_rx_data_cnt >= i_eth_len && eth_rx_data_cnt > 0;

/***********************************************/
wire [12:0] wr_fifo_rd_count;

fifo_eth_cache u_eth_rx_buff (
  .rst			(~i_reset_n		),        // input wire rst
  .wr_clk		(i_sys_clk		),  // input wire wr_clk
  .wr_en		(eth_rxdat_enable & i_rx_valid),    // input wire wr_en
  .din			(i_rx_data		),        // input wire [7 : 0] din
	
  .rd_clk		(dma_clk		),  // input wire rd_clk
  .rd_en		(wr_data_req	),    // input wire rd_en
  .dout			(wr_data		),      // output wire [31 : 0] dout
  .full			(				),      // output wire full
  .empty		(				),    // output wire empty
  .rd_data_count(wr_fifo_rd_count)
);

/***********************************************/
localparam	IDLE	= 0;
localparam	F_RD0	= 1;
localparam	F_RD1	= 2;
localparam	F_RD2	= 3;
localparam	F_WR0	= 4;
localparam	F_WR1	= 5;
localparam	F_WR2	= 6;

reg [2:0]	fsm_sta;
reg [65:0]	buff;

//fsm_1
always @(posedge dma_clk or negedge dma_rstn) begin
	if(!dma_rstn) begin
		fsm_sta <= IDLE;
		sfifo_rden <= 0;
		buff <= 0;
		wr_req	<= 0;
		rd_req	<= 0;
		// wr_data_ready	<= 0;
	end
	else begin
		sfifo_rden <= 0;
		case(fsm_sta)
			IDLE:begin
				if(sfifo_empty == 0) begin
					sfifo_rden  <= 1;
					fsm_sta		<= sfifo_dout[65] ? F_RD0 : F_WR0;
					buff		<= sfifo_dout; //eth_start【1】  0：wr  1：rd	
				end
				wr_req	<= 0;
				rd_req	<= 0;
				// wr_data_ready	<= 0;
			end
			F_WR0:begin
				fsm_sta	<= F_WR1;
				wr_req	<= 1;
			end
			F_WR1:begin
				if(wr_ack) begin
					wr_req  <= 0;
					fsm_sta	<= F_WR2;
				end
				else begin
					fsm_sta <= F_WR1;
				end
			end
			F_WR2:begin
				if(wr_req_done)
					fsm_sta	<= IDLE;
				else 
					fsm_sta <= F_WR2;
			end
		/***********************************************/
			F_RD0:begin
				fsm_sta	<= F_RD1;
				rd_req	<= 1;
			end
			F_RD1:begin
				if(rd_ack) begin
					rd_req  <= 0;
					fsm_sta	<= F_RD2;
				end
				else begin
					fsm_sta <= F_RD1;
				end
			end
			F_RD2:begin
				if(rd_req_done)
					fsm_sta	<= IDLE;
				else 
					fsm_sta <= F_RD2;
			end
			default:;
		endcase
	end
end

reg data_recv_done = 0;

always @(posedge dma_clk) begin
	if(wr_fifo_rd_count >= 1472/4 || data_recv_done)
		wr_data_ready <= 1;
	else 
		wr_data_ready <= 0;
	
	if(wr_req_done)	
		data_recv_done <= 0;
	else if(eth_rxdat_done)
		data_recv_done <= 1;
	
end

assign wr_addr = buff[63:32];
assign wr_len  = buff[31:0];
assign rd_addr = buff[63:32];
assign rd_len  = buff[31:0];

/***********************************************/
// ddr 数据先写入FIFO
wire [12:0]	rd_fifo_rd_count;

fifo_eth_cache u_eth_tx_buff (
  .rst				(~i_reset_n			),        // input wire rst
  .wr_clk			(dma_clk			),  // input wire wr_clk
  .wr_en			(rd_data_valid		),    // input wire wr_en
  .din				(rd_data			),        // input wire [7 : 0] din
			
  .rd_clk			(i_sys_clk			),  // input wire rd_clk
  .rd_en			(i_tx_data_req		),    // input wire rd_en
  .dout				(o_tx_data			),      // output wire [31 : 0] dout
  .full				(					),      // output wire full
  .empty			(					),    // output wire empty
  .rd_data_count	(rd_fifo_rd_count	)
);

wire [15:0] eth_spilt_len;
wire 		eth_spilt_st;
reg 		eth_spilt_permit;

reg [7:0]  rd_req_f;

always @(posedge dma_clk) begin
	rd_req_f <= {rd_req_f,rd_req};
end


eth_tx_len_spilt #(
	.PLOAD_LEN		(1400				)  // max 1472
)u_eth_tx_len_spilt( 
	.i_sys_clk		(i_sys_clk			),
	.i_reset_n		(i_reset_n			),
			
	.s_start		(rd_req_f != 0		),
	.s_len			(rd_len				),
	
	.m_start		(eth_spilt_st		),  //发送对应的长度
	.m_permit		(eth_spilt_permit	),   //允许发送对应的长度
	.m_len			(eth_spilt_len		),
	.m_done			(					)
);	

reg [2:0]	curr_sta;

//fsm_1
always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n) begin
		curr_sta 			<= 0;
		o_tx_len 			<= 0;
		o_tx_start 			<= 0;
		eth_spilt_permit 	<= 0;
	end
	else begin
		o_tx_start			<= 0;
		eth_spilt_permit	<= 0;
		case(curr_sta)
			0:begin
				if(eth_spilt_st) begin
					curr_sta <= 1;
				end
				else 
					curr_sta <= 0;
			end
			1:begin
				if({rd_fifo_rd_count,2'b0} >= eth_spilt_len) begin
					curr_sta	<= 2;
					o_tx_start  <= 1;
					o_tx_len    <= eth_spilt_len;
				end
			end
			2:begin
				eth_spilt_permit	<= 1;
				curr_sta		<= 3;
			end
			3:begin
				if(i_tx_data_done)
					curr_sta <= 0;
			end
			default:;
		endcase
	end
end

assign rd_data_ready = rd_fifo_rd_count < 3000;

endmodule


