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

output CCUSYA_Rst  //
output CCUSYA_CfgVld
input  SYACCU_CfgRdy
output CCUSYA_CfgMod
output CCUSYA_CfgNip 
output CCUSYA_CfgChi         
output CCUSYA_CfgScale        
output CCUSYA_CfgShift        
output CCUSYA_CfgZp
         
// output CCUSYA_Start
// input  SYACCU_Fnh
// output CCUSYA_EnLeft
// output CCUSYA_AccRstLeft

output CCUPOL_Rst
output CCUPOL_CfgVld
input  POLCCU_CfgRdy
output CCUPOL_CfgK
output CCUPOL_CfgNip
output CCUPOL_CfgChi

output CCUCTR_Rst
output CCUCTR_CfgVld
input  CTRCCU_CfgRdy
output CCUCTR_CfgMod          
output CCUCTR_CfgNip                    
output CCUCTR_CfgNop          
output CCUCTR_CfgK  

output CCUGLB_Rst
output CCUGLB_CfgVld          
input  GLBCCU_CfgRdy          
output CCUGLB_CfgBankPort 
output CCUGLB_CfgPort_AddrMax 
output CCUGLB_CfgRdPortParBank
output CCUGLB_CfgWrPortParBank      

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
        RD_CFG  :   if( full ) // 
                        next_state <= IDLE_CFG;
                    else
                        next_state <= RD_CFG;
        IDLE_CFG:   if (num_layer == Ly_Num)
                        next_state <= IDLE;
                    else if ( empty )
                        next_state <= RD_CFG;
                    else if (ReqCfg[0]) begin
                        next_state <= ARRAY_CFG;
                    end else if (Conv_ReqCfg) begin
                        next_state <= CONV_CFG;
                    end
        ARRAY_CFG:  if (AckCfg[0] ) begin
                        next_state <= IDLE_CFG;
                    end else 
                        next_state <= ARRAY_CFG;
        CONV_CFG:   if( Conv_AckCfg) /// Every type layer cfg: Array, FC,...
                        next_state <= IDLE_CFG;
                    else
                        next_state <= CONV_CFG;
        FC_CFG  :
        POL_CFG :
        FPS_CFG :
        KNN_CFG :
        FINISH  : 
        default :   next_state <= IDLE;
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
// Logic Design 3: Address of ISA RAM: input ReqCfg, output AckCfg
//=====================================================================================================================
// ReqCfg and AckCfg is only for state transfer

assign ReqCfgTri[0] =   state == IDLE & next_state == RD_CFG;//localparam OpCode_Array = 3'd0;
assign ReqCfgTri[1] = ( state == IDLE & next_state == RD_CFG ) | (SYACCU_CfgRdy & !SYACCU_CfgRdy);//localparam OpCode_Conv  = 3'd1;
assign ReqCfgTri[2] = 0;//== Conv localparam OpCode_FC    = 3'd2; 
assign ReqCfgTri[3] = ( state == IDLE & next_state == RD_CFG ) | (POLCCU_Fnh & POLCCU_Fnh_d);//localparam OpCode_Pool  = 3'd3;
assign ReqCfgTri[4] = ( state == IDLE & next_state == RD_CFG ) | (CTRCCU_FPSFnh & CTRCCU_FPSFnh_d);//localparam OpCode_FPS   = 3'd4;
assign ReqCfgTri[5] = ( state == IDLE & next_state == RD_CFG ) | (CTRCCU_KNNFnh & CTRCCU_KNNFnh_d);//localparam OpCode_KNN   = 3'd5;


