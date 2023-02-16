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
    parameter NUM_MODULE            = 5,

    parameter MAXPAR                = 32,
    parameter NUM_BANK              = 32,
    parameter ITF_NUM_RDPORT        = 12,
    parameter ITF_NUM_WRPORT        = 14,
    parameter NUM_FPC               = 4,
    parameter OPNUM                 = NUM_MODULE + (NUM_FPC -1) + (POOL_CORE -1),
    parameter MAXPAR_WIDTH          = $clog2(MAXPAR) + 1 // MAXPAR=2 -> 2

    )(
    input                                   clk                     ,
    input                                   rst_n                   ,
    input                                   TOPCCU_start            ,
    output                                  CCUTOP_NetFnh           ,

        // Configure
    output [ADDR_WIDTH              -1 : 0] CCUGLB_ISARdAddr        ,
    output                                  CCUGLB_ISARdAddrVld     ,
    input                                   GLBCCU_ISARdAddrRdy     ,
    input  [SRAM_WIDTH              -1 : 0] GLBCCU_ISARdDat         ,             
    input                                   GLBCCU_ISARdDatVld      ,          
    output                                  CCUGLB_ISARdDatRdy      ,
    output [ADDR_WIDTH              -1 : 0] CCUTOP_MduISARdAddrMin  , // To avoid ITF over-write ISARAM of GLB
    output                                  CCUITF_Rst              , 
    output reg [(ITF_NUM_RDPORT+ITF_NUM_WRPORT)-1 : 0][DRAM_ADDR_WIDTH-1 : 0] CCUITF_DRAMBaseAddr,

    output     [NUM_FPC             -1 : 0] CCUFPS_Rst              ,
    output     [NUM_FPC             -1 : 0] CCUFPS_CfgVld           ,
    input      [NUM_FPC             -1 : 0] FPSCCU_CfgRdy           ,        
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgNip           ,                    
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgNop           , 
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgCrdBaseRdAddr ,
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgCrdBaseWrAddr ,
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgIdxBaseWrAddr ,
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgMaskBaseAddr  ,   
    output  reg[IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgDistBaseAddr  ,

    output                                  CCUKNN_Rst              ,
    output                                  CCUKNN_CfgVld           ,
    input                                   KNNCCU_CfgRdy           ,        
    output  reg [IDX_WIDTH          -1 : 0] CCUKNN_CfgNip           ,                    
    output  reg [(MAP_WIDTH + 1)    -1 : 0] CCUKNN_CfgK             , 
    output  reg [IDX_WIDTH          -1 : 0] CCUKNN_CfgCrdRdAddr     ,
    output  reg [IDX_WIDTH          -1 : 0] CCUKNN_CfgMapWrAddr     ,

    output                                  CCUSYA_Rst              ,  //
    output                                  CCUSYA_CfgVld           ,
    input                                   SYACCU_CfgRdy           ,
    output  reg[2                   -1 : 0] CCUSYA_CfgMod           ,
    output  reg[IDX_WIDTH           -1 : 0] CCUSYA_CfgNip           , 
    output  reg[CHN_WIDTH           -1 : 0] CCUSYA_CfgChi           ,         
    output  reg[QNTSL_WIDTH         -1 : 0] CCUSYA_CfgScale         ,        
    output  reg[ACT_WIDTH           -1 : 0] CCUSYA_CfgShift         ,        
    output  reg[ACT_WIDTH           -1 : 0] CCUSYA_CfgZp            ,
    output  reg[ADDR_WIDTH          -1 : 0] CCUSYA_CfgActRdBaseAddr ,
    output  reg[ADDR_WIDTH          -1 : 0] CCUSYA_CfgWgtRdBaseAddr ,
    output  reg[ADDR_WIDTH          -1 : 0] CCUSYA_CfgOfmWrBaseAddr ,

    output      [POOL_CORE              -1 : 0] CCUPOL_Rst          ,
    output      [POOL_CORE              -1 : 0] CCUPOL_CfgVld       ,
    input       [POOL_CORE              -1 : 0] POLCCU_CfgRdy       ,
    output  reg [(MAP_WIDTH+1)*POOL_CORE-1 : 0] CCUPOL_CfgK         ,
    output  reg [IDX_WIDTH*POOL_CORE    -1 : 0] CCUPOL_CfgNip       ,
    output  reg [CHN_WIDTH*POOL_CORE    -1 : 0] CCUPOL_CfgChi       ,
             
    output reg [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)  -1 : 0][NUM_BANK    -1 : 0] CCUTOP_CfgPortBankFlag ,
    output reg [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)  -1 : 0][MAXPAR_WIDTH-1 : 0] CCUTOP_CfgPortParBank

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam OPCODE_WIDTH = 8;

