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
    SORT_LEN_WIDTH  = 5                 ,
    IDX_WIDTH       = 10                ,
    DIST_WIDTH      = 17                ,
    SORT_LEN        = 2**SORT_LEN_WIDTH
    )(
    input                                       clk             ,
    input                                       rst_n           ,
    input                                       PSSINS_LopLast  ,
    input        [IDX_WIDTH+DIST_WIDTH  -1 : 0] PSSINS_Lop      ,
    input                                       PSSINS_LopVld   ,
    output                                      INSPSS_LopRdy   ,
    output       [IDX_WIDTH*SORT_LEN    -1 : 0] INSPSS_Idx      ,   
    output reg                                  INSPSS_IdxVld   ,
    input                                       PSSINS_IdxRdy
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire[SORT_LEN          : 0] last_shift;
reg [DIST_WIDTH     -1 : 0] DistArray[0: SORT_LEN-1];
reg [IDX_WIDTH      -1 : 0] IdxArray[0: SORT_LEN-1];

wire [IDX_WIDTH     -1 : 0] Idx;
wire [DIST_WIDTH    -1 : 0] Dist;
wire                        Out_HandShake;
wire                        In_HandShake;
wire [SORT_LEN      -1 : 0] cur_insert;
//=====================================================================================================================
// Logic Design 2: HandShake
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        INSPSS_IdxVld <= 0;
    end else if(Out_HandShake)begin
        INSPSS_IdxVld <= 1'b0;
    end else if(In_HandShake & PSSINS_LopLast) begin
        INSPSS_IdxVld <= 1'b1;
    end
end

assign Out_HandShake = PSSINS_IdxRdy & INSPSS_IdxVld;
assign INSPSS_LopRdy = !INSPSS_IdxVld;

//=====================================================================================================================
// Logic Design 1: INSPSS_Idx
//=====================================================================================================================


assign {Idx, Dist} = PSSINS_Lop;
assign In_HandShake = PSSINS_LopVld & INSPSS_LopRdy;

genvar i;
generate 
    for(i=0; i<SORT_LEN; i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                IdxArray[i] <= 0;
                DistArray[i] <= -1;
            end else if (Out_HandShake) begin
                IdxArray[i] <= 0;
                DistArray[i] <= -1;                
            end else if (last_shift[i] & In_HandShake) begin
                if(i!=0) begin
                    IdxArray[i] <= IdxArray[i-1];
                    DistArray[i] <= DistArray[i-1];
                end else if(i==0) begin
                    IdxArray[i] <= 0; // Not exist
                    DistArray[i] <= 0;
                end
            end else if (cur_insert[i] & In_HandShake) begin
                IdxArray[i] <= Idx;
                DistArray[i] <= Dist;
            end
        end
        assign cur_insert[i] = !last_shift[i] & (DistArray[i] > Dist);
        assign last_shift[i+1] = last_shift[i] | cur_insert[i];
        assign INSPSS_Idx[IDX_WIDTH*i +: IDX_WIDTH] = IdxArray[i];
    end

endgenerate
assign last_shift[0] = 0;


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================


endmodule
