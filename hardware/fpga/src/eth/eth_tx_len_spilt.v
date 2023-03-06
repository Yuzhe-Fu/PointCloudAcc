`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:     eth_tx_len_spilt
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

module   eth_tx_len_spilt #(
	parameter	SYS_FRE 		= 100,
	parameter	PLOAD_LEN		= 1472  // max 1472
)( 
	input					i_sys_clk,
	input					i_reset_n,
	
	input					s_start,
	input	[31:0]			s_len,
	
	output	reg				m_start,  //发送对应的长度
	input					m_permit,   //允许发送对应的长度
	output	reg [15:0]		m_len,
	
	output					m_done
);	

/***********************************************/
localparam	IDLE		= 0;
localparam	PACK_SPLIT	= 1;
localparam	WAIT		= 2;
localparam	DONE		= 3;

reg [2:0]	fsm_sta;
reg [31:0]	tx_len;

//fsm_1
always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n) begin
		fsm_sta  <= IDLE;
		tx_len   <= 0;
		m_start  <= 0;
		m_len    <= 0;
	end
	else begin
		case(fsm_sta)
			IDLE:begin
				if(s_start) begin
					tx_len <= s_len;
					fsm_sta	<= PACK_SPLIT;
				end
			end
			PACK_SPLIT:begin
				if(tx_len <= PLOAD_LEN) begin
					tx_len 	<= 0;
					m_start <= 1;
					m_len   <= tx_len;
					fsm_sta <= WAIT;
				end
				else begin
					m_start <= 1;
					m_len   <= PLOAD_LEN;
					tx_len  <= tx_len -  PLOAD_LEN;
					fsm_sta <= WAIT;
				end
			end
			WAIT:begin
				if(m_permit) begin
					m_start <= 0;
					if(tx_len != 0)
						fsm_sta	<= PACK_SPLIT;
					else 
						fsm_sta	<= DONE;
				end
			end
			DONE:begin
				fsm_sta <= IDLE;
			end
			default:;
		endcase
	end
end

assign m_done = fsm_sta == DONE;

endmodule

