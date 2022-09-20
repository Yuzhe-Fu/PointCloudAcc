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
`include "../source/include/dw_params_presim.vh"
module INS #(
    SORT_LEN_WIDTH  = 5                 ,
    IDX_WIDTH       = 10                ,
    DIST_WIDTH      = 17                ,
    SORT_LEN        = 2**SORT_LEN_WIDTH
    )(
    input                                       clk             ,
    input                                       rst_n           ,
    input                                       SSCINS_LopLast  ,
    input        [IDX_WIDTH+DIST_WIDTH  -1 : 0] SSCINS_Lop      ,
    input                                       SSCINS_LopVld   ,
    output                                      SSCINS_LopRdy   ,
    output       [IDX_WIDTH*SORT_LEN    -1 : 0] INSSSC_Idx      ,   
    output                                      INSSSC_IdxVld   ,
    input                                       INSSSC_IdxRdy
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

//=====================================================================================================================
// Logic Design 2: HandShake
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        INSSSC_IdxVld <= 0;
    end else if(Out_HandShake)begin
        INSSSC_IdxVld <= 1'b0;
    end else if(In_HandShake & SSCINS_LopLast) begin
        INSSSC_IdxVld <= 1'b1;
    end
end
wire Out_HandShake = INSSSC_IdxRdy & INSSSC_IdxVld;

wire SSCINS_LopRdy = !INSSSC_IdxVld;

//=====================================================================================================================
// Logic Design 1: INSSSC_Idx
//=====================================================================================================================


assign {Idx, Dist} = SSCINS_Lop;
wire In_HandShake = SSCINS_LopVld & SSCINS_LopRdy;

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
                IdxArray[i] <= IdxArray[i-1];
                DistArray[i] <= DistArray[i-1];
            end else if (cur_insert[i] & In_HandShake) begin
                IdxArray[i] <= Idx;
                DistArray[i] <= Dist;
            end
        end
        assign cur_insert[i] = !last_shift[i] & (DistArray[i] > Dist);
        if(i==0)
            assign last_shift[i] = 1'b0;
        else
            assign last_shift[i+1] = last_shift[i] | cur_insert[i];
        assign INSSSC_Idx[IDX_WIDTH*i +: IDX_WIDTH] = IdxArray[i];
    end

endgenerate



//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================


endmodule
