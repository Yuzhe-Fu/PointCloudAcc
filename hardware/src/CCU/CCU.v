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
    parameter SRAM_WORD_ISA         = 64,
    parameter SRAM_WIDTH            = 256,

    parameter ADDR_WIDTH            = 16,
    parameter DRAM_ADDR_WIDTH       = 32,
    parameter NUM_RDPORT            = 2,
    parameter NUM_WRPORT            = 3,
    parameter IDX_WIDTH             = 16,
    parameter CHN_WIDTH             = 12,
    parameter ACT_WIDTH             = 8,
    parameter MAP_WIDTH             = 6,
    parameter NUM_LAYER_WIDTH       = 20,
    parameter OPNUM                 = 6,

    parameter MAXPAR                = 32,
    parameter NUM_BANK              = 32

    )(
    input                               clk                     ,
    input                               rst_n                   ,
    input                                               TOPCCU_start,
    output                                              CCUTOP_NetFnh,
    output                                              CCUITF_Empty ,
    output [ADDR_WIDTH                          -1 : 0] CCUITF_ReqNum,
    output [ADDR_WIDTH                          -1 : 0] CCUITF_Addr  ,
        // Configure
    input   [SRAM_WIDTH                         -1 : 0] ITFCCU_Dat,             
    input                                               ITFCCU_DatVld,          
    output                                              CCUITF_DatRdy,

    output  [DRAM_ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT) -1 : 0] CCUITF_BaseAddr,

    output                                              CCUSYA_Rst,  //
    output                                              CCUSYA_CfgVld,
    input                                               SYACCU_CfgRdy,
    output  [2                                  -1 : 0] CCUSYA_CfgMod,
    output  [IDX_WIDTH                          -1 : 0] CCUSYA_CfgNip, 
    output  [CHN_WIDTH                          -1 : 0] CCUSYA_CfgChi,         
    output  [20                                 -1 : 0] CCUSYA_CfgScale,        
    output  [ACT_WIDTH                          -1 : 0] CCUSYA_CfgShift,        
    output  [ACT_WIDTH                          -1 : 0] CCUSYA_CfgZp,

    output                                              CCUPOL_Rst,
    output                                              CCUPOL_CfgVld,
    input                                               POLCCU_CfgRdy,
    output  [MAP_WIDTH                          -1 : 0] CCUPOL_CfgK,
    output  [IDX_WIDTH                          -1 : 0] CCUPOL_CfgNip,
    output  [CHN_WIDTH                          -1 : 0] CCUPOL_CfgChi,

    output                                              CCUCTR_Rst,
    output                                              CCUCTR_CfgVld,
    input                                               CTRCCU_CfgRdy,
    output                                              CCUCTR_CfgMod,         
    output  [IDX_WIDTH                          -1 : 0] CCUCTR_CfgNip,                    
    output  [IDX_WIDTH                          -1 : 0] CCUCTR_CfgNop,          
    output  [MAP_WIDTH                          -1 : 0] CCUCTR_CfgK,  

    output                                              CCUGLB_Rst,
    output [NUM_RDPORT+NUM_WRPORT               -1 : 0] CCUGLB_CfgVld ,         
    input  [NUM_RDPORT+NUM_WRPORT               -1 : 0] GLBCCU_CfgRdy ,         
    output [(NUM_RDPORT + NUM_WRPORT)* NUM_BANK -1 : 0] CCUGLB_CfgBankPort ,
    output [ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)  -1 : 0] CCUGLB_CfgPort_AddrMax, 
    output [($clog2(MAXPAR) + 1)*NUM_RDPORT     -1 : 0] CCUGLB_CfgRdPortParBank,
    output [($clog2(MAXPAR) + 1)*NUM_WRPORT     -1 : 0] CCUGLB_CfgWrPortParBank      

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam OPCODE_WIDTH = $clog2(OPNUM);

localparam IDLE     = 3'd0000;
localparam RD_CFG   = 3'd0001;
localparam IDLE_CFG = 3'd0010;
localparam FNH      = 3'd0011;
localparam ARRAY_CFG= 3'd1000; // 0
localparam CONV_CFG = 3'd1001; // 1
localparam FC_CFG   = 3'd1010; // 2
localparam POL_CFG  = 3'd1011; // 3
localparam CTR_CFG  = 3'd1100; // 4




