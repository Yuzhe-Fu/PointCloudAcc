`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:    usart_rx_v1
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

module  usart_rx_v1 #(
	parameter	SYS_FRE 		= 50,
	parameter	CHACK_WAY		= 0 // 0 无校验 1：奇校验 2：偶校验 
)( 
	input					i_sys_clk,
	input					i_reset_n,
	input					i_bps_en,
	
	
	input					i_usart_rx,
	output	reg	[7:0]		o_data,
	
	output		reg 		o_err,
	output		reg			o_busy,
	output					o_done
);

/***********************************************/
reg [1:0]usart_in_f;
reg 	usart_in_ff;
always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n)
		usart_in_f <= -1;
	else if(i_bps_en)
	// else
		usart_in_f <= {usart_in_f[0],usart_in_ff};
	// else
		// ;

end

always @(posedge i_sys_clk ) begin
	usart_in_ff <= i_usart_rx;
end

/***********************************************/

localparam 	BAUD_DIV 		= 4'hf;
localparam 	RX_BIT_WIDTH 	= CHACK_WAY == 0 ? 4'b1000 : 4'b1001;
localparam  IDLE        	= 4'b0001,
			RECV_START  	= 4'b0010,
			RECV_DATA   	= 4'b0100,
			RECV_STOP   	= 4'b1000;

reg [3:0]	curr_sta,next_sta;
reg	[3:0]	cnt;
reg	[3:0]	rx_bit_cnt;									   
// FMS_1
always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n)
		curr_sta <= IDLE;
	else if(i_bps_en)
		curr_sta <= next_sta;
	else
		;
end

// FMS_2
always @(*)begin
	next_sta = IDLE;
	case(curr_sta)
		IDLE:
			if(usart_in_f == 2'b10)
				next_sta = RECV_START;
			else 
				next_sta = IDLE;
		RECV_START:
			if(cnt == BAUD_DIV - 1)
				next_sta = RECV_DATA;
			else 
				next_sta = RECV_START;
		RECV_DATA:
			if((cnt == BAUD_DIV ) &&(rx_bit_cnt == RX_BIT_WIDTH - 1))
				next_sta = RECV_STOP;
			else 
				next_sta = RECV_DATA;
		RECV_STOP:begin
			next_sta = IDLE;
		end
		default: begin
			next_sta = IDLE;
		end
	endcase
end

// FMS_3
reg [RX_BIT_WIDTH -1:0]rx_data_f;
wire mul_sim_dat;

always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n) begin
		cnt <= 0;
		rx_bit_cnt <= 0;
		o_data <= 0;
		o_busy <= 0;
		rx_data_f <= 0;
		o_err     <= 0;
	end
	else if(i_bps_en) begin
		cnt    <= 0;
		o_busy <= 1;
		o_err  <= 0;
		case (curr_sta)
			IDLE: begin
				rx_bit_cnt <= 0;
				rx_data_f <= 0;
				o_busy <= 0;
			end
			RECV_START:begin
				rx_bit_cnt <= 0;
				rx_data_f <= 0;
				if(cnt == BAUD_DIV - 1)
					cnt <= 0;
				else 
					cnt <= cnt + 1;
			end
			RECV_DATA:begin
				cnt <= cnt + 1;
				if(cnt == BAUD_DIV) begin
					rx_bit_cnt <= rx_bit_cnt + 1;
					rx_data_f <= {mul_sim_dat,rx_data_f[RX_BIT_WIDTH-1:1]};
				end
				else 
					;
			end
			RECV_STOP:begin
				case(CHACK_WAY[1:0])
					0:
						o_err  <= 0;
					1,3:
						if((~^rx_data_f[7:0]) == rx_data_f[8])
							o_err <= 0;
						else 
							o_err <= 1;
					2:	
						if(^rx_data_f[7:0]    == rx_data_f[8])
							o_err <= 0;
						else 
							o_err <= 1;
					default:;
				endcase
				o_data <= rx_data_f[7:0];
			end
			default:;
		endcase
	end	
end

/***********************************************/
reg [3:0]mul_sample;

always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n) begin
		mul_sample <= 0;
	end
	else if(i_bps_en && (curr_sta == RECV_DATA)) begin
		if(cnt < BAUD_DIV)
			if(usart_in_f[1])
				mul_sample <= mul_sample + 1;
			else 
				mul_sample <= mul_sample;
		else
			mul_sample <= 0;
	end
	else if(curr_sta == RECV_START)
		mul_sample <= 0;
	else 
		mul_sample <= mul_sample;
end

assign mul_sim_dat = (mul_sample > 8);

/***********************************************/
get_sig_edge_for_uart_rx get_done(
	.i_sys_clk		(i_sys_clk	),
    .i_sig			(o_busy		),
	.o_sig_dn		(o_done		)
);

endmodule

/*#############################################################*/
/*#############################################################*/
/*#############################################################*/
/*#############################################################*/

module  get_sig_edge_for_uart_rx #(
	parameter	SYS_FRE 		= 50,
	parameter   DELAY_CYCLE     = 0
)( 
	input					i_sys_clk,
    input                   i_sig,
 
    output                  o_sig_up,
    output                  o_sig_dn
);


generate
/*####################################################################################*/
if(DELAY_CYCLE <= 1) begin
	reg sig_f;
	
	always @(posedge i_sys_clk ) begin
			
		sig_f <= i_sig;
	end
	
	assign o_sig_dn = sig_f & (!i_sig);
	assign o_sig_up = (!sig_f) & i_sig;
end
else begin
/*####################################################################################*/
	reg [DELAY_CYCLE-1:0]sig_ff;
	
	always @(posedge i_sys_clk ) begin
		sig_ff <= {sig_ff[DELAY_CYCLE-2:0],i_sig};
	end
	
	assign o_sig_dn = sig_ff[DELAY_CYCLE-1-:2] == 2'b10;
	assign o_sig_up = sig_ff[DELAY_CYCLE-1-:2] == 2'b01;
end

endgenerate

endmodule
