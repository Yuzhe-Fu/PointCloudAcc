`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:     uart_dma_top
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

module   uart_dma_top #(
	parameter	SYS_FRE 		= 100
)( 
	input					i_sys_clk,
	input					i_reset_n,
	
	input		[1:0]		i_uart_st, // 【0】启动  eth_start【1】  0：wr  1：rd		
	input		[31:0]		i_uart_addr,
	input		[31:0]		i_uart_len,
	
	input					i_rx_valid,
	input		[7:0]		i_rx_data,
	output					o_tx_start,
	input					i_tx_busy,
	output		[7:0]		o_tx_data,
	
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
//	
);

/***********************************************/
// 时钟域处理
wire [65:0] sfifo_dout;
reg 		sfifo_rden;
wire 		sfifo_empty;

fifo_w66r66 u_fifo_w66r66 (
  .rst		(~i_reset_n		),        // input wire rst
  .wr_clk	(i_sys_clk		),  // input wire wr_clk
  .wr_en	(i_uart_st[0]	),    // input wire wr_en
  .din		({i_uart_st, i_uart_addr,i_uart_len}		),        // input wire [7 : 0] din
  
  .rd_clk	(dma_clk		),  // input wire rd_clk
  .rd_en	(sfifo_rden		),    // input wire rd_en
  .dout		(sfifo_dout		),      // output wire [31 : 0] dout
  .full		(				),      // output wire full
  .empty	(sfifo_empty	)    // output wire empty
);

/***********************************************/
reg 	uart_rxdat_enable;
wire 	uart_rxdat_done;

always @(posedge i_sys_clk ) begin
	if(!i_reset_n) 
		uart_rxdat_enable <= 0;
	else if(i_uart_st[0] && !i_uart_st[1]) begin  // wr
		uart_rxdat_enable <= 1;
	end
	else if(uart_rxdat_done)
		uart_rxdat_enable <= 0;
	else 
		;
end

/***********************************************/
reg [31:0] uart_rx_data_cnt;

always @(posedge i_sys_clk ) begin
	if(!i_reset_n) 
		uart_rx_data_cnt <= 0;
	else if(uart_rxdat_enable)
		if(i_rx_valid)
			uart_rx_data_cnt <= uart_rx_data_cnt + 1;
		else 
			;
	else 
		uart_rx_data_cnt <= 0;
end

assign uart_rxdat_done = uart_rx_data_cnt >= i_uart_len && uart_rx_data_cnt > 0 ;

/***********************************************/
wire [10:0] rd_count;

fifo_generator_w8r32 u_uart_rx_buff (
  .rst			(~i_reset_n		),        // input wire rst
  .wr_clk		(i_sys_clk		),  // input wire wr_clk
  .wr_en		(uart_rxdat_enable & i_rx_valid),    // input wire wr_en
  .din			(i_rx_data		),        // input wire [7 : 0] din
	
  .rd_clk		(dma_clk		),  // input wire rd_clk
  .rd_en		(wr_data_req	),    // input wire rd_en
  .dout			(wr_data		),      // output wire [31 : 0] dout
  .full			(full			),      // output wire full
  .empty		(empty			),    // output wire empty
  .rd_data_count(rd_count 		)
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
	if(data_recv_done || rd_count >= 256)
		wr_data_ready <= 1;
	else 
		wr_data_ready <= 0;
		
	if(wr_req_done)	
		data_recv_done <= 0;
	else if(uart_rxdat_done)
		data_recv_done <= 1;
end


assign wr_addr = buff[63:32];
assign wr_len  = buff[31:0] / 4;
assign rd_addr = buff[63:32];
assign rd_len  = buff[31:0] / 4;

/***********************************************/
wire rfifo_pfull;

uart_tx_queue #(
	.SYS_FRE 			(SYS_FRE		)
)u_uart_tx_queue( 	
	.i_sys_clk			(i_sys_clk		),
	.i_reset_n			(i_reset_n		),
	
	.i_rx_clk			(dma_clk		),
	.i_rx_valid			(rd_data_valid	),
	.i_rx_data			(rd_data		),
	.o_rfifo_pfull		(rfifo_pfull	),
	
	.i_tx_busy			(i_tx_busy		),
	.o_tx_start			(o_tx_start		),
	.o_tx_data		    (o_tx_data		)
);	

assign rd_data_ready = ~rfifo_pfull;

endmodule


