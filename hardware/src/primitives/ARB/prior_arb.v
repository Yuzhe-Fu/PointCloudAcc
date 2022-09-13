module prior_arb #(
  parameter REQ_WIDTH = 16
) (
  input  [REQ_WIDTH-1:0]     req,
  output [REQ_WIDTH-1:0]     gnt
);
  assign gnt = req & (~(req-1));
endmodule
