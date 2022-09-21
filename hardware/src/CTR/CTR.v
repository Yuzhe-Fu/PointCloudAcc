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
`include "../source/include/dw_params.vh"
module CTR #(
    parameter NUM_PEB         = 16,
    parameter FIFO_ADDR_WIDTH = 6  
    )(
    input                               clk                     ,
    input                               rst_n                   ,

    // Configure
    input                               GBCFG_rdy               , // level
    output reg                          CFGGB_val               , // level

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE    = 3'b000;
localparam CFG     = 3'b001;
localparam CMP     = 3'b010;
localparam STOP    = 3'b011;
localparam WAITGBF = 3'b100;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                                start_cmp     ;
wire [ 6                    -1 : 0] MEM_CCUGB_block[ 0 : NUM_PEB -1 ];
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE : if( ASICCCU_start)
                    next_state <= CFG; //A network config a time
                else
                    next_state <= IDLE;
        CFG: if( fifo_full)
                    next_state <= CMP;
                else
                    next_state <= CFG;
        CMP: if( all_finish) /// CMP_FRM CMP_PAT CMP_...
                    next_state <= IDLE;
                else
                    next_state <= CMP;
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
// Logic Design 2: Addr Gen.
//=====================================================================================================================



//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

fifo #(
    .DATA_WIDTH(PORT_WIDTH ),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH )
    ) fifo_CONFIG(
    .clk ( clk ),
    .rst_n ( rst_n ),
    .Reset ( 1'b0), 
    .push(fifo_push) ,
    .pop(fifo_pop ) ,
    .data_in( IFCFG_data),
    .data_out (fifo_out ),
    .empty(fifo_empty ),
    .full (fifo_full )
    );


endmodule