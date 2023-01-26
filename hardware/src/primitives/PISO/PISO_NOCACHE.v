
module PISO_NOCACHE
#( // INPUT PARAMETERS
    parameter DATA_IN_WIDTH  = 64,
    parameter DATA_OUT_WIDTH = 16
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
    localparam integer NUM_SHIFTS = DATA_IN_WIDTH / DATA_OUT_WIDTH;
// ******************************************************************

// ******************************************************************
// WIRES and REGS
// ******************************************************************
  reg [$clog2(NUM_SHIFTS)   : 0]count;
  wire                          bypass;
  wire                          in_rdy;
// ******************************************************************
  assign bypass     = count==0;
  assign OUT_VLD    = bypass? IN_VLD : 1'b1;
  assign OUT_LAST   = IN_LAST & count==1;
  assign in_rdy     = bypass? OUT_RDY : OUT_RDY & count==1; // : last data will be fetched
  assign IN_RDY = OUT_RDY & count==1; // must last data;

  assign OUT_DAT    = bypass? IN_DAT[0 +: DATA_OUT_WIDTH] : IN_DAT[DATA_OUT_WIDTH*(NUM_SHIFTS-count) +: DATA_OUT_WIDTH];

  always @(posedge CLK or negedge RST_N) begin: SHIFTER_COUNT
    if (!RST_N)
        count <= 0;
    else if (IN_VLD & in_rdy) begin
        if (bypass) // Bypass
            count <= NUM_SHIFTS - 1;// ahead
        else 
            count <= NUM_SHIFTS;
    end else if (OUT_VLD & OUT_RDY) 
        count <= count - 1;
  end

endmodule
