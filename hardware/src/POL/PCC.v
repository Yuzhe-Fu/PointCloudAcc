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

module PCC #(
    parameter NUM_MAX         = 64,
    parameter DATA_WIDTH      = 8
    )(
    input                                   clk                     ,
    input                                   rst_n                   ,
    input                                   Rst      ,   
    input                                   DatInVld ,
    input                                   DatInLast,
    input       [DATA_WIDTH*NUM_MAX -1 : 0] DatIn    ,
    output                                  DatInRdy ,
    output                                  DatOutVld,
    output      [DATA_WIDTH*NUM_MAX -1 : 0] DatOut   ,
    input                                   DatOutRdy
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE     = 3'b000;
localparam COMP     = 3'b001;
localparam OUTPUT   = 3'b011;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

reg [DATA_WIDTH     -1 : 0] MaxArray[0 : NUM_MAX    -1];



//=====================================================================================================================
// Logic Design 2: Addr Gen.
//=====================================================================================================================
reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE : 
                    next_state <= COMP;
        COMP: if ( DatInLast & (DatInVld & DatInRdy))
                    next_state <= OUTPUT;
                else
                    next_state <= OUTPUT;
        OUTPUT: if( DatOutVld & DatOutRdy) /// 
                    next_state <= COMP;
                else
                    next_state <= OUTPUT;

        default: next_state <= IDLE;
    endcase
end

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else if(Rst) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================
genvar i;
generate 
    for(i=0; i<NUM_MAX; i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                MaxArray[i] <= 0;
            end else if(Rst) begin
                MaxArray[i] <= 0;
            end else if ( state == OUTPUT & (next_state == COMP | next_state == IDLE) ) begin
                MaxArray[i] <= 0;                
            end else if ( state == COMP & (DatInVld & DatInRdy) ) begin
                MaxArray[i] <= (DatIn > MaxArray[i] )? DatIn : MaxArray[i];
            end
        end
        assign DatOut[DATA_WIDTH*i +: DATA_WIDTH] =  MaxArray[i];
    end
endgenerate
assign DatOutVld = state == OUTPUT;
assign DatInRdy = state == COMP;


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================



endmodule