localparam IDLE     = 4'b0000;
localparam IDLE_CFG = 4'b0001;
localparam CFG      = 4'b0010;
localparam NETFNH   = 4'b0011;

localparam OPCODE_CCU   = 0;
localparam OPCODE_FPS   = 1;
localparam OPCODE_KNN   = 2;
localparam OPCODE_SYA   = 3;
localparam OPCODE_POL   = 4;

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
wire                                        ISA_Full;
wire                                        ISA_Empty;
reg [ADDR_WIDTH                     -1 : 0] ISA_WrAddr;
reg [OPNUM -1 : 0][(ADDR_WIDTH)     -1 : 0] CntMduISARdAddr;
wire                                        ISA_WrEn;
wire                                        ISA_RdEn;
wire[ADDR_WIDTH                     -1 : 0] CntISARdWord;
wire[ADDR_WIDTH                     -1 : 0] ISA_CntRdWord_d;
reg                                         ISA_DatOutVld;

reg [NUM_LAYER_WIDTH                -1 : 0] CfgNumLy;
wire                                        ISA_RdEn_d;
wire [OPCODE_WIDTH                  -1 : 0] OpCode;
wire                                        OpCodeMatch;
reg [5                              -1 : 0] OpNumWord[0 : OPNUM -1];
reg [OPCODE_WIDTH                   -1 : 0] StateCode[0 : OPNUM -1];
reg [DRAM_ADDR_WIDTH                -1 : 0] DramAddr[0 : GLB_NUM_WRPORT+GLB_NUM_RDPORT -1];

reg [NUM_LAYER_WIDTH                -1 : 0] NumLy;
reg [OPCODE_WIDTH                     -1 : 0] Mode;
wire [$clog2(OPNUM)                 -1 : 0] AddrRdMinIdx;

wire                                        PISO_ISAInRdy;
wire [PORT_WIDTH                    -1 : 0] PISO_ISAOut;
wire                                        PISO_ISAOutVld;
wire                                        PISO_ISAOutRdy;
reg                                         Debug_TriggerSYACfgHS;   
integer                                     int_i;
wire [OPNUM                         -1 : 0] CfgRdy;
reg  [OPNUM                         -1 : 0] CfgVld;
wire [$clog2(OPNUM)                 -1 : 0] ArbCfgRdyIdx;
reg  [$clog2(OPNUM)                 -1 : 0] ArbCfgRdyIdx_s0;
reg  [$clog2(OPNUM)                 -1 : 0] ArbCfgRdyIdx_s1;
reg  [$clog2(OPNUM)                 -1 : 0] ArbCfgRdyIdx_s2;
reg                                         CCUTOP_CfgRdy;   
wire                                        CCUTOP_CfgVld;  
wire                                        Ovf_CntISARdWord;
wire                                        handshake_s1;

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================


