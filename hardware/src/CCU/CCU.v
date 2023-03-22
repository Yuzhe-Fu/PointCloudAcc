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
    parameter SRAM_WIDTH            = 256,
    parameter PORT_WIDTH            = 128,
    parameter POOL_CORE             = 6,

    parameter ADDR_WIDTH            = 16,
    parameter DRAM_ADDR_WIDTH       = 32,
    parameter GLB_NUM_RDPORT        = 12,
    parameter GLB_NUM_WRPORT        = 13,
    parameter IDX_WIDTH             = 16,
    parameter CHN_WIDTH             = 12,
    parameter QNTSL_WIDTH           = 20,
    parameter ACT_WIDTH             = 8,
    parameter MAP_WIDTH             = 5,
    parameter NUM_LAYER_WIDTH       = 20,
    parameter NUM_MODULE            = 6,

    parameter MAXPAR                = 32,
    parameter NUM_BANK              = 32,
    parameter ITF_NUM_RDPORT        = 12,
    parameter ITF_NUM_WRPORT        = 14,
    parameter NUM_FPC               = 8,
    parameter OPNUM                 = NUM_MODULE + (NUM_FPC -1) + (POOL_CORE -1),
    parameter MAXPAR_WIDTH          = $clog2(MAXPAR) + 1 // MAXPAR=2 -> 2

    )(
    input                                   clk                     ,
    input                                   rst_n                   ,

    input  [PORT_WIDTH              -1 : 0] TOPCCU_ISARdDat         ,   ???????????          
    input                                   TOPCCU_ISARdDatVld      ,          
    output                                  CCUTOP_ISARdDatRdy      ,

    output                                  CCUITF_CfgVld           ,
    input                                   ITFCCU_CfgRdy           ,   
    output reg [DRAM_ADDR_WIDTH     -1 : 0] CCUITF_DRAMBaseAddr     ,
    output reg [IDX_WIDTH           -1 : 0] CCUITF_DRAMNum          ,             

    output     [NUM_FPC             -1 : 0] CCUFPS_CfgVld           ,?????? Force to reset
    input      [NUM_FPC             -1 : 0] FPSCCU_CfgRdy           ,        
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgNip           ,                    
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgNop           , 
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgCrdBaseRdAddr ,
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgCrdBaseWrAddr ,
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgIdxBaseWrAddr ,
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgMaskBaseAddr  ,   
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgDistBaseAddr  ,

    output                                  CCUKNN_CfgVld           ,
    input                                   KNNCCU_CfgRdy           ,        
    output  reg [IDX_WIDTH          -1 : 0] CCUKNN_CfgNip           ,                    
    output  reg [(MAP_WIDTH + 1)    -1 : 0] CCUKNN_CfgK             , 
    output  reg [IDX_WIDTH          -1 : 0] CCUKNN_CfgCrdRdAddr     ,
    output  reg [IDX_WIDTH          -1 : 0] CCUKNN_CfgMapWrAddr     ,

    output                                  CCUSYA_CfgVld           ,
    input                                   SYACCU_CfgRdy           ,
    output  reg[2                   -1 : 0] CCUSYA_CfgMod           ,
    output  reg                             CCUSYA_CfgOfmPhaseShift ,
    output  reg[CHN_WIDTH           -1 : 0] CCUSYA_CfgChn           ,         
    output  reg[QNTSL_WIDTH         -1 : 0] CCUSYA_CfgScale         ,        
    output  reg[ACT_WIDTH           -1 : 0] CCUSYA_CfgShift         ,        
    output  reg[ACT_WIDTH           -1 : 0] CCUSYA_CfgZp            ,
    output  reg[IDX_WIDTH           -1 : 0] CCUSYA_CfgNumGrpPerTile,
    output  reg[IDX_WIDTH           -1 : 0] CCUSYA_CfgNumTilIfm    ,
    output  reg[IDX_WIDTH           -1 : 0] CCUSYA_CfgNumTilFlt    ,
    output  reg                             CCUSYA_CfgLopOrd       ,
    output  reg[ADDR_WIDTH          -1 : 0] CCUSYA_CfgActRdBaseAddr ,
    output  reg[ADDR_WIDTH          -1 : 0] CCUSYA_CfgWgtRdBaseAddr ,
    output  reg[ADDR_WIDTH          -1 : 0] CCUSYA_CfgOfmWrBaseAddr ,

    output      [POOL_CORE              -1 : 0] CCUPOL_CfgVld       ,
    input       [POOL_CORE              -1 : 0] POLCCU_CfgRdy       ,
    output  reg [(MAP_WIDTH+1)*POOL_CORE-1 : 0] CCUPOL_CfgK         ,
    output  reg [IDX_WIDTH*POOL_CORE    -1 : 0] CCUPOL_CfgNip       ,
    output  reg [CHN_WIDTH*POOL_CORE    -1 : 0] CCUPOL_CfgChn       ,
             
    output reg [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)  -1 : 0][NUM_BANK    -1 : 0] CCUTOP_CfgPortBankFlag ,
    output reg [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)  -1 : 0][MAXPAR_WIDTH-1 : 0] CCUTOP_CfgPortParBank,
    output reg [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)                   -1 : 0] CCUTOP_CfgPortOffEmptyFull

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam OPCODE_WIDTH = 8;
localparam NUMWORD_WIDTH= 8;