genvar i;
generate
    for(i=0; i<NUM_TYPE_LAYER; i=i+1) begin

        always @(posedge clk or rst_n) begin
            if (!rst_n) begin
                ReqCfg[i] <= 0;
            end else if (AckCfg[i]) begin
                ReqCfg[i] <= 0;
            end else if ( ReqCfgTri[i]) begin
                ReqCfg[i] <= 1;
            end
        end

        always @(posedge clk or rst_n) begin
            if (!rst_n)
                Word[0] = 1;// localparam Word_Array = 1;
                Word[1] = 2;// localparam Word_Conv  = 2;
                Word[2] = 1;// localparam Word_FC    = 1;
                Word[3] = 2;// localparam Word_Pool  = 2;
                Word[4] = 1;// localparam Word_FPS   = 1;
                Word[5] = 1;// localparam Word_KNN   = 1;
        end
        always @(posedge clk or negedge rst_n)  begin
            if (!rst_n) begin
                addr[i] <= 0;
            end else if ( state == IDLE ) begin
                addr[i] <= 0;
            end else if ( read_en) begin
                addr[i] <= addr + 1;
            end
        end

        always @(posedge clk or negedge rst_n)  begin
            if (!rst_n) begin
                cnt_word <= 0;
            end if ( match ) begin
                    if ( cnt_word == Word[i] -1 ) begin
                    cnt_word <= 0;
                end else if ( read_en ) begin
                    cnt_word <= cnt_word + 1;
                end
            end
        end
        assign AckCfg[i] = match & cnt_word == Word[i] -1;
endgenerate


always @(*) begin
    match = 0;
    addr_r = 0;
    read_en = 0;
    for (j=0; j<NUM_TYPE_LAYER; j=j+1) begin
        if ( state == ?_CFG) begin
            addr_r = addr[j]
            match = OpCode == j;
            read_en = !(cnt_word[i] == Word[i] -1 & match);
        end
    end
end

//=====================================================================================================================
// Logic Design 3: ISA RAM Read and Write
//=====================================================================================================================
// Write Path
assign write_en = ITFCCU_DatVld & CCUITF_DatRdy;
assign CCUITF_DatRdy = state == RD_CFG;

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

//=====================================================================================================================
// Logic Design 3: ISA Decoder
//=====================================================================================================================
assign OpCode == data_out[0 +: 3];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        CCUSYA_CfgVld <= 1'b0;
    end else if ( read_en_d ) begin
        if ( OpCode == OpCode_Array) begin
            {Base_Addr0, Ly_Num, Mode} <= data_out[3 : PORT_WIDTH -1];
        end else if ( OpCode == OpCode_Conv) begin
            if (cnt_word == 0) begin
                DatAddr         <= data_out[3  : 34];
                WgtAddr         <= data_out[35 :66];
                CCUSYA_CfgNip   <= data_out[67 : 82];
                CCUSYA_CfgChi   <= data_out[83 : 94];
            end else if (cnt_word == 1) begin
                Cho <= data_out[0 : 11];       
                CCUSYA_CfgScale <= data_out[12 : 31];       
                CCUSYA_CfgShift <= data_out[32 : 39];
                CCUSYA_CfgZp    <= data_out[40 : 47];
                CCUSYA_CfgMod   <= data_out[48 : 49];
                WgtAddrRange    <= data_out[50 : 65];
                DatAddrRange    <= data_out[66 : 81];
                OfmAddrRange    <= data_out[82 : 95]; // ?? =97
                CCUSYA_CfgVld   <= 1'b1;
            // end else if (cnt_word == 2) begin
                // GLB Ports
                SYA_RdPortActBank <= // CCUGLB_CfgBankPort[4, NUM_PORT+4, NUM_PORT*2 + 4...]<= ; // 
                SYA_RdPortWgtBank <= // CCUGLB_CfgBankPort[5, NUM_PORT+5, NUM_PORT*2 + 5...]<= ; 
                SYA_WrPortOFmBank  <= // CCUGLB_CfgBankPort[1, NUM_PORT+1, NUM_PORT*2 + 1...]<= ; ????????????????????????????????????
                SYA_RdPortAct_AddrMax  <= 
                SYA_RdPortWgt_AddrMax
                SYA_WrPortOFm_AddrMax 
                SYA_RdPortActParBank  <= 
                SYA_RdPortWgtParBank
                SYA_WrPortOFmParBank 
            end
            if ( CCUSYA_CfgVld & SYACCU_CfgRdy)
                CCUSYA_CfgVld   <= 1'b0;
        end else if (OpCode == OpCode_Pool) begin
                DatAddr         <= data_out[3  : 34];
                CCUPOL_CfgNip   <= data_out[35 : 50];
                CCUPOL_CfgChi   <= data_out[51 : 62];// 
                CCUPOL_CfgK     <= data_out[63 : 68];// 
                POL_RdPortOfmBank <= 
                POL_WrPortOfmBank <=
                POL_RdPortOfm_AddrMax <= 
                POL_WrPortOfm_AddrMax <=
                POL_RdPortOfmBank_AddrMax <= 
                POL_WrPortOfmBank_AddrMax <=
        // end else if (OpCode == OpCode_FC) begin

        end else if (OpCode == OpCode_FPS) begin
                CCUCTR_CfgMod   <= 1'b0;
                Crd_addr        <= data_out[3  : 34];
                CCUCTR_CfgNip   <= data_out[35 : 66];
                CCUCTR_CfgNop   <= data_out[67 : 82];
                
        end else if (OpCode == OpCode_KNN) begin
                CCUCTR_CfgMod   <= 1'b1;
                Map_addr        <= data_out[3  : 34];
                CCUCTR_CfgNip   <= data_out[35 : 66];
                CCUCTR_CfgK     <= data_out[67 : 72];
        end
    end 
