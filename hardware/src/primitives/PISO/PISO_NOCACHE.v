
module PISO_NOCACHE
#( // INPUT PARAMETERS
    parameter DATA_IN_WIDTH  = 64,
    parameter DATA_OUT_WIDTH = 16
)( // PORTS
    input  wire                         CLK     ,
    input  wire                         RST_N   ,
    input  wire                         RESET   ,
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
    localparam integer NUM_SHIFTS = DATA_IN_WIDTH / DATA_OUT_WIDTH;
// ******************************************************************

// ******************************************************************
// WIRES and REGS
// ******************************************************************
  reg [$clog2(NUM_SHIFTS) -1 : 0] count;
// ******************************************************************
  assign IN_RDY = OUT_RDY & count == 1; // must last data;

  assign OUT_VLD    = IN_VLD;
  assign OUT_LAST   = IN_LAST & count == 1;
  assign OUT_DAT    = count == 0? IN_DAT[0 +: DATA_OUT_WIDTH] : IN_DAT[DATA_OUT_WIDTH*(NUM_SHIFTS-count) +: DATA_OUT_WIDTH];

  always @(posedge CLK or negedge RST_N) begin: SHIFTER_COUNT
    if (!RST_N)
        count <= 0;
    else if ( RESET )
        count <= 0;
    else if (OUT_VLD & OUT_RDY) begin
        if (count == 0)
            count <= NUM_SHIFTS - 1; 
        else
            count <= count - 1;
    end
  end

endmodule
