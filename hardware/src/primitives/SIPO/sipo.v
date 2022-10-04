
module SIPO
#( // INPUT PARAMETERS
    parameter  DATA_IN_WIDTH  = 16,
    parameter  DATA_OUT_WIDTH = 64
)( // PORTS
    input  wire                         CLK,
    input  wire                         RST_N,
    input  wire                         ENABLE,
    input  wire [DATA_IN_WIDTH -1 : 0]  DATA_IN,
    output wire                         IN_READY,
    output wire [DATA_OUT_WIDTH -1 : 0] DATA_OUT,
    output wire                         OUT_VALID,
    input  wire                         OUT_READY
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
  wire                                        parallel_load;
  reg  [ SHIFT_COUNT_WIDTH    -1 : 0 ]        shift_count;
  reg  [ DATA_OUT_WIDTH       -1 : 0 ]        shift;
// ******************************************************************
wire   parallel_load_d;
    assign parallel_load = shift_count == NUM_SHIFTS;
    assign IN_READY = !OUT_VALID | (OUT_VALID & OUT_READY);
    assign OUT_VALID = parallel_load;
    assign DATA_OUT = shift;

    always @(posedge CLK or negedge RST_N)
    begin: SHIFTER_COUNT
      if (!RST_N)
        shift_count <= 0;
      else
      begin
        if ( (ENABLE & IN_READY) && !OUT_VALID)
          shift_count <= shift_count + 1;
        else if ( (ENABLE& IN_READY) && (OUT_VALID & OUT_READY) )
          shift_count <= 1;
        else if (OUT_VALID & OUT_READY)
          shift_count <= 0;
      end
    end

    always @(posedge CLK or negedge RST_N)
    begin: DATA_SHIFT
      if (!RST_N)
        shift <= 0;
      else if (ENABLE & IN_READY) begin
        if (DATA_OUT_WIDTH == DATA_IN_WIDTH)
          shift <={DATA_IN};
        else
          shift <= {DATA_IN, shift[DATA_OUT_WIDTH-1:DATA_IN_WIDTH]};
      end
    end


endmodule
