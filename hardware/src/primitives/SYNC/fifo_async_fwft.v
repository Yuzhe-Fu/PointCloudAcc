
module fifo_async_fwft
// ******************************************************************
// Parameters
// ******************************************************************
#(
    parameter    INIT                = "init.mif",
    parameter    DATA_WIDTH          = 4,
    parameter    ADDR_WIDTH          = 8,
    parameter    RAM_DEPTH           = (1 << ADDR_WIDTH),
    parameter    INITIALIZE_FIFO     = "no"
)
// ******************************************************************
// Port Declarations
// ******************************************************************
(
    input  wire                             rst_n,
    input  wire                             wr_clk,
    input  wire                             rd_clk,
    input  wire                             push,
    input  wire                             pop,
    input  wire [DATA_WIDTH-1:0]            data_in,
    output      [DATA_WIDTH-1:0]            data_out,
    output                                  empty,
    output                                  full
);    
 
// ******************************************************************
// Internal variables
// ******************************************************************
    wire                             fifo_pop;
    wire                             fifo_empty;
    reg                              dout_valid;
    
// ******************************************************************
// Logic
// ******************************************************************
// Read Clock Domain
assign fifo_pop     = !fifo_empty && (!dout_valid || pop);
assign empty        = !dout_valid;

always @ (posedge rd_clk or negedge rst_n)
begin
    if (!rst_n) begin
        dout_valid <= 0;
    end else if (fifo_pop) begin
        dout_valid <= 1;
    end
    else if (pop) begin
        dout_valid <= 0;
    end
end

// ******************************************************************
// INSTANTIATIONS
// ******************************************************************
fifo_async#(
    .data_width ( DATA_WIDTH ),
    .addr_width ( ADDR_WIDTH )
)u_fifo_async(
    .rst_n      ( rst_n     ),
    .wr_clk     ( wr_clk    ),
    .wr_en      ( push      ),
    .din        ( data_in   ),
    .rd_clk     ( rd_clk    ),
    .rd_en      ( fifo_pop  ),
    .valid      (           ),
    .dout       ( data_out  ),
    .empty      ( fifo_empty),
    .full       ( full      )
);


endmodule
