`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:     uart_tx_queue
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

module   uart_tx_queue #(
	parameter	SYS_FRE 		= 100
)( 
	input					i_sys_clk,
	input					i_reset_n,
	
	input					i_rx_clk,
	input					i_rx_valid,
	input	[31:0]			i_rx_data,
	output					o_rfifo_pfull,
	
	input					i_tx_busy,
	output	reg				o_tx_start,
	output	reg[7:0]		o_tx_data
);



localparam	IDLE	= 0;
localparam	WITE	= 1;
localparam	DONE	= 2;

reg [2:0]	fsm_sta;

wire 		fifo_empty;
reg  		fifo_rden;
wire [7:0] 	fifo_dout;

reg [1:0] busy_f;

always @(posedge i_sys_clk) begin
	busy_f <= {busy_f,i_tx_busy};
end

//fsm_1
always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n) begin
		fsm_sta <= IDLE;
		o_tx_start <= 0;
		o_tx_data <= 0;
		fifo_rden <= 0;
	end
	else begin
		fifo_rden <= 0;
		o_tx_start <= 0;
		case(fsm_sta)
			IDLE:begin
				if(fifo_empty == 0) begin
					fifo_rden <= 1;
					o_tx_start <= 1;
					o_tx_data <= fifo_dout;
					fsm_sta	 <= WITE;
				end
			end
			WITE:begin
				if(busy_f == 2)
					fsm_sta	<= DONE;
			end
			DONE:begin
				fsm_sta	<= IDLE;
			end
			default:;
		endcase
	end
end


fifo_w32r8 u_fifo_w32r8 (
  .rst(~i_reset_n),              // input wire rst
  .wr_clk(i_rx_clk),        // input wire wr_clk
  .din(i_rx_data),              // input wire [31 : 0] din
  .wr_en(i_rx_valid),          // input wire wr_en
  
  .rd_clk(i_sys_clk),        // input wire rd_clk
  .rd_en(fifo_rden),          // input wire rd_en
  .dout(fifo_dout),            // output wire [7 : 0] dout
  // .full(fifo_full	),            // output wire full
  .empty(fifo_empty),          // output wire empty
  .prog_full(o_rfifo_pfull)  // output wire prog_full
);

endmodule