localparam OpCode_Array = 3'd0;
localparam OpCode_Conv  = 3'd1;
localparam OpCode_FC    = 3'd2;
localparam OpCode_Pool  = 3'd3;
localparam OpCode_CTR   = 3'd4;
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
                        next_state <= FNH;
                    else if ( empty )
                        next_state <= RD_CFG;
                    else if (num_layer==0)
                        next_state <= ARRAY_CFG;
                    else if (SYACCU_CfgRdy)
                        next_state <= CONV_CFG;
                    else if (POLCCU_CfgRdy)
                        next_state <= POL_CFG;
                    else if (CTRCCU_CfgRdy)
                        next_state <= CTR_CFG;
                    else 
                        next_state <= IDLE_CFG;

        ARRAY_CFG:  if ( read_en_d & OpCode == OpCode_Array)
                        next_state <= IDLE_CFG;
                    else 
                        next_state <= ARRAY_CFG;
        CONV_CFG:   if( SYACCU_CfgRdy & CCUSYA_CfgVld)
                        next_state <= IDLE_CFG;
                    else
                        next_state <= CONV_CFG;
        POL_CFG :   if (POLCCU_CfgRdy & CCUPOL_CfgVld)
                        next_state <= IDLE_CFG;
                    else 
                        next_state <= POL_CFG;
        CTR_CFG :   if (CTRCCU_CfgRdy & CCUCTR_CfgVld)
                        next_state <= IDLE_CFG;
                    else 
                        next_state <= CTR_CFG;
        FNH     :   next_state <= IDLE;
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
// Logic Design TOP
//=====================================================================================================================
assign CCUTOP_NetFnh = state == FNH;
always @(posedge clk or rst_n) begin
    if(!rst_n) begin
        num_layer <= 0;
    end else if(state ==IDLE) begin
        num_layer <= 0;
    end else if(state==IDLE_CFG & next_state[3]) begin // transfer to layer config
        num_layer <= num_layer + 1;
    end
end

//=====================================================================================================================
// Logic Design 3: ISA RAM Write
//=====================================================================================================================
// Write Path
assign CCUITF_Empty = empty;
assign CCUITF_ReqNum = SRAM_WORD_ISA - (addr_w - AddrRdMin); // empty number
assign CCUITF_Addr = 0;

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

assign full = addr_w - AddrRdMin == SRAM_WORD_ISA;
assign empty = addr_w == AddrRdMin;


//=====================================================================================================================
// Logic Design 3: Address of ISA RAM: input ReqCfg, output AckCfg
//=====================================================================================================================

genvar i;
generate
    for(i=0; i<NUM_TYPE_LAYER; i=i+1) begin

        always @(posedge clk or rst_n) begin
            if (!rst_n)
                Word[0] = 1;// localparam Word_Array = 1;
                Word[1] = 6;// localparam Word_Conv  = 2;
                Word[2] = 0;// localparam Word_FC    = 1;
                Word[3] = 3;// localparam Word_Pool  = 2;
                Word[4] = 5;// localparam Word_FPS   = 1;
                Word[5] = 0;// localparam Word_KNN   = 1;
        end
        always @(posedge clk or negedge rst_n)  begin
            if (!rst_n) begin
                addr_array[i] <= 0;
            end else if ( state == IDLE ) begin
                addr_array[i] <= 0;
            end else if ( read_en & state[0 +: 3] == i) begin
                addr_array[i] <= addr_array[i] + 1;
            end
        end

endgenerate


always @(*) begin
    match = 0;
    addr_r = 0;
    read_en = 0;
    AddrRd1D = 0;
    cnt_word = cnt_word_d;
    for (j=0; j<NUM_TYPE_LAYER; j=j+1) begin
        if ( state[0 +: 3] == j) begin
            cnt_word = (read_en_d & match) ? cnt_word + 1 : cnt_word;
            match = OpCode == j;
            read_en = !(cnt_word[i] == Word[i] & match);

            addr_r = addr_array[j]
        end
        assign AddrRd1D[ADDR_WIDTH*j +: ADDR_WIDTH] = addr_array[j];
    end
end


