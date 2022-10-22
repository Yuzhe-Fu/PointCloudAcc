module RAM #(
    parameter SRAM_BIT = 128,
    parameter SRAM_BYTE = 1,
    parameter SRAM_WORD = 64,
    parameter CLOCK_PERIOD = 10,

    parameter SRAM_WIDTH = SRAM_BIT*SRAM_BYTE,
    parameter SRAM_DEPTH_BIT = $clog2(SRAM_WORD)

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

wire [ SRAM_DEPTH_BIT           -1 : 0] A;
wire [ SRAM_WIDTH               -1 : 0] DI;
wire [ SRAM_BYTE                -1 : 0] WEB;
wire                                    CSB;
wire [2                         -1 : 0] RTSEL;
// delay 1/2 clock period
`ifdef SIM // Delay for sim
    assign #(CLOCK_PERIOD/2) A   = Addr;
    assign #(CLOCK_PERIOD/2) DI  = data_in[SRAM_WIDTH -1 : 0];
    assign #(CLOCK_PERIOD/2) WEB = ~write_en ? {SRAM_BYTE{1'b1}}: {SRAM_BYTE{1'b0}};
    assign #(CLOCK_PERIOD/2) CSB = (~write_en)&(~read_en);

    assign RTSEL = 2'b10;
`else
    assign  A   = Addr;
    assign  DI  = data_in[SRAM_WIDTH -1 : 0];
    assign  WEB = ~write_en ? {SRAM_BYTE{1'b1}}: {SRAM_BYTE{1'b0}};
    assign  CSB = (~write_en)&(~read_en);

    assign RTSEL = 2'b00;
`endif

wire [ SRAM_WIDTH              -1 : 0] DO;
wire                                   read_en_d;
reg  [ SRAM_WIDTH              -1 : 0] DO_d;
assign data_out = read_en_d? DO : DO_d;
DELAY #(
    .NUM_STAGES(1),
    .DATA_WIDTH(1)
) Delay_read_en_d (
    .CLK     (clk       ),
    .RST_N   (rst_n     ),
    .DIN     (read_en   ),
    .DOUT    (read_en_d )
);
always @ ( posedge clk) begin
    if( read_en_d)
        DO_d <= DO;
end


// ******************************************************************************
`ifdef FUNC_SIM
    SPSRAM#(
        .SRAM_DEPTH_BIT ( SRAM_DEPTH_BIT ),
        .SRAM_WIDTH     ( SRAM_BIT )
    )u_SPSRAM(
        .clk            ( clk        ),
        .read_en        ( WEB & ~CSB ),
        .write_en       ( ~WEB       ),
        .addr           ( A          ),
        .data_in        ( DI         ),
        .data_out       ( DO         )
    );
`else
    generate
        if( SRAM_WORD == 128 && SRAM_BIT == 256 && SRAM_BYTE == 1)begin
            TS1N28HPCPUHDHVTB128X256M1SSO GLB_BANK(
            .SLP    ( 1'b0  ),
            .SD     ( 1'b0  ),
            .CLK    ( clk   ),
            .CEB    ( CSB   ),
            .WEB    ( WEB   ),
            .A      ( A     ),
            .D      ( DI    ),
            .RTSEL  ( RTSEL  ),
            .WTSEL  ( 2'd0  ),
            .Q      ( DO    )
            );
        end

        else if( SRAM_WORD == 64 && SRAM_BIT == 128 && SRAM_BYTE == 1)begin
            TS1N28HPCPUHDHVTB64X128M4SSO CCU_ISARAM(
            .SLP    ( 1'b0  ),
            .SD     ( 1'b0  ),
            .CLK    ( clk   ),
            .CEB    ( CSB   ),
            .WEB    ( WEB   ),
            .A      ( A     ),
            .D      ( DI    ),
            .RTSEL  ( RTSEL  ),
            .WTSEL  ( 2'd0  ),
            .Q      ( DO    )
            );
        end 
        else if( SRAM_WORD == 16 && SRAM_BIT == 8 && SRAM_BYTE == 1)begin
            TS1N28HPCPUHDHVTB16X8M2SSO SYA_RAM(
            .SLP    ( 1'b0  ),
            .SD     ( 1'b0  ),
            .CLK    ( clk   ),
            .CEB    ( CSB   ),
            .WEB    ( WEB   ),
            .A      ( A     ),
            .D      ( DI    ),
            .RTSEL  ( RTSEL  ),
            .WTSEL  ( 2'd0  ),
            .Q      ( DO    )
            );
        end
    endgenerate
`endif

endmodule
