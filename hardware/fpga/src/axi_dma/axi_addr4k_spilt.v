`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 		UESTCOC
// Engineer: 		Deam
// 
// Create Date: 
// Design Name:     
// Module Name:     axi_addr4k_spilt 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module axi_addr4k_spilt #(
	parameter		ADDR_WIDTH = 32,
	parameter		DATA_WIDTH = 32
)(
	input							sys_clk,
	input							reset_n,
	
	input							s_req,
	output	reg						s_ack,
	input		[ADDR_WIDTH-1:0]	s_addr,
	input		[31:0]				s_len,
	output							s_req_done,
	input							s_ready,
	
	output	reg						m_req,
	input							m_ack,
	output	reg [ADDR_WIDTH-1:0]	m_addr,
	output	reg [8:0]				m_len,
	input							m_req_done
);

/****************************************************/
localparam	IDLE		= 4'd1;
localparam	SPILT		= 4'd2;
localparam	WAIT		= 4'd3;
localparam	DONE		= 4'd4;

reg [3:0]	fsm_sta;
reg [31:0]	len;

// wire [31:0] temp = ({1'b1,12'b0} - {1'b0,s_addr[11:0]});// / ;
wire [15:0] temp = ({1'b1,12'b0} - {1'b0,s_addr[11:0]}) /(DATA_WIDTH/8);
reg [15:0]	cache;
 
// fsm
always @(posedge sys_clk or negedge reset_n) begin
	if(reset_n == 1'b0 ) begin
		fsm_sta <= IDLE;
		m_req 	<= 0;
		m_addr 	<= 0;
		m_len 	<= 0;
		len 	<= 0;
		cache 	<= 0;
		// s_ack 	<= 0;
	end
	else begin
		// s_ack 	<= 0;
		
		case(fsm_sta)
			IDLE:begin
				if(s_req && s_len > 0 && s_ready) begin
					// s_ack 	<= 1;
					if(s_addr[11:0] == 0) begin  // 4k 
						if(s_len > 256) begin
							m_req   <= 1;
							m_len   <= 256;
							m_addr  <= s_addr;
							len		<= s_len - 256;
							fsm_sta	<= WAIT;
						end
						else begin
							m_req  <= 1;
							m_len  <= s_len;
							m_addr <= s_addr;
							len		<= 0;
							fsm_sta	<= WAIT;
						end
						cache	<= 0;
					end
					else begin
						m_req   <= 1;
						
						if(s_len > 256) begin
							if(temp > 256) begin
								m_len <= 256;
								cache <= temp - 256;
								len   <= s_len - 256;
							end
							else begin
								m_len <= temp;
								cache <= 0;
								len   <= s_len - temp;
							end
						end
						else begin
							if(temp > s_len) begin
								m_len <= s_len;
								cache <= 0;
								len   <= 0;
							end
							else begin
								m_len <= temp;
								cache <= 0;
								len   <= s_len - temp;
							end
						end
						m_addr  	<= s_addr;
						fsm_sta		<= WAIT;
					end
				end
			end
			WAIT:begin
				if(m_ack)
					m_req <= 0;
					
				if(m_req_done)
					if(len == 0)
						fsm_sta	<= DONE;
					else 
						fsm_sta <= SPILT;
			end
			SPILT:begin
				if(s_ready) begin
					m_req	<= 1;
					
					if(len > 256) begin
						if(cache == 0) begin
							len 	<= len - 256;
							m_len 	<= 256;
						end
						else if(cache > 256) begin
							cache 	<= cache - 256;
							len   	<= len - 256;
							m_len 	<= 256;
						end
						else begin
							len		<= len -cache;
							cache	<= 0;
							m_len	<= cache;
						end
					end
					else begin
						if(cache == 0) begin
							m_len 	<= len;
							len		<= 0;
						end
						else if(cache > len) begin
							cache 	<= cache - len;
							len   	<= 0;
							m_len 	<= len;
						end
						else begin
							len		<= len -cache;
							cache	<= 0;
							m_len	<= cache;
						end
					end				
					
					m_addr	<= m_addr + m_len * (DATA_WIDTH/8);
					fsm_sta	<= WAIT;
				end
			end
			DONE:begin
				fsm_sta	<= IDLE;
			end
			default:;
		endcase
	end
end

always @(posedge sys_clk ) begin
	if(reset_n == 1'b0 ) begin
		s_ack <= 0;
	end
	else if(~s_ack && s_req && (fsm_sta != IDLE))
		s_ack <= 1;
	else 
		s_ack  <= 0;
		
end

assign s_req_done = fsm_sta == DONE;

/****************************************************/
function integer calc_width(input integer i);
	begin
		calc_width = 0;
		
		while(i>0) begin
			i = i >> 1;
			calc_width = calc_width + 1;
		end
		calc_width = calc_width - 1;
	end
endfunction

endmodule