//=====================================================================================================================
// Logic Design 3: ISA Decoder
//=====================================================================================================================
assign OpCode == data_out[0 +: 3];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        CCUSYA_CfgVld <= 1'b0;
        CCUPOL_CfgVld <= 1'b0;
    end else if ( read_en_d ) begin
        if ( OpCode == OpCode_Array) begin
            {Base_Addr0, Ly_Num, Mode} <= data_out[3 : PORT_WIDTH -1];

        end else if ( OpCode == OpCode_Conv) begin
            if (cnt_word == 1) begin
                DramDatAddr         <= data_out[3  : 34];
                DramWgtAddr         <= data_out[35 : 66];
                CCUSYA_CfgNip   <= data_out[67 : 82];
                CCUSYA_CfgChi   <= data_out[83 : 94];
                DramOfmAddr         <= data_out[95 +: 32];
            end else if (cnt_word == 2) begin
                Cho <= data_out[0 : 11];       
                CCUSYA_CfgScale <= data_out[12 : 31];       
                CCUSYA_CfgShift <= data_out[32 : 39];
                CCUSYA_CfgZp    <= data_out[40 : 47];
                CCUSYA_CfgMod   <= data_out[48 : 49];
                WgtAddrRange    <= data_out[50 : 65];
                DatAddrRange    <= data_out[66 : 81];
                OfmAddrRange    <= data_out[82 : 95]; // ?? =97
            end else if (cnt_word == 3) begin
                // GLB Ports
                SYA_RdPortActBank <= data_out[0 +: 32];
                SYA_RdPortWgtBank <= data_out[32 +: 32];
                SYA_WrPortOfmBank <= data_out[64 +: 32];
            end else if (cnt_word == 4) begin
                ITF_WrPortActBank <= data_out[0 +: 32];
                ITF_WrPortWgtBank <= data_out[32 +: 32];
                ITF_RdPortOfmBank <= data_out[64 +: 32];
            end else if (cnt_word == 5) begin
                SYA_RdPortAct_AddrMax <= data_out[0 +: 16];
                SYA_RdPortWgt_AddrMax <= data_out[16 +: 16];
                SYA_WrPortOFm_AddrMax <= data_out[32 +: 16];
                SYA_RdPortActParBank  <= data_out[48 +: 6];
                SYA_RdPortWgtParBank  <= data_out[54 +: 6];
                SYA_WrPortOFmParBank  <= data_out[60 +: 6];
            end else if (cnt_word == 6) begin
                ITF_WrPortAct_AddrMax <= data_out[0 +: 16];
                ITF_WrPortWgt_AddrMax <= data_out[16 +: 16];
                ITF_RdPortOFm_AddrMax <= data_out[32 +: 16];
                ITF_WrPortActParBank  <= data_out[48 +: 6];
                ITF_WrPortWgtParBank  <= data_out[54 +: 6];
                ITF_RdPortOFmParBank  <= data_out[60 +: 6];
            end
            if ( Conv_CfgVld & Conv_CfgRdy)
                Conv_CfgVld <= 1'b0;
            else if(cnt_word == 4 )
                Conv_CfgVld <= 1'b1;

        end else if (OpCode == OpCode_Pool) begin
            if (cnt_word == 1) begin
                DramDatAddr         <= data_out[3  +: 32];
                
                CCUPOL_CfgNip   <= data_out[35 +: 16];
                CCUPOL_CfgChi   <= data_out[51 +: 12];// 
                CCUPOL_CfgK     <= data_out[63 +: 16];// 
                DramWrMapAddr         <= data_out[79 +: 32];
            end else if(cnt_word == 2) begin
                POL_RdPortOfmBank <= data_out[0  +: 32];
                POL_WrPortOfmBank <= data_out[32 +: 32];
                POL_RdPortMapBank <= data_out[64 +: 32];
                ITF_WrPortMapBank <= data_out[96 +: 32];
            end else if(cnt_word == 3) begin
                POL_RdPortOfm_AddrMax <= data_out[0  +: 16];
                POL_WrPortOfm_AddrMax <= data_out[16 +: 16];
                POL_RdPortMap_AddrMax <= data_out[32 +: 16];
                ITF_WrPortMap_AddrMax <= data_out[48 +: 16];
                POL_RdPortOfmParBank  <= data_out[64 +:  6];
                POL_WrPortOfmParBank  <= data_out[70 +:  6];
                POL_RdPortMapParBank  <= data_out[76 +:  6];
                ITF_WrPortMapParBank  <= data_out[82  +: 6];
            end
            if (Pool_CfgVld & Pool_CfgRdy) begin
                Pool_CfgVld <= 1'b0;
            end else if(cnt_word == 3) 
                Pool_CfgVld <= 1'b1;

        end else if (OpCode == OpCode_CTR) begin
                if(cnt_word == 1) begin
                    CCUCTR_CfgMod   <= data_out[3];
                    DramCrdAddr        <= data_out[4  +: 32];
                    CCUCTR_CfgNip   <= data_out[36 +: 16];
                    CCUCTR_CfgNop   <= data_out[52 +: 16];
                    CCUCTR_CfgK     <= data_out[68 +: 6];
                    DramRdMapAddr   <= data_out[74 +: 32];
                end else if(cnt_word == 2) begin
                    ITF_WrPortCrdBank <= data_out[0 +: 32];
                    ITF_RdPortMapBank <= data_out[32+: 32];
                    CTR_WrPortDstBank <= data_out[64+: 32];
                end else if(cnt_word == 3) begin
                    CTR_WrPortMapBank <= data_out[0 +: 32];
                    CTR_RdPortCrdBank <= data_out[32+: 32];
                    CTR_RdPortDstBank <= data_out[64+: 32];
                end else if( cnt_word == 4) begin
                    ITF_WrPortCrd_AddrMax <= data_out[0  +: 16];
                    ITF_RdPortMap_AddrMax <= data_out[16 +: 16];
                    CTR_WrPortDst_AddrMax <= data_out[32 +: 16];
                    CTR_WrPortMap_AddrMax <= data_out[48 +: 16];
                    CTR_RdPortCrd_AddrMax <= data_out[64 +: 16];
                    CTR_RdPortDst_AddrMax <= data_out[80 +: 16];
                end else if ( cnt_word == 5) begin 
                    ITF_WrPortCrdParBank <= data_out[0  +: 6];
                    ITF_RdPortMapParBank <= data_out[6  +: 6];
                    CTR_WrPortDstParBank <= data_out[12 +: 6];
                    CTR_WrPortMapParBank <= data_out[18 +: 6];
                    CTR_RdPortCrdParBank <= data_out[24 +: 6];
                    CTR_RdPortDstParBank <= data_out[30 +: 6];            
                end
                if(Ctr_CfgVld & Ctr_CfgRdy) 
                    Ctr_CfgVld <= 1'b0;
                else
                    Ctr_CfgVld <= 1'b1;
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
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 0] = ITF_WrPortActBank[i];
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 1] = ITF_WrPortWgtBank[i];  
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 2] = ITF_WrPortCrdBank[i];  
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 3] = ITF_WrPortMapBank[i];  
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 4] = SYA_WrPortOfmBank[i];
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 5] = POL_WrPortOfmBank[i];
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 6] = CTR_WrPortDstBank[i];
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 7] = CTR_WrPortMapBank[i];
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 0] = ITF_RdPortMapBank[i];
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 1] = ITF_RdPortOfmBank[i];
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 2] = SYA_RdPortActBank[i];// SYA_RdPortActBank is 4th Column of SYA_RdPortActBank 
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 3] = SYA_RdPortWgtBank[i];
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 4] = POL_RdPortOfmBank[i];
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 5] = POL_RdPortMapBank[i];
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 6] = CTR_RdPortCrdBank[i];
        assign CCUGLB_CfgBankPort[i*NUM_PORT + 7] = CTR_RdPortDstBank[i];
    end
