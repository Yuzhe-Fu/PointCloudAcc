module prior_arb #(
  parameter REQ_WIDTH = 16
) (
  input     [REQ_WIDTH          -1 : 0] req,
  output    [REQ_WIDTH          -1 : 0] gnt,
  output reg[$clog2(REQ_WIDTH)  -1 : 0] arb_port
);

assign gnt = req & (~(req-1));

integer i;
always @(*) begin
    arb_port = 0;
    for(i=0; i<REQ_WIDTH; i=i+1) begin
        if(gnt[i]) begin
            arb_port |= i;
        end
    end
end

endmodule
