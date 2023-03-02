// 数据通路是: PC <--> FPGA（含DDR） <--> CHIP
// FPGA与CHIP的接口为简化版的AHB协议，CHIP为主机MASTER，有NUM_PORT组接口
module FPGA #( 
    parameter PORT_WIDTH        = 64,
    parameter DRAM_ADDR_WIDTH   = 32
)(
	input					clk_in1_p,
	input					clk_in1_n,
	input					i_reset,
	
	input					i_usart_rx,
	output					o_usart_tx,
	
    input            		gtrefclk_p,            // Differential +ve of reference clock for MGT: very high quality.
    input            		gtrefclk_n,            // Differential -ve of reference clock for MGT: very high quality.
    output           		txp,                   // Differential +ve of serial transmission from PMA to PMD.
    output           		txn,                   // Differential -ve of serial transmission from PMA to PMD.
    input            		rxp,                   // Differential +ve for serial reception from PMD to PMA.
    input            		rxn,                   // Differential -ve for serial reception from PMD to PMA.	
	output [13:0]		    DDR3_0_addr,
	output [2:0]		    DDR3_0_ba,
	output 				    DDR3_0_cas_n,
	output [0:0]		    DDR3_0_ck_n,
	output [0:0]		    DDR3_0_ck_p,
	output [0:0]		    DDR3_0_cke,
	output [0:0]		    DDR3_0_cs_n,
	output [7:0]		    DDR3_0_dm,
	inout [63:0]		    DDR3_0_dq,
	inout [7:0]			    DDR3_0_dqs_n,
	inout [7:0]			    DDR3_0_dqs_p,
	output [0:0]		    DDR3_0_odt,
	output 				    DDR3_0_ras_n,
	output 				    DDR3_0_reset_n,
	output 				    DDR3_0_we_n,

    output                          I_SysRst_n    , 
    output                          I_SysClk      , 
    output                          I_StartPulse  ,
    output                          I_BypAsysnFIFO, 
    inout   [PORT_WIDTH     -1 : 0] IO_Dat        , 
    inout                           IO_DatVld     ,
    inout                           OI_DatRdy     , 
    input                           O_DatOE       ,
    input                           O_CmdVld      ,
    input                           O_NetFnh  

);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
// TOP Inputs
reg                             I_StartPulse  ;
reg                             I_BypAsysnFIFO;

// TOP Outputs
wire                            O_DatOE;
wire                            O_CmdVld;
wire                            O_NetFnh;

// TOP Bidirs
wire  [PORT_WIDTH       -1 : 0] IO_Dat;
wire                            IO_DatVld ;
wire                            OI_DatRdy ;

reg                             rst_n ;
reg                             clk   ;
reg [PORT_WIDTH         -1 : 0] Dram[0 : 2**18-1];
reg [DRAM_ADDR_WIDTH    -1 : 0] addr;
reg [DRAM_ADDR_WIDTH    -1 : 0] BaseAddr;

wire				abh_clk;
wire				ahb_rstn;
wire	[31:0]		ahb_haddr;
wire	[2:0]		ahb_hburst;
wire	[3:0]		ahb_hprot;
wire	[31:0]		ahb_hrdata;
wire				ahb_hready_in;
wire				ahb_hready_out;
wire				ahb_hresp;
wire	[2:0]		ahb_hsize;
wire	[1:0]		ahb_htrans;
wire	[31:0]		ahb_hwdata;
wire				ahb_hwrite;
wire				ahb_sel;

//=====================================================================================================================
// Logic Design 1: FSM=ITF
//=====================================================================================================================
localparam IDLE     = 3'b000;
localparam CMD      = 3'b001;
localparam IN2CHIP  = 3'b010;
localparam OUT2OFF  = 3'b011;

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if( O_CmdVld )
                    next_state <= CMD;
                else
                    next_state <= IDLE;
        CMD :   if( O_DatOE & IO_DatVld & OI_DatRdy) begin
                    if ( IO_Dat[0] ) // 
                        next_state <= OUT2OFF;
                    else
                        next_state <= IN2CHIP;
                end else
                    next_state <= CMD;
        IN2CHIP:   if( O_CmdVld )
                    next_state <= IDLE;
                else
                    next_state <= IN2CHIP;
        OUT2OFF:   if( O_CmdVld )
                    next_state <= IDLE;
                else
                    next_state <= OUT2OFF;
        default:    next_state <= IDLE;
    endcase
end
always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

//=====================================================================================================================
// Logic Design 
//=====================================================================================================================

// Indexed addressing
always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        addr <= 0;
    end else if(state == IDLE) begin
        addr <= 0;
    end else if(state == IDLE & next_state == CMD ) begin
        addr <= IO_Dat[1 +: DRAM_ADDR_WIDTH];
    end else if ( (next_state == IN2CHIP | next_state == OUT2OFF) & IO_DatVld & OI_DatRdy) begin
        addr <= addr + 1;
    end
end