localparam IDLE         = 4'b0000;
localparam DEC          = 4'b0001;
localparam CFG          = 4'b0010;

localparam OPCODE_CCU   = 0;
localparam OPCODE_FPS   = 1;
localparam OPCODE_KNN   = 2;
localparam OPCODE_SYA   = 3;
localparam OPCODE_POL   = 4;
localparam OPCODE_ITF   = 4;

localparam GLBWRIDX_ITFISA = 0; 
localparam GLBWRIDX_ITFCRD = 1; 
localparam GLBWRIDX_ITFMAP = 2; 
localparam GLBWRIDX_ITFACT = 3; 
localparam GLBWRIDX_ITFWGT = 4; 
localparam GLBWRIDX_FPSMSK = 5; 
localparam GLBWRIDX_FPSCRD = 6; 
localparam GLBWRIDX_FPSDST = 7; 
localparam GLBWRIDX_FPSIDX = 8; 
localparam GLBWRIDX_KNNMAP = 9;
localparam GLBWRIDX_SYAOFM = 10;
localparam GLBWRIDX_POLOFM = 11;
                                
localparam GLBRDIDX_ITFMAP = 0; 
localparam GLBRDIDX_ITFOFM = 1; 
localparam GLBRDIDX_ITFIDX = 2; 
localparam GLBRDIDX_CCUISA = 3; 
localparam GLBRDIDX_FPSMSK = 4; 
localparam GLBRDIDX_FPSCRD = 5; 
localparam GLBRDIDX_FPSDST = 6; 
localparam GLBRDIDX_KNNCRD = 7; 
localparam GLBRDIDX_SYAACT = 8; 
localparam GLBRDIDX_SYAWGT = 9; 
localparam GLBRDIDX_POLMAP = 10;
localparam GLBRDIDX_POLOFM = 11;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire[ADDR_WIDTH                     -1 : 0] CntISARdWord_s1;

reg [OPCODE_WIDTH                   -1 : 0] OpCode;
reg [NUMWORD_WIDTH                  -1 : 0] OpNumWord[0 : OPNUM                             -1];

