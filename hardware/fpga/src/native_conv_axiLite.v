`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PKU
// Engineer:  Changchun Zhou 
// 
// Create Date: 
// Design Name: 
// Module Name:    native_conv_axi
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

module  native_conv_axiLite #(
	parameter	ADDR_WIDTH		= 32,
	parameter	DATA_WIDTH		= 32
)( 
	input							i_sys_clk		,
	input							i_reset_n		,
		
	input							i_wr_en			,
	input		[ADDR_WIDTH-1:0]	i_wr_addr		,
	input		[DATA_WIDTH-1:0]	i_wr_data		,
	output	reg						o_wr_busy		,
	
	input							i_rd_en			,
	input		[ADDR_WIDTH-1:0]	i_rd_addr		,
	output	reg	[DATA_WIDTH-1:0]	o_rd_data		,
	output	reg						o_rd_busy		,	
	output	reg						o_rd_valid		,	
	
    output	reg	[ADDR_WIDTH-1:0]	s_axi_awaddr 	,
    output	reg						s_axi_awvalid 	,
    input							s_axi_awready 	,
    output	reg	[DATA_WIDTH-1:0]	s_axi_wdata 	,
    output	reg	[DATA_WIDTH/8-1:0]	s_axi_wstrb 	,
	output	reg						s_axi_wvalid 	,
    input							s_axi_wready 	,
    input		[1:0]				s_axi_bresp 	,
    input							s_axi_bvalid 	,
    output	reg						s_axi_bready 	,
    output	reg	[ADDR_WIDTH-1:0]	s_axi_araddr 	,
    output	reg						s_axi_arvalid 	,
    input							s_axi_arready 	,
    input		[ADDR_WIDTH-1:0]	s_axi_rdata 	,
    input		[1:0]				s_axi_rresp 	,
    input							s_axi_rvalid 	,
    output	reg						s_axi_rready 	
);


wire wr_ready = ~o_wr_busy;

always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n) begin
		s_axi_awaddr 	<= 0;
		s_axi_awvalid	<= 0;
	end
	else if(s_axi_awvalid & s_axi_awready)
		s_axi_awvalid	<= 0;
	else if(i_wr_en & wr_ready) begin
		s_axi_awaddr 	<= i_wr_addr;
		s_axi_awvalid	<= 1;
	end
end

always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n) begin
		s_axi_wdata 	<= 0;
		s_axi_wvalid	<= 0;
	end
	else if(s_axi_wvalid & s_axi_wready)
		s_axi_wvalid	<= 0;
	else if(i_wr_en & wr_ready) begin
		s_axi_wdata 	<= i_wr_data;
		s_axi_wvalid	<= 1;
	end
end

always @(posedge i_sys_clk) begin
	s_axi_wstrb <= -1;
end


always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n) begin
		s_axi_bready	<= 0;
	end
	else if(s_axi_bready & s_axi_bvalid)
		s_axi_bready	<= 0;
	else if(i_wr_en & wr_ready)
		s_axi_bready	<= 1;
end


always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n)
		o_wr_busy 	<= 0;
	else if(s_axi_bready & s_axi_bvalid)
		o_wr_busy	<= 0;
	else if(i_wr_en)
		o_wr_busy 	<= 1;
end

/***********************************************/
//RD
wire	rd_ready = ~o_rd_busy;

always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n) begin
		s_axi_araddr 	<= 0;
		s_axi_arvalid 	<= 0;
	end
	else if(s_axi_arvalid & s_axi_arready)
		s_axi_arvalid	<= 0;
	else if(i_rd_en & rd_ready) begin
		s_axi_araddr 	<= i_rd_addr;
		s_axi_arvalid 	<= 1;	
	end
end

always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n)	begin
		s_axi_rready	<= 0;
		o_rd_valid		<= 0;
		o_rd_data		<= 0;
	end
	else if(s_axi_rready & s_axi_rvalid) begin	
		s_axi_rready	<= 0;
		o_rd_valid		<= 1;
		o_rd_data		<= s_axi_rdata;
	end
	else if(i_rd_en & rd_ready) begin
		s_axi_rready	<= 1;
		o_rd_valid		<= 0;
	end
	else 
		o_rd_valid		<= 0;
end

	
always @(posedge i_sys_clk or negedge i_reset_n) begin
	if(!i_reset_n)
		o_rd_busy	<= 0;
	else  if(s_axi_rready & s_axi_rvalid)
		o_rd_busy	<= 0;
	else if(i_rd_en)
		o_rd_busy	<= 1;
end
	
endmodule