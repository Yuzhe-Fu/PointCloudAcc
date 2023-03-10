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
module FPS #(
    parameter SRAM_WIDTH        = 256,
    parameter IDX_WIDTH         = 16,
    parameter CRD_WIDTH         = 8,
    parameter CRD_DIM           = 3,
    parameter NUM_FPC           = 8,
    parameter CUTMASK_WIDTH     = 32, // process bits at a time
    parameter DISTSQR_WIDTH     = CRD_WIDTH*2 + $clog2(CRD_DIM),
    parameter CRDIDX_WIDTH      = CRD_WIDTH*CRD_DIM+IDX_WIDTH
    )(
    input                                       clk                     ,
    input                                       rst_n                   ,

    // Configure
    input  [NUM_FPC                     -1 : 0] CCUFPS_Rst              ,
    input  [NUM_FPC                     -1 : 0] CCUFPS_CfgVld           ,
    output [NUM_FPC                     -1 : 0] FPSCCU_CfgRdy           ,
    input  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgNip           ,
    input  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgNop           ,
    input  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgCrdBaseRdAddr ,
    input  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgCrdBaseWrAddr ,
    input  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgIdxBaseWrAddr ,
    input  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgMaskBaseAddr  ,   
    input  [NUM_FPC -1 : 0][IDX_WIDTH   -1 : 0] CCUFPS_CfgDistBaseAddr  ,

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
    input                                       GLBFPS_IdxWrDatRdy      

);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam NUM_CRD_SRAM     = SRAM_WIDTH / (CRD_WIDTH*CRD_DIM);
localparam NUM_DIST_SRAM    = SRAM_WIDTH / DISTSQR_WIDTH;
localparam CNT_CUTMASK_WIDTH= IDX_WIDTH - $clog2(SRAM_WIDTH/CUTMASK_WIDTH);

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

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
        localparam IDLE   = 3'b000;
        localparam WORK   = 3'b001;

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
        wire[IDX_WIDTH          -1 : 0] FPS_PsIdx;
        reg [DISTSQR_WIDTH      -1 : 0] FPS_MaxDist;
        wire[DISTSQR_WIDTH      -1 : 0] FPS_MaxDist_;
        wire[DISTSQR_WIDTH      -1 : 0] FPS_PsDist;
        reg [DISTSQR_WIDTH      -1 : 0] FPS_PsDist_s2;
        reg [DISTSQR_WIDTH      -1 : 0] FPS_PsDist_s3;
        wire[DISTSQR_WIDTH      -1 : 0] LopDist;
        reg [DISTSQR_WIDTH      -1 : 0] FPS_LastPsDist_s2; 
        reg [IDX_WIDTH          -1 : 0] FPS_LastPsIdx_s2;
        reg                             LopCntLast_s1;
        reg                             LopCntLast_s2;
        reg                             LopCntLast_s3;
        wire                            LopCntLastMask;
        wire                            LopCntLastCrd;
        wire                            LopCntLastDist;
        reg                             LopCntLastMask_s1;
        reg [IDX_WIDTH          -1 : 0] LopPntIdx_s2;
        reg [IDX_WIDTH          -1 : 0] LopPntIdx_s1;
        reg [IDX_WIDTH          -1 : 0] LopPntIdx_s3;
        wire[IDX_WIDTH          -1 : 0] LopPntIdx;
        wire[CRD_WIDTH*CRD_DIM  -1 : 0] LopPntCrd;
        wire [IDX_WIDTH         -1 : 0] LopLLA;
        wire [IDX_WIDTH         -1 : 0] LopCnt;
        reg  [SRAM_WIDTH        -1 : 0] GLBFPS_MaskRdDat_s2;
        wire                            rdy_Mask_s0;
        wire                            rdy_Mask_s1;
        wire                            rdy_Mask_s2;
        wire                            rdy_Mask_s3;
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
        wire                            rdy_Dist_s3;
        reg                             vld_Dist_s0;
        wire                            vld_Dist_s1;
        reg                             vld_Dist_s2;
        reg                             vld_Dist_s3;
        wire                            handshake_Dist_s0;
        wire                            handshake_Dist_s1;
        wire                            handshake_Dist_s2;
        wire                            handshake_Dist_s3;
        wire                            ena_Dist_s0;
        wire                            ena_Dist_s1;
        wire                            ena_Dist_s2;
        wire                            ena_Dist_s3;

        wire                            rdy_Max_s0;
        wire                            rdy_Max_s1;
        wire                            rdy_Max_s2;
        wire                            rdy_Max_s3;
        reg                             vld_Max_s0;
        wire                            vld_Max_s1;
        reg                             vld_Max_s2;
        reg                             vld_Max_s3;
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
        wire                            VldArbCrd      ;
        wire                            VldArbCrd_next ;
        wire                            VldArbDist     ;
        wire                            VldArbDist_next;
        wire                            rdy_s2    ;
        reg                             MaskRdAddrVld_s1;
        reg                             DistRdAddrVld_s1;

        wire                            overflow_CntMaskRd;
        wire                            overflow_CntCrdRdAddr;
        wire                            overflow_CntDistRdAddr;
        wire                            overflow_CntCpMask;
        reg                             overflow_CntCpMask_s1;
        reg                             overflow_CntCpMask_s2;
        reg                             overflow_CntCpMask_s3;
        wire                            overflow_CntCpCrdRdAddr;
        reg                             overflow_CntCpCrdRdAddr_s1;
        reg                             overflow_CntCpCrdRdAddr_s2;
        reg                             overflow_CntCpCrdRdAddr_s3;
        wire                            overflow_CntCpDistRdAddr;
        reg                             overflow_CntCpDistRdAddr_s1;
        reg                             overflow_CntCpDistRdAddr_s2;
        reg                             overflow_CntCpDistRdAddr_s3;

        wire [IDX_WIDTH         -1 : 0] CntCpMask;
        reg  [IDX_WIDTH         -1 : 0] CntCpMask_s1;
        reg  [IDX_WIDTH         -1 : 0] CntCpMask_s2;
        reg  [IDX_WIDTH         -1 : 0] CntCpMask_s3;
        wire [IDX_WIDTH         -1 : 0] CntCpCrdRdAddr;
        reg  [IDX_WIDTH         -1 : 0] CntCpCrdRdAddr_s1;
        reg  [IDX_WIDTH         -1 : 0] CntCpCrdRdAddr_s2;
        wire [IDX_WIDTH         -1 : 0] CntCpDistRdAddr;
        reg  [IDX_WIDTH         -1 : 0] CntCpDistRdAddr_s1;
        reg  [IDX_WIDTH         -1 : 0] CntCpDistRdAddr_s2;
        //=====================================================================================================================
        // Logic Design: Stage0
        //=====================================================================================================================
        // Combinational Logic
            reg [ 3 -1:0 ]state;
            reg [ 3 -1:0 ]next_state;
            always @(*) begin
                case ( state )
                    IDLE :  if(FPSCCU_CfgRdy[gv_fpc] & CCUFPS_CfgVld[gv_fpc])
                                next_state <= WORK; //
                            else
                                next_state <= IDLE;
                    WORK :if(LopCntLast_s2 & !FPC_MaskWrDatVld[gv_fpc] & !FPC_DistWrDatVld[gv_fpc] & !FPC_CrdWrDatVld[gv_fpc] & !FPC_IdxWrDatVld[gv_fpc]) // Last Loop point & no to Write
                                next_state <= IDLE;
                            else
                                next_state <= WORK;
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

            assign FPSCCU_CfgRdy[gv_fpc] = state==IDLE;

            assign LopCntLastMask = (CntMaskRd+1)*CUTMASK_WIDTH >= CCUFPS_CfgNip[gv_fpc];
            assign LopCntLastCrd  = (CntCrdRdAddr+1)*NUM_CRD_SRAM >= CCUFPS_CfgNip[gv_fpc];
            assign LopCntLastDist = (CntDistRdAddr+1)*NUM_DIST_SRAM >= CCUFPS_CfgNip[gv_fpc];

        // HandShake

            // 3 Seperate pipelines/HandShakes forMask, Crd, Dist;

            // Ahead 1 clk enables no idle clk: because 1 ahead clk makeups the 1 idle clk between AddrVld and VldArbMask
            assign req_Mask_s1 = !VldArbMask_next;  //Load1's rdy
            assign rdy_Mask_s0 = (CntCpMask == 0? 1'b1 : GLBFPS_MaskRdAddrRdy & ArbFPCMaskRdIdx == gv_fpc) & req_Mask_s1; // Two loads: MaskAddr(Load0) for GLB and Need(Load1, ahead of ena_Mask_s1);
            assign handshake_Mask_s0 = rdy_Mask_s0 & vld_Mask_s0;
            assign ena_Mask_s0 = handshake_Mask_s0 | ~vld_Mask_s0;
            assign vld_Mask_s0 = state == WORK & !(overflow_CntCpMask & LopCntLastMask);

            assign req_Crd_s1 = !VldArbCrd_next;  
            assign rdy_Crd_s0 = GLBFPS_CrdRdAddrRdy & ArbFPCCrdRdIdx ==gv_fpc & req_Crd_s1;
            assign handshake_Crd_s0 = rdy_Crd_s0 & vld_Crd_s0;
            assign ena_Crd_s0 = handshake_Crd_s0 | ~vld_Crd_s0;
            assign vld_Crd_s0 = state == WORK & !(overflow_CntCpCrdRdAddr & LopCntLastCrd);

            assign req_Dist_s1 = !VldArbDist_next;  
            assign rdy_Dist_s0 = (CntCpDistRdAddr == 0? 1'b1 : GLBFPS_DistRdAddrRdy & ArbFPCDistRdIdx==gv_fpc) & req_Dist_s1;
            assign handshake_Dist_s0 = rdy_Dist_s0 & vld_Dist_s0;
            assign ena_Dist_s0 = handshake_Dist_s0 | ~vld_Dist_s0;
            assign vld_Dist_s0 = state == WORK & !(overflow_CntCpDistRdAddr & LopCntLastDist);

        // Reg Update

            // Mask Pipeline
            wire [CNT_CUTMASK_WIDTH     -1 : 0] MaxCntMaskRd = ( CCUFPS_CfgNip[gv_fpc] % CUTMASK_WIDTH?  CCUFPS_CfgNip[gv_fpc] / CUTMASK_WIDTH + 1 : CCUFPS_CfgNip[gv_fpc] / CUTMASK_WIDTH ) - 1;
            counter#(
                .COUNT_WIDTH ( CNT_CUTMASK_WIDTH )
            )u1_counter_CntMaskRd(
                .CLK       ( clk                ),
                .RESET_N   ( rst_n              ),
                .CLEAR     ( CCUFPS_Rst[gv_fpc] ), // MaxCntMaskRd also Clears
                .DEFAULT   ( {CNT_CUTMASK_WIDTH{1'b0}}  ),
                .INC       ( handshake_Mask_s0  ),
                .DEC       ( 1'b0               ),
                .MIN_COUNT ( {CNT_CUTMASK_WIDTH{1'b0}}  ),
                .MAX_COUNT ( MaxCntMaskRd   ),
                .OVERFLOW  ( overflow_CntMaskRd                   ),
                .UNDERFLOW (                    ),
                .COUNT     ( CntMaskRd      )
            );
            wire [IDX_WIDTH     -1 : 0] MaxCntCpMask = CCUFPS_CfgNop[gv_fpc] - 1;
            counter#(
                .COUNT_WIDTH ( IDX_WIDTH )
            )u0_counter_CntCpMask(
                .CLK       ( clk                ),
                .RESET_N   ( rst_n              ),
                .CLEAR     ( CCUFPS_Rst[gv_fpc] ),
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
            wire [IDX_WIDTH     -1 : 0] MaxCntCrdRdAddr = ( CCUFPS_CfgNip[gv_fpc] % NUM_CRD_SRAM?  CCUFPS_CfgNip[gv_fpc] / NUM_CRD_SRAM + 1 : CCUFPS_CfgNip[gv_fpc] / NUM_CRD_SRAM ) - 1;
            counter#( // Pipe S0
                .COUNT_WIDTH ( IDX_WIDTH )
            )u1_counter_CntCrdRdAddr(
                .CLK       ( clk                ),
                .RESET_N   ( rst_n              ),
                .CLEAR     ( CCUFPS_Rst[gv_fpc] ),
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
                .CLEAR     ( CCUFPS_Rst[gv_fpc] ),
                .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
                .INC       ( overflow_CntCrdRdAddr & handshake_Crd_s0),
                .DEC       ( 1'b0               ),
                .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
                .MAX_COUNT ( MaxCntCpCrd       ),
                .OVERFLOW  ( overflow_CntCpCrdRdAddr ),
                .UNDERFLOW (                    ),
                .COUNT     ( CntCpCrdRdAddr          )
            );

            // Dist Pipeline
            wire [IDX_WIDTH     -1 : 0] MaxCntDistRdAddr = ( CCUFPS_CfgNip[gv_fpc] % NUM_DIST_SRAM?  CCUFPS_CfgNip[gv_fpc] / NUM_DIST_SRAM + 1 : CCUFPS_CfgNip[gv_fpc] / NUM_DIST_SRAM ) - 1;
            counter#( // Pipe S0
                .COUNT_WIDTH ( IDX_WIDTH )
            )u1_counter_CntDistRdAddr(
                .CLK       ( clk                ),
                .RESET_N   ( rst_n              ),
                .CLEAR     ( CCUFPS_Rst[gv_fpc] ), 
                .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
                .INC       ( handshake_Dist_s0   ),
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
                .CLEAR     ( CCUFPS_Rst[gv_fpc] ),
                .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
                .INC       ( overflow_CntDistRdAddr & handshake_Dist_s0), // The least bitwidth determines
                .DEC       ( 1'b0               ),
                .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
                .MAX_COUNT ( MaxCntCpDist       ),
                .OVERFLOW  ( overflow_CntCpDistRdAddr ),
                .UNDERFLOW (                    ),
                .COUNT     ( CntCpDistRdAddr          )
            );

        //=====================================================================================================================
        // Logic Design: Stage1
        //=====================================================================================================================
        // Combinational Logic
            assign FPC_MaskRdAddrVld[gv_fpc] = (vld_Mask_s0 & req_Mask_s1 ) & CntCpMask != 0; // self is valid & load1 is rdy; To avoid occupying BUS invalidly
            assign FPC_CrdRdAddrVld[gv_fpc]  = vld_Crd_s0  & req_Crd_s1;
            assign FPC_DistRdAddrVld[gv_fpc] = (vld_Dist_s0 & req_Dist_s1 ) & CntCpDistRdAddr != 0;

            assign FPC_MaskRdAddr[gv_fpc] = CCUFPS_CfgMaskBaseAddr[gv_fpc] + ((MaxCntMaskRd + 1)*(CntCpMask - 1) + CntMaskRd) / (SRAM_WIDTH / CUTMASK_WIDTH); // read is less a loop than write
            assign FPC_CrdRdAddr[gv_fpc] = CCUFPS_CfgCrdBaseRdAddr[gv_fpc] +CntCrdRdAddr;
            assign FPC_DistRdAddr[gv_fpc] = CCUFPS_CfgDistBaseAddr[gv_fpc] + (MaxCntDistRdAddr + 1)*(CntCpDistRdAddr - 1) + CntDistRdAddr;

        // HandShake

            // 1. MaskRdDat drivers s2(load0) and FPC_MaskWr(load1);
            // 2. Load0: MaskCheck_s2 MUST be invalid, then MaskRdDat can be transferred to MaskCheck_s2
            assign rdy_Mask_s1 = (ena_Mask_s2) & (LopCntLast_s1? GLBFPS_MaskWrDatRdy & ArbFPCMaskWrIdx==gv_fpc : 1'b1);
            assign handshake_Mask_s1 = rdy_Mask_s1 & vld_Mask_s1;
            assign ena_Mask_s1 = handshake_Mask_s1 | ~vld_Mask_s1;
            assign FPC_MaskRdDatRdy[gv_fpc] = rdy_Mask_s1;
            assign vld_Mask_s1 = CntCpMask_s1 == 0? MaskRdAddrVld_s1 : GLBFPS_MaskRdDatVld & (ArbFPCMaskRdIdx_d == gv_fpc);

            assign rdy_Crd_s1 = !(vld_Crd_s2 & VldArbCrd) & ena_Crd_s2; // back pressure
            assign handshake_Crd_s1 = rdy_Crd_s1 & vld_Crd_s1;
            assign ena_Crd_s1 = handshake_Crd_s1 | ~vld_Crd_s1;
            assign FPC_CrdRdDatRdy[gv_fpc] = rdy_Crd_s1; 
            assign vld_Crd_s1 = GLBFPS_CrdRdDatVld & (ArbFPCCrdRdIdx_d == gv_fpc);

            assign rdy_Dist_s1 = !(vld_Dist_s2 & VldArbDist) & ena_Dist_s2; // 
            assign handshake_Dist_s1 = rdy_Dist_s1 & vld_Dist_s1;
            assign ena_Dist_s1 = handshake_Dist_s1 | ~vld_Dist_s1;
            assign FPC_DistRdDatRdy[gv_fpc] = rdy_Dist_s1; 
            assign vld_Dist_s1 = CntCpDistRdAddr_s1 == 0? DistRdAddrVld_s1 : GLBFPS_DistRdDatVld & (ArbFPCDistRdIdx_d == gv_fpc);

        // Reg Update
            reg [IDX_WIDTH      -1 : 0] FPC_MaskRdAddr_s1;
            reg [CNT_CUTMASK_WIDTH  -1 : 0] CntMaskRd_s1;
            reg [IDX_WIDTH      -1 : 0] CntCrdRdAddr_s1;
            wire [IDX_WIDTH      -1 : 0] CntCrdRdAddr_s1_arb;
            reg [IDX_WIDTH      -1 : 0] CntCrdRdAddr_s2;
            reg [IDX_WIDTH      -1 : 0] CntDistRdAddr_s1;
            wire [IDX_WIDTH      -1 : 0] CntDistRdAddr_s1_arb;
            reg [IDX_WIDTH      -1 : 0] CntDistRdAddr_s2;
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {FPC_MaskRdAddr_s1, CntMaskRd_s1, CntCpMask_s1, LopCntLastMask_s1, MaskRdAddrVld_s1, overflow_CntCpMask_s1} <= 0;
                end else if (  ena_Mask_s1 ) begin 
                    {FPC_MaskRdAddr_s1, CntMaskRd_s1, CntCpMask_s1, LopCntLastMask_s1, MaskRdAddrVld_s1, overflow_CntCpMask_s1} <= handshake_Mask_s0? {FPC_MaskRdAddr[gv_fpc], CntMaskRd, CntCpMask, LopCntLastMask, vld_Mask_s0, overflow_CntCpMask} : {FPC_MaskRdAddr_s1, CntMaskRd_s1, CntCpMask_s1, 1'b0, 1'b0, overflow_CntCpMask_s1}; // s0 drives two load; only when handshake_s0 -> s1 update
                end
            end   
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {CntCrdRdAddr_s1, CntCpCrdRdAddr_s1, overflow_CntCpCrdRdAddr_s1} <= 0;
                end else if (  ena_Crd_s1 ) begin
                    {CntCrdRdAddr_s1, CntCpCrdRdAddr_s1, overflow_CntCpCrdRdAddr_s1} <= handshake_Crd_s0? {CntCrdRdAddr, CntCpCrdRdAddr, overflow_CntCpCrdRdAddr} : {CntCrdRdAddr_s1, CntCpCrdRdAddr_s1, overflow_CntCpCrdRdAddr_s1};
                end
            end
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {CntDistRdAddr_s1, CntCpDistRdAddr_s1, DistRdAddrVld_s1, overflow_CntCpDistRdAddr_s1} <= 0;
                end else if (  ena_Dist_s1 ) begin
                    {CntDistRdAddr_s1, CntCpDistRdAddr_s1, DistRdAddrVld_s1, overflow_CntCpDistRdAddr_s1} <= handshake_Dist_s0? {CntDistRdAddr, CntCpDistRdAddr, vld_Dist_s0, overflow_CntCpDistRdAddr} : {CntDistRdAddr_s1, CntCpDistRdAddr_s1, 1'b0, overflow_CntCpDistRdAddr_s1};
                end
            end

        //=====================================================================================================================
        // Logic Design: Stage2
        //======================================================MaskCheck_s2_next===============================================================
        // Combinational Logic
            assign LopCntLast_s1 = LopCntLastMask_s1 & !VldArbMask_next; // Last mask & no valid bit in the next clk;

            // Mask Pipeline
                wire [CUTMASK_WIDTH        -1 : 0] Mask_s1;
                reg  [CUTMASK_WIDTH        -1 : 0] MaskCheck_s2;
                reg  [CUTMASK_WIDTH        -1 : 0] MaskCheck_s2_next;
                wire [$clog2(CUTMASK_WIDTH)-1 : 0] VldIdx;
                wire [$clog2(CUTMASK_WIDTH)-1 : 0] VldIdx_next;
                wire                               VldArbMask;
                wire [SRAM_WIDTH            -1 : 0] FPC_MaskRdDat;
                // Current
                    assign FPC_MaskRdDat = CntCpMask_s1 == 0? {SRAM_WIDTH{1'b0}} : GLBFPS_MaskRdDat; // Default: begin with (0,0,0)
                    assign Mask_s1 =  vld_Mask_s1? FPC_MaskRdDat[CUTMASK_WIDTH*(CntMaskRd_s1 % (SRAM_WIDTH /CUTMASK_WIDTH)) +: CUTMASK_WIDTH] : MaskCheck_s2;
                    prior_arb#(
                        .REQ_WIDTH ( CUTMASK_WIDTH )
                    )u_prior_arb_MaskCheck(
                        .req ( ~Mask_s1     ),
                        .gnt (              ),
                        .arb_port ( VldIdx  )
                    );
                    assign VldArbMask = !(&Mask_s1); // exist 0
                    assign CurIdx_s1 = VldArbMask? (CUTMASK_WIDTH*CntMaskRd_s1 + VldIdx) : CUTMASK_WIDTH*(CntMaskRd_s1+1)-1;// exist 0(valid? arbed Idx : last byte of current word
                // Next (for ahead MaskAddrVld=1)
                    always@(*) begin // set the arbed "0" to "1"
                        MaskCheck_s2_next = Mask_s1;
                        if (VldArbMask)
                            MaskCheck_s2_next[VldIdx] = 1'b1;
                    end
                    prior_arb#(
                        .REQ_WIDTH ( CUTMASK_WIDTH )
                    )u_prior_arb_MaskCheck_next(
                        .req ( ~MaskCheck_s2_next   ),
                        .gnt (                      ),
                        .arb_port  ( VldIdx_next    )
                    ); 
                    assign VldArbMask_next = !(&MaskCheck_s2_next); // exist 0
                    assign CurIdx_s1_next = VldArbMask_next? (CUTMASK_WIDTH*CntMaskRd_s1 + VldIdx_next) : CUTMASK_WIDTH*(CntMaskRd_s1+1)-1;

                // Mask write back
                    assign FPC_MaskWrAddr[gv_fpc] = ( (MaxCntMaskRd + 1)*CntCpMask_s1 + CntMaskRd_s1 ) / (SRAM_WIDTH / CUTMASK_WIDTH);
                    wire MtnPntExt = (SRAM_WIDTH*(CntMaskRd_s1 / (SRAM_WIDTH / CUTMASK_WIDTH) )) <= FPS_MaxIdx_LastCp 
                            & FPS_MaxIdx_LastCp < (SRAM_WIDTH*(CntMaskRd_s1 / (SRAM_WIDTH / CUTMASK_WIDTH) + 1))
                            & CntCpMask_s1 != 0;
                            // Maintained point of LastCp is At current SRAM WORD (FPC_MaskRdDat)
                    always @ (*) begin
                        FPC_MaskWrDat[gv_fpc] = 0;
                        if ( FPC_MaskWrDatVld[gv_fpc] ) begin
                            FPC_MaskWrDat[gv_fpc]   =  FPC_MaskRdDat;
                            if ( CntCpMask_s1 != 0 ) begin // Write 'd0 at First Cp 
                                FPC_MaskWrDat[gv_fpc][FPS_MaxIdx_LastCp % SRAM_WIDTH] = 1'b1; 
                                // set 1
                            end
                        end
                    end
                    assign FPC_MaskWrDatVld[gv_fpc] = ( ( MtnPntExt & !FPC_MaskRdDat[FPS_MaxIdx_LastCp % SRAM_WIDTH] & vld_Mask_s1 ) 
                    | (CntCpMask_s1 == 0) ) & ((MaxCntMaskRd + 1)*CntCpMask_s1 + CntMaskRd_s1 ) % (SRAM_WIDTH / CUTMASK_WIDTH) == 0 ; 
                    // Need to Update (Write back): (The Maintained point is never been set 1 | Initialize when CntCpMask_s1 == 0) and first Mask of SRAM Word

            // Crd Pipeline
                wire [SRAM_WIDTH            -1 : 0] Crd_s1;
                reg  [SRAM_WIDTH            -1 : 0] Crd_s2;
                wire [SRAM_WIDTH            -1 : 0] Dist_s1;
                reg  [SRAM_WIDTH            -1 : 0] Dist_s2;
                reg  [SRAM_WIDTH            -1 : 0] Dist_s2_next;
                wire [DISTSQR_WIDTH         -1 : 0] FPS_LastPsDist;
                // Current
                    assign Crd_s1 = vld_Crd_s2? Crd_s2 : GLBFPS_CrdRdDat;
                    assign CntCrdRdAddr_s1_arb = vld_Crd_s2? CntCrdRdAddr_s2 : CntCrdRdAddr_s1;

                    // CurIdx is in the Current Crd
                    assign VldArbCrd = (vld_Crd_s1 | vld_Crd_s2) & ( CntCrdRdAddr_s1_arb*NUM_CRD_SRAM <= CurIdx_s1 & CurIdx_s1 < (CntCrdRdAddr_s1_arb + 1)*NUM_CRD_SRAM );
                
                // Next
                    assign VldArbCrd_next   = (vld_Crd_s1 | vld_Crd_s2) & ( CntCrdRdAddr_s1_arb*NUM_CRD_SRAM <= CurIdx_s1_next & CurIdx_s1_next < (CntCrdRdAddr_s1_arb + 1)*NUM_CRD_SRAM );
                    assign FPS_CpCrd_next = (LopCntLast_s1 | CntCpMask_s1==0)? FPS_MaxCrd_ : FPS_CpCrd;

            // Dist Pipeline
                // Current
                    assign Dist_s1 = vld_Dist_s2? Dist_s2 : (CntCpDistRdAddr_s1 == 0? {SRAM_WIDTH{1'b1}}: GLBFPS_DistRdDat) ; // Dist_s2 is prior; When CntCp_s1 ==0, Dist is 
                    assign CntDistRdAddr_s1_arb = vld_Dist_s2? CntDistRdAddr_s2 : CntDistRdAddr_s1;

                    assign VldArbDist       =  (vld_Dist_s1 | vld_Dist_s2) & ( CntDistRdAddr_s1_arb*NUM_DIST_SRAM <= CurIdx_s1 & CurIdx_s1 < (CntDistRdAddr_s1_arb + 1)*NUM_DIST_SRAM );

                // Next
                    assign VldArbDist_next  = (vld_Dist_s1 | vld_Dist_s2) & ( CntDistRdAddr_s1_arb*NUM_DIST_SRAM <= CurIdx_s1_next & CurIdx_s1_next < (CntDistRdAddr_s1_arb + 1)*NUM_DIST_SRAM );
                    // Ahead Update Dist_s2 (array) with FPS_PsDist
                    always@(*) begin // set the arbed "0" to "1"
                        Dist_s2_next = Dist_s1;
                        if(rdy_s2) // Max enable
                            Dist_s2_next[DISTSQR_WIDTH*(CurIdx_s1 % NUM_DIST_SRAM) +: DISTSQR_WIDTH] = FPS_PsDist;
                    end
                // Write Back
                    assign FPC_DistWrDatVld[gv_fpc] = (vld_Dist_s1 | vld_Dist_s2) & !VldArbDist_next & (VldArbMask & VldArbCrd & VldArbDist);// When VldArbDist_next=0(finishes Current Dist) & other three loads is ready to update
                    wire DistWrRdy = (FPC_DistWrDatVld[gv_fpc]? GLBFPS_DistWrDatRdy & (gv_fpc == ArbFPCDistWrIdx) : 1'b1);
                    assign FPC_DistWrAddr[gv_fpc] = CCUFPS_CfgDistBaseAddr + (MaxCntDistRdAddr + 1)*CntCpDistRdAddr_s1 + CntDistRdAddr_s1_arb;
                    assign FPC_DistWrDat[gv_fpc] = Dist_s2_next;

            // Max Pipeline  
                assign LopPntCrd = VldArbMask? Crd_s1[CRD_WIDTH*CRD_DIM*(VldIdx % NUM_CRD_SRAM) +: CRD_WIDTH*CRD_DIM]: 0;   

                EDC#(
                    .CRD_WIDTH ( CRD_WIDTH  ),
                    .CRD_DIM   ( CRD_DIM    )
                )u_EDC(
                    .Crd0      ( FPS_CpCrd  ),
                    .Crd1      ( LopPntCrd  ),
                    .DistSqr   ( LopDist    )
                );
                assign FPS_LastPsDist = VldArbDist? Dist_s1[DISTSQR_WIDTH*(CurIdx_s1 % NUM_DIST_SRAM) +: DISTSQR_WIDTH] : 0; // [0 +: DISTSQR_WIDTH]; //  : 0; // 
                assign FPS_PsDist = FPS_LastPsDist > LopDist ? LopDist : FPS_LastPsDist;
                assign FPS_UpdMax = FPS_MaxDist < FPS_PsDist;

                // Max Update
                assign {FPS_MaxDist_, FPS_MaxCrd_, FPS_MaxIdx_} = FPS_UpdMax & rdy_s2 ? {FPS_PsDist, LopPntCrd, CurIdx_s1} : {FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx};

        // HandShake

            // rdy_s2 Must be s1 (s1==s3), becuase s2's load0 is s1
            assign rdy_s2      = VldArbMask & VldArbCrd & (VldArbDist & DistWrRdy ); // Three loads: Mask, Crd, Dist;

            assign rdy_Max_s2 = (LopCntLast_s2? rdy_Max_s3 : 1'b1) & rdy_s2; // other loads are rdy
            assign handshake_Max_s2 = rdy_Max_s2 & vld_Max_s2;
            assign ena_Max_s2 = handshake_Max_s2 | ~vld_Max_s2;

            assign rdy_Mask_s2 = VldArbCrd & VldArbDist & DistWrRdy;
            assign handshake_Mask_s2 = rdy_Mask_s2 & vld_Mask_s2;
            assign ena_Mask_s2 = handshake_Mask_s2 | ~vld_Mask_s2;
            assign vld_Mask_s2 = !(&MaskCheck_s2); // In s2, whether MashCheck_s2 is valid

            assign rdy_Crd_s2 = VldArbMask & VldArbDist & DistWrRdy;
            assign handshake_Crd_s2 = rdy_Crd_s2 & (vld_Crd_s2 & VldArbCrd); // vld_Crd_s2 & real valid for CurIdx
            assign ena_Crd_s2 = handshake_Crd_s2 | ~(vld_Crd_s2 & VldArbCrd);

            assign rdy_Dist_s2 = VldArbMask & VldArbCrd & DistWrRdy; // 3 loads: Mask, Crd, GLB
            assign handshake_Dist_s2 = rdy_Dist_s2 & (vld_Dist_s2 & VldArbDist);
            assign ena_Dist_s2 = handshake_Dist_s2 | ~(vld_Dist_s2 & VldArbDist);

        // Reg Updates
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    MaskCheck_s2 <= {CUTMASK_WIDTH{1'b1}}; // Not exist 0
                    CntCpMask_s2 <= 0;
                    overflow_CntCpMask_s2 <= 0;
                end else if (ena_Mask_s2) begin
                    MaskCheck_s2 <= MaskCheck_s2_next;
                    CntCpMask_s2 <= CntCpMask_s1;
                    overflow_CntCpMask_s2 <= overflow_CntCpMask_s1;
                end
            end

            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {CntCrdRdAddr_s2, Crd_s2, CntCpCrdRdAddr_s2, vld_Crd_s2} <= 0;
                end else if (ena_Crd_s2) begin
                    {CntCrdRdAddr_s2, Crd_s2, CntCpCrdRdAddr_s2, vld_Crd_s2} <= { CntCrdRdAddr_s1_arb, Crd_s1, CntCpCrdRdAddr_s1, VldArbCrd_next };
                end
            end
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {CntDistRdAddr_s2, Dist_s2, CntCpDistRdAddr_s2, vld_Dist_s2} <= 0;
                end else if (ena_Dist_s2) begin
                    {CntDistRdAddr_s2, Dist_s2, CntCpDistRdAddr_s2, vld_Dist_s2} <= {CntDistRdAddr_s1_arb, Dist_s2_next, CntCpDistRdAddr_s1, VldArbDist_next };
                end
            end

            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {FPS_CpCrd, FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx_LastCp, FPS_MaxIdx, FPS_PsDist_s2, LopCntLast_s2, vld_Max_s2} <= 0;
                end else if (ena_Max_s2) begin
                    {FPS_CpCrd, FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx_LastCp, FPS_MaxIdx, FPS_PsDist_s2, LopCntLast_s2, vld_Max_s2} <= 
                    {FPS_CpCrd_next, FPS_MaxCrd_, LopCntLast_s1? FPS_MaxIdx_ : FPS_MaxIdx_LastCp, FPS_MaxIdx_, FPS_PsDist, LopCntLast_s1, rdy_s2};
                end
            end

        //=====================================================================================================================
        // Logic Design: S3
        //=====================================================================================================================
        // Combinational Logic

        // HandShake
            wire                SIPO_DistInRdy;
            wire                SIPO_CrdInRdy;
            wire                SIPO_IdxInRdy;

            assign rdy_Max_s3 = SIPO_CrdInRdy & SIPO_IdxInRdy;

            // SIPO Crd
            wire [CRD_WIDTH*CRD_DIM*(SRAM_WIDTH/(CRD_WIDTH*CRD_DIM))  -1 : 0] SIPO_CrdOutDat;
            SIPO#(
                .DATA_IN_WIDTH   ( CRD_WIDTH*CRD_DIM  ), 
                .DATA_OUT_WIDTH  ( CRD_WIDTH*CRD_DIM*(SRAM_WIDTH/(CRD_WIDTH*CRD_DIM))  )
            )u_SIPO_CrdWr(
                .CLK       ( clk                    ),
                .RST_N     ( rst_n                  ),
                .IN_VLD    ( vld_Max_s2 & LopCntLast_s2 ),
                .IN_LAST   ( LopCntLast_s2          ),
                .IN_DAT    ( FPS_MaxCrd             ),
                .IN_RDY    ( SIPO_CrdInRdy          ),
                .OUT_DAT   ( SIPO_CrdOutDat         ),
                .OUT_VLD   ( FPC_CrdWrDatVld[gv_fpc]),
                .OUT_LAST  (                        ),
                .OUT_RDY   ( GLBFPS_CrdWrDatRdy & (gv_fpc == ArbFPCCrdWrIdx) )
            );
            assign FPC_CrdWrDat[gv_fpc] = SIPO_CrdOutDat;
            assign FPC_CrdWrAddr[gv_fpc] = CCUFPS_CfgCrdBaseWrAddr[gv_fpc] + ( CntCpMask_s2 - (SRAM_WIDTH/(CRD_WIDTH*CRD_DIM)) ) / NUM_CRD_SRAM;

            // SIPO Idx
            SIPO#(
                .DATA_IN_WIDTH   ( IDX_WIDTH    ), 
                .DATA_OUT_WIDTH  ( SRAM_WIDTH   )
            )u_SIPO_IdxWr(
                .CLK       ( clk                        ),
                .RST_N     ( rst_n                      ),
                .IN_VLD    ( vld_Max_s2 & LopCntLast_s2 ),
                .IN_LAST   ( LopCntLast_s2              ),
                .IN_DAT    ( FPS_MaxIdx                 ),
                .IN_RDY    ( SIPO_IdxInRdy              ),
                .OUT_DAT   ( FPC_IdxWrDat[gv_fpc]       ),
                .OUT_VLD   ( FPC_IdxWrDatVld[gv_fpc]    ),
                .OUT_LAST  (                            ),
                .OUT_RDY   ( GLBFPS_IdxWrDatRdy & (gv_fpc == ArbFPCIdxWrIdx) )
            );
            assign FPC_IdxWrAddr[gv_fpc] = CCUFPS_CfgIdxBaseWrAddr[gv_fpc] + ( CntCpMask_s2 - SRAM_WIDTH / IDX_WIDTH) / (SRAM_WIDTH/IDX_WIDTH);

    end 

endgenerate

//=====================================================================================================================
// Assertion
//=====================================================================================================================
// `ifdef ASSERTION_ON
//     parameter delay = 200;
//     property p_high(a, b);
//         disable iff (!rst_n)
//         @(posedge clk) 
//             a |-> ##delay b;
//     endproperty


//     a_GLBFPS_MaskRdAddrRdy: assert property (p_high(FPC_MaskRdAddrVld[ArbFPCMaskRdIdx] & FPC_MaskRdDatRdy[ArbFPCMaskRdIdx], GLBFPS_MaskRdAddrRdy))
//     else 
//         $display("GLBFPS_MaskRdAddrRdy fails to pull up at %t, #FPC = %d\n", $time, ArbFPCMaskRdIdx);

//     a_GLBFPS_DistRdAddrRdy: assert property (p_high(FPC_DistRdAddrVld[ArbFPCDistRdIdx] & FPC_DistRdDatRdy[ArbFPCDistRdIdx], GLBFPS_DistRdAddrRdy))
//     else 
//         $display("GLBFPS_DistRdAddrRdy fails to pull up at %t, #FPC = %d\n", $time, ArbFPCDistRdIdx);

//     a_GLBFPS_CrdRdAddrRdy: assert property (p_high(FPC_CrdRdAddrVld[ArbFPCCrdRdIdx] & FPC_CrdRdDatRdy[ArbFPCCrdRdIdx], GLBFPS_CrdRdAddrRdy))
//     else 
//         $display("GLBFPS_CrdRdAddrRdy fails to pull up at %t, #FPC = %d\n", $time, ArbFPCCrdRdIdx);

//     a_GLBFPS_MaskWrDatRdy: assert property (p_high(FPC_MaskWrDatVld[ArbFPCMaskWrIdx], GLBFPS_MaskWrDatRdy))
//     else 
//         $display("GLBFPS_MaskWrDatRdy fails to pull up at %t, #FPC = %d\n", $time, ArbFPCMaskWrIdx);

//     a_GLBFPS_DistWrDatRdy: assert property (p_high(FPC_DistWrDatVld[ArbFPCDistWrIdx], GLBFPS_DistWrDatRdy))
//     else 
//         $display("GLBFPS_DistWrDatRdy fails to pull up at %t, #FPC = %d\n", $time, ArbFPCDistWrIdx);

//     a_GLBFPS_CrdWrDatRdy: assert property (p_high(FPC_CrdWrDatVld[ArbFPCCrdWrIdx], GLBFPS_CrdWrDatRdy))
//     else 
//         $display("GLBFPS_CrdWrDatRdy fails to pull up at %t, #FPC = %d\n", $time, ArbFPCCrdWrIdx);

//     a_GLBFPS_IdxWrDatRdy: assert property (p_high(FPC_IdxWrDatVld[ArbFPCIdxWrIdx], GLBFPS_IdxWrDatRdy))
//     else 
//         $display("GLBFPS_IdxWrDatRdy fails to pull up at %t, #FPC = %d\n", $time, ArbFPCIdxWrIdx);


// `endif

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================




endmodule
