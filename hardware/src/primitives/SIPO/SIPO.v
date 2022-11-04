
module SIPO
#( // INPUT PARAMETERS
    parameter  DATA_IN_WIDTH  = 16,
    parameter  DATA_OUT_WIDTH = 64
)( // PORTS
    input  wire                         CLK     ,
    input  wire                         RST_N   ,
    input  wire                         IN_VLD  ,
    input  wire                         IN_LAST ,
    input  wire [DATA_IN_WIDTH -1 : 0]  IN_DAT  ,
    output wire                         IN_RDY  ,
    output wire [DATA_OUT_WIDTH -1 : 0] OUT_DAT ,
    output wire                         OUT_VLD ,
    output wire                         OUT_LAST,
    input  wire                         OUT_RDY 
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
localparam integer NUM_SHIFTS = DATA_OUT_WIDTH / DATA_IN_WIDTH;
localparam integer SHIFT_COUNT_WIDTH = $clog2(NUM_SHIFTS)+1;
// ******************************************************************

// ******************************************************************
// WIRES and REGS
// ******************************************************************
wire                            parallel_load;
wire                            parallel_load_d;
reg  [ SHIFT_COUNT_WIDTH-1 : 0] shift_count;
reg  [ DATA_OUT_WIDTH   -1 : 0] shift;
reg                             last;
// ******************************************************************

assign parallel_load    = shift_count == NUM_SHIFTS;
assign IN_RDY           = !OUT_VLD | (OUT_VLD & OUT_RDY);
assign OUT_VLD          = parallel_load;
assign OUT_LAST         = last & parallel_load;
assign OUT_DAT          = shift;

always @(posedge CLK or negedge RST_N) begin: SHIFTER_COUNT
    if (!RST_N)
        shift_count <= 0;
    else begin
        if ( (IN_VLD & IN_RDY) && !OUT_VLD)
            shift_count <= shift_count + 1;
        else if ( (IN_VLD& IN_RDY) && (OUT_VLD & OUT_RDY) )
            shift_count <= 1;
        else if (OUT_VLD & OUT_RDY)
            shift_count <= 0;
    end
end

always @(posedge CLK or negedge RST_N) begin: DATA_SHIFT
    if (!RST_N) begin
        shift <= 0;
        last  <= 0;
    end else if (IN_VLD & IN_RDY) begin
        last  <= IN_LAST;
        if (DATA_OUT_WIDTH == DATA_IN_WIDTH)
            shift <={IN_DAT};
        else
            shift <= {IN_DAT, shift[DATA_OUT_WIDTH-1:DATA_IN_WIDTH]};
    end
end


endmodule