end


//=====================================================================================================================
// Logic Design 3: SYA Control
//=====================================================================================================================
assign CCUSYA_Rst = state == IDLE;
assign CCUPOL_Rst = state == IDLE;
assign CCUCTR_Rst = state == IDLE;
assign CCUGLB_Rst = state == IDLE;


//=====================================================================================================================
// Logic Design 4: GLB Control
//=====================================================================================================================
assign SYA_RdPortActRst  = (read_en_d & OpCode == OpCode_Conv & cnt_word == 2)_d; // Paulse, same with SYA_RdPortActBank;
assign SYA_RdPortWgtRst  = SYA_RdPortActRst;
assign SYA_WrPortOFmRst  = SYA_RdPortActRst;


genvar i;
generate
    for (i=0; i<NUM_BANK; i=i+1) begin 
            assign CCUGLB_CfgBankPort[i*NUM_PORT + 0] = ITF_WrPortDatBank[i];     CCU Control, Not Configuration       ???????????????????????????????????????????????????????????????????????
            assign CCUGLB_CfgBankPort[i*NUM_PORT + 1] = SYA_WrPortOfmBank[i];
            assign CCUGLB_CfgBankPort[i*NUM_PORT + 2] = POL_WrPortOfmBank[i];
            assign CCUGLB_CfgBankPort[i*NUM_PORT + 3] = ITF_RdPortDatBank[i];
            assign CCUGLB_CfgBankPort[i*NUM_PORT + 4] = SYA_RdPortActBank[i];// SYA_RdPortActBank is 4th Column of SYA_RdPortActBank 
            assign CCUGLB_CfgBankPort[i*NUM_PORT + 5] = SYA_RdPortWgtBank[i];
            assign CCUGLB_CfgBankPort[i*NUM_PORT + 6] = POL_RdPortOfmBank[i];

        end
endgenerate


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

RAM#(
    .SRAM_BIT     ( PORT_WIDTH   ),
    .SRAM_BYTE    ( 1            ),
    .SRAM_WORD    ( SRAM_WORD_ISA),
    .CLOCK_PERIOD ( CLOCK_PERIOD )
)u_RAM_ISA(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .addr_r       ( addr_r       ),
    .addr_w       ( addr_w       ),
    .read_en      ( read_en      ),
    .write_en     ( write_en     ),
    .data_in      ( ITFCCU_Dat   ),
    .data_out     ( data_out     )
);



endmodule
