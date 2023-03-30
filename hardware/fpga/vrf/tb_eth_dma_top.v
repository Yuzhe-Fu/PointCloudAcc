`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:      tb_eth_dma_top 
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

module  tb_eth_dma_top ;

/***********************************************/
localparam		SYS_FRE 	= 100;
localparam		AXI_CLK 	= 200;

/***********************************************/
reg i_reset_n,i_axi_clk,i_axi_reset_n,
	i_sys_clk;
	
always #(1000/2/SYS_FRE) i_sys_clk = ~i_sys_clk;
always #(1000/2/AXI_CLK) i_axi_clk = ~i_axi_clk;

initial begin
	i_sys_clk = 0;
	i_reset_n = 0;
	repeat(10) 
		@(posedge i_sys_clk);
	i_reset_n = 1;
end

initial begin
	i_axi_clk 		= 0;
	i_axi_reset_n 	= 0;
	repeat(10) 
		@(posedge i_axi_clk);
	i_axi_reset_n 	= 1;
end
 
/***********************************************/
/***********************************************/
reg 		uart_rx_en = 0;
reg [7:0] 	uart_rx_data = 0;

wire [1:0]	eth_st;
wire [31:0]	eth_addr;
wire [31:0]	eth_len;


user_cmd_pro #(
	.SYS_FRE 			(SYS_FRE		)
)uut1( 
	.i_sys_clk			(i_sys_clk		),
	.i_reset_n			(i_reset_n		),
	
	.i_rx_valid			(uart_rx_en		),
	.i_rx_data			(uart_rx_data	),

	.o_eth_addr			(eth_addr		),
	.o_eth_len	        (eth_len		),
	.o_eth_st	        (eth_st			)
	// .o_src_ip			(src_ip			),
	// .o_src_mac          (src_mac		),
	// .o_des_ip	        (des_ip			),
	// .o_des_mac          (des_mac 		)
	
);


localparam MEM_LEN = 40960;
reg [31:0] mem [MEM_LEN-1:0] ;

wire 			wr_req;
reg 			wr_ack;
wire 	[31:0]	wr_addr;
wire 	[31:0]	wr_len;
wire 	[31:0]	wr_data;
reg 			wr_data_req;
reg 			wr_req_done;
wire 			wr_data_ready;

wire 			rd_req;
reg 			rd_ack;
wire 	[31:0]	rd_addr;
wire 	[31:0]	rd_len;
reg 	[31:0]	rd_data;
reg 			rd_data_valid;
reg 			rd_req_done;
wire 			rd_data_ready;


reg 		eth_rx_valid = 0;
reg 		eth_rx_done	 = 0;
reg [31:0]	eth_rx_data	 = 0;
wire		eth_tx_st;
reg 		eth_tx_valid;
wire 		eth_tx_done;
wire [31:0]	eth_tx_len;
wire [31:0]	eth_tx_data;

eth_dma_top u_eth_dma_top( 
	.i_sys_clk			(i_sys_clk			),
	.i_reset_n			(i_reset_n			),
		
	.i_eth_st			(eth_st				), // 【0】启动  eth_start【1】  0：wr  1：rd		
	.i_eth_addr			(eth_addr			),
	.i_eth_len			(eth_len			),
	
	.i_rx_valid			(eth_rx_valid		),
	.i_rx_done			(eth_rx_done		),
	.i_rx_data			(eth_rx_data		),
		
	.i_tx_data_req		(eth_tx_valid		),	
	.i_tx_data_done		(eth_tx_done		),
	.o_tx_data			(eth_tx_data		),
	.o_tx_len			(eth_tx_len			),
	.o_tx_start			(eth_tx_st			),
	
// dma	
	.dma_clk			(i_axi_clk			),
	.dma_rstn			(i_axi_reset_n		),
	
	.wr_req				(wr_req				),
	.wr_ack				(wr_ack				),
	.wr_addr			(wr_addr			),
	.wr_len				(wr_len				),
	.wr_data			(wr_data			),
	.wr_data_req		(wr_data_req		),
	.wr_req_done		(wr_req_done		),
	.wr_data_ready		(wr_data_ready		),
		
	.rd_req				(rd_req				),
	.rd_ack             (rd_ack          	),
	.rd_addr            (rd_addr         	),
	.rd_len             (rd_len          	),
	.rd_data            (rd_data         	),
	.rd_data_valid      (rd_data_valid   	),
	.rd_req_done	    (rd_req_done	 	),
	.rd_data_ready      (rd_data_ready   	)
		
	// input					error_reg,
	// input					busy		
);

reg [31:0] eth_tx_cnt;

always @(posedge i_sys_clk ) begin
	if(!i_reset_n) begin 
		eth_tx_valid <= 0;
		eth_tx_cnt <= 0;
	end
	else if(eth_tx_done) begin
		eth_tx_valid <= 0;
		eth_tx_cnt   <= 0;
	end
	else if(eth_tx_st) begin
		eth_tx_valid <= 1;
		eth_tx_cnt  <= 4;
	end
	else if(eth_tx_valid)
		eth_tx_cnt <= eth_tx_cnt + 4;
end

assign eth_tx_done =  eth_tx_cnt >= eth_tx_len && eth_tx_cnt > 0;

// wr 
always @(posedge i_axi_clk ) begin
	if(!i_axi_reset_n) 
		wr_ack <= 0;
	else if(wr_req & wr_data_ready)
		wr_ack <= 1;
	else 
		wr_ack <= 0;
				
end

always @(posedge i_axi_clk ) begin
	if(!i_axi_reset_n) 
		rd_ack <= 0;
	else if(rd_req & rd_data_ready)
		rd_ack <= 1;
	else 
		rd_ack <= 0;
end

/***********************************************/
reg [31:0] addr_buff;
reg [31:0] wr_cnt_buff;

reg  [7:0] fsm_sta;
reg  [11:0] cnt0;

always @(posedge i_axi_clk ) begin
	if(!i_axi_reset_n) begin 
		addr_buff <= 0;
		fsm_sta 		<= 0;
		cnt0 		<= 0;
		wr_cnt_buff <= 0;
		wr_data_req <= 0;
		wr_req_done <= 0;
		rd_data_valid <= 0;
		rd_req_done <= 0;
		rd_data 	<= 0;
	end
	else begin
		wr_data_req <= 0;
		wr_req_done <= 0;
		rd_data_valid <= 0;
		rd_req_done <= 0;
		
		case (fsm_sta)
			0: begin
				if(wr_req & wr_data_ready) begin
					addr_buff 	<= wr_addr;
					wr_cnt_buff <= wr_len;
					fsm_sta 	<= 1;
					cnt0 		<= 0;
				end
				
				if(rd_req & rd_data_ready) begin
					addr_buff 	<= rd_addr;
					wr_cnt_buff <= rd_len;
					fsm_sta 	<= 11;
					cnt0 		<= 0;
				end
				
			end
			1: begin
				if(wr_cnt_buff >= 1400) begin
					wr_cnt_buff <= wr_cnt_buff - 1400;
					fsm_sta 	<= 2;
					cnt0    	<= 1400;
				end
				else begin
					wr_cnt_buff <= 0;
					fsm_sta 	<= 2;
					cnt0    	<= wr_cnt_buff;
				end
			end
			2:begin
				cnt0 <= cnt0 - 4;
				
				if(cnt0 <= 4) begin
					fsm_sta <= 3;
				end
				
				addr_buff <= addr_buff + 1;

				wr_data_req <= 1;
			end
			3:begin
				if(wr_cnt_buff == 0)
					fsm_sta <= 4;
				else if(wr_data_ready)
					fsm_sta <=  1;
			end
			4:begin
				wr_req_done <= 1;
				fsm_sta 	<= 0;
			end

			/***********************************************/
			11: begin
				if(wr_cnt_buff >= 1400) begin
					wr_cnt_buff <= wr_cnt_buff - 1400;
					fsm_sta 	<= 12;
					cnt0    	<= 1400;
				end
				else begin
					wr_cnt_buff <= 0;
					fsm_sta 	<= 12;
					cnt0    	<= wr_cnt_buff;
				end
			end
			12:begin
				cnt0 <= cnt0 - 4;
				
				if(cnt0 <= 4) begin
					fsm_sta <= 13;
				end
				
				addr_buff <= addr_buff + 1;
				rd_data <= mem[addr_buff % MEM_LEN] ;
				rd_data_valid <= 1;
			end
			13:begin
				if(rd_data_ready)
					if(wr_cnt_buff == 0)
						fsm_sta <= 14;
					else 
						fsm_sta <=  11;
			end
			14:begin
				rd_req_done <= 1;
				fsm_sta 	<= 0;
			end
			
		endcase
	
	end
end

// wr 
always @(posedge i_axi_clk ) begin
		
	if(wr_data_req)
		mem[(addr_buff - 1) % MEM_LEN] <= wr_data;
					
end

initial begin
/* 添加仿真代码在这里 */
	repeat(20) 
		@(posedge i_sys_clk);
		
	uart_send_str(0,100);
	uart_send_str(1,3000);
	uart_send_str(2,1); //wr
	
	@(posedge i_sys_clk);
	eth_rx_data = 0;
	
	repeat(3000/4) begin
		@(posedge i_sys_clk);
			eth_rx_valid   <= 1;
			eth_rx_data   <= eth_rx_data +1;
		@(posedge i_sys_clk);
			eth_rx_valid   <= 0;
	end
	
	eth_rx_done <= 1;
	@(posedge i_sys_clk)
	eth_rx_done <= 0;
	
	repeat(500) 
		@(posedge i_sys_clk);
	
	uart_send_str(0,100);
	uart_send_str(1,3000);
	uart_send_str(2,3); //rd
end

/******************************************************************************************/
task uart_send_char;
	input [7:0] a;
	begin
		@(posedge i_sys_clk);
			uart_rx_en   <= 1;
			uart_rx_data <= a;
		@(posedge i_sys_clk);
			uart_rx_en <= 0;
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

endmodule