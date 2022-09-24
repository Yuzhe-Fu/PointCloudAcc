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
module CCU #(
    parameter NUM_PEB         = 16,
    parameter FIFO_ADDR_WIDTH = 6  
    )(
    input                               clk                     ,
    input                               rst_n                   ,

    // Configure
input  ITFCCU_Dat             
input  ITFCCU_DatVld          
output ITFCCU_DatRdy          
output CCUSYA_CfgMod          
output CCUSYA_CfgScale        
output CCUSYA_CfgShift        
output CCUSYA_CfgZp           
output CCUSYA_Start           
output CCUPOL_CfgK            
output CCUCTR_CfgMod          
output CCUCTR_CfgNip          
output CCUCTR_CfgNfl          
output CCUCTR_CfgNop          
output CCUCTR_CfgK            
output CCUGLB_CfgVld          
input  GLBCCU_CfgRdy          
output CCUGLB_CfgPort_BankFlg 
output CCUGLB_CfgPort_AddrMax 
output CCUGLB_CfgRdPortParBank
output CCUGLB_CfgWrPortParBank
input  GLBCCU_Port_fnh        
output CCUGLB_Port_rst        

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE    = 3'b000;
localparam RD_CFG     = 3'b001;
localparam LY_CFG    = 3'b010;
localparam LY_WORK    = 3'b011;
localparam FNH = 3'b100;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                                start_COMP                       ;
wire [ 6                    -1 : 0] MEM_CCUGB_block[0 : NUM_PEB -1 ];
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE : if( ASICCCU_start)
                    next_state <= RD_CFG; //A network config a time
                else
                    next_state <= IDLE;
        RD_CFG: if( fifo_full)
                    next_state <= LY_CFG;
                else
                    next_state <= RD_CFG;
        LY_CFG: if( all_finish) /// COMP_FRM COMP_PAT COMP_...
                    next_state <= IDLE;
                else
                    next_state <= LY_CFG;
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

assign {
    OpCode,
    CCUSYA_CfgMod,
    DatAddr,
    WgtAddr,
    Nip,
    Chi,
    Cho,
    CCUSYA_CfgScale,
    CCUSYA_CfgShift,
    CCUSYA_CfgZp,


    } = fifo_out;


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

FIFO_FWFT #(
    .DATA_WIDTH(SRAM_WIDTH ),
    .ADDR_WIDTH(FIFO_ADDR_WIDTH )
    ) U1_FIFO_FWFT_CFG(
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
