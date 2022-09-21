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
module PLCC #(
    parameter NUM_MAX         = 64,
    parameter DATA_WIDTH      = 8
    )(
    input                               clk                     ,
    input                               rst_n                   ,   
    input   DatInVld ,
input   DatInLast,
input   DatIn    ,
output DatInRdy ,
output DatOutVld,
output DatOut   ,
input DatOutRdy
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE     = 3'b000;
localparam CMP      = 3'b001;
localparam OUTPUT   = 3'b011;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

reg [DATA_WIDTH     -1 : 0] MaxArray[0 : NUM_MAX    -1];

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================
genvar i;
generate 
    for(i=0; i<NUM_MAX; i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                MaxArray[i] <= 0;
            end else if ( state == OUTPUT & (next_state == CMP | next_state == IDLE) ) begin
                MaxArray[i] <= 0;                
            end else if ( state == CMP & (DatInVld & DatInRdy) ) begin
                MaxArray[i] <= (DatIn > MaxArray[i] )? DatIn : MaxArray[i];
            end
        end
        assign DatOut[DATA_WIDTH*i +: DATA_WIDTH] =  MaxArray[i];
    end
endgenerate
assign DatOutVld = state == OUTPUT;


//=====================================================================================================================
// Logic Design 2: Addr Gen.
//=====================================================================================================================
reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE : 
                    next_state <= CMP;
        CMP: if ( DatInLast & (DatInVld & DatInRdy))
                    next_state <= OUTPUT;
                else
                    next_state <= CMP;
        OUTPUT: if( DatOutVld & DatOutRdy) /// CMP_FRM CMP_PAT CMP_...
                    next_state <= CMP;
                else
                    next_state <= OUTPUT;

        default: next_state <= IDLE;
    endcase
end

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================



endmodule
