module RAM #(
    parameter SRAM_BIT = 128,
    parameter SRAM_BYTE = 1,
    parameter SRAM_WORD = 64,
    parameter CLOCK_PERIOD = 10,

    parameter SRAM_WIDTH = SRAM_BIT*SRAM_BYTE,
    parameter SRAM_DEPTH_BIT = `C_LOG_2(SRAM_WORD)

)(
    input                           clk,
    input                           rst_n,
    input [SRAM_DEPTH_BIT   -1 : 0] addr_r, addr_w,
    input                           read_en, write_en,
    input [SRAM_WIDTH       -1 : 0] data_in,
    output[SRAM_WIDTH       -1 : 0] data_out
);

// ******************************************************************
// INSTANTIATIONS
// ******************************************************************

wire                        [SRAM_DEPTH_BIT - 1 : 0] Addr;
assign Addr = write_en ? addr_w : addr_r;

wire [ SRAM_DEPTH_BIT          -1 : 0] A;
wire [ SRAM_WIDTH              -1 : 0] DI;
wire [ SRAM_BYTE               -1 : 0] WEB;
wire                                   CSB;
// delay 1/2 clock period
`ifdef DELAY_SRAM // Delay for sim
    assign #(`CLOCK_PERIOD/2) A   = Addr;
    assign #(`CLOCK_PERIOD/2) DI  = data_in[SRAM_WIDTH -1 : 0];
    assign #(`CLOCK_PERIOD/2) WEB = ~write_en ? {SRAM_BYTE{1'b1}}: {SRAM_BYTE{1'b0}};
    assign #(`CLOCK_PERIOD/2) CSB = (~write_en)&(~read_en);
`else
    assign  A   = Addr;
    assign  DI  = data_in[SRAM_WIDTH -1 : 0];
    assign  WEB = ~write_en ? {SRAM_BYTE{1'b1}}: {SRAM_BYTE{1'b0}};
    assign  CSB = (~write_en)&(~read_en);
`endif

wire [ SRAM_WIDTH              -1 : 0] DO;
wire                                   read_en_d;
reg  [ SRAM_WIDTH              -1 : 0] DO_d;
assign data_out = read_en_d? DO : DO_d;
Delay #(
    .NUM_STAGES(1),
    .DATA_WIDTH(1)
) Delay_read_en_d (
    .CLK     (clk       ),
    .RESET_N (rst_n     ),
    .DIN     (read_en   ),
    .DOUT    (read_en_d )
);
always @ ( posedge clk) begin
    if( read_en_d)
        DO_d <= DO;
end
// ******************************************************************************
generate
    if( SRAM_WORD == 32 && SRAM_BIT == 128 && SRAM_BYTE == 1)begin
        SYLA55_32X128X1CM2 RAM_DELTA0_SYLA55_32X128X1CM2(
        .A                   (  A       ),
        .DO                  (  DO      ),
        .DI                  (  DI      ),
        .DVSE                (  1'b0    ),
        .DVS                 (  4'b0    ),
        .WEB                 (  WEB     ),
        .CK                  (  clk     ),
        .CSB                 (  CSB     )
         );
    end
    else if( SRAM_WORD == 64 && SRAM_BIT == 32 && SRAM_BYTE == 1) begin
        SYLA55_64X32X1CM2 RAM_DELTA0_SYLA55_64X32X1CM2(
        .A                   (  A       ),
        .DO                  (  DO      ),
        .DI                  (  DI      ),
        .DVSE                (  1'b0    ),
        .DVS                 (  4'b0    ),
        .WEB                 (  WEB     ),
        .CK                  (  clk     ),
        .CSB                 (  CSB     )
         );
    end
    else if ( SRAM_WORD == 108 && SRAM_BIT == 128 && SRAM_BYTE == 1) begin
        SYLA55_108X128X1CM2 RAM_DELTA0_SYLA55_108X128X1CM2(
        .A                   (  A       ),
        .DO                  (  DO      ),
        .DI                  (  DI      ),
        .DVSE                (  1'b0    ),
        .DVS                 (  4'b0    ),
        .WEB                 (  WEB     ),
        .CK                  (  clk     ),
        .CSB                 (  CSB     )
         );
    end
    else if ( SRAM_WORD == 49 && SRAM_BIT == 8 && SRAM_BYTE == 16) begin
        SYLA55_49X8X16CM2 RAM_FRMPOOL0(
            .A               (  A         ),
            .DO              (  DO        ),
            .DI              (  DI        ),
            .DVSE            (  1'b0      ),
            .DVS             (  4'b0      ),
            .WEB             (  WEB       ),
            .CK              (  clk       ),
            .CSB             (  CSB       )
             );
    end
    else if ( SRAM_WORD == 196 && SRAM_BIT == 8 && SRAM_BYTE == 16) begin
        SYLA55_196X8X16CM2 RAM_DELTA0(
        .A                   (  A         ),
        .DO                  (  DO        ),
        .DI                  (  DI        ),
        .DVSE                (  1'b0      ),
        .DVS                 (  4'b0      ),
        .WEB                 (  WEB       ),
        .CK                  (  clk       ),
        .CSB                 (  CSB       )
         );
    end

    else if ( SRAM_WORD == 512 && SRAM_BIT == 32 && SRAM_BYTE == 4) begin
        SYLA55_512X32X4CM2 RAM_GB(
        .A                   (  A         ),
        .DO                  (  DO        ),
        .DI                  (  DI        ),
        .DVSE                (  1'b0      ),
        .DVS                 (  4'b0      ),
        .WEB                 (  WEB       ),
        .CK                  (  clk       ),
        .CSB                 (  CSB       )
         );
    end
endgenerate


endmodule
