/* --- INSTANTIATION TEMPLATE BEGIN ---

wire [ADDR_WIDTH     -1 : 0] MaxCnt= ;

counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u_counter_Cnt(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     (                ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
    .INC       (                ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
    .MAX_COUNT ( MaxCnt         ),
    .OVERFLOW  ( Overflow       ),
    .UNDERFLOW (                ),
    .COUNT     ( Cnt            )
);

--- INSTANTIATION TEMPLATE END ---*/


module counter #(
    // INPUT PARAMETERS
    parameter COUNT_WIDTH               = 3,
    parameter DEFAULT_VAR               = 0 // whether the DEFAULT is a variable
)
(
    // PORTS
    input  wire                         CLK,
    input  wire                         RESET_N,

    input  wire                         CLEAR,
    input  wire [COUNT_WIDTH-1    : 0]  DEFAULT,

    input  wire                         INC,
    input  wire                         DEC,

    input  wire [COUNT_WIDTH-1    : 0]  MIN_COUNT,
    input  wire [COUNT_WIDTH-1    : 0]  MAX_COUNT,

    output wire                         OVERFLOW,
    output wire                         UNDERFLOW,
    output reg  [COUNT_WIDTH-1    : 0]  COUNT
);

// ******************************************************************
// CONTROL LOGIC
// ******************************************************************

assign OVERFLOW = (COUNT == MAX_COUNT);
assign UNDERFLOW = (COUNT == MIN_COUNT);

// UPCOUNTER
always @ (posedge CLK or negedge RESET_N) begin : COUNTER
    if (!RESET_N) begin
        if(DEFAULT_VAR) // // when the DEFAULT is a variable, reset to 0 NOT variable "DEFAULT"
            COUNT <= 0;
        else
            COUNT <= DEFAULT;
    end else if (CLEAR)
        COUNT <= DEFAULT;
    else if (INC && !DEC) begin
        if (!OVERFLOW)
            COUNT <= COUNT + 1'b1;
        else if (OVERFLOW)
            COUNT <= MIN_COUNT;
    end
    else if (DEC && !INC) begin
        if (!UNDERFLOW)
            COUNT <= COUNT - 1'b1;
        else if (UNDERFLOW)
            COUNT <= MAX_COUNT;
    end
end
endmodule
