// Thic is a simple example.
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
`define CEIL(a, b) ( \
 (a % b)? (a / b + 1) : (a / b) \
)
module FPS #(
    parameter FPSISA_WIDTH      = 128*16,
    parameter SRAM_WIDTH        = 256,
    parameter IDX_WIDTH         = 16,
    parameter CRD_WIDTH         = 8,
    parameter CRD_DIM           = 3,
    parameter NUM_FPC           = 16,
    parameter NUMMASK_PROC     = 32, // process bits at a time
    parameter FPSMON_WIDTH      = FPSISA_WIDTH + 3,
    parameter DISTSQR_WIDTH     = CRD_WIDTH*2 + $clog2(CRD_DIM),
    parameter CRDIDX_WIDTH      = CRD_WIDTH*CRD_DIM+IDX_WIDTH
    )(
    input                                       clk                     ,
    input                                       rst_n                   ,

    // Configure
    input  [NUM_FPC                     -1 : 0] CCUFPS_CfgVld           ,
    output [NUM_FPC                     -1 : 0] FPSCCU_CfgRdy           ,
    input  [FPSISA_WIDTH                -1 : 0] CCUFPS_CfgInfo          ,

    output [IDX_WIDTH                   -1 : 0] FPSGLB_MaskRdAddr       ,
    output                                      FPSGLB_MaskRdAddrVld    ,
    input                                       GLBFPS_MaskRdAddrRdy    ,
    input  [SRAM_WIDTH                  -1 : 0] GLBFPS_MaskRdDat        ,    
    input                                       GLBFPS_MaskRdDatVld     ,    
    output                                      FPSGLB_MaskRdDatRdy     ,    
    output [IDX_WIDTH                   -1 : 0] FPSGLB_MaskWrAddr       ,
    output [SRAM_WIDTH                  -1 : 0] FPSGLB_MaskWrDat        ,   
    output                                      FPSGLB_MaskWrDatVld     ,
    input                                       GLBFPS_MaskWrDatRdy     , 
    output [IDX_WIDTH                   -1 : 0] FPSGLB_CrdRdAddr        ,
    output                                      FPSGLB_CrdRdAddrVld     ,
    input                                       GLBFPS_CrdRdAddrRdy     ,
    input  [SRAM_WIDTH                  -1 : 0] GLBFPS_CrdRdDat         ,    
    input                                       GLBFPS_CrdRdDatVld      ,    
    output                                      FPSGLB_CrdRdDatRdy      ,    
    output [IDX_WIDTH                   -1 : 0] FPSGLB_CrdWrAddr        ,
    output [SRAM_WIDTH                  -1 : 0] FPSGLB_CrdWrDat         ,   
    output                                      FPSGLB_CrdWrDatVld      ,
    input                                       GLBFPS_CrdWrDatRdy      ,  
    output [IDX_WIDTH                   -1 : 0] FPSGLB_DistRdAddr       ,
    output                                      FPSGLB_DistRdAddrVld    ,
    input                                       GLBFPS_DistRdAddrRdy    ,
    input  [SRAM_WIDTH                  -1 : 0] GLBFPS_DistRdDat        ,    
    input                                       GLBFPS_DistRdDatVld     ,    
    output                                      FPSGLB_DistRdDatRdy     ,    
    output [IDX_WIDTH                   -1 : 0] FPSGLB_DistWrAddr       ,
    output [SRAM_WIDTH                  -1 : 0] FPSGLB_DistWrDat        ,   
    output                                      FPSGLB_DistWrDatVld     ,
    input                                       GLBFPS_DistWrDatRdy     ,
    output [IDX_WIDTH                   -1 : 0] FPSGLB_IdxWrAddr        ,
    output [SRAM_WIDTH                  -1 : 0] FPSGLB_IdxWrDat         ,   
    output                                      FPSGLB_IdxWrDatVld      ,
    input                                       GLBFPS_IdxWrDatRdy      ,

    output [FPSMON_WIDTH                -1 : 0] FPSMON_Dat              

);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam NUM_CRD_SRAM     = SRAM_WIDTH / (CRD_WIDTH*CRD_DIM);
localparam NUM_DIST_SRAM    = SRAM_WIDTH / DISTSQR_WIDTH;
localparam CNT_CUTMASK_WIDTH= IDX_WIDTH - $clog2(SRAM_WIDTH/NUMMASK_PROC);

localparam IDLE   = 3'b000;
localparam WORK   = 3'b001;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

wire [NUM_FPC   -1 : 0][IDX_WIDTH   -1 : 0] FPC_MaskRdAddr;
wire [NUM_FPC                       -1 : 0] FPC_MaskRdAddrVld;
wire [NUM_FPC                       -1 : 0] FPC_MaskRdDatRdy;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCMaskRdIdx;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCMaskRdIdx_d;

wire [NUM_FPC   -1 : 0][IDX_WIDTH   -1 : 0] FPC_CrdRdAddr;
wire [NUM_FPC                       -1 : 0] FPC_CrdRdAddrVld;
wire [NUM_FPC                       -1 : 0] FPC_CrdRdDatRdy;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCCrdRdIdx;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCCrdRdIdx_d;

wire [NUM_FPC   -1 : 0][IDX_WIDTH   -1 : 0] FPC_DistRdAddr;
wire [NUM_FPC                       -1 : 0] FPC_DistRdAddrVld;
wire [NUM_FPC                       -1 : 0] FPC_DistRdDatRdy;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCDistRdIdx;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCDistRdIdx_d;

wire [NUM_FPC   -1 : 0][IDX_WIDTH   -1 : 0] FPC_MaskWrAddr;
reg  [NUM_FPC   -1 : 0][SRAM_WIDTH  -1 : 0] FPC_MaskWrDat;
wire [NUM_FPC                       -1 : 0] FPC_MaskWrDatVld;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCMaskWrIdx;

wire [NUM_FPC   -1 : 0][IDX_WIDTH   -1 : 0] FPC_CrdWrAddr;
wire [NUM_FPC   -1 : 0][SRAM_WIDTH  -1 : 0] FPC_CrdWrDat;
wire [NUM_FPC                       -1 : 0] FPC_CrdWrDatVld;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCCrdWrIdx;

wire [NUM_FPC   -1 : 0][IDX_WIDTH   -1 : 0] FPC_DistWrAddr;
wire [NUM_FPC   -1 : 0][SRAM_WIDTH  -1 : 0] FPC_DistWrDat;
wire [NUM_FPC                       -1 : 0] FPC_DistWrDatVld;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCDistWrIdx;

wire [NUM_FPC   -1 : 0][IDX_WIDTH   -1 : 0] FPC_IdxWrAddr;
wire [NUM_FPC   -1 : 0][SRAM_WIDTH  -1 : 0] FPC_IdxWrDat;
wire [NUM_FPC                       -1 : 0] FPC_IdxWrDatVld;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCIdxWrIdx;

wire  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgNip          ;
wire  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgNop          ;
wire  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgCrdBaseRdAddr;
wire  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgCrdBaseWrAddr;
wire  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgIdxBaseWrAddr;
wire  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgMaskBaseAddr ;   
wire  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgDistBaseAddr ;
reg [NUM_FPC -1 : 0][3             -1 : 0] state;
reg [NUM_FPC -1 : 0][3             -1 : 0] next_state;

//=====================================================================================================================
// Logic Design: ISA Decode
//=====================================================================================================================
assign {
CCUFPS_CfgDistBaseAddr ,// 16 x 16
CCUFPS_CfgMaskBaseAddr ,// 16 x 16
CCUFPS_CfgIdxBaseWrAddr,// 16 x 16
CCUFPS_CfgCrdBaseWrAddr,// 16 x 16
CCUFPS_CfgCrdBaseRdAddr,// 16 x 16
CCUFPS_CfgNop          ,// 16 x 16
CCUFPS_CfgNip           // 16 x 16
} = CCUFPS_CfgInfo[FPSISA_WIDTH -1 : 16];

//=====================================================================================================================
// Logic Design
//=====================================================================================================================
// Arb MaskRd
ArbCore#(
    .NUM_CORE    ( NUM_FPC      ),
    .ADDR_WIDTH  ( IDX_WIDTH    ),
    .DATA_WIDTH  ( SRAM_WIDTH   )
)u_ArbCore_FPCRdMask(
    .clk         ( clk                  ),
    .rst_n       ( rst_n                ),
    .CoreOutVld  ( FPC_MaskRdAddrVld    ),
    .CoreOutAddr ( FPC_MaskRdAddr       ),
    .CoreOutDat  (                      ),
    .CoreOutRdy  ( FPC_MaskRdDatRdy     ),
    .TopOutVld   ( FPSGLB_MaskRdAddrVld ),
    .TopOutAddr  ( FPSGLB_MaskRdAddr    ),
    .TopOutDat   (                      ),
    .TopOutRdy   ( FPSGLB_MaskRdDatRdy  ),
    .TOPInRdy    ( GLBFPS_MaskRdAddrRdy ),
    .ArbCoreIdx  ( ArbFPCMaskRdIdx      ),
    .ArbCoreIdx_d( ArbFPCMaskRdIdx_d    )
);

// Arb CrdRd
ArbCore#(
    .NUM_CORE    ( NUM_FPC      ),
    .ADDR_WIDTH  ( IDX_WIDTH    ),
    .DATA_WIDTH  ( SRAM_WIDTH   )
)u_ArbCore_FPCRdCrd(
    .clk         ( clk                  ),
    .rst_n       ( rst_n                ),
    .CoreOutVld  ( FPC_CrdRdAddrVld     ),
    .CoreOutAddr ( FPC_CrdRdAddr        ),
    .CoreOutDat  (                      ),
    .CoreOutRdy  ( FPC_CrdRdDatRdy      ),
    .TopOutVld   ( FPSGLB_CrdRdAddrVld  ),
    .TopOutAddr  ( FPSGLB_CrdRdAddr     ),
    .TopOutDat   (                      ),
    .TopOutRdy   ( FPSGLB_CrdRdDatRdy   ),
    .TOPInRdy    ( GLBFPS_CrdRdAddrRdy  ),
    .ArbCoreIdx  ( ArbFPCCrdRdIdx       ),
    .ArbCoreIdx_d( ArbFPCCrdRdIdx_d     )
);

// Arb DistRd
ArbCore#(
    .NUM_CORE    ( NUM_FPC      ),
    .ADDR_WIDTH  ( IDX_WIDTH    ),
    .DATA_WIDTH  ( SRAM_WIDTH   )
)u_ArbCore_FPCRdDist(
    .clk         ( clk                  ),
    .rst_n       ( rst_n                ),
    .CoreOutVld  ( FPC_DistRdAddrVld    ),
    .CoreOutAddr ( FPC_DistRdAddr       ),
    .CoreOutDat  (                      ),
    .CoreOutRdy  ( FPC_DistRdDatRdy     ),
    .TopOutVld   ( FPSGLB_DistRdAddrVld ),
    .TopOutAddr  ( FPSGLB_DistRdAddr    ),
    .TopOutDat   (                      ),
    .TopOutRdy   ( FPSGLB_DistRdDatRdy  ),
    .TOPInRdy    ( GLBFPS_DistRdAddrRdy  ),
    .ArbCoreIdx  ( ArbFPCDistRdIdx      ),
    .ArbCoreIdx_d( ArbFPCDistRdIdx_d    )
);


// Arb MaskWr
ArbCore#(
    .NUM_CORE    ( NUM_FPC      ),
    .ADDR_WIDTH  ( IDX_WIDTH    ),
    .DATA_WIDTH  ( SRAM_WIDTH   )
)u_ArbCore_FPCWrMask(
    .clk         ( clk                  ),
    .rst_n       ( rst_n                ),
    .CoreOutVld  ( FPC_MaskWrDatVld     ),
    .CoreOutAddr ( FPC_MaskWrAddr       ),
    .CoreOutDat  ( FPC_MaskWrDat        ),
    .CoreOutRdy  (                      ),
    .TopOutVld   ( FPSGLB_MaskWrDatVld  ),
    .TopOutAddr  ( FPSGLB_MaskWrAddr    ),
    .TopOutDat   ( FPSGLB_MaskWrDat     ),
    .TopOutRdy   (                      ),
    .TOPInRdy    ( GLBFPS_MaskWrDatRdy  ),
    .ArbCoreIdx  ( ArbFPCMaskWrIdx      ),
    .ArbCoreIdx_d(                      )
);

ArbCore#(
    .NUM_CORE    ( NUM_FPC      ),
    .ADDR_WIDTH  ( IDX_WIDTH    ),
    .DATA_WIDTH  ( SRAM_WIDTH   )
)u_ArbCore_FPCWrCrd(
    .clk         ( clk                  ),
    .rst_n       ( rst_n                ),
    .CoreOutVld  ( FPC_CrdWrDatVld      ),
    .CoreOutAddr ( FPC_CrdWrAddr        ),
    .CoreOutDat  ( FPC_CrdWrDat         ),
    .CoreOutRdy  (                      ),
    .TopOutVld   ( FPSGLB_CrdWrDatVld   ),
    .TopOutAddr  ( FPSGLB_CrdWrAddr     ),
    .TopOutDat   ( FPSGLB_CrdWrDat      ),
    .TopOutRdy   (                      ),
    .TOPInRdy    ( GLBFPS_CrdWrDatRdy   ),
    .ArbCoreIdx  ( ArbFPCCrdWrIdx       ),
    .ArbCoreIdx_d(                      )
);

ArbCore#(
    .NUM_CORE    ( NUM_FPC      ),
    .ADDR_WIDTH  ( IDX_WIDTH    ),
    .DATA_WIDTH  ( SRAM_WIDTH   )
)u_ArbCore_FPCWrDist(
    .clk         ( clk                  ),
    .rst_n       ( rst_n                ),
    .CoreOutVld  ( FPC_DistWrDatVld     ),
    .CoreOutAddr ( FPC_DistWrAddr       ),
    .CoreOutDat  ( FPC_DistWrDat        ),
    .CoreOutRdy  (                      ),
    .TopOutVld   ( FPSGLB_DistWrDatVld  ),
    .TopOutAddr  ( FPSGLB_DistWrAddr    ),
    .TopOutDat   ( FPSGLB_DistWrDat     ),
    .TopOutRdy   (                      ),
    .TOPInRdy    ( GLBFPS_DistWrDatRdy  ),
    .ArbCoreIdx  ( ArbFPCDistWrIdx      ),
    .ArbCoreIdx_d(                      )
);

ArbCore#(
    .NUM_CORE    ( NUM_FPC      ),
    .ADDR_WIDTH  ( IDX_WIDTH    ),
    .DATA_WIDTH  ( SRAM_WIDTH   )
)u_ArbCore_FPCWrIdx(
    .clk         ( clk                  ),
    .rst_n       ( rst_n                ),
    .CoreOutVld  ( FPC_IdxWrDatVld      ),
    .CoreOutAddr ( FPC_IdxWrAddr        ),
    .CoreOutDat  ( FPC_IdxWrDat         ),
    .CoreOutRdy  (                      ),
    .TopOutVld   ( FPSGLB_IdxWrDatVld   ),
    .TopOutAddr  ( FPSGLB_IdxWrAddr     ),
    .TopOutDat   ( FPSGLB_IdxWrDat      ),
    .TopOutRdy   (                      ),
    .TOPInRdy    ( GLBFPS_IdxWrDatRdy   ),
    .ArbCoreIdx  ( ArbFPCIdxWrIdx       ),
    .ArbCoreIdx_d(                      )
);

//=====================================================================================================================
// Logic Design
//=====================================================================================================================
genvar  gv_fpc;
generate
    for(gv_fpc = 0; gv_fpc < NUM_FPC; gv_fpc = gv_fpc + 1) begin: GEN_FPC
        //=====================================================================================================================
        // Constant Definition :
        //=====================================================================================================================


        //=====================================================================================================================
        // Variable Definition :
        //=====================================================================================================================
        reg [IDX_WIDTH          -1 : 0] FPS_MaxIdx;
        reg [IDX_WIDTH          -1 : 0] FPS_MaxIdx_LastCp;
        wire[IDX_WIDTH          -1 : 0] FPS_MaxIdx_;
        reg [CRD_WIDTH*CRD_DIM  -1 : 0] FPS_MaxCrd;
        wire[CRD_WIDTH*CRD_DIM  -1 : 0] FPS_MaxCrd_;
        reg [CRD_WIDTH*CRD_DIM  -1 : 0] FPS_CpCrd;
        wire[CRD_WIDTH*CRD_DIM  -1 : 0] FPS_CpCrd_next;
        wire                            FPS_UpdMax;
        reg [DISTSQR_WIDTH      -1 : 0] FPS_MaxDist;
        wire[DISTSQR_WIDTH      -1 : 0] FPS_MaxDist_;
        wire[DISTSQR_WIDTH      -1 : 0] FPS_PsDist;
        reg [DISTSQR_WIDTH      -1 : 0] FPS_PsDist_s2;
        wire[DISTSQR_WIDTH      -1 : 0] LopDist;
        reg                             LopCntLast_s1;
        reg                             LopCntLast_s2;
        reg                             LopCntLast_s3;
        wire                            CntLopMaskLast;
        wire                            CntLopCrdLast;
        wire                            CntLopDistLast;
        reg                             CntLopMaskLast_s1;
        wire[CRD_WIDTH*CRD_DIM  -1 : 0] LopPntCrd;
        wire [IDX_WIDTH         -1 : 0] LopLLA;
        wire                            rdy_Mask_s0;
        wire                            rdy_Mask_s1;
        wire                            rdy_Mask_s2;
        reg                             vld_Mask_s0;
        wire                            vld_Mask_s1;
        reg                             vld_Mask_s2;
        wire                            handshake_Mask_s0;
        wire                            handshake_Mask_s1;
        wire                            handshake_Mask_s2;
        wire                            ena_Mask_s0;
        wire                            ena_Mask_s1;
        wire                            ena_Mask_s2;

        wire                            rdy_Crd_s0;
        wire                            rdy_Crd_s1;
        wire                            rdy_Crd_s2;
        reg                             vld_Crd_s0;
        wire                            vld_Crd_s1;
        reg                             vld_Crd_s2;
        wire                            handshake_Crd_s0;
        wire                            handshake_Crd_s1;
        wire                            handshake_Crd_s2;
        wire                            handshake_Crd_s3;
        wire                            ena_Crd_s0;
        wire                            ena_Crd_s1;
        wire                            ena_Crd_s2;
        wire                            ena_Crd_s3;

        wire                            rdy_Dist_s0;
        wire                            rdy_Dist_s1;
        wire                            rdy_Dist_s2;
        reg                             vld_Dist_s0;
        wire                            vld_Dist_s1;
        reg                             vld_Dist_s2;
        wire                            handshake_Dist_s0;
        wire                            handshake_Dist_s1;
        wire                            handshake_Dist_s2;
        wire                            handshake_Dist_s3;
        wire                            ena_Dist_s0;
        wire                            ena_Dist_s1;
        wire                            ena_Dist_s2;
        wire                            ena_Dist_s3;

        wire                            rdy_Max_s2;
        wire                            rdy_Max_s3;
        reg                             vld_Max_s2;
        wire                            handshake_Max_s0;
        wire                            handshake_Max_s1;
        wire                            handshake_Max_s2;
        wire                            handshake_Max_s3;
        wire                            ena_Max_s0;
        wire                            ena_Max_s1;
        wire                            ena_Max_s2;
        wire                            ena_Max_s3;

        wire                            req_Mask_s1;
        wire                            req_Crd_s1;
        wire                            req_Dist_s1;

        wire [CNT_CUTMASK_WIDTH     -1 : 0] CntMaskRd;
        wire [IDX_WIDTH         -1 : 0] CntDistRdAddr;
        wire [IDX_WIDTH         -1 : 0] CntCrdRdAddr;
        wire [IDX_WIDTH         -1 : 0] CurIdx_s1;
        wire [IDX_WIDTH         -1 : 0] CurIdx_s1_next;
        wire                            VldArbMask_next;
        wire                            VldArbCrd_s1      ;
        wire                            VldArbDist_s1     ;
        wire                            VldArbDist_next;
        wire                            rdy_s2    ;
        reg                             MaskRdAddrVld_s1;
        reg                             DistRdDatVld_s1;

        wire                            overflow_CntMaskRd;
        wire                            overflow_CntCrdRdAddr;
        wire                            overflow_CntDistRdAddr;
        wire                            overflow_CntCpMask;
        reg                             overflow_CntCpMask_s1;
        reg                             overflow_CntCpMask_s2;
        wire                            overflow_CntCpCrd;
        reg                             overflow_CntCpCrd_s1;
        reg                             overflow_CntCpCrd_s2;
        reg                             overflow_CntCpCrd_s3;
        wire                            overflow_CntCpDistRdAddr;
        reg                             overflow_CntCpDistRdAddr_s1;
        reg                             overflow_CntCpDistRdAddr_s2;
        reg                             overflow_CntCpDistRdAddr_s3;

        wire [IDX_WIDTH         -1 : 0] CntCpMask;
        reg  [IDX_WIDTH         -1 : 0] CntCpMask_s1;
        reg  [IDX_WIDTH         -1 : 0] CntCpMask_s2;
        reg  [IDX_WIDTH         -1 : 0] CntCpMask_s3;
        wire [IDX_WIDTH         -1 : 0] CntCpCrd;
        reg  [IDX_WIDTH         -1 : 0] CntCpCrd_s1;
        reg  [IDX_WIDTH         -1 : 0] CntCpCrd_s2;
        wire [IDX_WIDTH         -1 : 0] CntCpDistRdAddr;
        reg  [IDX_WIDTH         -1 : 0] CntCpDistRdAddr_s1;
        reg  [IDX_WIDTH         -1 : 0] CntCpDistRdAddr_s2;

        wire [NUMMASK_PROC        -1 : 0] Mask_s1;
        reg  [NUMMASK_PROC        -1 : 0] Mask_s2;
        reg  [NUMMASK_PROC        -1 : 0] Mask_s2_next;
        reg  [NUMMASK_PROC        -1 : 0] ArbMask_s1;
        wire [$clog2(NUMMASK_PROC)-1 : 0] VldIdx;
        wire [$clog2(NUMMASK_PROC)-1 : 0] VldIdx_next;
        wire                              VldArbMask_s1;
        wire [SRAM_WIDTH        -1 : 0] FPC_MaskRdDat;
        reg [SRAM_WIDTH         -1 : 0] FPC_MaskRdDat_s2;
        wire [IDX_WIDTH         -1 : 0] MaxCntCpMask;

        reg                             overflow_CntDistRdAddr_s1;
        reg                             overflow_CntCrdRdAddr_s1;
        wire                            DistWrRdy;
        reg [SRAM_WIDTH         -1 : 0] FPC_DistWrDat_s2;

        reg                             ActCrd_s2;
        reg                             ActDist_s2;
        //=====================================================================================================================
        // Logic Design: Stage0
        //=====================================================================================================================
        // --------------------------------------------------------------------------------------------------------
        // Combinational Logic
        // --------------------------------------------------------------------------------------------------------
        always @(*) begin
            case ( state[gv_fpc] )
                IDLE :  if(FPSCCU_CfgRdy[gv_fpc] & CCUFPS_CfgVld[gv_fpc])
                            next_state[gv_fpc] <= WORK; //
                        else
                            next_state[gv_fpc] <= IDLE;
                WORK :  if(CCUFPS_CfgVld[gv_fpc]) // Force
                            next_state[gv_fpc] <= IDLE;
                        else if( CntCpMask_s2 == MaxCntCpMask & LopCntLast_s2 & !FPC_MaskWrDatVld[gv_fpc] & !FPC_DistWrDatVld[gv_fpc] & !FPC_CrdWrDatVld[gv_fpc] & !FPC_IdxWrDatVld[gv_fpc]) // Last Loop point & no to Write
                            next_state[gv_fpc] <= IDLE;
                        else
                            next_state[gv_fpc] <= WORK;
                default: next_state[gv_fpc] <= IDLE;
            endcase
        end
        always @ ( posedge clk or negedge rst_n ) begin
            if ( !rst_n ) begin
                state[gv_fpc] <= IDLE;
            end else begin
                state[gv_fpc] <= next_state[gv_fpc];
            end
        end

        assign FPSCCU_CfgRdy[gv_fpc] = state[gv_fpc]==IDLE;

        assign CntLopMaskLast = (CntMaskRd+1)*NUMMASK_PROC      >= CCUFPS_CfgNip[gv_fpc];
        assign CntLopCrdLast  = (CntCrdRdAddr+1)*NUM_CRD_SRAM   >= CCUFPS_CfgNip[gv_fpc];
        assign CntLopDistLast = (CntDistRdAddr+1)*NUM_DIST_SRAM >= CCUFPS_CfgNip[gv_fpc];

        // --------------------------------------------------------------------------------------------------------
        // HandShake
        // --------------------------------------------------------------------------------------------------------
        // 3 Seperate pipelines/HandShakes forMask, Crd, Dist;
        // Ahead 1 clk enables no idle clk: because 1 ahead clk makeups the 1 idle clk between AddrVld and VldArbMask_s1
        assign rdy_Mask_s0      = (CntCpMask == 0? 1'b1 : (state[gv_fpc] != IDLE & GLBFPS_MaskRdAddrRdy) & ArbFPCMaskRdIdx == gv_fpc); // Two loads: MaskAddr(Load0) for GLB and Need(Load1, ahead of ena_Mask_s1);
        assign handshake_Mask_s0= rdy_Mask_s0 & vld_Mask_s0;
        assign ena_Mask_s0      = handshake_Mask_s0 | ~vld_Mask_s0;
        assign vld_Mask_s0      = state[gv_fpc] == WORK & !(CntCpMask_s1 == MaxCntCpMask & CntLopMaskLast_s1)
                                    & req_Mask_s1;

        assign rdy_Crd_s0       = (state[gv_fpc] != IDLE & GLBFPS_CrdRdAddrRdy) & ArbFPCCrdRdIdx ==gv_fpc;
        assign handshake_Crd_s0 = rdy_Crd_s0 & vld_Crd_s0;
        assign ena_Crd_s0       = handshake_Crd_s0 | ~vld_Crd_s0;
        assign vld_Crd_s0       = ( state[gv_fpc] == WORK & !(overflow_CntCpCrd_s1 & overflow_CntCrdRdAddr_s1) )
                                    & req_Crd_s1;

        // assign req_Dist_s1      = !VldArbDist_next;  
        assign rdy_Dist_s0      = (CntCpDistRdAddr == 0? 1'b1 : (state[gv_fpc] != IDLE & GLBFPS_DistRdAddrRdy) & ArbFPCDistRdIdx==gv_fpc);
        assign handshake_Dist_s0= rdy_Dist_s0 & vld_Dist_s0;
        assign ena_Dist_s0      = handshake_Dist_s0 | ~vld_Dist_s0;
        assign vld_Dist_s0      = state[gv_fpc] == WORK & !(overflow_CntCpDistRdAddr_s1 & overflow_CntDistRdAddr_s1)
                                    & req_Dist_s1;

        // --------------------------------------------------------------------------------------------------------
        // Reg Update
        // --------------------------------------------------------------------------------------------------------
        // Mask Pipeline
        wire [CNT_CUTMASK_WIDTH     -1 : 0] MaxCntMaskRd = `CEIL(CCUFPS_CfgNip[gv_fpc], NUMMASK_PROC) - 1;
        counter#(
            .COUNT_WIDTH ( CNT_CUTMASK_WIDTH )
        )u1_counter_CntMaskRd(
            .CLK       ( clk                ),
            .RESET_N   ( rst_n              ),
            .CLEAR     ( state[gv_fpc] == IDLE ), // MaxCntMaskRd also Clears
            .DEFAULT   ( {CNT_CUTMASK_WIDTH{1'b0}}  ),
            .INC       ( handshake_Mask_s0  ),
            .DEC       ( 1'b0               ),
            .MIN_COUNT ( {CNT_CUTMASK_WIDTH{1'b0}}  ),
            .MAX_COUNT ( MaxCntMaskRd       ),
            .OVERFLOW  ( overflow_CntMaskRd ),
            .UNDERFLOW (                    ),
            .COUNT     ( CntMaskRd          )
        );
        assign MaxCntCpMask = CCUFPS_CfgNop[gv_fpc] - 1;
        counter#(
            .COUNT_WIDTH ( IDX_WIDTH )
        )u0_counter_CntCpMask(
            .CLK       ( clk                ),
            .RESET_N   ( rst_n              ),
            .CLEAR     ( state[gv_fpc] == IDLE ),
            .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
            .INC       ( overflow_CntMaskRd & handshake_Mask_s0),
            .DEC       ( 1'b0               ),
            .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
            .MAX_COUNT ( MaxCntCpMask       ),
            .OVERFLOW  ( overflow_CntCpMask ),
            .UNDERFLOW (                    ),
            .COUNT     ( CntCpMask          )
        );

        // Crd Pipeline
        wire [IDX_WIDTH     -1 : 0] MaxCntCrdRdAddr = `CEIL(CCUFPS_CfgNip[gv_fpc], NUM_CRD_SRAM) - 1;
        counter#( // Pipe S0
            .COUNT_WIDTH ( IDX_WIDTH )
        )u1_counter_CntCrdRdAddr(
            .CLK       ( clk                ),
            .RESET_N   ( rst_n              ),
            .CLEAR     ( state[gv_fpc] == IDLE ),
            .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
            .INC       ( handshake_Crd_s0   ),
            .DEC       ( 1'b0               ),
            .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
            .MAX_COUNT ( MaxCntCrdRdAddr    ),
            .OVERFLOW  ( overflow_CntCrdRdAddr),
            .UNDERFLOW (                    ),
            .COUNT     ( CntCrdRdAddr       )
        );
        wire [IDX_WIDTH     -1 : 0] MaxCntCpCrd = CCUFPS_CfgNop[gv_fpc] - 1;
        counter#(
            .COUNT_WIDTH ( IDX_WIDTH )
        )u0_counter_CntCpCrd(
            .CLK       ( clk                ),
            .RESET_N   ( rst_n              ),
            .CLEAR     ( state[gv_fpc] == IDLE ),
            .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
            .INC       ( overflow_CntCrdRdAddr & handshake_Crd_s0),
            .DEC       ( 1'b0               ),
            .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
            .MAX_COUNT ( MaxCntCpCrd        ),
            .OVERFLOW  ( overflow_CntCpCrd ),
            .UNDERFLOW (                    ),
            .COUNT     ( CntCpCrd     )
        );

        // Dist Pipeline
        wire [IDX_WIDTH     -1 : 0] MaxCntDistRdAddr = `CEIL(CCUFPS_CfgNip[gv_fpc], NUM_DIST_SRAM) - 1;
        counter#( // Pipe S0
            .COUNT_WIDTH ( IDX_WIDTH )
        )u1_counter_CntDistRdAddr(
            .CLK       ( clk                ),
            .RESET_N   ( rst_n              ),
            .CLEAR     ( state[gv_fpc] == IDLE ), 
            .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
            .INC       ( handshake_Dist_s0  ),
            .DEC       ( 1'b0               ),
            .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
            .MAX_COUNT ( MaxCntDistRdAddr   ),
            .OVERFLOW  ( overflow_CntDistRdAddr ),
            .UNDERFLOW (                    ),
            .COUNT     ( CntDistRdAddr      )
        );
        wire [IDX_WIDTH     -1 : 0] MaxCntCpDist = CCUFPS_CfgNop[gv_fpc] - 1;
        counter#(
            .COUNT_WIDTH ( IDX_WIDTH )
        )u0_counter_CntCpDist(
            .CLK       ( clk                ),
            .RESET_N   ( rst_n              ),
            .CLEAR     ( state[gv_fpc] == IDLE ),
            .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
            .INC       ( overflow_CntDistRdAddr & handshake_Dist_s0), // The least bitwidth determines
            .DEC       ( 1'b0               ),
            .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
            .MAX_COUNT ( MaxCntCpDist       ),
            .OVERFLOW  ( overflow_CntCpDistRdAddr ),
            .UNDERFLOW (                    ),
            .COUNT     ( CntCpDistRdAddr    )
        );

        //=====================================================================================================================
        // Logic Design: Stage1
        //=====================================================================================================================
        // --------------------------------------------------------------------------------------------------------
        // Combinational Logic
        // --------------------------------------------------------------------------------------------------------
        assign FPC_MaskRdAddrVld[gv_fpc] = state[gv_fpc] != IDLE & vld_Mask_s0 & CntCpMask != 0; // self is valid & load1 is rdy; To avoid occupying BUS invalidly
        assign FPC_CrdRdAddrVld [gv_fpc] = state[gv_fpc] != IDLE & vld_Crd_s0;
        assign FPC_DistRdAddrVld[gv_fpc] = state[gv_fpc] != IDLE & vld_Dist_s0 & CntCpDistRdAddr != 0;

        assign FPC_MaskRdAddr[gv_fpc] = state[gv_fpc] == IDLE? 0 :
        CCUFPS_CfgMaskBaseAddr[gv_fpc] + ((MaxCntMaskRd + 1)*(CntCpMask - 1) + CntMaskRd) / (SRAM_WIDTH / NUMMASK_PROC); // read is less a loop than write
        assign FPC_CrdRdAddr [gv_fpc] = state[gv_fpc] == IDLE? 0 :
        CCUFPS_CfgCrdBaseRdAddr[gv_fpc] + CntCrdRdAddr;
        assign FPC_DistRdAddr[gv_fpc] = state[gv_fpc] == IDLE? 0 :
        CCUFPS_CfgDistBaseAddr[gv_fpc] + (MaxCntDistRdAddr + 1)*(CntCpDistRdAddr - 1) + CntDistRdAddr;

        // --------------------------------------------------------------------------------------------------------
        // HandShake
        // 1. MaskRdDat drivers s2(load0) and FPC_MaskWr(load1);
        // 2. Load0: Mask_s2 MUST be invalid, then MaskRdDat can be transferred to Mask_s2
        wire MaskWrRdy;

        assign rdy_Mask_s1              = (!vld_Mask_s2 | !VldArbMask_s1) & ena_Mask_s2;
        assign handshake_Mask_s1        = rdy_Mask_s1 & vld_Mask_s1;
        assign ena_Mask_s1              = handshake_Mask_s1 | ~vld_Mask_s1;
        assign FPC_MaskRdDatRdy[gv_fpc] =  state[gv_fpc] != IDLE & rdy_Mask_s1; // 
        assign MaskRdDatVld_s1          = (state[gv_fpc] != IDLE & GLBFPS_MaskRdDatVld) & (ArbFPCMaskRdIdx_d == gv_fpc);

        assign rdy_Crd_s1               = ena_Crd_s2 & !vld_Crd_s2; // back pressure
        assign handshake_Crd_s1         = rdy_Crd_s1 & vld_Crd_s1;
        assign ena_Crd_s1               = handshake_Crd_s1 | ~vld_Crd_s1;
        assign FPC_CrdRdDatRdy[gv_fpc]  =  state[gv_fpc] != IDLE & rdy_Crd_s1; 
        assign CrdRdDatVld_s1           = (state[gv_fpc] != IDLE & GLBFPS_CrdRdDatVld) & (ArbFPCCrdRdIdx_d == gv_fpc);

        assign rdy_Dist_s1              = ena_Dist_s2 & !vld_Dist_s2; // 
        assign handshake_Dist_s1        = rdy_Dist_s1 & vld_Dist_s1;
        assign ena_Dist_s1              = handshake_Dist_s1 | ~vld_Dist_s1;
        assign FPC_DistRdDatRdy[gv_fpc] =  state[gv_fpc] != IDLE & rdy_Dist_s1; 
        assign DistRdDatVld_s1          = (state[gv_fpc] != IDLE & GLBFPS_DistRdDatVld) & (ArbFPCDistRdIdx_d == gv_fpc);

        // --------------------------------------------------------------------------------------------------------
        // Reg Update
        reg [IDX_WIDTH          -1 : 0] FPC_MaskRdAddr_s1;
        reg [CNT_CUTMASK_WIDTH  -1 : 0] CntMaskRd_s1;
        wire[CNT_CUTMASK_WIDTH  -1 : 0] ArbCntMaskRd_s1;
        reg [CNT_CUTMASK_WIDTH  -1 : 0] CntMaskRd_s2;
        reg [IDX_WIDTH          -1 : 0] CntCrdRdAddr_s1;
        reg [IDX_WIDTH          -1 : 0] CntCrdRdAddr_s2;
        reg [IDX_WIDTH          -1 : 0] CntDistRdAddr_s1;
        wire[IDX_WIDTH          -1 : 0] CntDistRdAddr_s1_arb;
        reg [IDX_WIDTH          -1 : 0] CntDistRdAddr_s2;
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                FPC_MaskRdAddr_s1       <= 0; 
                CntMaskRd_s1            <= 0;
                CntCpMask_s1            <= 0; 
                CntLopMaskLast_s1       <= 0;  
                overflow_CntCpMask_s1   <= 0;
            end else if(state[gv_fpc] == IDLE) begin    
                FPC_MaskRdAddr_s1       <= 0; 
                CntMaskRd_s1            <= 0;
                CntCpMask_s1            <= 0; 
                CntLopMaskLast_s1       <= 0;  
                overflow_CntCpMask_s1   <= 0;
            end else if (  ena_Mask_s1 ) begin 
                if ( handshake_Mask_s0 ) begin
                    FPC_MaskRdAddr_s1       <= FPC_MaskRdAddr[gv_fpc]; 
                    CntMaskRd_s1            <= CntMaskRd;
                    CntCpMask_s1            <= CntCpMask; 
                    CntLopMaskLast_s1       <= CntLopMaskLast;  
                    overflow_CntCpMask_s1   <= overflow_CntCpMask;
                end
            end
        end   
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                CntCrdRdAddr_s1             <= 0;
                CntCpCrd_s1           <= 0;
                overflow_CntCrdRdAddr_s1    <= 0;
                overflow_CntCpCrd_s1  <= 0;
            end else if(state[gv_fpc] == IDLE) begin 
                CntCrdRdAddr_s1             <= 0;
                CntCpCrd_s1           <= 0;
                overflow_CntCrdRdAddr_s1    <= 0;
                overflow_CntCpCrd_s1  <= 0;
            end else if ( ena_Crd_s1 ) begin
                if (handshake_Crd_s0) begin // Update
                    CntCrdRdAddr_s1             <= CntCrdRdAddr;
                    CntCpCrd_s1           <= CntCpCrd;
                    overflow_CntCrdRdAddr_s1    <= overflow_CntCrdRdAddr;
                    overflow_CntCpCrd_s1  <= overflow_CntCpCrd;
                end
            end
        end
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                CntDistRdAddr_s1            <= 0;
                CntCpDistRdAddr_s1          <= 0;
                overflow_CntDistRdAddr_s1   <= 0;
                overflow_CntCpDistRdAddr_s1 <= 0;
            end else if(state[gv_fpc] == IDLE) begin 
                CntDistRdAddr_s1            <= 0;
                CntCpDistRdAddr_s1          <= 0;
                overflow_CntDistRdAddr_s1   <= 0;
                overflow_CntCpDistRdAddr_s1 <= 0;
            end else if (  ena_Dist_s1 ) begin
                if (handshake_Dist_s0) begin
                    CntDistRdAddr_s1            <= CntDistRdAddr;
                    CntCpDistRdAddr_s1          <= CntCpDistRdAddr;
                    overflow_CntDistRdAddr_s1   <= overflow_CntDistRdAddr;
                    overflow_CntCpDistRdAddr_s1 <= overflow_CntCpDistRdAddr;
                end
            end
        end

        //=====================================================================================================================
        // Logic Design: Stage2
        //=====================================================================================================================
        // --------------------------------------------------------------------------------------------------------
        // Combinational Logic
        assign LopCntLast_s1 = CntLopMaskLast_s1; // & !VldArbMask_next; // Last mask & no valid bit in the next clk;

        // --------------------------------------------------------------------------------------------------------
        // Mask Pipeline
        assign FPC_MaskRdDat= CntCpMask_s1 == 0? {SRAM_WIDTH{1'b0}} : (state[gv_fpc] == IDLE? 0 : GLBFPS_MaskRdDat); // Default: begin with (0,0,0)
        assign Mask_s1      = FPC_MaskRdDat[NUMMASK_PROC*(CntMaskRd_s1 % (SRAM_WIDTH /NUMMASK_PROC)) +: NUMMASK_PROC];
        assign vld_Mask_s1  = MaskRdDatVld_s1 & !(&Mask_s1);
        assign vld_Mask_s2  = !(&Mask_s2);

        assign VldArbMask_s1= vld_Mask_s1 | vld_Mask_s2; // exist 0
        assign ArbMask_s1   =  vld_Mask_s2? Mask_s2 : Mask_s1;
        assign ArbCntMaskRd_s1= vld_Mask_s2? CntMaskRd_s2 : CntMaskRd_s1;
        assign CurIdx_s1    = VldArbMask_s1? (NUMMASK_PROC*ArbCntMaskRd_s1 + VldIdx) : NUMMASK_PROC*(ArbCntMaskRd_s1 + 1) - 1;
        // exist 0(valid? arbed Idx : last byte of current word
        prior_arb#(
            .REQ_WIDTH ( NUMMASK_PROC )
        )u_prior_arb_MaskCheck(
            .req ( ~ArbMask_s1     ),
            .gnt (              ),
            .arb_port ( VldIdx  )
        );
        assign req_Mask_s1  = !VldArbMask_s1;

        // --------------------------------------------------------------------------------------------------------
        // Crd Pipeline
        wire [SRAM_WIDTH            -1 : 0] ArbCrd_s1;
        reg  [SRAM_WIDTH            -1 : 0] Crd_s2;
        wire [SRAM_WIDTH            -1 : 0] ArbDist_s1;
        reg  [SRAM_WIDTH            -1 : 0] Dist_s2;
        reg  [SRAM_WIDTH            -1 : 0] Dist_s2_next;
        wire [DISTSQR_WIDTH         -1 : 0] FPS_LastPsDist;
        // Current
        assign vld_Crd_s1 = CrdRdDatVld_s1 & (CntCrdRdAddr_s1*NUM_CRD_SRAM <= CurIdx_s1 & CurIdx_s1 < (CntCrdRdAddr_s1 + 1)*NUM_CRD_SRAM);
        assign vld_Crd_s2 = ActCrd_s2 & CntCrdRdAddr_s2*NUM_CRD_SRAM <= CurIdx_s1 & CurIdx_s1 < (CntCrdRdAddr_s2 + 1)*NUM_CRD_SRAM;

        // CurIdx is in the Current Crd
        assign VldArbCrd_s1            = vld_Crd_s1 | vld_Crd_s2;
        assign ArbCrd_s1               = vld_Crd_s2? Crd_s2 : (state[gv_fpc] == IDLE? 0 : GLBFPS_CrdRdDat);
    
        assign req_Crd_s1 = !VldArbCrd_s1;

        // --------------------------------------------------------------------------------------------------------
        // Dist Pipeline
        // Current
        assign vld_Dist_s1  = DistRdDatVld_s1 & ( CntDistRdAddr_s1*NUM_DIST_SRAM <= CurIdx_s1 & CurIdx_s1 < (CntDistRdAddr_s1 + 1)*NUM_DIST_SRAM );
        assign vld_Dist_s2  = ActDist_s2 & (CntDistRdAddr_s2*NUM_DIST_SRAM <= CurIdx_s1 & CurIdx_s1 < (CntDistRdAddr_s2 + 1)*NUM_DIST_SRAM );
        assign VldArbDist_s1= vld_Dist_s1 | vld_Dist_s2;
        assign ArbDist_s1   = vld_Dist_s2? Dist_s2 : (CntCpDistRdAddr_s1 == 0? {SRAM_WIDTH{1'b1}}: (state[gv_fpc] == IDLE? 0 : GLBFPS_DistRdDat) ); 
        assign req_Dist_s1  = !VldArbDist_s1;

        // Ahead Update Dist_s2 (array) with FPS_PsDist
        always@(*) begin // set the arbed "0" to "1"
            Dist_s2_next = ArbDist_s1;
            if(rdy_Max_s2) // Max enable
                Dist_s2_next[DISTSQR_WIDTH*(CurIdx_s1 % NUM_DIST_SRAM) +: DISTSQR_WIDTH] = FPS_PsDist;
        end

        // --------------------------------------------------------------------------------------------------------
        // Max Pipeline  
        assign LopPntCrd = VldArbMask_s1? ArbCrd_s1[CRD_WIDTH*CRD_DIM*(VldIdx % NUM_CRD_SRAM) +: CRD_WIDTH*CRD_DIM]: 0;   

        EDC#(
            .CRD_WIDTH ( CRD_WIDTH  ),
            .CRD_DIM   ( CRD_DIM    )
        )u_EDC(
            .Crd0      ( FPS_CpCrd  ),
            .Crd1      ( LopPntCrd  ),
            .DistSqr   ( LopDist    )
        );
        assign FPS_LastPsDist = VldArbDist_s1? ArbDist_s1[DISTSQR_WIDTH*(CurIdx_s1 % NUM_DIST_SRAM) +: DISTSQR_WIDTH] : 0; // [0 +: DISTSQR_WIDTH]; //  : 0; // 
        assign FPS_PsDist = FPS_LastPsDist > LopDist ? LopDist : FPS_LastPsDist;
        assign FPS_UpdMax = FPS_MaxDist < FPS_PsDist;

        // --------------------------------------------------------------------------------------------------------
        // HandShake
        // --------------------------------------------------------------------------------------------------------
        // rdy_s2 Must be s1 (s1==s3), becuase s2's load0 is s1
        assign rdy_s2           = VldArbMask_s1 & VldArbCrd_s1 & (VldArbDist_s1 & DistWrRdy ) & MaskWrRdy; // Three loads: Mask, Crd, Dist;
        assign rdy_Max_s2       = (LopCntLast_s2? rdy_Max_s3 : 1'b1) & rdy_s2; // other loads are rdy
        assign handshake_Max_s2 = rdy_Max_s2 & vld_Max_s2;
        assign ena_Max_s2       = handshake_Max_s2 | ~vld_Max_s2;
        assign MaskWrRdy        = (FPC_MaskWrDatVld[gv_fpc]? (state[gv_fpc] != IDLE & GLBFPS_MaskWrDatRdy) & (ArbFPCMaskWrIdx == gv_fpc) : 1'b1);// but Combination Loop: GLBFPS_MaskWrDatRdy=1 -> FPC_MaskRdDatRdy=1 ->GLBFPS_MaskWrDatRdy=0

        assign rdy_Mask_s2      = (VldArbCrd_s1 & VldArbDist_s1 & DistWrRdy & MaskWrRdy) & (LopCntLast_s2? rdy_Max_s3 : 1'b1);
        assign handshake_Mask_s2= rdy_Mask_s2 & (vld_Mask_s2 & VldArbMask_s1);
        assign ena_Mask_s2      = handshake_Mask_s2 | ~(vld_Mask_s2 & VldArbMask_s1);

        assign rdy_Crd_s2       = (VldArbMask_s1 & VldArbDist_s1 & DistWrRdy & MaskWrRdy) & (LopCntLast_s2? rdy_Max_s3 : 1'b1);
        assign handshake_Crd_s2 = rdy_Crd_s2 & (vld_Crd_s2 & VldArbCrd_s1); // vld_Crd_s2 & real valid for CurIdx
        assign ena_Crd_s2       = handshake_Crd_s2 | ~vld_Crd_s2;

        assign rdy_Dist_s2      = (VldArbMask_s1 & VldArbCrd_s1 & DistWrRdy & MaskWrRdy) & (LopCntLast_s2? rdy_Max_s3 : 1'b1); // 3 loads: Mask, Crd, GLB
        assign handshake_Dist_s2= rdy_Dist_s2 & (vld_Dist_s2 & VldArbDist_s1);
        assign ena_Dist_s2      = handshake_Dist_s2 | ~(vld_Dist_s2 & VldArbDist_s1);

        // --------------------------------------------------------------------------------------------------------
        // Reg Updates
        // --------------------------------------------------------------------------------------------------------
        // --------------------------------------------------------------------------------------------------------
        // Update Crd s2
        reg vld_MaskRdDat_s2;
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                Mask_s2                 <= {NUMMASK_PROC{1'b1}}; // Not exist 0
                CntCpMask_s2            <= 0;
                overflow_CntCpMask_s2   <= 0;
                CntMaskRd_s2            <= 0;
                FPC_MaskRdDat_s2        <= 0;
                vld_MaskRdDat_s2        <= 0;
            end else if(state[gv_fpc] == IDLE) begin 
                Mask_s2                 <= {NUMMASK_PROC{1'b1}}; // Not exist 0
                CntCpMask_s2            <= 0;
                overflow_CntCpMask_s2   <= 0;
                CntMaskRd_s2            <= 0;
                FPC_MaskRdDat_s2        <= 0;
                vld_MaskRdDat_s2        <= 0;
            end else if (ena_Mask_s2) begin
                if ( VldArbMask_s1 )
                    Mask_s2                 <= ArbMask_s1 | ( (32'd1) << VldIdx ); // Set bit in Vldidx to 1
                if ( !vld_Mask_s2 ) begin // Update from s1 to s2
                    CntCpMask_s2            <= CntCpMask_s1;
                    overflow_CntCpMask_s2   <= overflow_CntCpMask_s1;
                    CntMaskRd_s2            <= ArbCntMaskRd_s1;
                    FPC_MaskRdDat_s2        <= FPC_MaskRdDat;
                    vld_MaskRdDat_s2        <= vld_Mask_s1;
                end
            end
        end

        // --------------------------------------------------------------------------------------------------------
        // Write back Mask 
        assign FPC_MaskWrAddr[gv_fpc] = state[gv_fpc] == IDLE? 0 : ( (MaxCntMaskRd + 1)*CntCpMask_s2 + CntMaskRd_s2 ) / (SRAM_WIDTH / NUMMASK_PROC);
        wire MtnPntExt = (SRAM_WIDTH*(CntMaskRd_s2 / (SRAM_WIDTH / NUMMASK_PROC) )) <= FPS_MaxIdx_LastCp 
                & FPS_MaxIdx_LastCp < (SRAM_WIDTH*(CntMaskRd_s2 / (SRAM_WIDTH / NUMMASK_PROC) + 1))
                & CntCpMask_s2 != 0;
                // Maintained point of LastCp is At current SRAM WORD (FPC_MaskRdDat)
        always @ (*) begin
            FPC_MaskWrDat[gv_fpc] = 0;
            if(state[gv_fpc] == IDLE)
                FPC_MaskWrDat[gv_fpc] = 0;
            else if ( FPC_MaskWrDatVld[gv_fpc] ) begin
                FPC_MaskWrDat[gv_fpc]   =  FPC_MaskRdDat_s2;
                if ( CntCpMask_s2 != 0 ) begin // Write 'd0 at First Cp 
                    FPC_MaskWrDat[gv_fpc][FPS_MaxIdx_LastCp % SRAM_WIDTH] = 1'b1; 
                    // set 1
                end
            end
        end
        assign FPC_MaskWrDatVld[gv_fpc] = state[gv_fpc] != IDLE & 
            (   (MtnPntExt & !FPC_MaskRdDat_s2[FPS_MaxIdx_LastCp % SRAM_WIDTH]) 
                | ((MaxCntMaskRd + 1)*CntCpMask_s2 + CntMaskRd_s2 ) % (SRAM_WIDTH / NUMMASK_PROC) == 0 
            ) & vld_MaskRdDat_s2 & (VldArbCrd_s1 & VldArbDist_s1 & DistWrRdy);
        // Need to Update (Write back): (The Maintained point is never been set 1 | Initialize when CntCpMask_s1 == 0) and first Mask of SRAM Word

        // --------------------------------------------------------------------------------------------------------
        // Update Crd s2
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                CntCpCrd_s2   <= 0;
                CntCrdRdAddr_s2     <= 0;
                Crd_s2              <= 0;
                ActCrd_s2           <= 0; // Whether be assigned
            end else if(state[gv_fpc] == IDLE) begin 
                CntCpCrd_s2   <= 0;
                CntCrdRdAddr_s2     <= 0;
                Crd_s2              <= 0;
                ActCrd_s2           <= 0;
            end else if (ena_Crd_s2) begin
                if( !vld_Crd_s2 ) begin // Update s1 to s2
                    CntCpCrd_s2   <= CntCpCrd_s1;
                    CntCrdRdAddr_s2     <= CntCrdRdAddr_s1;
                    Crd_s2              <= ArbCrd_s1;
                end
                if (CrdRdDatVld_s1) // trigger
                    ActCrd_s2 <= 1;
            end
        end

        // --------------------------------------------------------------------------------------------------------
        // Update Dist s2
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                CntCpDistRdAddr_s2  <= 0;
                CntDistRdAddr_s2    <= 0;
                FPC_DistWrDat_s2    <= 0;
                Dist_s2             <= 0;
                ActDist_s2          <= 0;
            end else if(state[gv_fpc] == IDLE) begin 
                CntCpDistRdAddr_s2  <= 0;
                CntDistRdAddr_s2    <= 0;
                FPC_DistWrDat_s2    <= 0;
                Dist_s2             <= 0;
                ActDist_s2          <= 0;
            end else if (ena_Dist_s2) begin
                if ( !vld_Dist_s2 ) begin // will be invalid & handshake_s2 (can be updated)
                    CntCpDistRdAddr_s2  <= CntCpDistRdAddr_s1;
                    CntDistRdAddr_s2    <= CntDistRdAddr_s1;
                    FPC_DistWrDat_s2    <= ArbDist_s1;
                    Dist_s2             <= ArbDist_s1;
                end
                if (DistRdDatVld_s1) // trigger
                    ActDist_s2 <= 1;
            end
        end

        // --------------------------------------------------------------------------------------------------------
        // Write Back Dist
        assign FPC_DistWrDatVld[gv_fpc] = !vld_Dist_s2 & (VldArbMask_s1 & VldArbCrd_s1);// & MaskWrRdy);// When VldArbDist_next=0(finishes Current Dist) & other three loads is ready to update
        assign DistWrRdy                = (FPC_DistWrDatVld[gv_fpc]? GLBFPS_DistWrDatRdy & (gv_fpc == ArbFPCDistWrIdx) : 1'b1);
        assign FPC_DistWrAddr[gv_fpc]   = CCUFPS_CfgDistBaseAddr + (MaxCntDistRdAddr + 1)*CntCpDistRdAddr_s2 + CntDistRdAddr_s2;
        assign FPC_DistWrDat[gv_fpc]    = FPC_DistWrDat_s2;

        // --------------------------------------------------------------------------------------------------------
        // Update Max, CpCrd
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                FPS_CpCrd           <= 0;
                FPS_MaxDist         <= 0;
                FPS_MaxCrd          <= 0; 
                FPS_MaxIdx_LastCp   <= 0;
                FPS_MaxIdx          <= 0;  
                FPS_PsDist_s2       <= 0; 
                LopCntLast_s2       <= 0; 
                vld_Max_s2          <= 0;
            end else if(state[gv_fpc] == IDLE) begin 
                FPS_CpCrd           <= 0;
                FPS_MaxDist         <= 0;
                FPS_MaxCrd          <= 0; 
                FPS_MaxIdx_LastCp   <= 0;
                FPS_MaxIdx          <= 0;  
                FPS_PsDist_s2       <= 0; 
                LopCntLast_s2       <= 0; 
                vld_Max_s2          <= 0;
            end else if (ena_Max_s2) begin
                if ( LopCntLast_s1 | CntCpMask_s1==0) begin
                    if ( FPS_UpdMax )
                        FPS_CpCrd <= LopPntCrd;
                    else 
                        FPS_CpCrd <= FPS_MaxCrd;
                end
                if ( LopCntLast_s1) begin
                    if( FPS_UpdMax)
                        FPS_MaxIdx_LastCp <= CurIdx_s1;
                    else
                        FPS_MaxIdx_LastCp <= FPS_MaxIdx;
                end
                if ( FPS_UpdMax ) begin
                    FPS_MaxDist         <= FPS_PsDist;
                    FPS_MaxCrd          <= LopPntCrd; 
                    FPS_MaxIdx          <= CurIdx_s1; 
                end 
                FPS_PsDist_s2       <= FPS_PsDist; 
                LopCntLast_s2       <= LopCntLast_s1;
                vld_Max_s2          <= rdy_Max_s2;
            end
        end

        //=====================================================================================================================
        // Logic Design: S3-OUT
        //=====================================================================================================================
        // --------------------------------------------------------------------------------------------------------
        // Combinational Logic

        // --------------------------------------------------------------------------------------------------------
        // HandShake
        wire                SIPO_CrdInRdy;
        wire                SIPO_IdxInRdy;
        assign rdy_Max_s3 = SIPO_CrdInRdy & SIPO_IdxInRdy;

        // --------------------------------------------------------------------------------------------------------
        // SIPO Crd
        wire [CRD_WIDTH*CRD_DIM*(SRAM_WIDTH/(CRD_WIDTH*CRD_DIM))  -1 : 0] SIPO_CrdOutDat;
        SIPO#(
            .DATA_IN_WIDTH   ( CRD_WIDTH*CRD_DIM ), 
            .DATA_OUT_WIDTH  ( CRD_WIDTH*CRD_DIM*(SRAM_WIDTH/(CRD_WIDTH*CRD_DIM))  )
        )u_SIPO_CrdWr(
            .CLK       ( clk                    ),
            .RST_N     ( rst_n                  ),
            .RESET     ( state[gv_fpc] == IDLE  ),
            .IN_VLD    ( (vld_Max_s2 & LopCntLast_s2) & rdy_s2 & SIPO_IdxInRdy), // valid & other is ready: Max drivers 3 loads: other(Mask, Crd, Dist), SIPO_Crd, and SIPO_Idx
            .IN_LAST   ( CntCpMask_s2 == MaxCntCpMask + 1),
            .IN_DAT    ( FPS_MaxCrd             ),
            .IN_RDY    ( SIPO_CrdInRdy          ),
            .OUT_DAT   ( SIPO_CrdOutDat         ),
            .OUT_VLD   ( FPC_CrdWrDatVld[gv_fpc]),
            .OUT_LAST  (                        ),
            .OUT_RDY   ( state[gv_fpc] != IDLE & GLBFPS_CrdWrDatRdy & (gv_fpc == ArbFPCCrdWrIdx) )
        );
        assign FPC_CrdWrDat[gv_fpc]  = state[gv_fpc] == IDLE? 0 : SIPO_CrdOutDat;
        assign FPC_CrdWrAddr[gv_fpc] = state[gv_fpc] == IDLE? 0 : &CCUFPS_CfgCrdBaseWrAddr[gv_fpc] + ( CntCpMask_s2 - (SRAM_WIDTH/(CRD_WIDTH*CRD_DIM)) ) / NUM_CRD_SRAM; // ???

        // --------------------------------------------------------------------------------------------------------
        // SIPO Idx
        SIPO#(
            .DATA_IN_WIDTH   ( IDX_WIDTH    ), 
            .DATA_OUT_WIDTH  ( SRAM_WIDTH   )
        )u_SIPO_IdxWr(
            .CLK       ( clk                        ),
            .RST_N     ( rst_n                      ),
            .RESET     ( state[gv_fpc] == IDLE      ),
            .IN_VLD    ( (vld_Max_s2 & LopCntLast_s2) & rdy_s2 & SIPO_CrdInRdy), // valid & other is ready: Max drivers 3 loads: other(Mask, Crd, Dist), SIPO_Crd, and SIPO_Idx
            .IN_LAST   ( CntCpMask_s2 == MaxCntCpMask + 1 ),
            .IN_DAT    ( FPS_MaxIdx                 ),
            .IN_RDY    ( SIPO_IdxInRdy              ),
            .OUT_DAT   ( FPC_IdxWrDat[gv_fpc]       ),
            .OUT_VLD   ( FPC_IdxWrDatVld[gv_fpc]    ),
            .OUT_LAST  (                            ),
            .OUT_RDY   ( state[gv_fpc] != IDLE & GLBFPS_IdxWrDatRdy & (gv_fpc == ArbFPCIdxWrIdx) )
        );
        assign FPC_IdxWrAddr[gv_fpc] = state[gv_fpc] == IDLE? 0 : CCUFPS_CfgIdxBaseWrAddr[gv_fpc] + ( CntCpMask_s2 - SRAM_WIDTH / IDX_WIDTH) / (SRAM_WIDTH/IDX_WIDTH);

    end 

endgenerate

//=====================================================================================================================
// Logic Design: Monitor
//=====================================================================================================================
assign FPSMON_Dat = {CCUFPS_CfgInfo, state};

endmodule