reg [4      -1 : 0] state       ;
reg [4      -1 : 0] state_s1       ;
reg [4      -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE    :   if( TOPCCU_start)
                        next_state <= IDLE_CFG; //
                    else
                        next_state <= IDLE;

        IDLE_CFG:   if ( |CfgRdy)
                        next_state <= CFG;
                    else 
                        next_state <= IDLE_CFG;

        CFG     :   if (NumLy == CfgNumLy & CfgNumLy != 0)
                        next_state <= NETFNH;
                    else if(CfgVld[ArbCfgRdyIdx_s2] & CfgRdy[ArbCfgRdyIdx_s2] )
                        next_state <= IDLE_CFG;
                    else
                        next_state <= CFG;

        NETFNH  :       next_state <= IDLE;

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
// Logic Design: TOP
//=====================================================================================================================
assign CCUTOP_NetFnh = state == NETFNH;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        NumLy <= 0;
    end else if(state ==IDLE) begin
        NumLy <= 0;
    // end else if(state == NETFNH) begin
    //     NumLy <= NumLy + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        CCUTOP_CfgRdy <= 1'b1;
    end else if(CCUTOP_CfgVld & CCUTOP_CfgRdy) begin // HS
        CCUTOP_CfgRdy <= 1'b0;
    end else if(state == IDLE) begin
        CCUTOP_CfgRdy <= 1'b1;
    end
end

//=====================================================================================================================
// Logic Design 3: Req and Ack of Cfg
//=====================================================================================================================

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        OpNumWord[0] = 1;// localparam OPCODE_CCU             = 0;
        OpNumWord[1] = 5;// localparam OPCODE_FPS             = 1;
        OpNumWord[2] = 1;// localparam OPCODE_KNN             = 2;
        OpNumWord[3] = 2;// localparam OPCODE_SYA             = 3;
        OpNumWord[4] = 4;// localparam OPCODE_POL             = 4;
    end
end

// CfgRdy -> Req
assign CfgRdy = {&POLCCU_CfgRdy, SYACCU_CfgRdy, KNNCCU_CfgRdy, &FPSCCU_CfgRdy, CCUTOP_CfgRdy};
prior_arb#(
    .REQ_WIDTH ( OPNUM )
)u_prior_arb_ArbCfgRdyIdx(
    .req ( CfgRdy               ),
    .gnt (                      ),
    .arb_port  ( ArbCfgRdyIdx   )
);

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ArbCfgRdyIdx_s0 <= 0;
    end else if ( state == IDLE_CFG & next_state == CFG ) begin
        ArbCfgRdyIdx_s0 <= ArbCfgRdyIdx;
    end
end

