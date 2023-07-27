module SUM #(
    parameter DATA_NUM   = 8,
    parameter DATA_WIDTH = 10,
    parameter SUM_WIDTH = DATA_WIDTH + $clog2(DATA_NUM)
)(
    input       [DATA_NUM   -1 : 0][ DATA_WIDTH -1 : 0] DIN,
    output reg  [SUM_WIDTH                      -1 : 0] DOUT
);

integer i;

always@(*) begin
    DOUT = 0;
    for(i=0; i< DATA_NUM; i=i+1) begin
        DOUT = DOUT + DIN[i];
    end
end

endmodule