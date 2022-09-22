
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
module CCU #(
    parameter NUM_PEB         = 16,
    parameter FIFO_ADDR_WIDTH = 6  
    )(
    input                               clk                     ,
    input                               rst_n                   ,

K             
POLPLC_IdxVld 
POLPLC_Idx    
output PLCPOL_IdxRdy 
PLCPOL_AddrVld
PLCPOL_Addr   
POLPLC_AddrRdy
POLPLC_Fm     
POLPLC_FmVld  
PLCPOL_FmRdy  
POLPCL_Fm     
POLPCL_FmVld  
PCLPOL_FmRdy  

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE     = 3'b000;
localparam IDX      = 3'b001;
localparam ADDR     = 3'b010;
localparam OUTPUT   = 3'b011;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
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

assign DatInLast  = overflow; // & &
assign inc_addr   = POLPLC_AddrRdy & PLCPOL_AddrVld;
assign clear_addr = POLPLC_IdxVld  & PLCPOL_IdxRdy ;

assign PLCPOL_IdxRdy  = state == IDX;
assign PLCPOL_AddrVld = state == ADDR;


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

PLCC#(
    .NUM_MAX   ( 64 ),
    .DATA_WIDTH ( 8 )
)U1_PLCC(
    .clk       ( clk       ),
    .rst_n     ( rst_n     ),
    .DatInVld  ( POLPLC_FmVld  ),
    .DatInLast ( DatInLast ),
    .DatIn     ( POLPLC_Fm     ),
    .DatInRdy  ( PLCPOL_FmRdy  ),
    .DatOutVld ( POLPCL_FmVld ),
    .DatOut    ( POLPCL_Fm    ),
    .DatOutRdy  ( PCLPOL_FmRdy  )
);

counter#(
    .COUNT_WIDTH ( 3 )
)u_counter(
    .CLK       ( clk       ),
    .RESET_N   ( rst_n   ),
    .CLEAR     ( clear_addr     ),
    .DEFAULT   ( 0   ),
    .INC       ( inc_addr       ),
    .DEC       ( 1'b0       ),
    .MIN_COUNT ( 0 ),
    .MAX_COUNT ( K-1 ),
    .OVERFLOW  ( overflow  ),
    .UNDERFLOW ( UNDERFLOW ),
    .COUNT     ( addr     )
);


endmodule
