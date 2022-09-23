// 读SRAM用握手协议的接口；
// 对于是否能读/写SRAM，由addr的valid控制，也就是valid高就能读写，因此assign wready  = 1'b1; 和assign arready = rready;
// 1. 对于写，地址，数据和使能都是同周期的，自然满足握手协议
// 2. 对于读：由于SRAM口上的数据延后于读使能和地址，不是握手协议所要要求的提前放到端口
//      因此，对地址和数据分别使用握手协议：
//          先握手地址输入，arready是否有效取决于rready让端口数据是否将被取走；再
//          再握手数据输出，rvalid是：要么上一次读了，否则要么读了没被取走

module RAM_HS #(
    parameter SRAM_BIT = 128,
    parameter SRAM_BYTE = 1,
    parameter SRAM_WORD = 64,
    parameter CLOCK_PERIOD = 10,
    
    parameter SRAM_WIDTH = SRAM_BIT*SRAM_BYTE,
    parameter SRAM_DEPTH_BIT = `C_LOG_2(SRAM_WORD)
)(
	input clk,
	input rst_n,
	
	input  					   wvalid,
	output 					   wready,
	input  [SRAM_DEPTH_BIT -1:0]waddr,
	input  [SRAM_WIDTH         -1:0]wdata,
	
	input  					   arvalid,
	output 					   arready,
	input  [SRAM_DEPTH_BIT -1:0]araddr,
	
	output					   rvalid,
	input					   rready,
	output [SRAM_WIDTH         -1:0]rdata	
);

//***********************************************
// define: wr_condition, rd_condition
//***********************************************



//***********************************************
// ram inst
//***********************************************
wire 					 ram_wenc;
wire [SRAM_DEPTH_BIT -1:0]ram_waddr;
wire [SRAM_WIDTH         -1:0]ram_wdata;
wire 					 ram_renc;
wire [SRAM_DEPTH_BIT -1:0]ram_raddr;
wire [SRAM_WIDTH         -1:0]ram_rdata;



//***********************************************
// write path
//***********************************************
assign ram_wenc  = wvalid && wready;
assign ram_waddr = waddr;
assign ram_wdata = wdata;

assign wready  = 1'b1;
//***********************************************
// read path
//***********************************************
assign ram_renc  = arvalid && arready;
assign ram_raddr = araddr;

//***********************************************
//  read out logic
//***********************************************
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rvalid <= 1'b0;
    end else if (ram_renc ) begin
        rvalid <= 1'b1;
    end else if (rvalid & rready ) begin
        rvalid <= 1'b0;
    end
end

assign rvalid = ram_renc_ff;
assign rdata = ram_rdata;
assign arready = rready;


endmodule