reg [OPCODE_WIDTH                   -1 : 0] Mode;
integer                                     int_i;
wire [OPNUM                         -1 : 0] CfgRdy;
reg  [OPNUM                         -1 : 0] CfgVld;
reg                                         CCUTOP_CfgRdy;   
wire                                        CCUTOP_CfgVld;  
wire                                        Ovf_CntISARdWord_s1;
wire                                        handshake_s1;

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================
reg [4      -1 : 0] state       ;
reg [4      -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE    :   if(TOPCCU_ISARdDatVld)
                        next_state <= DEC; //
                    else
                        next_state <= IDLE;

        DEC:        if (CfgVld[OpCode])
                        next_state <= CFG;
                    else 
                        next_state <= DEC;

        CFG     :   if(CfgRdy[OpCode])
                        next_state <= IDLE;
                    else
                        next_state <= CFG;

        default :       next_state <= IDLE;
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
// Logic Design 3: Req and Ack of Cfg
//=====================================================================================================================
// CfgRdy -> Req
`ifdef PSEUDO_DATA
    assign CfgRdy = {1'b0, 1'b0, 1'b0, &FPSCCU_CfgRdy, CCUTOP_CfgRdy};
`else
    assign CfgRdy = {&POLCCU_CfgRdy, SYACCU_CfgRdy, KNNCCU_CfgRdy, &FPSCCU_CfgRdy, CCUTOP_CfgRdy};
`endif

//=====================================================================================================================
// Logic Design: s2
//=====================================================================================================================
assign CCUTOP_ISARdDatRdy   = state == DEC;
assign handshake_s1         = TOPCCU_ISARdDatVld & CCUTOP_ISARdDatRdy;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        OpCode <= {OPCODE_WIDTH{1'b1}};
    end else if(next_state == IDLE) begin // HS
        OpCode <= {OPCODE_WIDTH{1'b1}};
    end else if(state == IDLE & next_state == DEC) begin
        OpCode <= TOPCCU_ISARdDat[0 +: OPCODE_WIDTH];
    end
end

// Reg Update
wire [ADDR_WIDTH     -1 : 0] MaxCntISARdWord = OpNumWord[OpCode] -1;
counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u_counter_CntISARdWord(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state == IDLE  ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
    .INC       ( handshake_s1  ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
    .MAX_COUNT ( MaxCntISARdWord),
    .OVERFLOW  ( Ovf_CntISARdWord_s1),
    .UNDERFLOW (                ),
    .COUNT     ( CntISARdWord_s1)
);

// ISA Decoder

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        OpNumWord[0] = 1;   // localparam OPCODE_CCU             = 0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        Mode                    <= 0;
        CCUSYA_CfgChn           <= 0;
        CCUSYA_CfgScale         <= 0;
        CCUSYA_CfgShift         <= 0;
        CCUSYA_CfgZp            <= 0;
        CCUSYA_CfgMod           <= 0;
        CCUSYA_CfgOfmPhaseShift <= 0;
        CCUSYA_CfgNumGrpPerTile <= 0;
        CCUSYA_CfgNumTilIfm     <= 0;
        CCUSYA_CfgNumTilFlt     <= 0;
        CCUSYA_CfgLopOrd        <= 0;
        CCUPOL_CfgNip           <= 0;
        CCUPOL_CfgChn           <= 0;
        CCUPOL_CfgK             <= 0;
        CCUFPS_CfgNip           <= 0;
        CCUFPS_CfgNop           <= 0;
        CCUKNN_CfgNip           <= 0;
        CCUKNN_CfgK             <= 0;
        CCUFPS_CfgCrdBaseRdAddr <= 0;
        CCUFPS_CfgCrdBaseWrAddr <= 0;
        CCUFPS_CfgIdxBaseWrAddr <= 0;
        CCUFPS_CfgMaskBaseAddr  <= 0;
        CCUFPS_CfgDistBaseAddr  <= 0;
        CCUKNN_CfgCrdRdAddr     <= 0;
        CCUKNN_CfgMapWrAddr     <= 0;
        CCUSYA_CfgActRdBaseAddr <= 0;
        CCUSYA_CfgWgtRdBaseAddr <= 0;
        CCUSYA_CfgOfmWrBaseAddr <= 0;
        CCUTOP_CfgPortOffEmptyFull <= 0;
        for(int_i = 0; int_i < GLB_NUM_RDPORT + GLB_NUM_WRPORT; int_i=int_i+1) begin
            if(int_i == GLBWRIDX_ITFISA) begin
                CCUTOP_CfgPortBankFlag[int_i] <= 'd1; // ISA write bank0
                CCUTOP_CfgPortParBank[int_i] <= 'd1;
            end else if(int_i == GLB_NUM_WRPORT + GLBRDIDX_CCUISA) begin
                CCUTOP_CfgPortBankFlag[int_i] <= 'd1; // ISA read bank0
                CCUTOP_CfgPortParBank[int_i] <= 'd1;

            end else begin
                CCUTOP_CfgPortBankFlag[int_i] <= 0; // ISA read bank0
                CCUTOP_CfgPortParBank[int_i] <= 'd1;   // default  
            end 
        end 
        for(int_i = 0; int_i < ITF_NUM_RDPORT+ITF_NUM_WRPORT; int_i=int_i+1) begin
            if(int_i == GLBWRIDX_ITFISA) begin
                CCUITF_DRAMBaseAddr[int_i]    <= 'd0; // ISA read DramAddr = 0
            end else begin
                CCUITF_DRAMBaseAddr[int_i]    <= 'd0;
            end
        end

    end else if ( handshake_s1) begin
        if ( OpCode == OPCODE_CCU) begin
            {Mode, OpNumWord[5], OpNumWord[4], OpNumWord[3], OpNumWord[2], OpNumWord[1]} <= TOPCCU_ISARdDat[OPCODE_WIDTH +: NUMWORD_WIDTH*(NUM_MODULE - 1) + OPCODE_WIDTH];

        end else if (OpCode == OPCODE_FPS) begin
                     if(CntISARdWord_s1 == 0) begin
                CCUFPS_CfgNip[0 +: IDX_WIDTH*( (PORT_WIDTH - OPCODE_WIDTH)/IDX_WIDTH )]  <= TOPCCU_ISARdDat[OPCODE_WIDTH +: IDX_WIDTH*( (PORT_WIDTH - OPCODE_WIDTH)/IDX_WIDTH )];
            end else if(CntISARdWord_s1 == 1) begin
                CCUFPS_CfgNip[IDX_WIDTH*( (PORT_WIDTH - OPCODE_WIDTH)/IDX_WIDTH ) +: PORT_WIDTH]  <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 2) begin
                CCUFPS_CfgNip[IDX_WIDTH*NUM_FPC -1 : IDX_WIDTH*( (PORT_WIDTH - OPCODE_WIDTH)/IDX_WIDTH ) + PORT_WIDTH ]  <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 3) begin
                CCUFPS_CfgNop[0 +: PORT_WIDTH]                      <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 4) begin
                CCUFPS_CfgNop[PORT_WIDTH +: PORT_WIDTH]             <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 5) begin
                CCUFPS_CfgCrdBaseRdAddr[0 +: PORT_WIDTH]            <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 6) begin
                CCUFPS_CfgCrdBaseRdAddr[PORT_WIDTH +: PORT_WIDTH]   <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 7) begin
                CCUFPS_CfgCrdBaseWrAddr[0 +: PORT_WIDTH]            <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 8) begin
                CCUFPS_CfgCrdBaseWrAddr[PORT_WIDTH +: PORT_WIDTH]   <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 9) begin
                CCUFPS_CfgIdxBaseWrAddr[0 +: PORT_WIDTH]            <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 10) begin
                CCUFPS_CfgIdxBaseWrAddr[PORT_WIDTH +: PORT_WIDTH]   <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 11) begin
                CCUFPS_CfgMaskBaseAddr[0 +: PORT_WIDTH]             <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 12) begin
                CCUFPS_CfgMaskBaseAddr[PORT_WIDTH +: PORT_WIDTH]    <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 13) begin
                CCUFPS_CfgDistBaseAddr[0 +: PORT_WIDTH]             <= TOPCCU_ISARdDat;
            end else if(CntISARdWord_s1 == 14) begin
                CCUFPS_CfgDistBaseAddr[PORT_WIDTH +: PORT_WIDTH]    <= TOPCCU_ISARdDat;

            end else if(CntISARdWord_s1 == 15) begin
                CCUITF_DRAMBaseAddr   [GLBWRIDX_ITFCRD                 ]   <= TOPCCU_ISARdDat[                               +: DRAM_ADDR_WIDTH];
                CCUITF_DRAMBaseAddr   [ITF_NUM_WRPORT + GLBRDIDX_ITFIDX]   <= TOPCCU_ISARdDat[DRAM_ADDR_WIDTH                +: DRAM_ADDR_WIDTH];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_ITFCRD                 ]   <= TOPCCU_ISARdDat[DRAM_ADDR_WIDTH*2              +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_FPSCRD]   <= TOPCCU_ISARdDat[DRAM_ADDR_WIDTH*2 + NUM_BANK   +: NUM_BANK];
            end else if(CntISARdWord_s1 == 16) begin
                CCUTOP_CfgPortBankFlag[GLBWRIDX_FPSMSK                 ]   <= TOPCCU_ISARdDat[0           +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_FPSMSK]   <= TOPCCU_ISARdDat[NUM_BANK    +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_FPSDST                 ]   <= TOPCCU_ISARdDat[NUM_BANK*2  +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_FPSDST]   <= TOPCCU_ISARdDat[NUM_BANK*3  +: NUM_BANK];
            end else if(CntISARdWord_s1 == 17) begin
                CCUTOP_CfgPortBankFlag[GLBWRIDX_FPSIDX                 ]   <= TOPCCU_ISARdDat[0           +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_ITFIDX]   <= TOPCCU_ISARdDat[NUM_BANK    +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_FPSCRD                 ]   <= TOPCCU_ISARdDat[NUM_BANK*2  +: NUM_BANK];
            end else if(CntISARdWord_s1 == 18) begin
                CCUTOP_CfgPortParBank     [GLBWRIDX_ITFCRD                 ] <= TOPCCU_ISARdDat[0                +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_FPSCRD] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*1   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLBWRIDX_FPSMSK                 ] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*2   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_FPSMSK] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*3   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLBWRIDX_FPSDST                 ] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*4   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_FPSDST] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*5   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLBWRIDX_FPSIDX                 ] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*6   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_ITFIDX] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*7   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLBWRIDX_FPSCRD                 ] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*8   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_ITFCRD                 ] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*9      +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSCRD] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*9   +1 +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_FPSMSK                 ] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*9   +2 +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSMSK] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*9   +3 +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_FPSDST                 ] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*9   +4 +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSDST] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*9   +5 +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_FPSIDX                 ] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*9   +6 +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_ITFIDX] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*9   +7 +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_FPSCRD                 ] <= TOPCCU_ISARdDat[MAXPAR_WIDTH*9   +8 +: 1];
            end

        end else if (OpCode == OPCODE_KNN) begin
                if(CntISARdWord_s1 == 0) begin
                CCUKNN_CfgNip                                           <= TOPCCU_ISARdDat[OPCODE_WIDTH                                                                 +: IDX_WIDTH];
                CCUKNN_CfgK                                             <= TOPCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH                                                     +: IDX_WIDTH];
                CCUKNN_CfgCrdRdAddr                                     <= TOPCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*2                                                   +: IDX_WIDTH];
                CCUKNN_CfgMapWrAddr                                     <= TOPCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*3                                                   +: IDX_WIDTH];
                CCUITF_DRAMBaseAddr   [ITF_NUM_WRPORT + GLBRDIDX_ITFMAP]<= TOPCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*4                                                   +: DRAM_ADDR_WIDTH];
            end else if(CntISARdWord_s1 == 1) begin
                CCUTOP_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_ITFMAP] <= TOPCCU_ISARdDat[0                             +: NUM_BANK];
                CCUTOP_CfgPortBankFlag    [GLBWRIDX_KNNMAP                 ] <= TOPCCU_ISARdDat[NUM_BANK                      +: NUM_BANK];
                CCUTOP_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_KNNCRD] <= TOPCCU_ISARdDat[NUM_BANK*2                    +: NUM_BANK];
                CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_ITFMAP] <= TOPCCU_ISARdDat[NUM_BANK*3                    +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLBWRIDX_KNNMAP                 ] <= TOPCCU_ISARdDat[NUM_BANK*3 + MAXPAR_WIDTH     +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_KNNCRD] <= TOPCCU_ISARdDat[NUM_BANK*3 + MAXPAR_WIDTH*2   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_ITFMAP] <= TOPCCU_ISARdDat[NUM_BANK*3 + MAXPAR_WIDTH*3     +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_KNNMAP                 ] <= TOPCCU_ISARdDat[NUM_BANK*3 + MAXPAR_WIDTH*3 +1  +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_KNNCRD] <= TOPCCU_ISARdDat[NUM_BANK*3 + MAXPAR_WIDTH*3 +2  +: 1];
            end

        end else if ( OpCode == OPCODE_SYA) begin
            if (CntISARdWord_s1 == 0) begin
                CCUSYA_CfgShift                                         <= TOPCCU_ISARdDat[OPCODE_WIDTH                                                                         +: ACT_WIDTH];  
                CCUSYA_CfgZp                                            <= TOPCCU_ISARdDat[OPCODE_WIDTH   + ACT_WIDTH                                                           +: ACT_WIDTH]; 
                CCUSYA_CfgMod                                           <= TOPCCU_ISARdDat[OPCODE_WIDTH   + ACT_WIDTH*2                                                         +: OPCODE_WIDTH/2];// 4bit
                CCUSYA_CfgOfmPhaseShift                                 <= TOPCCU_ISARdDat[OPCODE_WIDTH*3/2+ ACT_WIDTH*2                                                        +: OPCODE_WIDTH/2];// 4bit
                CCUSYA_CfgChn                                           <= TOPCCU_ISARdDat[OPCODE_WIDTH*2 + ACT_WIDTH*2                                                         +: CHN_WIDTH];           
                CCUSYA_CfgNumGrpPerTile                                 <= TOPCCU_ISARdDat[OPCODE_WIDTH*2 + ACT_WIDTH*2 + CHN_WIDTH                                             +: IDX_WIDTH];
                CCUSYA_CfgNumTilFlt                                     <= TOPCCU_ISARdDat[OPCODE_WIDTH*2 + ACT_WIDTH*2 + CHN_WIDTH + IDX_WIDTH                                 +: IDX_WIDTH];
                CCUSYA_CfgNumTilIfm                                     <= TOPCCU_ISARdDat[OPCODE_WIDTH*2 + ACT_WIDTH*2 + CHN_WIDTH + IDX_WIDTH*2                               +: IDX_WIDTH];
                CCUSYA_CfgLopOrd                                        <= TOPCCU_ISARdDat[OPCODE_WIDTH*2 + ACT_WIDTH*2 + CHN_WIDTH + IDX_WIDTH*3                               +: OPCODE_WIDTH];
                CCUSYA_CfgActRdBaseAddr                                 <= TOPCCU_ISARdDat[OPCODE_WIDTH*2 + ACT_WIDTH*2 + CHN_WIDTH + IDX_WIDTH*3 + OPCODE_WIDTH                +: ADDR_WIDTH]; 
            end else if(CntISARdWord_s1 == 1) begin
                CCUSYA_CfgWgtRdBaseAddr                                 <= TOPCCU_ISARdDat[0                                +: ADDR_WIDTH]; 
                CCUSYA_CfgOfmWrBaseAddr                                 <= TOPCCU_ISARdDat[ADDR_WIDTH*1                     +: ADDR_WIDTH]; 
                CCUITF_DRAMBaseAddr   [GLBWRIDX_ITFACT                 ]<= TOPCCU_ISARdDat[ADDR_WIDTH*2                     +: DRAM_ADDR_WIDTH]; 
                CCUITF_DRAMBaseAddr   [GLBWRIDX_ITFWGT                 ]<= TOPCCU_ISARdDat[ADDR_WIDTH*3 + DRAM_ADDR_WIDTH   +: DRAM_ADDR_WIDTH]; 
                CCUITF_DRAMBaseAddr   [ITF_NUM_WRPORT + GLBRDIDX_ITFOFM]<= TOPCCU_ISARdDat[ADDR_WIDTH*3 + DRAM_ADDR_WIDTH*2 +: DRAM_ADDR_WIDTH];
            end else if(CntISARdWord_s1 == 2) begin
                CCUTOP_CfgPortBankFlag[GLBWRIDX_ITFACT                 ]   <= TOPCCU_ISARdDat[0             +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_SYAACT]   <= TOPCCU_ISARdDat[NUM_BANK      +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_ITFWGT                 ]   <= TOPCCU_ISARdDat[NUM_BANK*2    +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_SYAWGT]   <= TOPCCU_ISARdDat[NUM_BANK*3    +: NUM_BANK];
            end else if(CntISARdWord_s1 == 3) begin    
                CCUTOP_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_ITFOFM]   <= TOPCCU_ISARdDat[0                             +: NUM_BANK];
                CCUTOP_CfgPortBankFlag    [GLBWRIDX_SYAOFM                 ]   <= TOPCCU_ISARdDat[NUM_BANK                      +: NUM_BANK];
                CCUTOP_CfgPortParBank     [GLBWRIDX_ITFACT                 ]   <= TOPCCU_ISARdDat[NUM_BANK*2                    +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_SYAACT]   <= TOPCCU_ISARdDat[NUM_BANK*2 + MAXPAR_WIDTH     +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLBWRIDX_ITFWGT                 ]   <= TOPCCU_ISARdDat[NUM_BANK*2 + MAXPAR_WIDTH*2   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_SYAWGT]   <= TOPCCU_ISARdDat[NUM_BANK*2 + MAXPAR_WIDTH*3   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_ITFOFM]   <= TOPCCU_ISARdDat[NUM_BANK*2 + MAXPAR_WIDTH*4   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank     [GLBWRIDX_SYAOFM                 ]   <= TOPCCU_ISARdDat[NUM_BANK*2 + MAXPAR_WIDTH*5   +: MAXPAR_WIDTH]; // 8+32+192+12=244
                CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_ITFACT                 ]   <= TOPCCU_ISARdDat[NUM_BANK*2 + MAXPAR_WIDTH*6     +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_SYAACT]   <= TOPCCU_ISARdDat[NUM_BANK*2 + MAXPAR_WIDTH*6  +1 +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_ITFWGT                 ]   <= TOPCCU_ISARdDat[NUM_BANK*2 + MAXPAR_WIDTH*6  +2 +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_SYAWGT]   <= TOPCCU_ISARdDat[NUM_BANK*2 + MAXPAR_WIDTH*6  +3 +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_ITFOFM]   <= TOPCCU_ISARdDat[NUM_BANK*2 + MAXPAR_WIDTH*6  +4 +: 1];
                CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_SYAOFM                 ]   <= TOPCCU_ISARdDat[NUM_BANK*2 + MAXPAR_WIDTH*6  +5 +: 1];
            end

        end else if (OpCode == OPCODE_POL) begin
                if (CntISARdWord_s1 == 0) begin
                CCUPOL_CfgNip[0 +: PORT_WIDTH]                          <= TOPCCU_ISARdDat[OPCODE_WIDTH +: IDX_WIDTH*POOL_CORE];
            end else if(CntISARdWord_s1 == 1) begin 
            end else if(CntISARdWord_s1 == 1) begin 
                CCUPOL_CfgChn                                           <= TOPCCU_ISARdDat[OPCODE_WIDTH +: CHN_WIDTH*POOL_CORE];
            end else if(CntISARdWord_s1 == 2) begin
                CCUPOL_CfgK                                             <= TOPCCU_ISARdDat[OPCODE_WIDTH +: OPCODE_WIDTH*POOL_CORE]; // 8bit
                CCUITF_DRAMBaseAddr   [GLBWRIDX_ITFMAP                 ]   <= TOPCCU_ISARdDat[OPCODE_WIDTH*(POOL_CORE + 1)                                                 +: DRAM_ADDR_WIDTH]; // 8bit; 
                CCUTOP_CfgPortBankFlag[GLBWRIDX_ITFMAP                 ]   <= TOPCCU_ISARdDat[OPCODE_WIDTH*(POOL_CORE + 1) + DRAM_ADDR_WIDTH                               +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_POLMAP]   <= TOPCCU_ISARdDat[OPCODE_WIDTH*(POOL_CORE + 1) + DRAM_ADDR_WIDTH + NUM_BANK                    +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_POLOFM                 ]   <= TOPCCU_ISARdDat[OPCODE_WIDTH*(POOL_CORE + 1) + DRAM_ADDR_WIDTH + NUM_BANK*2                  +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_POLOFM]   <= TOPCCU_ISARdDat[OPCODE_WIDTH*(POOL_CORE + 1) + DRAM_ADDR_WIDTH + NUM_BANK*3                  +: NUM_BANK];
            end else if(CntISARdWord_s1 == 3) begin
                for(int_i = 1; int_i < POOL_CORE; int_i = int_i + 1) begin
                    CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_POLOFM + int_i]   <= TOPCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*(int_i - 1) +: NUM_BANK]; // 1 bank
                end
                CCUTOP_CfgPortParBank [GLBWRIDX_ITFMAP                 ]   <= TOPCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*(POOL_CORE - 1)                  +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_POLMAP]   <= TOPCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*(POOL_CORE - 1) + MAXPAR_WIDTH   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLBWRIDX_POLOFM                 ]   <= TOPCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*(POOL_CORE - 1) + MAXPAR_WIDTH*2 +: MAXPAR_WIDTH];
                for(int_i = 0; int_i < POOL_CORE; int_i = int_i + 1) begin
                    CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_POLOFM + int_i]   <= TOPCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*(POOL_CORE - 1) + MAXPAR_WIDTH*(3 + int_i) +: MAXPAR_WIDTH];
                end
            end else if(CntISARdWord_s1 == 4) begin
                CCUTOP_CfgPortOffEmptyFull [GLBWRIDX_ITFMAP                 ]   <= TOPCCU_ISARdDat[OPCODE_WIDTH     +: 1];
                CCUTOP_CfgPortOffEmptyFull [GLB_NUM_WRPORT + GLBRDIDX_POLMAP]   <= TOPCCU_ISARdDat[OPCODE_WIDTH +1  +: 1];
                CCUTOP_CfgPortOffEmptyFull [GLBWRIDX_POLOFM                 ]   <= TOPCCU_ISARdDat[OPCODE_WIDTH +2  +: 1];
                for(int_i = 0; int_i < POOL_CORE; int_i = int_i + 1) begin
                    CCUTOP_CfgPortOffEmptyFull [GLB_NUM_WRPORT + GLBRDIDX_POLOFM + int_i]   <= TOPCCU_ISARdDat[OPCODE_WIDTH + 3 + int_i +: 1];
                end
            end                
        end else if (OpCode == OPCODE_ITF) begin
            if (CntISARdWord_s1 == 0) begin
                CCUITF_DRAMBaseAddr <= TOPCCU_ISARdDat[OPCODE_WIDTH                     +: DRAM_ADDR_WIDTH];
                CCUITF_DRAMNum      <= TOPCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH   +: IDX_WIDTH];
            end
        end
    end
end



generate
    for(gv_i=0; gv_i<OPNUM; gv_i=gv_i+1) begin: GEN_CfgVld
        always @(posedge clk or negedge rst_n)  begin
            if (!rst_n) begin
                CfgVld[gv_i] <= 0;
            end else if ( CfgVld[gv_i] & CfgRdy[gv_i] ) begin
                CfgVld[gv_i] <= 0;
            end else if ( state == DEC & (OpCode == gv_i) & Ovf_CntISARdWord_s1 & handshake_s1) begin
                CfgVld[gv_i] <= 1'b1;
            end
        end
    end
endgenerate


wire        FPS_CfgVld;
wire        POL_CfgVld;

assign {CCUITF_CfgVld, POL_CfgVld, CCUSYA_CfgVld, CCUKNN_CfgVld, FPS_CfgVld, CCUTOP_CfgVld} = CfgVld;
assign CCUFPS_CfgVld = {NUM_FPC{FPS_CfgVld}};
assign CCUPOL_CfgVld = {POOL_CORE{POL_CfgVld}};

//=====================================================================================================================
// Logic Design: TOP
//=====================================================================================================================s
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        CCUTOP_CfgRdy <= 1'b1;
    end else if(CCUTOP_CfgVld & CCUTOP_CfgRdy) begin // HS
        CCUTOP_CfgRdy <= 1'b0;
    end else if(state == IDLE) begin
        CCUTOP_CfgRdy <= 1'b1;
    end
end

endmodule
