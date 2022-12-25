module DEC2D #(
    parameter WIDTH = 8,
    parameter DEPTH = 4
)(
    input [WIDTH*DEPTH  -1 : 0] IN
);
wire [WIDTH     -1 : 0] Debug_2D [0 : DEPTH   -1];
genvar gv_db;
generate
    for(gv_db=0; gv_db<DEPTH; gv_db=gv_db+1) begin: GEN_Debug_2D
        assign Debug_2D[gv_db] = IN[WIDTH*gv_db +: WIDTH];
    end
endgenerate

endmodule