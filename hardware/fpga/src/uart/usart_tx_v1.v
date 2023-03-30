`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:    usart_tx_v1
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

module  usart_tx_v1 #(
	parameter	SYS_FRE 		= 50,
	parameter	CHACK_WAY		= 0    // 0 无校验 1：奇校验 2：偶校验 
)( 
	input					i_sys_clk,
	input					i_reset_n,
	input					i_bps_en,
	
	
	input					i_start,
	input		[7:0]		i_data,
	output		reg			o_usart_tx,
	
	output		reg			o_busy,
	output					o_done
);

/***********************************************/
localparam 	BAUD_DIV 		= 4'hf;
localparam 	TX_BIT_WIDTH 	= 4'd7;
localparam	IDLE       		=  5'B00001,
			START_BIT  		=  5'B00010,
			SEND_DATA  		=  5'B00100,
			PARITY_BIT 		=  5'B01000,
			STOP_BIT   		=  5'B10000;
reg	[4 :0]	curr_sta,next_sta;
reg [3 :0] 	tx_bit_cnt;
reg [3 :0]	cnt;

// FMS_1
always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n)
		curr_sta <= IDLE;
	else 
		curr_sta <= next_sta;
end


// FSM_2
always @(*) begin
	next_sta = IDLE;
	case(curr_sta)
		IDLE : 
			if(i_start)
				next_sta = START_BIT;
			else 
				next_sta = IDLE;
		START_BIT : 
			if(cnt == BAUD_DIV) 
				next_sta = SEND_DATA;
			else 
				next_sta = START_BIT;
		SEND_DATA:
			if(tx_bit_cnt == TX_BIT_WIDTH && cnt == BAUD_DIV)
				if(CHACK_WAY == 0)
					next_sta = STOP_BIT;
				else 
					next_sta = PARITY_BIT;
			else
				next_sta = SEND_DATA;
		PARITY_BIT:
			if(cnt == BAUD_DIV) 
				next_sta = STOP_BIT;
			else 
				next_sta = PARITY_BIT;
		STOP_BIT:
			if(cnt == BAUD_DIV) 
				next_sta = IDLE;
			else 
				next_sta = STOP_BIT;
		default:;
	endcase
end

//FSM_3
always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n) begin
		tx_bit_cnt <= 0;
		cnt <= 0;
		o_usart_tx <= 1;
		o_busy <= 0;
	end
	else if(i_bps_en) begin
		cnt <= cnt + 1;
		case(curr_sta)
			IDLE: begin
				o_usart_tx <= 1;
				o_busy <= 0;
				tx_bit_cnt <= 0;
				cnt <= 0;
			end
			START_BIT:begin
				o_usart_tx <= 0;
				o_busy <= 1;
				tx_bit_cnt <= 0;
			end
			SEND_DATA:begin
				if(cnt == BAUD_DIV) begin
					tx_bit_cnt <= tx_bit_cnt + 1;
				end
				else 
					;
				o_usart_tx <= i_data[tx_bit_cnt];
				o_busy <= 1;
			end
			PARITY_BIT:begin
				case (CHACK_WAY[1:0])
					1,3 :o_usart_tx <= ~^i_data;
					2,0 :o_usart_tx <=  ^i_data;
					default:o_usart_tx <= 1;
				endcase
				o_busy <= 1;
			end
			STOP_BIT:begin
				o_usart_tx <= 1;
				o_busy <= 1;
			end
			default: begin
				o_busy <= 1;
				cnt <= 0;
				tx_bit_cnt <= 0;
				o_usart_tx <= 1;
			end
		endcase
	end	
	else if(curr_sta != next_sta)
		cnt <= 0;
	else 
		;
end

get_sig_edge_for_uart_tx get_done(
	.i_sys_clk		(i_sys_clk	),
    .i_sig			(o_busy		),
	.o_sig_dn		(o_done		)
);

// debug

always @(posedge i_sys_clk ) begin
	if(i_start) begin
		case (CHACK_WAY[1:0])
			1,3 :$display("PARITY_BIT code  %x",~^i_data);
			2,0 :$display("PARITY_BIT code  %x",^i_data);
			default:;
		endcase
	end
end


endmodule

/*#############################################################*/
/*#############################################################*/
/*#############################################################*/
/*#############################################################*/
module  get_sig_edge_for_uart_tx #(
	parameter	SYS_FRE 		= 50,
	parameter   DELAY_CYCLE     = 0
)( 
	input					i_sys_clk,
    input                   i_sig,
 
    output                  o_sig_up,
    output                  o_sig_dn
);


generate
/*#############################################################*/
if(DELAY_CYCLE <= 1) begin
	reg sig_f;
	
	always @(posedge i_sys_clk ) begin
			
		sig_f <= i_sig;
	end
	
	assign o_sig_dn = sig_f & (!i_sig);
	assign o_sig_up = (!sig_f) & i_sig;
end
else begin
/*#############################################################*/
	reg [DELAY_CYCLE-1:0]sig_ff;
	
	always @(posedge i_sys_clk ) begin
		sig_ff <= {sig_ff[DELAY_CYCLE-2:0],i_sig};
	end
	
	assign o_sig_dn = sig_ff[DELAY_CYCLE-1-:2] == 2'b10;
	assign o_sig_up = sig_ff[DELAY_CYCLE-1-:2] == 2'b01;
end

endgenerate

endmodule
