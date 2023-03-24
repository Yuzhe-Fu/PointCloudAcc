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
    parameter BYTE_WIDTH            = 8,

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
    parameter NUM_FPC               = 8,
    parameter OPNUM                 = NUM_MODULE + (NUM_FPC -1) + (POOL_CORE -1),
    parameter MAXPAR_WIDTH          = $clog2(MAXPAR) + 1 // MAXPAR=2 -> 2

    )(
    input                                   clk                     ,
    input                                   rst_n                   ,

    input   [PORT_WIDTH             -1 : 0] TOPCCU_ISARdDat         ,       
    input                                   TOPCCU_ISARdDatVld      ,          
    output                                  CCUTOP_ISARdDatRdy      ,

    output                                  CCUITF_CfgVld           ,
    input                                   ITFCCU_CfgRdy           ,  
    output  [BYTE_WIDTH             -1 : 0] CCUITF_CfgInOut            , 
    output  [DRAM_ADDR_WIDTH        -1 : 0] CCUITF_CfgDRAMBaseAddr     ,
    output  [IDX_WIDTH              -1 : 0] CCUITF_CfgGLBBaseAddr      ,
    output  [IDX_WIDTH              -1 : 0] CCUITF_CfgNum              , 
                

    output  [NUM_FPC                -1 : 0] CCUFPS_CfgVld           ,
    input   [NUM_FPC                -1 : 0] FPSCCU_CfgRdy           ,        
    output  [IDX_WIDTH*NUM_FPC      -1 : 0] CCUFPS_CfgNip           ,                    
    output  [IDX_WIDTH*NUM_FPC      -1 : 0] CCUFPS_CfgNop           , 
    output  [IDX_WIDTH*NUM_FPC      -1 : 0] CCUFPS_CfgCrdBaseRdAddr ,
    output  [IDX_WIDTH*NUM_FPC      -1 : 0] CCUFPS_CfgCrdBaseWrAddr ,
    output  [IDX_WIDTH*NUM_FPC      -1 : 0] CCUFPS_CfgIdxBaseWrAddr ,
    output  [IDX_WIDTH*NUM_FPC      -1 : 0] CCUFPS_CfgMaskBaseAddr  ,   
    output  [IDX_WIDTH*NUM_FPC      -1 : 0] CCUFPS_CfgDistBaseAddr  ,

    output                                  CCUKNN_CfgVld        ,
    input                                   KNNCCU_CfgRdy        ,        
    output  [IDX_WIDTH              -1 : 0] CCUKNN_CfgNip           ,                    
    output  [(MAP_WIDTH + 1)        -1 : 0] CCUKNN_CfgK             , 
    output  [IDX_WIDTH              -1 : 0] CCUKNN_CfgCrdRdAddr     ,
    output  [IDX_WIDTH              -1 : 0] CCUKNN_CfgMapWrAddr     ,

    output                                  CCUSYA_CfgVld        ,
    input                                   SYACCU_CfgRdy        ,
    output  [2                      -1 : 0] CCUSYA_CfgMod           ,
    output                                  CCUSYA_CfgOfmPhaseShift ,
    output  [CHN_WIDTH              -1 : 0] CCUSYA_CfgChn           ,         
    output  [QNTSL_WIDTH            -1 : 0] CCUSYA_CfgScale         ,        
    output  [ACT_WIDTH              -1 : 0] CCUSYA_CfgShift         ,        
    output  [ACT_WIDTH              -1 : 0] CCUSYA_CfgZp            ,
    output  [IDX_WIDTH              -1 : 0] CCUSYA_CfgNumGrpPerTile ,
    output  [IDX_WIDTH              -1 : 0] CCUSYA_CfgNumTilIfm     ,
    output  [IDX_WIDTH              -1 : 0] CCUSYA_CfgNumTilFlt     ,
    output                                  CCUSYA_CfgLopOrd        ,
    output  [ADDR_WIDTH             -1 : 0] CCUSYA_CfgActRdBaseAddr ,
    output  [ADDR_WIDTH             -1 : 0] CCUSYA_CfgWgtRdBaseAddr ,
    output  [ADDR_WIDTH             -1 : 0] CCUSYA_CfgOfmWrBaseAddr ,

    output  [POOL_CORE              -1 : 0] CCUPOL_CfgVld       ,
    input   [POOL_CORE              -1 : 0] POLCCU_CfgRdy       ,
    output  [(MAP_WIDTH+1)*POOL_CORE-1 : 0] CCUPOL_CfgK         ,
    output  [IDX_WIDTH*POOL_CORE    -1 : 0] CCUPOL_CfgNip       ,
    output  [CHN_WIDTH*POOL_CORE    -1 : 0] CCUPOL_CfgChn       ,
             
    output  [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)  -1 : 0][NUM_BANK    -1 : 0] CCUTOP_CfgPortBankFlag ,
    output  [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)  -1 : 0][MAXPAR_WIDTH-1 : 0] CCUTOP_CfgPortParBank,
    output  [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)                   -1 : 0] CCUTOP_CfgPortOffEmptyFull,
    output [OPNUM                   -1 : 0] CCUTOP_CfgRdy

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