// DRAM READ
assign IO_DatVld  = O_DatOE? 1'bz : state== IN2CHIP;
assign IO_Dat = O_DatOE? {PORT_WIDTH{1'bz}} : ahb_hrdata;

// DRAM WRITE
assign OI_DatRdy = O_DatOE? (state==CMD | state==OUT2OFF) & (ahb_hready_in & ahb_hresp == 0) : 1'bz;

// initial begin
//     $readmemh("Dram.txt", Dram);
// end
// always @(posedge clk or rst_n) begin
//     if(state == OUT2OFF) begin
//         if(IO_DatVld & OI_DatRdy)
//             Dram[addr] <= IO_Dat;
//     end
// end

assign abh_clk      = clk;
assign ahb_rstn     = rst_n;
assign ahb_haddr    = addr << 3;
assign ahb_hburst   = 3'b001;
assign ahb_hprot    = 4'd0;
assign ahb_hready_out= OI_DatRdy;
assign ahb_hsize    = 3'b011;
assign ahb_htrans   = (state == CMD) & (next_state == IN2CHIP | next_state == OUT2OFF) ? 2'b01 : (next_state != IDLE) & (state == IN2CHIP | state == OUT2OFF) ? 2'b10 : 2'b00;
assign ahb_hwdata   = IO_Dat;
assign ahb_hwrite   = state == OUT2OFF;
assign ahb_sel      = 1'b0;

assign I_SysRst_n   = rst_n;
assign I_SysClk     = clk;
assign I_StartPulse = 1'b1;
assign I_BypAsysnFIFO= 1'b0;

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

pc_recv_send_top#(
    .SYS_FRE             ( 100 )
)u_pc_recv_send_top(
    .clk_in1_p           ( clk_in1_p           ),
    .clk_in1_n           ( clk_in1_n           ),
    .i_reset             ( i_reset             ),
    .i_usart_rx          ( i_usart_rx          ),
    .o_usart_tx          ( o_usart_tx          ),
    .gtrefclk_p          ( gtrefclk_p          ),
    .gtrefclk_n          ( gtrefclk_n          ),
    .txp                 ( txp                 ),
    .txn                 ( txn                 ),
    .rxp                 ( rxp                 ),
    .rxn                 ( rxn                 ),
    .DDR3_0_addr         ( DDR3_0_addr         ),
    .DDR3_0_ba           ( DDR3_0_ba           ),
    .DDR3_0_cas_n        ( DDR3_0_cas_n        ),
    .DDR3_0_ck_n         ( DDR3_0_ck_n         ),
    .DDR3_0_ck_p         ( DDR3_0_ck_p         ),
    .DDR3_0_cke          ( DDR3_0_cke          ),
    .DDR3_0_cs_n         ( DDR3_0_cs_n         ),
    .DDR3_0_dm           ( DDR3_0_dm           ),
    .DDR3_0_dq           ( DDR3_0_dq           ),
    .DDR3_0_dqs_n        ( DDR3_0_dqs_n        ),
    .DDR3_0_dqs_p        ( DDR3_0_dqs_p        ),
    .DDR3_0_odt          ( DDR3_0_odt          ),
    .DDR3_0_ras_n        ( DDR3_0_ras_n        ),
    .DDR3_0_reset_n      ( DDR3_0_reset_n      ),
    .DDR3_0_we_n         ( DDR3_0_we_n         ),
    .abh_clk             ( abh_clk             ),
    .ahb_rstn            ( ahb_rstn            ),
    .ahb_haddr           ( ahb_haddr           ),
    .ahb_hburst          ( ahb_hburst          ),
    .ahb_hprot           ( ahb_hprot           ),
    .ahb_hrdata          ( ahb_hrdata          ),
    .ahb_hready_in       ( ahb_hready_in       ),
    .ahb_hready_out      ( ahb_hready_out      ),
    .ahb_hresp           ( ahb_hresp           ),
    .ahb_hsize           ( ahb_hsize           ),
    .ahb_htrans          ( ahb_htrans          ),
    .ahb_hwdata          ( ahb_hwdata          ),
    .ahb_hwrite          ( ahb_hwrite          ),
    .ahb_sel             ( ahb_sel             ),
    .nul                 ( nul                 )
);

//==============================================================================
// FPGA ILA :
//==============================================================================

// `ifdef FPGA

    // wire clk_ibufg;
    // IBUFGDS #
    // (
    // .DIFF_TERM ("FALSE"),
    // .IBUF_LOW_PWR ("FALSE")
    // )
    // u_ibufg_sys_clk
    // (
    // .I (I_clk_src_p), //差分时钟正端输入
    // .IB (I_clk_src_n), // 差分时钟负端输入
    // .O (clk_ibufg) //时钟缓冲输出
    // );

    // clk_wiz clk_wiz
    // (
    // // Clock out ports
    // .clk_out1(clk), // output clk_out1&nbsp;&nbsp;5MHZ&nbsp;&nbsp;
    // .clk_out2(clk_400M),
    // // Status and control signals
    // .locked(O_FPGA_clk_locked), // output locked
    // // Clock in ports
    // .clk_in1(clk_ibufg));
     
    // blk_mem_gen_0 blk_mem_128x2_18 (
    //   .clka(clk),    // input wire clka
    //   .ena(blk_mem_en),
    //   .addra(blk_mem_addr),  // input wire [31 : 0] addra
    //   .douta(blk_mem_dout)  // output wire [127 : 0] douta
    // );

    // ILA_200bit ILA_data (
    //     .clk(clk), // input wire clk

    //     .probe0(IO_Dat), 
    //     .probe2({IO_DatVld, OI_DatRdy, O_DatOE, O_CmdVld, O_NetFnh })  
    // );

// `else 
//     initial begin
//         clk_400M = 1'b0;
//         forever #(1.25) clk_400M = ~clk_400M;
//     end

//     ROM #(
//             .DATA_WIDTH(PORT_WIDTH),
//             .INIT("/workspace/home/zhoucc/Share/Chip_test/Whole_test/scripts/ROM_FPGA_tapeout.txt"),
//             .ADDR_WIDTH(16),
//             .INITIALIZE_FIFO("yes")
//         ) inst_ROM (
//             .clk      (clk),
//             .address  (blk_mem_addr),
//             .enable   (blk_mem_en),
//             .data_out (blk_mem_dout)
//         );


// `endif


endmodule