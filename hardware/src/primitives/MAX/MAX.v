module MAX 
#( // INPUT PARAMETERS
    parameter DATA_WIDTH  = 16,
    parameter PORT = 4
)( // PORTS
    input [DATA_WIDTH*PORT  -1 : 0] IN,
    output reg [$clog2(PORT)     -1 : 0] MAXIDX,
    output reg [DATA_WIDTH       -1 : 0] MAXVALUE
);

integer i;
always @(*) begin
    MAXVALUE = 0;
    MAXIDX = 0;
    for(i=0; i<PORT; i=i+1) begin
        if (MAXVALUE < IN[DATA_WIDTH*i +: DATA_WIDTH]) begin
            MAXVALUE = IN[DATA_WIDTH*i +: DATA_WIDTH];
            MAXIDX = i;
        end
    end
end