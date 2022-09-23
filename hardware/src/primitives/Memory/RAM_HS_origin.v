// With handshake

module hand_dp_ram #(
	parameter DEPTH = 16,
	parameter WIDTH = 8
)(
	input clk,
	input rst_n,
	
	input  					   wvalid,
	output 					   wready,
	input  [$clog2(DEPTH) -1:0]waddr,
	input  [WIDTH         -1:0]wdata,
	
	input  					   arvalid,
	output 					   arready,
	input  [$clog2(DEPTH) -1:0]araddr,
	
	output					   rvalid,
	input					   rready,
	output [WIDTH         -1:0]rdata	
);
//***********************************************
// ram inst
//***********************************************
wire 					 ram_wenc;
wire [$clog2(DEPTH) -1:0]ram_waddr;
wire [WIDTH         -1:0]ram_wdata;
wire 					 ram_renc;
wire [$clog2(DEPTH) -1:0]ram_raddr;
wire [WIDTH         -1:0]ram_rdata;

dual_port_RAM #(
	.DEPTH(DEPTH),
	.WIDTH(WIDTH))
u_ram(
    .wclk(clk),
    .wenc(ram_wenc),
    .waddr(ram_waddr),
    .wdata(ram_wdata),
    .rclk(clk),
    .renc(ram_renc),
    .raddr(ram_raddr),
    .rdata(ram_rdata)
);
//***********************************************
// write path
//***********************************************
assign ram_wenc  = wvalid && wready;
assign ram_waddr = waddr;
assign ram_wdata = wdata;
//***********************************************
// read path
//***********************************************
assign ram_renc  = arvalid && arready;
assign ram_raddr = araddr;
//***********************************************
// read pipe
//***********************************************
wire ram_renc_ff;
dffr #(.WIDTH(1)) u_renc_ff(
	.clk(clk),
	.rst_n(rst_n),
	.d(ram_renc),
	.q(ram_renc_ff)
);
wire pipe_in_valid = ram_renc_ff;
wire pipe_in_ready;
bw_pipe #(
	.WIDTH(WIDTH))
u_pipe(
	.clk(clk),
	.rst_n(rst_n),
	
	.data_in(ram_rdata),
	.data_in_valid(pipe_in_valid),
	.data_in_ready(pipe_in_ready),
	
	.data_out(rdata),
	.data_out_valid(rvalid),
	.data_out_ready(rready)
);
//***********************************************
// out logic
//***********************************************
assign wready  = 1'b1;
assign arready = rready || (~pipe_in_valid && pipe_in_ready);

endmodule