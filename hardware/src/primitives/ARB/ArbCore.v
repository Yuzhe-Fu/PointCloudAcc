module ArbCore #(
    parameter NUM_CORE = 8,
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 16
)(
    input                               clk,
    input                               rst_n,
    input [NUM_CORE             -1 : 0] CoreOutVld,
    input [ADDR_WIDTH*NUM_CORE  -1 : 0] CoreOutAddr,
    input [DATA_WIDTH*NUM_CORE  -1 : 0] CoreOutDat,
    input [NUM_CORE             -1 : 0] CoreOutRdy ,
    output                              TopOutVld,
    output [ADDR_WIDTH          -1 : 0] TopOutAddr,
    output [DATA_WIDTH          -1 : 0] TopOutDat,
    output                              TopOutRdy,
    input                               TOPInRdy,

    output [$clog2(NUM_CORE)    -1 : 0] ArbCoreIdx,
    output reg [$clog2(NUM_CORE)-1 : 0] ArbCoreIdx_d
);
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

//=====================================================================================================================
// Logic Design
//=====================================================================================================================
// Arb
// s0
RR_arbiter#(
    .REQ_WIDTH ( NUM_CORE )
)u_RR_arbiter(
    .clk (clk),
    .rst_n (rst_n),
    .arb_round(TopOutVld & TOPInRdy),
    .req ( CoreOutVld ),
    .gnt (  ),
    .arb_port  ( ArbCoreIdx  )
);

assign TopOutAddr  = CoreOutAddr[ADDR_WIDTH*ArbCoreIdx +: ADDR_WIDTH];
assign TopOutDat   = CoreOutDat[DATA_WIDTH*ArbCoreIdx +: DATA_WIDTH];
assign TopOutVld   = CoreOutVld[ArbCoreIdx];

// s1
always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        ArbCoreIdx_d <= 0;
    end else if(TopOutVld & TOPInRdy) begin // HandShake
        ArbCoreIdx_d <= ArbCoreIdx;
    end
end
assign TopOutRdy      = CoreOutRdy[ArbCoreIdx_d];

endmodule