endgenerate

assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*0      +: ADDR_WIDTH] = ITF_WrPortAct_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*1      +: ADDR_WIDTH] = ITF_WrPortWgt_AddrMax;  
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*2      +: ADDR_WIDTH] = ITF_WrPortCrd_AddrMax;  
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*3      +: ADDR_WIDTH] = ITF_WrPortMap_AddrMax;  
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*4      +: ADDR_WIDTH] = SYA_WrPortOfm_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*5      +: ADDR_WIDTH] = POL_WrPortOfm_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*6      +: ADDR_WIDTH] = CTR_WrPortDst_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*7      +: ADDR_WIDTH] = CTR_WrPortMap_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(0+8)  +: ADDR_WIDTH] = ITF_RdPortMap_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(1+8)  +: ADDR_WIDTH] = ITF_RdPortOfm_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(2+8)  +: ADDR_WIDTH] = SYA_RdPortAct_AddrMax;// SYA_RdPortActBank is 4th Column of SYA_RdPortActBank 
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(3+8)  +: ADDR_WIDTH] = SYA_RdPortWgt_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(4+8)  +: ADDR_WIDTH] = POL_RdPortOfm_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(5+8)  +: ADDR_WIDTH] = POL_RdPortMap_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(6+8)  +: ADDR_WIDTH] = CTR_RdPortCrd_AddrMax;
assign CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(7+8)  +: ADDR_WIDTH] = CTR_RdPortDst_AddrMax;

assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*0 +: ($clog2(MAXPAR) + 1)] = ITF_WrPortActParBank;
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*1 +: ($clog2(MAXPAR) + 1)] = ITF_WrPortWgtParBank;  
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*2 +: ($clog2(MAXPAR) + 1)] = ITF_WrPortCrdParBank;  
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*3 +: ($clog2(MAXPAR) + 1)] = ITF_WrPortMapParBank;  
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*4 +: ($clog2(MAXPAR) + 1)] = SYA_WrPortOfmParBank;
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*5 +: ($clog2(MAXPAR) + 1)] = POL_WrPortOfmParBank;
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*6 +: ($clog2(MAXPAR) + 1)] = CTR_WrPortDstParBank;
assign CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*7 +: ($clog2(MAXPAR) + 1)] = CTR_WrPortMapParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*0 +: ($clog2(MAXPAR) + 1)] = ITF_RdPortMapParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*1 +: ($clog2(MAXPAR) + 1)] = ITF_RdPortOfmParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*2 +: ($clog2(MAXPAR) + 1)] = SYA_RdPortActParBank;// SYA_RdPortActBank is 4th Column of SYA_RdPortActBank 
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*3 +: ($clog2(MAXPAR) + 1)] = SYA_RdPortWgtParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*4 +: ($clog2(MAXPAR) + 1)] = POL_RdPortOfmParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*5 +: ($clog2(MAXPAR) + 1)] = POL_RdPortMapParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*6 +: ($clog2(MAXPAR) + 1)] = CTR_RdPortCrdParBank;
assign CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*7 +: ($clog2(MAXPAR) + 1)] = CTR_RdPortDstParBank;

assign CCUGLB_CfgVld[0    ] = ITF_WrPortAct_AddrMax;
assign CCUGLB_CfgVld[1    ] = ITF_WrPortWgt_AddrMax;  
assign CCUGLB_CfgVld[2    ] = ITF_WrPortCrd_AddrMax;  
assign CCUGLB_CfgVld[3    ] = ITF_WrPortMap_AddrMax;  
assign CCUGLB_CfgVld[4    ] = SYA_WrPortOfm_AddrMax;
assign CCUGLB_CfgVld[5    ] = POL_WrPortOfm_AddrMax;
assign CCUGLB_CfgVld[6    ] = CTR_WrPortDst_AddrMax;
assign CCUGLB_CfgVld[7    ] = CTR_WrPortMap_AddrMax;
assign CCUGLB_CfgVld[(0+8)] = ITF_RdPortMap_AddrMax;
assign CCUGLB_CfgVld[(1+8)] = ITF_RdPortOfm_AddrMax;
assign CCUGLB_CfgVld[(2+8)] = SYA_RdPortAct_AddrMax;// SYA_RdPortActBank is 4th Column of SYA_RdPortActBank 
assign CCUGLB_CfgVld[(3+8)] = SYA_RdPortWgt_AddrMax;
assign CCUGLB_CfgVld[(4+8)] = POL_RdPortOfm_AddrMax;
assign CCUGLB_CfgVld[(5+8)] = POL_RdPortMap_AddrMax;
assign CCUGLB_CfgVld[(6+8)] = CTR_RdPortCrd_AddrMax;
assign CCUGLB_CfgVld[(7+8)] = CTR_RdPortDst_AddrMax;


assign Conv_CfgRdy = SYACCU_CfgRdy & GLBCCU_CfgRdy[0] & GLBCCU_CfgRdy[1] & GLBCCU_CfgRdy[4] &  GLBCCU_CfgRdy[9] &  GLBCCU_CfgRdy[10] &  GLBCCU_CfgRdy[11];
assign CCUSYA_CfgVld = Conv_CfgVld & SYACCU_CfgRdy;
assign CCUGLB_CfgVld[ 0] = Conv_CfgVld & GLBCCU_CfgRdy[ 0];
assign CCUGLB_CfgVld[ 1] = Conv_CfgVld & GLBCCU_CfgRdy[ 1];
assign CCUGLB_CfgVld[ 4] = Conv_CfgVld & GLBCCU_CfgRdy[ 4];
assign CCUGLB_CfgVld[ 9] = Conv_CfgVld & GLBCCU_CfgRdy[ 9];
assign CCUGLB_CfgVld[10] = Conv_CfgVld & GLBCCU_CfgRdy[10];
assign CCUGLB_CfgVld[11] = Conv_CfgVld & GLBCCU_CfgRdy[11];