localparam NUMPORT_CCU   = 1;
localparam NUMPORT_FPS   = 19;
localparam NUMPORT_KNN   = 2;
localparam NUMPORT_SYA   = 3;
localparam NUMPORT_POL   = 4;
localparam NUMPORT_ITF   = 4;

localparam GLBWRIDX_ITFGLB = 0; 
localparam GLBWRIDX_FPSMSK = 1; 
localparam GLBWRIDX_FPSCRD = 2; 
localparam GLBWRIDX_FPSDST = 3; 
localparam GLBWRIDX_FPSIDX = 4; 
localparam GLBWRIDX_KNNMAP = 5;
localparam GLBWRIDX_SYAOFM = 6;
localparam GLBWRIDX_POLOFM = 7;
                                
localparam GLBRDIDX_ITFGLB = 0; 
localparam GLBRDIDX_FPSMSK = 1; 
localparam GLBRDIDX_FPSCRD = 2; 
localparam GLBRDIDX_FPSDST = 3; 
localparam GLBRDIDX_KNNCRD = 4; 
localparam GLBRDIDX_SYAACT = 5; 
localparam GLBRDIDX_SYAWGT = 6; 
localparam GLBRDIDX_POLMAP = 7;
localparam GLBRDIDX_POLOFM = 8;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg [OPCODE_WIDTH                   -1 : 0] OpCode;
integer                                     int_i;
wire  [OPNUM                        -1 : 0] CfgVld; 
wire  [OPNUM                        -1 : 0] SIPO_InRdy; 
wire                                        CCUTOP_CfgVld;  

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

        DEC:        if (CfgVld[OpCode] & CCUTOP_CfgRdy[OpCode])
                        next_state <= IDLE;
                    else 
                        next_state <= DEC;

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
// Logic Design
//=====================================================================================================================
// CCUTOP_CfgRdy -> Req
`ifdef PSEUDO_DATA
    assign CCUTOP_CfgRdy = {ITFCCU_CfgRdy, 1'b0, 1'b0, 1'b0, &FPSCCU_CfgRdy, 1'b0};
`else
    assign CCUTOP_CfgRdy = {ITFCCU_CfgRdy, &POLCCU_CfgRdy, SYACCU_CfgRdy, KNNCCU_CfgRdy, &FPSCCU_CfgRdy, 1'b0};
`endif

wire        FPS_CfgVld;
wire        POL_CfgVld;

assign {CCUITF_CfgVld, POL_CfgVld, CCUSYA_CfgVld, CCUKNN_CfgVld, FPS_CfgVld, CCUTOP_CfgVld} = CfgVld;
assign CCUFPS_CfgVld = {NUM_FPC{FPS_CfgVld}};
assign CCUPOL_CfgVld = {POOL_CORE{POL_CfgVld}};

//=====================================================================================================================
// Logic Design: s2
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        OpCode <= {OPCODE_WIDTH{1'b1}};
    end else if(next_state == IDLE) begin // HS
        OpCode <= {OPCODE_WIDTH{1'b1}};
    end else if(state == IDLE & next_state == DEC) begin
        OpCode <= TOPCCU_ISARdDat[0 +: OPCODE_WIDTH];
    end
end

wire [PORT_WIDTH*NUMPORT_CCU    -1 : 0] ISA_CCU;
wire [PORT_WIDTH*NUMPORT_FPS    -1 : 0] ISA_FPS;
wire [PORT_WIDTH*NUMPORT_KNN    -1 : 0] ISA_KNN;
wire [PORT_WIDTH*NUMPORT_SYA    -1 : 0] ISA_SYA;
wire [PORT_WIDTH*NUMPORT_POL    -1 : 0] ISA_POL;
wire [PORT_WIDTH*NUMPORT_ITF    -1 : 0] ISA_ITF;

wire                                    SIPO_CCU_InRdy;
wire                                    SIPO_FPS_InRdy;
wire                                    SIPO_KNN_InRdy;
wire                                    SIPO_SYA_InRdy;
wire                                    SIPO_POL_InRdy;
wire                                    SIPO_ITF_InRdy;

SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH               ),
    .DATA_OUT_WIDTH ( PORT_WIDTH*NUMPORT_FPS  )
)u_SIPO_ISA_FPS(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .IN_VLD       ( state == DEC & TOPCCU_ISARdDatVld & OpCode == OPCODE_FPS ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( TOPCCU_ISARdDat),
    .IN_RDY       ( SIPO_FPS_InRdy ),
    .OUT_DAT      ( ISA_FPS        ),
    .OUT_VLD      ( CfgVld[OPCODE_FPS] ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( CCUTOP_CfgRdy[OPCODE_FPS])
);

SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH               ),
    .DATA_OUT_WIDTH ( PORT_WIDTH*NUMPORT_KNN  )
)u_SIPO_ISA_KNN(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .IN_VLD       ( state == DEC & TOPCCU_ISARdDatVld & OpCode == OPCODE_KNN ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( TOPCCU_ISARdDat),
    .IN_RDY       ( SIPO_KNN_InRdy ),
    .OUT_DAT      ( ISA_KNN        ),
    .OUT_VLD      ( CfgVld[OPCODE_KNN] ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( CCUTOP_CfgRdy[OPCODE_KNN])
);

SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH               ),
    .DATA_OUT_WIDTH ( PORT_WIDTH*NUMPORT_SYA  )
)u_SIPO_ISA_SYA(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .IN_VLD       ( state == DEC & TOPCCU_ISARdDatVld & OpCode == OPCODE_SYA ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( TOPCCU_ISARdDat),
    .IN_RDY       ( SIPO_SYA_InRdy ),
    .OUT_DAT      ( ISA_SYA        ),
    .OUT_VLD      ( CfgVld[OPCODE_SYA] ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( CCUTOP_CfgRdy[OPCODE_SYA])
);
SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH               ),
    .DATA_OUT_WIDTH ( PORT_WIDTH*NUMPORT_POL  )
)u_SIPO_ISA_POL(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .IN_VLD       ( state == DEC & TOPCCU_ISARdDatVld & OpCode == OPCODE_POL ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( TOPCCU_ISARdDat),
    .IN_RDY       ( SIPO_POL_InRdy ),
    .OUT_DAT      ( ISA_POL        ),
    .OUT_VLD      ( CfgVld[OPCODE_POL] ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( CCUTOP_CfgRdy[OPCODE_POL])
);
SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH               ),
    .DATA_OUT_WIDTH ( PORT_WIDTH*NUMPORT_ITF  )
)u_SIPO_ISA_ITF(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .IN_VLD       ( state == DEC & TOPCCU_ISARdDatVld & OpCode == OPCODE_ITF ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( TOPCCU_ISARdDat),
    .IN_RDY       ( SIPO_ITF_InRdy ),
    .OUT_DAT      ( ISA_ITF        ),
    .OUT_VLD      ( CfgVld[OPCODE_ITF] ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( CCUTOP_CfgRdy[OPCODE_ITF])
);

assign SIPO_InRdy           = {SIPO_ITF_InRdy, SIPO_POL_InRdy, SIPO_SYA_InRdy, SIPO_KNN_InRdy, SIPO_FPS_InRdy, 1'b1};
assign CCUTOP_ISARdDatRdy   = state == DEC & SIPO_InRdy[OpCode];

assign {
    CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_FPSCRD                 ],
    CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_FPSIDX                 ],
    CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSDST],
    CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_FPSDST                 ],
    CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSMSK],
    CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_FPSMSK                 ],
    CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSCRD],
    CCUTOP_CfgPortParBank     [GLBWRIDX_FPSCRD                 ],
    CCUTOP_CfgPortParBank     [GLBWRIDX_FPSIDX                 ],
    CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_FPSDST],
    CCUTOP_CfgPortParBank     [GLBWRIDX_FPSDST                 ],
    CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_FPSMSK],
    CCUTOP_CfgPortParBank     [GLBWRIDX_FPSMSK                 ],
    CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_FPSCRD],
    CCUTOP_CfgPortBankFlag  [GLBWRIDX_FPSCRD                 ]  ,
    CCUTOP_CfgPortBankFlag  [GLBWRIDX_FPSIDX                 ]  ,
    CCUTOP_CfgPortBankFlag  [GLB_NUM_WRPORT + GLBRDIDX_FPSDST]  ,
    CCUTOP_CfgPortBankFlag  [GLBWRIDX_FPSDST                 ]  ,
    CCUTOP_CfgPortBankFlag  [GLB_NUM_WRPORT + GLBRDIDX_FPSMSK]  ,
    CCUTOP_CfgPortBankFlag  [GLBWRIDX_FPSMSK                 ]  ,
    CCUTOP_CfgPortBankFlag  [GLB_NUM_WRPORT + GLBRDIDX_FPSCRD]  ,
    CCUFPS_CfgDistBaseAddr                                      ,
    CCUFPS_CfgMaskBaseAddr                                      ,
    CUFPS_CfgIdxBaseWrAddr                                      ,
    CCUFPS_CfgCrdBaseWrAddr                                     ,
    CCUFPS_CfgCrdBaseRdAddr                                     ,
    CCUFPS_CfgNop                                               , 
    CCUFPS_CfgNip                                                 
} = ISA_FPS[PORT_WIDTH*NUMPORT_FPS -1 : OPCODE_WIDTH];

assign {
    CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_KNNCRD],
    CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_KNNMAP                 ],
    CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_KNNCRD],
    CCUTOP_CfgPortParBank     [GLBWRIDX_KNNMAP                 ],
    CCUTOP_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_KNNCRD],
    CCUTOP_CfgPortBankFlag    [GLBWRIDX_KNNMAP                 ],
    CCUKNN_CfgMapWrAddr                                         ,
    CCUKNN_CfgCrdRdAddr                                         ,
    CCUKNN_CfgK                                                 ,
    CCUKNN_CfgNip      
} = ISA_KNN[PORT_WIDTH*NUMPORT_KNN -1 : OPCODE_WIDTH];

assign {
    CCUTOP_CfgPortOffEmptyFull[GLBWRIDX_SYAOFM                 ],
    CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_SYAWGT],
    CCUTOP_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_SYAACT],
    CCUTOP_CfgPortParBank     [GLBWRIDX_SYAOFM                 ],
    CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_SYAWGT],
    CCUTOP_CfgPortParBank     [GLB_NUM_WRPORT + GLBRDIDX_SYAACT],
    CCUTOP_CfgPortBankFlag    [GLBWRIDX_SYAOFM                 ],
    CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_SYAWGT]    ,
    CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_SYAACT]    ,
    CCUSYA_CfgOfmWrBaseAddr                                     ,
    CCUSYA_CfgWgtRdBaseAddr                                     ,
    CCUSYA_CfgActRdBaseAddr                                     ,
    CCUSYA_CfgLopOrd                                            ,
    CCUSYA_CfgNumTilIfm                                         ,
    CCUSYA_CfgNumTilFlt                                         ,
    CCUSYA_CfgNumGrpPerTile                                     ,
    CCUSYA_CfgChn                                               ,       
    CCUSYA_CfgOfmPhaseShift                                     ,
    CCUSYA_CfgMod                                               ,
    CCUSYA_CfgZp                                                ,
    CCUSYA_CfgShift                                             
} = ISA_SYA[PORT_WIDTH*NUMPORT_SYA -1 : OPCODE_WIDTH];

assign {
    CCUTOP_CfgPortOffEmptyFull [GLB_NUM_WRPORT + GLBRDIDX_POLOFM +: POOL_CORE]  ,
    CCUTOP_CfgPortOffEmptyFull [GLBWRIDX_POLOFM                 ]               ,
    CCUTOP_CfgPortOffEmptyFull [GLB_NUM_WRPORT + GLBRDIDX_POLMAP]               ,
    CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_POLOFM +: POOL_CORE],
    CCUTOP_CfgPortParBank [GLBWRIDX_POLOFM                 ]                      ,
    CCUTOP_CfgPortParBank [GLB_NUM_WRPORT + GLBRDIDX_POLMAP]                      ,
    CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_POLOFM +: POOL_CORE],
    CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_POLOFM]                      ,
    CCUTOP_CfgPortBankFlag[GLBWRIDX_POLOFM                 ]                      ,
    CCUTOP_CfgPortBankFlag[GLB_NUM_WRPORT + GLBRDIDX_POLMAP]                      ,
    CCUPOL_CfgK                                                                   ,
    CCUPOL_CfgChn                                                                 ,
    CCUPOL_CfgNip                                                                 
} = ISA_POL[PORT_WIDTH*NUMPORT_POL -1 : OPCODE_WIDTH];

assign { 
    CCUITF_CfgNum,     
    CCUITF_CfgGLBBaseAddr,
    CCUITF_CfgDRAMBaseAddr,
    CCUITF_CfgInOut // 0: IN2CHIP; 1: OUT2OFF
} = ISA_ITF[PORT_WIDTH*NUMPORT_ITF -1 : OPCODE_WIDTH];

endmodule
