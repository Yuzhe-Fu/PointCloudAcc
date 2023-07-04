// This is a simpleCCUMON_InOut example.
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
module MON #(
    parameter MONISA_WIDTH      = 128*2,
    parameter PORT_WIDTH        = 128,
    parameter MON_WIDTH         = 128*3
    )(
    input                                               clk             ,
    input                                               rst_n           ,

    input                                               CCUMON_CfgVld   ,
    output                                              MONCCU_CfgRdy   ,  
    input   [MONISA_WIDTH                       -1 : 0] CCUMON_CfgInfo  ,

    input  [MON_WIDTH                           -1 : 0] TOPMON_Dat      ,

    output [PORT_WIDTH                          -1 : 0] MONITF_Dat      ,
    output                                              MONITF_DatVld   ,
    output                                              MONITF_DatLast  ,
    input                                               ITFMON_DatRdy   

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE     = 3'b000;
localparam OUT2OFF  = 3'b011;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

//=====================================================================================================================
// Logic Design: ISA Decode
//=====================================================================================================================


//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================
reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if( CCUMON_CfgVld ) // Start
                    next_state <= OUT2OFF;
                else
                    next_state <= IDLE;
        OUT2OFF:if(CCUMON_CfgVld)
                    next_state <= IDLE;
                else if( MONITF_DatLast & MONITF_DatVld & ITFMON_DatRdy  ) // fetched by Off-chip
                    next_state <= IDLE;
                else
                    next_state <= OUT2OFF;
        default:    next_state <= IDLE;
    endcase
end
always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end
assign MONCCU_CfgRdy = state == IDLE;

//=====================================================================================================================
// Logic Design:
//=====================================================================================================================

PISO_NOCACHE#(
    .DATA_IN_WIDTH ( MON_WIDTH ),
    .DATA_OUT_WIDTH ( PORT_WIDTH )
)u_PISO(
    .CLK           ( clk            ),
    .RST_N         ( rst_n          ),
    .RESET         ( state == IDLE  ),
    .IN_VLD        ( state == OUT2OFF),
    .IN_LAST       ( 1'b1           ),
    .IN_DAT        ( TOPMON_Dat     ),
    .IN_RDY        (                ),
    .OUT_DAT       ( MONITF_Dat     ),
    .OUT_VLD       ( MONITF_DatVld  ),
    .OUT_LAST      ( MONITF_DatLast ),
    .OUT_RDY       ( ITFMON_DatRdy  )
);

endmodule