//=====================================================================================================================
// Logic Design: s1-ISA_RAM Read
//=====================================================================================================================
genvar gv_i;
generate
    for(gv_i=0; gv_i<OPNUM; gv_i=gv_i+1) begin: GEN_CntMduISARdAddr
        wire [ADDR_WIDTH     -1 : 0] MaxCnt= 2**ADDR_WIDTH -1;
        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_CntMduISARdAddr(
            .CLK       ( clk            ),
            .RESET_N   ( rst_n          ),
            .CLEAR     ( state == IDLE  ),
            .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
            .INC       ( (CCUGLB_ISARdAddrVld & GLBCCU_ISARdAddrRdy) & ArbCfgRdyIdx_s0 == gv_i ),
            .DEC       ( 1'b0           ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
            .MAX_COUNT ( MaxCnt         ),
            .OVERFLOW  (                ),
            .UNDERFLOW (                ),
            .COUNT     ( CntMduISARdAddr[gv_i])
        );
    end
endgenerate

assign CCUGLB_ISARdAddr = CntMduISARdAddr[ArbCfgRdyIdx_s0];
assign CCUGLB_ISARdAddrVld = state==CFG & !(Ovf_CntISARdWord & OpCodeMatch);

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        {ArbCfgRdyIdx_s1, state_s1} <= 0;
    else if (CCUGLB_ISARdAddrVld & GLBCCU_ISARdAddrRdy)
        {ArbCfgRdyIdx_s1, state_s1} <= {ArbCfgRdyIdx_s0, state};
end

//=====================================================================================================================
// Logic Design: s2
//=====================================================================================================================
assign CCUGLB_ISARdDatRdy = state_s1 == CFG;
assign handshake_s1 = GLBCCU_ISARdDatVld & CCUGLB_ISARdDatRdy;
assign OpCode = GLBCCU_ISARdDatVld? GLBCCU_ISARdDat[0 +: OPCODE_WIDTH] : {OPCODE_WIDTH{1'b1}};
assign OpCodeMatch = OpCode == ArbCfgRdyIdx_s1;

wire [ADDR_WIDTH     -1 : 0] MaxCntISARdWord= OpNumWord[ArbCfgRdyIdx_s1] -1;

// Reg Update
counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u_counter_CntISARdWord(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     (                ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
    .INC       ( handshake_s1 & OpCodeMatch ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
    .MAX_COUNT ( MaxCntISARdWord   ),
    .OVERFLOW  ( Ovf_CntISARdWord),
    .UNDERFLOW (                ),
    .COUNT     ( CntISARdWord   )
);

// ISA Decoder
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        CfgNumLy                <= 0;
        Mode                    <= 0;
        CCUSYA_CfgNip           <= 0;
        CCUSYA_CfgChi           <= 0;
        CCUSYA_CfgScale         <= 0;
        CCUSYA_CfgShift         <= 0;
        CCUSYA_CfgZp            <= 0;
        CCUSYA_CfgMod           <= 0;
        CCUPOL_CfgNip           <= 0;
        CCUPOL_CfgChi           <= 0;
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
        for(int_i = 0; int_i < GLB_NUM_RDPORT + GLB_NUM_WRPORT; int_i=int_i+1) begin
            if(int_i == GLBWRIDX_ITFISA) begin
                CCUTOP_CfgPortBankFlag[int_i] <= 'd1; // ISA write bank0
                CCUTOP_CfgPortParBank[int_i] <= 'd1;
            end else if(int_i ==  GLB_NUM_WRPORT + GLBRDIDX_CCUISA) begin
                CCUTOP_CfgPortBankFlag[int_i] <= 'd1; // ISA read bank0
                CCUTOP_CfgPortParBank[int_i] <= 'd1;
            end else begin
                CCUTOP_CfgPortBankFlag[int_i] <= 0; // ISA read bank0
                CCUTOP_CfgPortParBank[int_i] <= 'd1;   // default  
            end 
        end 
        for(int_i = 0; int_i < ITF_NUM_RDPORT+ITF_NUM_WRPORT; int_i=int_i+1) begin
            if(int_i == GLBWRIDX_ITFISA)
                CCUITF_DRAMBaseAddr[int_i]    <= 'd0; // ISA read DramAddr = 0
            else 
                CCUITF_DRAMBaseAddr[int_i]    <= 'd0;
        end

    end else if ( handshake_s1 & OpCodeMatch) begin
        if ( OpCode == OPCODE_CCU) begin
            {CfgNumLy, Mode} <= GLBCCU_ISARdDat[OPCODE_WIDTH +: OPCODE_WIDTH + NUM_LAYER_WIDTH ];

        end else if (OpCode == OPCODE_FPS) begin
            if(CntISARdWord == 1) begin
                CCUFPS_CfgNip                                           <= GLBCCU_ISARdDat[OPCODE_WIDTH                                         +: IDX_WIDTH*NUM_FPC];
                CCUFPS_CfgNop                                           <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*NUM_FPC                     +: IDX_WIDTH*NUM_FPC];
                CCUFPS_CfgCrdBaseRdAddr                                 <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*NUM_FPC*2                   +: IDX_WIDTH*NUM_FPC];
            end else if(CntISARdWord == 2) begin
                CCUFPS_CfgCrdBaseWrAddr                                 <= GLBCCU_ISARdDat[OPCODE_WIDTH                                         +: IDX_WIDTH*NUM_FPC];
                CCUFPS_CfgIdxBaseWrAddr                                 <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*NUM_FPC                     +: IDX_WIDTH*NUM_FPC];
                CCUFPS_CfgMaskBaseAddr                                  <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*NUM_FPC*2                   +: IDX_WIDTH*NUM_FPC];
            end else if(CntISARdWord == 3) begin
                CCUFPS_CfgDistBaseAddr                                  <= GLBCCU_ISARdDat[OPCODE_WIDTH                                         +: IDX_WIDTH*NUM_FPC];
                CCUITF_DRAMBaseAddr   [GLBWRIDX_ITFCRD                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*NUM_FPC                     +: DRAM_ADDR_WIDTH];
                CCUITF_DRAMBaseAddr   [ITF_NUM_WRPORT + GLBRDIDX_ITFIDX]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*NUM_FPC + DRAM_ADDR_WIDTH   +: DRAM_ADDR_WIDTH];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_ITFCRD                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*NUM_FPC + DRAM_ADDR_WIDTH*2 +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_FPSCRD]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*NUM_FPC + DRAM_ADDR_WIDTH*2 + NUM_BANK  +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_FPSMSK                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*NUM_FPC + DRAM_ADDR_WIDTH*2 + NUM_BANK*2 +: NUM_BANK];
            end else if(CntISARdWord == 4) begin
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_FPSMSK]   <= GLBCCU_ISARdDat[OPCODE_WIDTH              +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_FPSDST                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK   +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_FPSDST]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*2 +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_FPSIDX                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*3 +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_ITFIDX]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*4 +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_FPSCRD                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*5 +: NUM_BANK];
            end else if(CntISARdWord == 5) begin
                CCUTOP_CfgPortParBank [GLBWRIDX_ITFCRD                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH                    +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_FPSCRD]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + MAXPAR_WIDTH*1   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLBWRIDX_FPSMSK                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + MAXPAR_WIDTH*2   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_FPSMSK]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + MAXPAR_WIDTH*3   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLBWRIDX_FPSDST                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + MAXPAR_WIDTH*4   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_FPSDST]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + MAXPAR_WIDTH*5   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLBWRIDX_FPSIDX                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + MAXPAR_WIDTH*6   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_ITFIDX]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + MAXPAR_WIDTH*7   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLBWRIDX_FPSCRD                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + MAXPAR_WIDTH*8   +: MAXPAR_WIDTH];
            end

        end else if (OpCode == OPCODE_KNN) begin
            if(CntISARdWord == 1) begin
                CCUKNN_CfgNip                                           <= GLBCCU_ISARdDat[OPCODE_WIDTH                                                                 +: IDX_WIDTH];
                CCUKNN_CfgK                                             <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH                                                     +: IDX_WIDTH];
                CCUKNN_CfgCrdRdAddr                                     <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*2                                                   +: IDX_WIDTH];
                CCUKNN_CfgMapWrAddr                                     <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*3                                                   +: IDX_WIDTH];
                CCUITF_DRAMBaseAddr   [ITF_NUM_WRPORT + GLBRDIDX_ITFMAP]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*4                                                   +: DRAM_ADDR_WIDTH];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_ITFMAP]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*4 + DRAM_ADDR_WIDTH                                 +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_KNNMAP                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*4 + DRAM_ADDR_WIDTH + NUM_BANK                      +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_KNNCRD]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*4 + DRAM_ADDR_WIDTH + NUM_BANK*2                    +: NUM_BANK];
                CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_ITFMAP]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*4 + DRAM_ADDR_WIDTH + NUM_BANK*3                    +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLBWRIDX_KNNMAP                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*4 + DRAM_ADDR_WIDTH + NUM_BANK*3 + MAXPAR_WIDTH     +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_KNNCRD]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + IDX_WIDTH*4 + DRAM_ADDR_WIDTH + NUM_BANK*3 + MAXPAR_WIDTH*2   +: MAXPAR_WIDTH];
            end

        end else if ( OpCode == OPCODE_SYA) begin
            if (CntISARdWord == 1) begin
                CCUSYA_CfgMod                                           <= GLBCCU_ISARdDat[OPCODE_WIDTH                                                                         +: OPCODE_WIDTH];// 8bit
                CCUSYA_CfgNip                                           <= GLBCCU_ISARdDat[OPCODE_WIDTH*2                                                                       +: IDX_WIDTH];
                CCUSYA_CfgChi                                           <= GLBCCU_ISARdDat[OPCODE_WIDTH*2 + IDX_WIDTH                                                           +: CHN_WIDTH];     
                CCUSYA_CfgScale                                         <= GLBCCU_ISARdDat[OPCODE_WIDTH*2 + IDX_WIDTH + CHN_WIDTH                                               +: QNTSL_WIDTH];       
                CCUSYA_CfgShift                                         <= GLBCCU_ISARdDat[OPCODE_WIDTH*2 + IDX_WIDTH + CHN_WIDTH + QNTSL_WIDTH                                 +: ACT_WIDTH];  
                CCUSYA_CfgZp                                            <= GLBCCU_ISARdDat[OPCODE_WIDTH*2 + IDX_WIDTH + CHN_WIDTH + QNTSL_WIDTH + ACT_WIDTH                     +: ACT_WIDTH]; 
                CCUSYA_CfgActRdBaseAddr                                 <= GLBCCU_ISARdDat[OPCODE_WIDTH*2 + IDX_WIDTH + CHN_WIDTH + QNTSL_WIDTH + ACT_WIDTH*2                   +: ADDR_WIDTH]; 
                CCUSYA_CfgWgtRdBaseAddr                                 <= GLBCCU_ISARdDat[OPCODE_WIDTH*2 + IDX_WIDTH + CHN_WIDTH + QNTSL_WIDTH + ACT_WIDTH*2 + ADDR_WIDTH      +: ADDR_WIDTH]; 
                CCUSYA_CfgOfmWrBaseAddr                                 <= GLBCCU_ISARdDat[OPCODE_WIDTH*2 + IDX_WIDTH + CHN_WIDTH + QNTSL_WIDTH + ACT_WIDTH*2 + ADDR_WIDTH*2    +: ADDR_WIDTH]; 
                CCUITF_DRAMBaseAddr   [GLBWRIDX_ITFACT                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH*2 + IDX_WIDTH + CHN_WIDTH + QNTSL_WIDTH + ACT_WIDTH*2 + ADDR_WIDTH*3    +: DRAM_ADDR_WIDTH]; 
                CCUITF_DRAMBaseAddr   [GLBWRIDX_ITFWGT                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH*2 + IDX_WIDTH + CHN_WIDTH + QNTSL_WIDTH + ACT_WIDTH*2 + ADDR_WIDTH*4 + DRAM_ADDR_WIDTH  +: DRAM_ADDR_WIDTH]; 
            end else if(CntISARdWord == 2) begin
                CCUITF_DRAMBaseAddr   [ITF_NUM_WRPORT + GLBRDIDX_ITFOFM]   <= GLBCCU_ISARdDat[OPCODE_WIDTH                                   +: DRAM_ADDR_WIDTH];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_ITFACT                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH                 +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_SYAACT]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH + NUM_BANK      +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_ITFWGT                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH + NUM_BANK*2    +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_SYAWGT]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH + NUM_BANK*3    +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_ITFOFM]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH + NUM_BANK*4    +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_SYAOFM                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH + NUM_BANK*5    +: NUM_BANK];

                CCUTOP_CfgPortParBank [GLBWRIDX_ITFACT                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH + NUM_BANK*6                    +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_SYAACT]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH + NUM_BANK*6 + MAXPAR_WIDTH     +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLBWRIDX_ITFWGT                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH + NUM_BANK*6 + MAXPAR_WIDTH*2   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_SYAWGT]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH + NUM_BANK*6 + MAXPAR_WIDTH*3   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_ITFOFM]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH + NUM_BANK*6 + MAXPAR_WIDTH*4   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLBWRIDX_SYAOFM                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + DRAM_ADDR_WIDTH + NUM_BANK*6 + MAXPAR_WIDTH*5   +: MAXPAR_WIDTH]; // 8+32+192+12=244
            end

        end else if (OpCode == OPCODE_POL) begin
            if (CntISARdWord == 1) begin
                CCUPOL_CfgNip                                           <= GLBCCU_ISARdDat[OPCODE_WIDTH +: IDX_WIDTH*POOL_CORE];
            end else if(CntISARdWord == 2) begin 
                CCUPOL_CfgChi                                           <= GLBCCU_ISARdDat[OPCODE_WIDTH +: CHN_WIDTH*POOL_CORE];
            end else if(CntISARdWord == 3) begin
                CCUPOL_CfgK                                             <= GLBCCU_ISARdDat[OPCODE_WIDTH +: OPCODE_WIDTH*POOL_CORE]; // 8bit
                CCUITF_DRAMBaseAddr   [GLBWRIDX_ITFMAP                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH*(POOL_CORE + 1)                                                 +: DRAM_ADDR_WIDTH]; // 8bit; 
                CCUTOP_CfgPortBankFlag[GLBWRIDX_ITFMAP                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH*(POOL_CORE + 1) + DRAM_ADDR_WIDTH                               +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_POLMAP]   <= GLBCCU_ISARdDat[OPCODE_WIDTH*(POOL_CORE + 1) + DRAM_ADDR_WIDTH + NUM_BANK                    +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLBWRIDX_POLOFM                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH*(POOL_CORE + 1) + DRAM_ADDR_WIDTH + NUM_BANK*2                  +: NUM_BANK];
                CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_POLOFM]   <= GLBCCU_ISARdDat[OPCODE_WIDTH*(POOL_CORE + 1) + DRAM_ADDR_WIDTH + NUM_BANK*3                  +: NUM_BANK];
            end else if(CntISARdWord == 4) begin
                for(int_i = 1; int_i < POOL_CORE; int_i = int_i + 1) begin
                    CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_POLOFM + int_i]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*(int_i - 1) +: NUM_BANK]; // 1 bank
                end
                CCUTOP_CfgPortParBank [GLBWRIDX_ITFMAP                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*(POOL_CORE - 1)                  +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_POLMAP]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*(POOL_CORE - 1) + MAXPAR_WIDTH   +: MAXPAR_WIDTH];
                CCUTOP_CfgPortParBank [GLBWRIDX_POLOFM                 ]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*(POOL_CORE - 1) + MAXPAR_WIDTH*2 +: MAXPAR_WIDTH];
                for(int_i = 0; int_i < POOL_CORE; int_i = int_i + 1) begin
                    CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_POLOFM + int_i]   <= GLBCCU_ISARdDat[OPCODE_WIDTH + NUM_BANK*(POOL_CORE - 1) + MAXPAR_WIDTH*(3 + int_i) +: MAXPAR_WIDTH];
                end
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
            end else if ( state_s1 == CFG & ArbCfgRdyIdx_s1 == gv_i & Ovf_CntISARdWord & handshake_s1 & OpCodeMatch) begin
                CfgVld[gv_i] <= 1'b1;
            end
        end
    end
