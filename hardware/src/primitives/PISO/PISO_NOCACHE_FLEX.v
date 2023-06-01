
module PISO_NOCACHE_FLEX
#( // INPUT PARAMETERS
    parameter DATA_IN_WIDTH  = 64,
    parameter DATA_OUT_WIDTH = 16
)( // PORTS
    input  wire                         CLK     ,
    input  wire                         RST_N   ,
    input  wire                         RESET   ,
    input  wire [$clog2(DATA_IN_WIDTH):0]OUT_BW  , // Up to 64
    input  wire                         IN_VLD  ,
    input  wire                         IN_LAST ,
    input  wire [DATA_IN_WIDTH -1 : 0]  IN_DAT  ,
    output wire                         IN_RDY  ,
    output reg  [DATA_IN_WIDTH -1 : 0] OUT_DAT ,
    output wire                         OUT_VLD ,
    output wire                         OUT_LAST,
    input  wire                         OUT_RDY      
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
    localparam integer MAXNUM_SHIFTS = DATA_IN_WIDTH;
// ******************************************************************

// ******************************************************************
// WIRES and REGS
// ******************************************************************
  reg [$clog2(MAXNUM_SHIFTS) -1 : 0] count;
    wire [$clog2(DATA_IN_WIDTH) + 1   -1 : 0] num_shifts;
integer i;
// ******************************************************************
  assign num_shifts = DATA_IN_WIDTH / OUT_BW;

  assign IN_RDY = OUT_RDY & count == 1; // must last data;

  assign OUT_VLD    = IN_VLD;
  assign OUT_LAST   = IN_LAST & count == 1;

always @(*) begin
    if (count == 0) begin
        OUT_DAT = IN_DAT;
    end else begin
        for(i=0; i<DATA_IN_WIDTH; i=i+1) begin
            if(OUT_BW*(num_shifts-count) + i < DATA_IN_WIDTH)
                OUT_DAT[i] = IN_DAT[OUT_BW*(num_shifts-count) + i];
            else
                OUT_DAT[i] = 0;
        end
    end
end

  always @(posedge CLK or negedge RST_N) begin: SHIFTER_COUNT
    if (!RST_N)
        count <= 0;
    else if ( RESET )
        count <= 0;
    else if (OUT_VLD & OUT_RDY) begin
        if (count == 0)
            count <= num_shifts - 1; 
        else
            count <= count - 1;
    end
  end

endmodule