assign Pool_CfgRdy = POLCCU_CfgRdy & GLBCCU_CfgRdy[3] & GLBCCU_CfgRdy[5] & GLBCCU_CfgRdy[12] & GLBCCU_CfgRdy[13];
assign CCUPOL_CfgVld = Pol_CfgVld & POLCCU_CfgRdy; 
assign CCUGLB_CfgRdy[ 3] = Pool_CfgVld & GLBCCU_CfgRdy[ 3];
assign CCUGLB_CfgRdy[ 5] = Pool_CfgVld & GLBCCU_CfgRdy[ 5];
assign CCUGLB_CfgRdy[12] = Pool_CfgVld & GLBCCU_CfgRdy[12];
assign CCUGLB_CfgRdy[13] = Pool_CfgVld & GLBCCU_CfgRdy[13];

assign Ctr_CfgRdy = CTRCCU_CfgRdy & GLBCCU_CfgRdy[2] & GLBCCU_CfgRdy[6] & GLBCCU_CfgRdy[7] & GLBCCU_CfgRdy[8] & GLBCCU_CfgRdy[14] & GLBCCU_CfgRdy[15];
assign CCUCTR_CfgVld = Ctr_CfgVld & CTRCCU_CfgRdy;
assign CCUGLB_CfgRdy[ 2] = Ctr_CfgVld & GLBCCU_CfgRdy[ 2];
assign CCUGLB_CfgRdy[ 6] = Ctr_CfgVld & GLBCCU_CfgRdy[ 6];
assign CCUGLB_CfgRdy[ 7] = Ctr_CfgVld & GLBCCU_CfgRdy[ 7];
assign CCUGLB_CfgRdy[ 8] = Ctr_CfgVld & GLBCCU_CfgRdy[ 8];
assign CCUGLB_CfgRdy[14] = Ctr_CfgVld & GLBCCU_CfgRdy[14];
assign CCUGLB_CfgRdy[15] = Ctr_CfgVld & GLBCCU_CfgRdy[15];


assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*0     +: DRAM_ADDR_WIDTH] = DramDatAddr; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*1     +: DRAM_ADDR_WIDTH] = DramWgtAddr; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*2     +: DRAM_ADDR_WIDTH] = DramCrdAddr; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*3     +: DRAM_ADDR_WIDTH] = DramWrMapAddr;//
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*4     +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*5     +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*6     +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*7     +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(0+8) +: DRAM_ADDR_WIDTH] = DramRdMapAddr; // Read
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(1+8) +: DRAM_ADDR_WIDTH] = DramOfmAddr; // Read
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(2+8) +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(3+8) +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(4+8) +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(5+8) +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(6+8) +: DRAM_ADDR_WIDTH] = 0; // 
assign CCUITF_BaseAddr[DRAM_ADDR_WIDTH*(7+8) +: DRAM_ADDR_WIDTH] = 0; // 

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

MINMAX#(
    .DATA_WIDTH ( ADDR_WIDTH ),
    .PORT       ( OPNUM ),
    .MINMAX     ( 0 )
)u_MINMAX(
    .IN         ( AddrRd1D         ),
    .IDX        ( AddrRdMinIdx        ),
    .VALUE      ( AddrRdMin      )
);


DELAY#(
    .NUM_STAGES ( 1 ),
    .DATA_WIDTH ( 1 )
)u_DELAY_read_en_d(
    .CLK        ( clk        ),
    .RST_N      ( rst_n      ),
    .DIN        ( read_en        ),
    .DOUT       ( read_en_d       )
);

DELAY#(
    .NUM_STAGES ( 1 ),
    .DATA_WIDTH ( 3 )
)u_DELAY_cnt_word_d(
    .CLK        ( clk        ),
    .RST_N      ( rst_n      ),
    .DIN        ( cnt_word        ),
    .DOUT       ( cnt_word_d       )
);


endmodule
