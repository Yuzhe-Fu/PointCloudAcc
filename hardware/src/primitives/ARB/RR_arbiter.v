/* --- INSTANTIATION TEMPLATE BEGIN ---

RR_arbiter #(
    .REQ_WIDTH ( 16 )
)u_RR_arbiter(
    .clk        ( clk       ),
    .rst_n      ( rst_n     ),
    .req        ( req       ),
    .gnt        ( gnt       ),
    .arb_port   ( arb_port  )
);

--- INSTANTIATION TEMPLATE END ---*/

module RR_arbiter #( // round_robin_arbiter
 parameter REQ_WIDTH = 16
)(

input                                   clk,
input                                   rst_n,
input                                   arb_round, // update have been arbed info(port) when arbing sucessfully
input [REQ_WIDTH                -1 : 0] req,
output[REQ_WIDTH                -1 : 0] gnt,
output reg[$clog2(REQ_WIDTH)    -1 : 0] arb_port
);

wire [REQ_WIDTH -1 : 0] req_masked;
wire [REQ_WIDTH -1 : 0] mask_higher_pri_reqs;
wire [REQ_WIDTH -1 : 0] grant_masked;
wire [REQ_WIDTH -1 : 0] unmask_higher_pri_reqs;
wire [REQ_WIDTH -1 : 0] grant_unmasked;
wire                    no_req_masked;
reg [REQ_WIDTH  -1 : 0] pointer_reg;

// Simple priority arbitration for masked portion
assign req_masked = req & pointer_reg;
assign mask_higher_pri_reqs[REQ_WIDTH-1:1] = mask_higher_pri_reqs[REQ_WIDTH-2: 0] | req_masked[REQ_WIDTH-2:0];
assign mask_higher_pri_reqs[0] = 1'b0;
assign grant_masked[REQ_WIDTH-1:0] = req_masked[REQ_WIDTH-1:0] & ~mask_higher_pri_reqs[REQ_WIDTH-1:0];

// Simple priority arbitration for unmasked portion
assign unmask_higher_pri_reqs[REQ_WIDTH-1:1] = unmask_higher_pri_reqs[REQ_WIDTH-2:0] | req[REQ_WIDTH-2:0];
assign unmask_higher_pri_reqs[0] = 1'b0;
assign grant_unmasked[REQ_WIDTH-1:0] = req[REQ_WIDTH-1:0] & ~unmask_higher_pri_reqs[REQ_WIDTH-1:0];

// Use grant_masked if there is any there, otherwise use grant_unmasked. 
assign no_req_masked = ~(|req_masked);
assign gnt = ({REQ_WIDTH{no_req_masked}} & grant_unmasked) | grant_masked;

// Pointer update
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pointer_reg <= {REQ_WIDTH{1'b1}};
    end else if(arb_round) begin
        if (|req_masked) begin // Which arbiter was used?
            pointer_reg <= mask_higher_pri_reqs;
        end else begin
            if (|req) begin // Only update if there's a req 
                pointer_reg <= unmask_higher_pri_reqs;
            end else begin
                pointer_reg <= pointer_reg ;
            end
        end
  end
end

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