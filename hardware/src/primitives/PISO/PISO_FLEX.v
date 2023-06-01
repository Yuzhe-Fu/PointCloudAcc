
module PISO 
#( // INPUT PARAMETERS
    parameter DATA_IN_WIDTH  = 64
)( // PORTS
    input  wire                         CLK     ,
    input  wire                         RST_N   ,
    input  wire                         RESET   ,
    input  wire [$clog2(DATA_IN_WIDTH):0]OUT_BW  , // Up to 64
    input  wire                         IN_VLD  ,
    input  wire                         IN_LAST ,
    input  wire [DATA_IN_WIDTH  -1 : 0] IN_DAT  ,
    output wire                         IN_RDY  ,
    output wire [DATA_IN_WIDTH  -1 : 0] OUT_DAT ,
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
  reg [MAXNUM_SHIFTS-1 : 0] shift_count;
  reg [DATA_IN_WIDTH-1 : 0] serial;
  reg                       last;
  wire                      bypass;
  wire [$clog2(DATA_IN_WIDTH) + 1   -1 : 0] num_shifts;

// ******************************************************************
  assign num_shifts = DATA_IN_WIDTH / OUT_BW;

  assign bypass     = shift_count==0;
  assign OUT_VLD    = bypass? IN_VLD : 1'b1;
  assign OUT_LAST   = last & shift_count[num_shifts -1];
  assign IN_RDY     = bypass? OUT_RDY : OUT_RDY & shift_count[num_shifts -1]; // : last data will be fetched

  assign OUT_DAT    = bypass? IN_DAT : serial;

  always @(posedge CLK or negedge RST_N) begin: SHIFTER_COUNT
    if (!RST_N)
        shift_count <= 0;
    else if (RESET)
        shift_count <= 0;
    else if (IN_VLD & IN_RDY) begin
        if (bypass) begin // Bypass
            if (num_shifts==2 )
                shift_count <= {1'b1, 1'b0};
            else
                shift_count <= {shift_count[num_shifts - 3 :0], 1'b1, 1'b0};// ahead shift 1
        end else
            shift_count <= {shift_count[num_shifts-2:0], 1'b1};
    end else if (OUT_VLD & OUT_RDY)
        shift_count <= {shift_count[num_shifts-2:0], 1'b0};
  end

always @(posedge CLK or negedge RST_N) begin: DATA_SHIFT
    if (!RST_N) begin
        serial <= 0;
        last   <= 0;
    end else if (RESET) begin
        serial <= 0;
        last   <= 0;
    end else begin
        if (IN_VLD & IN_RDY) begin
            if (bypass) begin
                serial <= {{num_shifts{1'b0}}, IN_DAT[DATA_IN_WIDTH-1:num_shifts]}; // ahead shift
                last   <= IN_LAST;
            end else begin
                serial <= IN_DAT;
                last   <= IN_LAST;
            end
        end else if (OUT_VLD & OUT_RDY)
            serial <= {{num_shifts{1'b0}}, serial[DATA_IN_WIDTH-1:num_shifts]};
    end
end

endmodule