endgenerate

always @(posedge clk or negedge rst_n)  begin
    if (!rst_n) begin
        ArbCfgRdyIdx_s2 <= 0;
    end else if ( state_s1 == CFG & Ovf_CntISARdWord & handshake_s1 & OpCodeMatch)begin
        ArbCfgRdyIdx_s2 <= ArbCfgRdyIdx_s1;
    end
end

wire FPS_CfgVld;
wire POL_CfgVld;

assign {POL_CfgVld, CCUSYA_CfgVld, CCUKNN_CfgVld, FPS_CfgVld, CCUTOP_CfgVld} = CfgVld;
assign CCUFPS_CfgVld = {NUM_FPC{FPS_CfgVld}};
assign CCUPOL_CfgVld = {POOL_CORE{POL_CfgVld}};
//=====================================================================================================================
// Logic Design 3: Rst
//=====================================================================================================================
assign CCUSYA_Rst = state == IDLE;
assign CCUPOL_Rst = {POOL_CORE{state == IDLE}};
assign CCUFPS_Rst = {NUM_FPC{state == IDLE}};
assign CCUKNN_Rst = state == IDLE;
assign CCUITF_Rst = state == IDLE;

//=====================================================================================================================
// Logic Design 4: GLB Control
//=====================================================================================================================


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================
MINMAX#(
    .DATA_WIDTH ( ADDR_WIDTH            ),
    .PORT       ( OPNUM                 ),
    .MINMAX     ( 0                     )
)u_MINMAX(
    .IN         ( CntMduISARdAddr       ),
    .IDX        (                       ),
    .VALUE      ( CCUTOP_MduISARdAddrMin)
);

//=====================================================================================================================
// Debug :
//=====================================================================================================================

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        Debug_TriggerSYACfgHS <= 0;
    else if (CCUSYA_CfgVld & SYACCU_CfgRdy)
        Debug_TriggerSYACfgHS <= 1;
end

endmodule
