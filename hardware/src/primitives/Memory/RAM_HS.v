
module RAM_HS #(
    parameter SRAM_BIT      = 128,
    parameter SRAM_BYTE     = 1,
    parameter SRAM_WORD     = 64,
    parameter CLOCK_PERIOD  = 10,
    
    parameter SRAM_WIDTH    = SRAM_BIT*SRAM_BYTE,
    parameter SRAM_DEPTH_BIT= $clog2(SRAM_WORD)
)(
	input                           clk,
	input                           rst_n,
	
	input  					        wvalid,
	output 					        wready,
	input  [SRAM_DEPTH_BIT  -1 : 0] waddr,
	input  [SRAM_WIDTH      -1 : 0] wdata,
	
	input  					        arvalid,
	output 					        arready,
	input  [SRAM_DEPTH_BIT  -1 : 0] araddr,
	
	output reg					    rvalid,
	input					        rready,
	output [SRAM_WIDTH      -1 : 0] rdata	
);

//***********************************************
// define: wr_condition, rd_condition
//***********************************************



//***********************************************
// ram inst
//***********************************************
wire 					    ram_wenc;
wire [SRAM_DEPTH_BIT-1 : 0] ram_waddr;
wire [SRAM_WIDTH    -1 : 0] ram_wdata;
wire 					    ram_renc;
// wire 					    ram_renc_d;
wire [SRAM_DEPTH_BIT-1 : 0] ram_raddr;
wire [SRAM_WIDTH    -1 : 0] ram_rdata;


//***********************************************
// write path
//***********************************************
assign ram_wenc  = wvalid && wready;
assign ram_waddr = waddr;
assign ram_wdata = wdata;

assign wready   = 1'b1;
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

assign rdata   = ram_rdata;
assign arready = rready;

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================
RAM#(
    .SRAM_BIT     ( SRAM_BIT    ),
    .SRAM_BYTE    ( SRAM_BYTE   ),
    .SRAM_WORD    ( SRAM_WORD   ),
    .CLOCK_PERIOD ( CLOCK_PERIOD)
)u_RAM(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .addr_r       ( ram_raddr    ),
    .addr_w       ( ram_waddr    ),
    .read_en      ( ram_renc     ),
    .write_en     ( ram_wenc     ),
    .data_in      ( ram_wdata    ),
    .data_out     ( ram_rdata    )
);

// DELAY#(
//     .NUM_STAGES ( 1 ),
//     .DATA_WIDTH ( 1 )
// )u_DELAY_ram_renc_d(
//     .CLK        ( clk        ),
//     .RST_N      ( rst_n      ),
//     .DIN        ( ram_renc        ),
//     .DOUT       ( ram_renc_d       )
// );


endmodule