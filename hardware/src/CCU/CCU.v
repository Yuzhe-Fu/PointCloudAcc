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
    input                               TOPCCU_start,

    // Configure
input  ITFCCU_Dat             
input  ITFCCU_DatVld          
output CCUITF_DatRdy          
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
output CCUGLB_CfgBankPort 
output CCUGLB_CfgPortMod,
output CCUGLB_CfgRdPortLoop,
output CCUGLB_CfgWrPortLoop,
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
localparam RD_CFG  = 3'b001;
localparam LY_CFG  = 3'b010;
localparam LY_WORK = 3'b011;
localparam FNH     = 3'b100;


localparam OpCode_Array = 3'd0;
localparam OpCode_Conv  = 3'd1;
localparam OpCode_FC    = 3'd2;
localparam OpCode_Pool  = 3'd3;
localparam OpCode_FPS   = 3'd4;
localparam OpCode_KNN   = 3'd5;

localparam Word_Array = 1;
localparam Word_Conv  = 2;
localparam Word_FC    = 1;
localparam Word_Pool  = 2;
localparam Word_FPS   = 1;
localparam Word_KNN   = 1;
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
        IDLE    :   if( TOPCCU_start)
                        next_state <= RD_CFG; //
                    else
                        next_state <= IDLE;
        RD_CFG  :   if( fifo_full) // 
                        next_state <= LY_CFG;
                    else
                        next_state <= RD_CFG;
        IDLE_CFG:   if (Array_ReqCfg) begin
                        next_state <= ARRAY_CFG;
                    end else if (Conv_ReqCfg) begin
                        next_state <= CONV_CFG;
                    end
        ARRAY_CFG: 
        CONV_CFG:   if( Conv_AckCfg) /// Every type layer cfg: Array, FC,...
                        next_state <= IDLE_CFG;
                    else
                        next_state <= CONV_CFG;
        FC_CFG  :
        POL_CFG :
        FPS_CFG :
        KNN_CFG :
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

//=====================================================================================================================
// Logic Design 2: GLB Max Addr Gen.
//=====================================================================================================================






//=====================================================================================================================
// Logic Design 3: Cfg Memory Address Gen: input ReqCfg, output AckCfg
//=====================================================================================================================

genvar i;
generate
    for(i=0; i<NUM_TYPE_LAYER; i=i+1) begin
        always @(posedge clk or negedge rst_n)  begin
            if (!rst_n) begin
                addr[i] <= 0;
            end else if ( state == IDLE | cnt_word == Word[i]) begin
                addr[i] <= 0;
            end else if ( ReqCfg & match) begin
                addr[i] <= addr + 1;
            end
        end

        always @(posedge clk or negedge rst_n)  begin
            if (!rst_n) begin
                cnt_word <= 0;
            end else if (  cnt_word == Word[i]) begin
                cnt_word <= 0;
            end else if ( ReqCfg & match) begin
                cnt_word <= cnt_word + 1;
            end
        end


endgenerate


always @(*) begin
    for (j=0; j<NUM_TYPE_LAYER; j=j+1) begin
        if (ReqCfg[j]) begin
            addr_r = addr[j]
        end
    end
end


assign match = ;

assign OpCode == data_out[0 +: 3];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
    end else if ( read_en_d ) begin
        if ( OpCode == OpCode_Array) begin
            {Base_Addr0, Ly_Num, Mode} <= data_out[3 : PORT_WIDTH -1];
        end else if ( OpCode == OpCode_Conv) begin
            if (cnt_word == 0) begin
                DatAddr <= data_out[3: 34];
                WgtAddr <= data_out[35 :66];
                Nip <= data_out[67 : 82];
                Chi <= data_out[83 : 94];
            end else if (cnt_word == 1) begin
                Cho <= data_out[0 : 11];       
                CCUSYA_CfgScale <= data_out[12 : 31];       
                CCUSYA_CfgShift <= data_out[32 : 39];
                CCUSYA_CfgZp <= data_out[40: 47];
                CCUSYA_CfgMod <= data_out[48: 49];
                WgtAddrRange <= data_out[50 : 65];
                DatAddrRange <= data_out[66 : 81];
                OfmAddrRange <= data_out[82 : 95]; // ?? =97
            end
        end else if (OpCode == OpCode_Pool) begin
            
        end else if (OpCode == OpCode_FC) begin
            
        end else if (OpCode == OpCode_FPS) begin
            
        end
    end 
end


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

RAM#(
    .SRAM_BIT     ( PORT_WIDTH ),
    .SRAM_BYTE    ( 1 ),
    .SRAM_WORD    ( SRAM_WORD_ISA ),
    .CLOCK_PERIOD ( CLOCK_PERIOD )
)u_RAM_ISA(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .addr_r       ( addr_r       ),
    .addr_w       ( addr_w       ),
    .read_en      ( read_en      ),
    .write_en     ( write_en     ),
    .data_in      ( ITFCCU_Dat      ),
    .data_out     ( data_out     )
);
// Write Path
assign write_en = ITFCCU_DatVld & CCUITF_DatRdy;

always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        addr_w <= 0;
    end else if (state == IDLE ) begin
        addr_w <= 0;
    end else if (write_en ) begin
        addr_w <= addr_w + 1;
    end
end

assign full = addr_w - min(addr[]) == SRAM_WORD_ISA;
assign empty = addr_w == min(addr[];

// Read Path
assign read_en = ReqCfg;



endmodule
