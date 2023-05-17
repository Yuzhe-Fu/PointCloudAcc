// This is a simple example.
// You can make a your own header file and set its path to settings.
// (Preferences > Package Settings > Verilog Gadget > Settings - User)
//
//      "header": "Packages/Verilog Gadget/template/verilog_header.v"
//
// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : zhouchch@pku.edu.cn
// File   : CCU.v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------

module INS #(
    SORT_LEN_WIDTH  = 5,
    IDX_WIDTH       = 10,
    DATA_WIDTH      = 17,
    SORT_LEN        = 2**SORT_LEN_WIDTH
    )(
    input                                       clk             ,
    input                                       rst_n           ,
    input                                       reset           ,
    input [(SORT_LEN_WIDTH + 1)         -1 : 0] KNNINS_CfgK     ,              
    input                                       KNNINS_LopLast  ,
    input [IDX_WIDTH+DATA_WIDTH         -1 : 0] KNNINS_Lop      ,
    input                                       KNNINS_LopVld   ,
    output                                      INSKNN_LopRdy   ,
    output[SORT_LEN -1 : 0][IDX_WIDTH   -1 : 0] INSKNN_Map      ,   
    output reg                                  INSKNN_MapVld   ,
    input                                       KNNINS_MapRdy
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire[SORT_LEN          : 0] last_shift;
reg [DATA_WIDTH     -1 : 0] DistArray[0: SORT_LEN-1];
reg [IDX_WIDTH      -1 : 0] IdxArray[0: SORT_LEN-1];

wire [IDX_WIDTH     -1 : 0] Idx;
wire [DATA_WIDTH    -1 : 0] Dist;
wire                        Out_HandShake;
wire                        In_HandShake;
wire [SORT_LEN      -1 : 0] cur_insert;
//=====================================================================================================================
// Logic Design 2: HandShake
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        INSKNN_MapVld <= 0;
    end else if (reset) begin
        INSKNN_MapVld <= 0;
    end else if(Out_HandShake)begin
        INSKNN_MapVld <= 1'b0;
    end else if(In_HandShake & KNNINS_LopLast) begin
        INSKNN_MapVld <= 1'b1;
    end
end

assign Out_HandShake = KNNINS_MapRdy & INSKNN_MapVld;
assign INSKNN_LopRdy = !INSKNN_MapVld;

//=====================================================================================================================
// Logic Design 1: INSKNN_Map
//=====================================================================================================================


assign {Idx, Dist} = KNNINS_Lop;
assign In_HandShake = KNNINS_LopVld & INSKNN_LopRdy;

genvar i;
generate 
    for(i=0; i<SORT_LEN; i=i+1) begin
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    IdxArray[i]  <= 0;
                    DistArray[i] <= -1;
                end else if (reset) begin
                    IdxArray[i]  <= 0;
                    DistArray[i] <= -1;
                end if (i < KNNINS_CfgK) begin
                    if (Out_HandShake) begin
                        IdxArray[i]  <= 0;
                        DistArray[i] <= -1;                
                    end else if (last_shift[i] & In_HandShake) begin
                        if(i!=0) begin
                            IdxArray[i]  <= IdxArray[i-1];
                            DistArray[i] <= DistArray[i-1];
                        end else if(i==0) begin
                            IdxArray[i]  <= 0; // Not exist
                            DistArray[i] <= 0;
                        end
                    end else if (cur_insert[i] & In_HandShake) begin
                        IdxArray[i]  <= Idx;
                        DistArray[i] <= Dist;
                    end
                end else begin 
                    IdxArray[i]  <= 0;
                    DistArray[i] <= -1;
                end
            end
        assign cur_insert[i]                        = (i < KNNINS_CfgK) ? !last_shift[i] & (DistArray[i] > Dist)    : 1'b0;
        assign last_shift[i+1]                      = (i < KNNINS_CfgK) ? last_shift[i] | cur_insert[i]             : 1'b0;
        assign INSKNN_Map[i]                        = (i < KNNINS_CfgK) ? IdxArray[i]                               : 0;
    end

endgenerate
assign last_shift[0] = 0;


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================


endmodule
