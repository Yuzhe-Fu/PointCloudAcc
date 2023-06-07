
module BWC // Bit Width Conversion
#( // INPUT PARAMETERS
    parameter DATA_IN_WIDTH = 64,
    parameter DATA_OUT_WIDTH= 128,
    parameter CACHE_WIDTH   = DATA_IN_WIDTH + DATA_OUT_WIDTH

)( // PORTS
    input  wire                                 CLK     ,
    input  wire                                 RST_N   ,
    input  wire                                 RESET   ,
    input  wire [$clog2(DATA_IN_WIDTH)+1-1 : 0] INP_BW  , // Valid input bit-width
    input  wire [$clog2(DATA_OUT_WIDTH)+1-1: 0] OUT_BW  , // Valid output bit-width;
    input  wire                                 IN_VLD  ,
    input  wire                                 IN_LAST ,
    input  wire [DATA_IN_WIDTH          -1 : 0] IN_DAT  ,
    output wire                                 IN_RDY  ,
    output wire                                 IN_NFULL,
    output reg  [DATA_OUT_WIDTH         -1 : 0] OUT_DAT ,
    output wire                                 OUT_VLD ,
    output wire                                 OUT_LAST,
    input  wire                                 OUT_RDY      
);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg  [$clog2(CACHE_WIDTH)   + 1 -1 : 0] count; // Count valid bits
integer                                 i;
reg                                     last;
reg [DATA_IN_WIDTH+DATA_OUT_WIDTH-1: 0] serial;
wire[DATA_IN_WIDTH+DATA_OUT_WIDTH-1: 0] serial_shift;

//=====================================================================================================================
// Logic Design: ISA Decode
//=====================================================================================================================
assign IN_RDY       = (count + INP_BW < CACHE_WIDTH) 
                        | (OUT_RDY & (count + INP_BW < CACHE_WIDTH + OUT_BW) ); // must last data;
assign OUT_VLD      = count >= OUT_BW;
assign OUT_LAST     = last & count <= OUT_BW;

assign IN_NFULL     = IN_RDY & IN_VLD & ( count + INP_BW > CACHE_WIDTH | (OUT_RDY & (count + INP_BW > CACHE_WIDTH + OUT_BW) ) );

always @(*) begin
    for(i=0; i<DATA_IN_WIDTH; i=i+1) begin
        if (i < OUT_BW)
            OUT_DAT[i] = serial[i];
        else
            OUT_DAT[i] = 0;
    end
end

always @(posedge CLK or negedge RST_N) begin: SHIFTER_COUNT
    if (!RST_N) begin
        count <= 0;
        last  <= 0;
        serial<= 0;
    end else if ( RESET ) begin
        count <= 0;
        last  <= 0;
        serial<= 0;
    end else if (IN_VLD & IN_RDY) begin
        if (OUT_VLD & OUT_RDY) begin
                count <= count + INP_BW - OUT_BW;
                for( i = 0; i < DATA_IN_WIDTH + DATA_OUT_WIDTH; i = i + 1 ) begin
                    if( count - OUT_BW <= i & i < count + INP_BW - OUT_BW) // Insert
                        serial[i] <= IN_DAT[i-(count - OUT_BW)];
                    else
                        serial[i] <= serial_shift[i];
                end
        end else begin
                count <= count + INP_BW;
                for(i=0; i<DATA_IN_WIDTH+DATA_OUT_WIDTH; i=i+1) begin
                    if(count <= i & i < count + INP_BW) // Insert
                        serial[i] <= IN_DAT[i-count];
                    else
                        serial[i] <= serial[i];
                end
        end
        last <= IN_LAST;
    end
end

assign serial_shift = serial >> OUT_BW;

endmodule
