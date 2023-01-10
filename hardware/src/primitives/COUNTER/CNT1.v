module CNT1 #(
    parameter DATA_WIDTH = 10,
    parameter ADDR_WIDTH = $clog2(DATA_WIDTH)
)(
    input       [ DATA_WIDTH    -1 : 0] din,
    output reg  [ ADDR_WIDTH       : 0] dout
);

integer i;

always@(*) begin
    dout = 0;
    for(i=0; i< DATA_WIDTH; i=i+1) begin
        if(din[i])
            dout = dout + 1;
    end
end

endmodule 