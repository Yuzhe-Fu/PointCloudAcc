`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: wdog_mod
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


module wdog_mod #(
	parameter 	TIME	= 1000,
	parameter	SIG_TYPE= 1 // 0 脉冲  1：电平
)(
	input		i_sys_clk,
	input		i_reset_n,
	
	input		i_wdog_in,
	output	reg	o_wdog_out
);

reg [calc_width(TIME):0] cnt = 0;

always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(~i_reset_n)
		cnt <= 0;
	else begin
		case (SIG_TYPE)
			1: begin
				if(i_wdog_in)
					cnt <= 0;
				else if(cnt < TIME-1)
					cnt <= cnt + 1;
				else 
					cnt <= 0;
			end
			default:$display("type err");
		endcase
	
	end
end

always @(posedge i_sys_clk) begin
	if(~i_reset_n)
		o_wdog_out <= 0;
	else if(cnt > TIME - 10 && cnt < TIME)
		o_wdog_out <= 1;
	else 
		o_wdog_out <= 0;
end


/*****************************************************************/
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
