`ifdef DELAY_SRAM
`timescale 1ns/1ps
`endif
module RAM_DELTA_wrap #(
    parameter SRAM_DEPTH_BIT = 6,
    parameter SRAM_DEPTH = 2 ** SRAM_DEPTH_BIT,
    parameter SRAM_WIDTH = 28,
    parameter BYTES      = 2,
    parameter KEEP_DATA  = 0,
    parameter INIT_IF    = "no",
    parameter INIT_FILE  = ""
)(
    input  clk,
    input  rst_n,
    input  [SRAM_DEPTH_BIT -1 :0] addr_r, 
    input  [SRAM_DEPTH_BIT -1 :0] addr_w,
    input  read_en,
    input  write_en,
    input  [SRAM_WIDTH     -1 :0] data_in,
    output [SRAM_WIDTH     -1 :0] data_out
);

// ******************************************************************
// INSTANTIATIONS
// ******************************************************************
`ifdef SYNTH_MINI
reg [SRAM_WIDTH  - 1 : 0]mem[0 : SRAM_DEPTH - 1];
reg [SRAM_WIDTH  - 1 : 0]data_out_reg;
initial begin
  if (INIT_IF == "yes") begin
    $readmemh(INIT_FILE, mem, 0, SRAM_DEPTH-1);
  end
end

always @(posedge clk) begin
    if (read_en) begin
        data_out_reg <= mem[addr_r];
    end
end
assign data_out = data_out_reg;

always @(posedge clk) begin
    if (write_en) begin
        mem[addr_w] <= data_in;
    end
end

`else

wire [SRAM_DEPTH_BIT - 1 : 0] Addr = write_en ? addr_w : addr_r;

// ******************* Delay for sim ********************************************
wire [ SRAM_DEPTH_BIT          -1 : 0] A;
wire [ SRAM_WIDTH              -1 : 0] DI;
wire [ BYTES                   -1 : 0] WEB;
wire                                   CSB;
wire [ SRAM_WIDTH              -1 : 0] DO;

// delay 1/2 clock period
`ifdef DELAY_SRAM
`define CLOCK_PERIOD_ASIC 10
    assign #(`CLOCK_PERIOD_ASIC/2) A = Addr;
    assign #(`CLOCK_PERIOD_ASIC/2) DI = data_in[SRAM_WIDTH -1 : 0];
    assign #(`CLOCK_PERIOD_ASIC/2) WEB= ~write_en ? {BYTES{1'b1}} : {BYTES{1'b0}};
    assign #(`CLOCK_PERIOD_ASIC/2) CSB = (~write_en)&(~read_en);
`else
    assign  A   = Addr;
    assign  DI  = data_in[SRAM_WIDTH -1 : 0];
    assign  WEB = ~write_en ? {BYTES{1'b1}} : {BYTES{1'b0}};
    assign  CSB = (~write_en)&(~read_en);
`endif

generate 
    if( KEEP_DATA == 1 )begin : RAM_DO_BLOCK
        reg [ SRAM_WIDTH -1 : 0] DO_d;
        reg read_en_d;
        always @ ( posedge clk or negedge rst_n )begin
            if( ~rst_n )
                DO_d <= 'd0;
            else if( read_en_d )
                DO_d <= DO;
        end
        always @ ( posedge clk or negedge rst_n )begin
            if( ~rst_n )
                read_en_d <= 'd0;
            else 
                read_en_d <= read_en;
        end
        
        assign data_out = read_en_d ? DO : DO_d;
    
    end
    else begin
        assign data_out = DO;
    end
endgenerate

// ******************************************************************************
genvar gen_i;
generate
    if( SRAM_DEPTH_BIT == 6 && SRAM_WIDTH == 128 ) begin
        SYLA55_64X32X4CM2 RAM_DELTA0(
            .A       (  A     ),
            .DO      (  DO    ),
            .DI      (  DI    ),
            .DVSE    (  1'b0  ),
            .DVS     (  4'b0  ),
            .WEB     (  WEB   ),
            .CK      (  clk   ),
            .CSB     (  CSB   )
       );
    end
    else if( SRAM_DEPTH_BIT == 8 && SRAM_WIDTH == 8 ) begin
        SYLA55_256X8X1CM4 RAM_DELTA1(
            .A       (  A     ),
            .DO      (  DO    ),
            .DI      (  DI    ),
            .DVSE    (  1'b0  ),
            .DVS     (  4'b0  ),
            .WEB     (  WEB   ),
            .CK      (  clk   ),
            .CSB     (  CSB   )
       );
    end     
    else if( SRAM_DEPTH_BIT == 8 && SRAM_WIDTH == 128 ) begin
        SYLA55_256X32X4CM2 RAM_DELTA2(
            .A       (  A     ),
            .DO      (  DO    ),
            .DI      (  DI    ),
            .DVSE    (  1'b0  ),
            .DVS     (  4'b0  ),
            .WEB     (  WEB   ),
            .CK      (  clk   ),
            .CSB     (  CSB   )
       );
    end

endgenerate

`endif

endmodule
