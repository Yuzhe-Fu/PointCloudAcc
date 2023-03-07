`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:    usart_bps_clk_gen
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

module  usart_bps_clk_gen #(
	parameter	SYS_FRE 		= 50 ,
	parameter   USART_BPS		= 115200
	
)( 
	input					i_sys_clk,
	input					i_reset_n,	
	output					o_bps_clk
);

localparam BPS_SET = SYS_FRE * 1000_000 / USART_BPS / 16;

/***********************************************/
reg [calc_width(BPS_SET):0]cnt;

always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n)
		cnt <= 0;
	else if(cnt == BPS_SET - 1)
		cnt <= 0;
	else 
		cnt <= cnt + 1;
end

assign o_bps_clk = (cnt == BPS_SET -1);

/***********************************************/
function integer calc_width(input integer num);
	begin
		calc_width = 0;
		while(num > 0) begin
			num = num >> 1 ;
			calc_width = calc_width + 1;
		end
		calc_width = calc_width - 1;
	end
endfunction

/***********************************************/


endmodule