
module PISO_NOCACHE_FLEX
#( // INPUT PARAMETERS
    parameter DATA_IN_WIDTH  = 64
)( // PORTS
    input  wire                                 CLK     ,
    input  wire                                 RST_N   ,
    input  wire                                 RESET   ,
    input  wire [$clog2(DATA_IN_WIDTH)+1-1 : 0] INP_BW  , // Valid input bit-width
    input  wire [$clog2(DATA_IN_WIDTH)+1-1 : 0] OUT_BW  , // Valid output bit-width; Up to 64
    input  wire                                 IN_VLD  ,
    input  wire                                 IN_LAST ,
    input  wire [DATA_IN_WIDTH          -1 : 0] IN_DAT  ,
    output wire                                 IN_RDY  ,
    output reg  [DATA_IN_WIDTH          -1 : 0] OUT_DAT ,
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
reg  [$clog2(DATA_IN_WIDTH)     -1 : 0] count;
wire [$clog2(DATA_IN_WIDTH) + 1 -1 : 0] num_shifts;
integer                                 i;

//=====================================================================================================================
// Logic Design: ISA Decode
//=====================================================================================================================
assign num_shifts   = INP_BW / OUT_BW;
assign IN_RDY       = OUT_RDY & (count == 1 | num_shifts == 1); // must last data;
assign OUT_VLD      = IN_VLD;
assign OUT_LAST     = IN_LAST & (count == 1 | num_shifts == 1);

always @(*) begin
    for(i=0; i<DATA_IN_WIDTH; i=i+1) begin
        if (count == 0 & i<OUT_BW)
            OUT_DAT[i] = IN_DAT[i];
        else if(OUT_BW*(num_shifts-count) + i < INP_BW)
            OUT_DAT[i] = IN_DAT[OUT_BW*(num_shifts-count) + i];
        else
            OUT_DAT[i] = 0;
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
