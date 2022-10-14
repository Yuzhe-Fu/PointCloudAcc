module MINMAX 
#( // INPUT PARAMETERS
    parameter DATA_WIDTH  = 16,
    parameter PORT        = 4,
    parameter MINMAX      = 0 // 0: MIN; 1: MAX
)( // PORTS
    input [DATA_WIDTH*PORT  -1 : 0] IN,
    output reg [$clog2(PORT)     -1 : 0] IDX,
    output reg [DATA_WIDTH       -1 : 0] VALUE
);

integer i;
always @(*) begin
    VALUE = IN[0 +: DATA_WIDTH];
    IDX = 0;
    for(i=1; i<PORT; i=i+1) begin
        if ( MINMAX ? VALUE < IN[DATA_WIDTH*i +: DATA_WIDTH] : VALUE > IN[DATA_WIDTH*i +: DATA_WIDTH]) begin
            VALUE = IN[DATA_WIDTH*i +: DATA_WIDTH];
            IDX = i;
        end
    end
end

endmodule