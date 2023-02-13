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
    parameter CRD_WIDTH         = 16,
    parameter CRD_DIM           = 3,
    parameter NUM_FPC           = 4,
    parameter CUT_MASK_WIDTH     = 16, // process bits at a time
    parameter DISTSQR_WIDTH     = CRD_WIDTH*2 + $clog2(CRD_DIM),
    parameter CRDIDX_WIDTH      = CRD_WIDTH*CRD_DIM+IDX_WIDTH
    )(
    input                               clk                     ,
    input                               rst_n                   ,

    // Configure
    input  [NUM_FPC             -1 : 0] CCUFPS_Rst              ,
    input  [NUM_FPC             -1 : 0] CCUFPS_CfgVld           ,
    output [NUM_FPC             -1 : 0] FPSCCU_CfgRdy           ,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgNip           ,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgNop           ,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgCrdBaseRdAddr ,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgCrdBaseWrAddr ,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgIdxBaseWrAddr ,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgMaskBaseAddr  ,   
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgDistBaseAddr  ,

    output [IDX_WIDTH           -1 : 0] FPSGLB_MaskRdAddr       ,
    output                              FPSGLB_MaskRdAddrVld    ,
    input                               GLBFPS_MaskRdAddrRdy    ,
    input  [SRAM_WIDTH          -1 : 0] GLBFPS_MaskRdDat        ,    
    input                               GLBFPS_MaskRdDatVld     ,    
    output                              FPSGLB_MaskRdDatRdy     ,    

    output [IDX_WIDTH           -1 : 0] FPSGLB_MaskWrAddr       ,
    output [SRAM_WIDTH          -1 : 0] FPSGLB_MaskWrDat        ,   
    output                              FPSGLB_MaskWrDatVld     ,
    input                               GLBFPS_MaskWrDatRdy     , 

    output [IDX_WIDTH           -1 : 0] FPSGLB_CrdRdAddr        ,
    output                              FPSGLB_CrdRdAddrVld     ,
    input                               GLBFPS_CrdRdAddrRdy     ,
    input  [SRAM_WIDTH          -1 : 0] GLBFPS_CrdRdDat         ,    
    input                               GLBFPS_CrdRdDatVld      ,    
    output                              FPSGLB_CrdRdDatRdy      ,    

    output [IDX_WIDTH           -1 : 0] FPSGLB_CrdWrAddr        ,
    output [SRAM_WIDTH          -1 : 0] FPSGLB_CrdWrDat         ,   
    output                              FPSGLB_CrdWrDatVld      ,
    input                               GLBFPS_CrdWrDatRdy      ,  

    output [IDX_WIDTH           -1 : 0] FPSGLB_DistRdAddr       ,
    output                              FPSGLB_DistRdAddrVld    ,
    input                               GLBFPS_DistRdAddrRdy    ,
    input  [SRAM_WIDTH          -1 : 0] GLBFPS_DistRdDat        ,    
    input                               GLBFPS_DistRdDatVld     ,    
    output                              FPSGLB_DistRdDatRdy     ,    

    output [IDX_WIDTH           -1 : 0] FPSGLB_DistWrAddr       ,
    output [SRAM_WIDTH          -1 : 0] FPSGLB_DistWrDat        ,   
    output                              FPSGLB_DistWrDatVld     ,
    input                               GLBFPS_DistWrDatRdy     ,

    output [IDX_WIDTH           -1 : 0] FPSGLB_IdxWrAddr        ,
    output [SRAM_WIDTH          -1 : 0] FPSGLB_IdxWrDat         ,   
    output                              FPSGLB_IdxWrDatVld      ,
    input                               GLBFPS_IdxWrDatRdy      

);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam NUM_CRD_SRAM = 2**$clog2( SRAM_WIDTH / (CRD_WIDTH*CRD_DIM) );
localparam NUM_DIST_SRAM = SRAM_WIDTH / DISTSQR_WIDTH;
localparam CNTMASK_WIDTH = IDX_WIDTH+$clog2(SRAM_WIDTH/CUT_MASK_WIDTH);

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
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCMaskWrIdx_d;

wire [NUM_FPC   -1 : 0][IDX_WIDTH   -1 : 0] FPC_CrdWrAddr;
wire [NUM_FPC   -1 : 0][SRAM_WIDTH  -1 : 0] FPC_CrdWrDat;
wire [NUM_FPC                       -1 : 0] FPC_CrdWrDatVld;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCCrdWrIdx;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCCrdWrIdx_d;

wire [NUM_FPC   -1 : 0][IDX_WIDTH   -1 : 0] FPC_DistWrAddr;
wire [NUM_FPC   -1 : 0][SRAM_WIDTH  -1 : 0] FPC_DistWrDat;
wire [NUM_FPC                       -1 : 0] FPC_DistWrDatVld;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCDistWrIdx;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCDistWrIdx_d;

wire [NUM_FPC   -1 : 0][IDX_WIDTH   -1 : 0] FPC_IdxWrAddr;
wire [NUM_FPC   -1 : 0][SRAM_WIDTH  -1 : 0] FPC_IdxWrDat;
wire [NUM_FPC                       -1 : 0] FPC_IdxWrDatVld;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCIdxWrIdx;
wire [$clog2(NUM_FPC)               -1 : 0] ArbFPCIdxWrIdx_d;

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
    .TOPInRdy    ( GLBFPS_DistWrDatRdy  ),
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
    for(gv_fpc=0; gv_fpc<NUM_FPC; gv_fpc=gv_fpc+1) begin: GEN_FPC
        //=====================================================================================================================
        // Constant Definition :
        //=====================================================================================================================
        localparam IDLE   = 3'b000;
        localparam WORK   = 3'b001;

        //=====================================================================================================================
        // Variable Definition :
        //=====================================================================================================================
        reg [IDX_WIDTH          -1 : 0] FPS_MaxIdx;
        wire[IDX_WIDTH          -1 : 0] FPS_MaxIdx_;
        reg [CRD_WIDTH*CRD_DIM  -1 : 0] FPS_MaxCrd;
        wire[CRD_WIDTH*CRD_DIM  -1 : 0] FPS_MaxCrd_;
        reg [CRD_WIDTH*CRD_DIM  -1 : 0] FPS_CpCrd;
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
        reg [CRD_WIDTH*CRD_DIM  -1 : 0] LopPntCrd_s2;
        reg [CRD_WIDTH*CRD_DIM  -1 : 0] LopPntCrd_s3;
        wire                            CpLast;
        reg                             CpLast_s1;
        reg                             CpLast_s2;
        reg                             CpLast_s3;
        wire [IDX_WIDTH         -1 : 0] CntCp;
        reg  [IDX_WIDTH         -1 : 0] CntCp_s1;
        reg  [IDX_WIDTH         -1 : 0] CntCp_s2;
        reg  [IDX_WIDTH         -1 : 0] CntCp_s3;
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
        reg                             vld_Mask_s3;
        wire                            handshake_Mask_s0;
        wire                            handshake_Mask_s1;
        wire                            handshake_Mask_s2;
        wire                            handshake_Mask_s3;
        wire                            ena_Mask_s0;
        wire                            ena_Mask_s1;
        wire                            ena_Mask_s2;
        wire                            ena_Mask_s3;

        wire                            rdy_Crd_s0;
        wire                            rdy_Crd_s1;
        wire                            rdy_Crd_s2;
        wire                            rdy_Crd_s3;
        reg                             vld_Crd_s0;
        wire                            vld_Crd_s1;
        reg                             vld_Crd_s2;
        reg                             vld_Crd_s3;
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

        wire                            rdy_Mask_Need;
        wire                            rdy_Crd_Need;
        wire                            rdy_Dist_Need;

        wire [CNTMASK_WIDTH     -1 : 0] CntMaskRd;
        wire [IDX_WIDTH         -1 : 0] CntDistRdAddr;
        wire [IDX_WIDTH         -1 : 0] CntCrdRdAddr;
        wire [CNTMASK_WIDTH     -1 : 0] CurIdx_s1;
        wire                            overflow_CntCrdRdAddr;
        wire                            VldArbMask_next;
        wire                            VldArbCrd      ;
        wire                            VldArbCrd_next ;
        wire                            VldArbDist     ;
        wire                            VldArbDist_next;
        wire                            vld_Byte_s1    ;
        //=====================================================================================================================
        // Logic Design: Stage0
        //=====================================================================================================================

        reg [ 3 -1:0 ]state;
        reg [ 3 -1:0 ]next_state;
        always @(*) begin
            case ( state )
                IDLE :  if(FPSCCU_CfgRdy[gv_fpc] & CCUFPS_CfgVld[gv_fpc])
                            next_state <= WORK; //
                        else
                            next_state <= IDLE;
                WORK :if(CpLast_s3 & LopCntLast_s3 & FPC_MaskWrDatVld[gv_fpc] & FPC_DistWrDatVld[gv_fpc] & FPC_CrdWrDatVld[gv_fpc] & FPC_IdxWrDatVld[gv_fpc]) // Last Loop point & no to Write
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

        // Combinational Logic
            assign LopCntLastMask = (CntMaskRd+1)*CUT_MASK_WIDTH >= CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH];
            assign LopCntLastCrd  = (CntCrdRdAddr+1)*NUM_CRD_SRAM >= CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH];
            assign LopCntLastDist = (CntDistRdAddr+1)*NUM_DIST_SRAM >= CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH];

        // HandShake

            // 3 Seperate pipelines/HandShakes forMask, Crd, Dist;

            // Ahead 1 clk enables no idle clk: because 1 ahead clk makeups the 1 idle clk between AddrVld and VldArbMask
            assign rdy_Mask_Need = !VldArbMask_next;  //Load1's rdy
            assign rdy_Mask_s0 = GLBFPS_MaskRdAddrRdy & ArbFPCMaskRdIdx==gv_fpc & rdy_Mask_Need; // Two loads: MaskAddr(Load0) for GLB and Need(Load1);
            assign handshake_Mask_s0 = rdy_Mask_s0 & vld_Mask_s0;
            assign ena_Mask_s0 = handshake_Mask_s0 | ~vld_Mask_s0;
            assign vld_Mask_s0 = state == WORK & !(CpLast & LopCntLastMask);

            assign rdy_Crd_Need = !VldArbCrd_next;  
            assign rdy_Crd_s0 = GLBFPS_CrdRdAddrRdy & ArbFPCCrdRdIdx==gv_fpc & rdy_Crd_Need;
            assign handshake_Crd_s0 = rdy_Crd_s0 & vld_Crd_s0;
            assign ena_Crd_s0 = handshake_Crd_s0 | ~vld_Crd_s0;
            assign vld_Crd_s0 = state == WORK & !(CpLast & LopCntLastCrd);

            assign rdy_Dist_Need = !VldArbDist_next;  
            assign rdy_Dist_s0 = GLBFPS_DistRdAddrRdy & ArbFPCDistRdIdx==gv_fpc & rdy_Dist_Need;
            assign handshake_Dist_s0 = rdy_Dist_s0 & vld_Dist_s0;
            assign ena_Dist_s0 = handshake_Dist_s0 | ~vld_Dist_s0;
            assign vld_Dist_s0 = state == WORK & !(CpLast & LopCntLastDist);

        // Reg Update
            wire [IDX_WIDTH     -1 : 0] MaxCntCp = CCUFPS_CfgNop[IDX_WIDTH*gv_fpc +: IDX_WIDTH] -1;
            counter#(
                .COUNT_WIDTH ( IDX_WIDTH )
            )u0_counter_CntCp(
                .CLK       ( clk                ),
                .RESET_N   ( rst_n              ),
                .CLEAR     ( CCUFPS_Rst[gv_fpc] ),
                .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
                .INC       ( overflow_CntCrdRdAddr & handshake_Crd_s0), // The least bitwidth
                .DEC       ( 1'b0               ),
                .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
                .MAX_COUNT ( MaxCntCp           ),
                .OVERFLOW  ( CpLast             ),
                .UNDERFLOW (                    ),
                .COUNT     ( CntCp              )
            );

            // Mask Pipeline
            wire [CNTMASK_WIDTH     -1 : 0] MaxCntMaskRd = CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH] % CUT_MASK_WIDTH?  CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH] / CUT_MASK_WIDTH -1 : CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH] / CUT_MASK_WIDTH;
            counter#(
                .COUNT_WIDTH ( CNTMASK_WIDTH )
            )u1_counter_CntMaskRd(
                .CLK       ( clk                ),
                .RESET_N   ( rst_n              ),
                .CLEAR     ( CCUFPS_Rst[gv_fpc] ), // MaxCntMaskRd also Clears
                .DEFAULT   ( {CNTMASK_WIDTH{1'b0}}  ),
                .INC       ( handshake_Mask_s0  ),
                .DEC       ( 1'b0               ),
                .MIN_COUNT ( {CNTMASK_WIDTH{1'b0}}  ),
                .MAX_COUNT ( MaxCntMaskRd   ),
                .OVERFLOW  (                    ),
                .UNDERFLOW (                    ),
                .COUNT     ( CntMaskRd      )
            );

            // Crd Pipeline
            wire [IDX_WIDTH     -1 : 0] MaxCntCrdRdAddr = CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH] % NUM_CRD_SRAM?  CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH] / NUM_CRD_SRAM -1 : CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH] / NUM_CRD_SRAM;
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

            // Dist Pipeline
            wire [IDX_WIDTH     -1 : 0] MaxCntDistRdAddr = CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH] % NUM_DIST_SRAM?  CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH] / NUM_DIST_SRAM -1 : CCUFPS_CfgNip[IDX_WIDTH*gv_fpc +: IDX_WIDTH] / NUM_DIST_SRAM;
            counter#( // Pipe S0
                .COUNT_WIDTH ( IDX_WIDTH )
            )u1_counter_CntDistRdAddr(
                .CLK       ( clk                ),
                .RESET_N   ( rst_n              ),
                .CLEAR     ( CCUFPS_Rst[gv_fpc] ), 
                .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
                .INC       ( handshake_Crd_s0   ),
                .DEC       ( 1'b0               ),
                .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
                .MAX_COUNT ( MaxCntDistRdAddr   ),
                .OVERFLOW  (                    ),
                .UNDERFLOW (                    ),
                .COUNT     ( CntDistRdAddr      )
            );

        //=====================================================================================================================
        // Logic Design: Stage1
        //=====================================================================================================================
        // Combinational Logic
            assign FPC_MaskRdAddrVld = vld_Mask_s0 & rdy_Mask_Need; // self is valid & load1 is rdy;
            assign FPC_CrdRdAddrVld  = vld_Crd_s0  & rdy_Crd_Need;
            assign FPC_DistRdAddrVld = vld_Dist_s0 & rdy_Dist_Need;

            assign FPC_MaskRdAddr[gv_fpc] = CCUFPS_CfgMaskBaseAddr[IDX_WIDTH*gv_fpc +: IDX_WIDTH] + CntMaskRd / (SRAM_WIDTH / CUT_MASK_WIDTH);
            assign FPC_CrdRdAddr[gv_fpc] = CCUFPS_CfgCrdBaseRdAddr[IDX_WIDTH*gv_fpc +: IDX_WIDTH] +CntCrdRdAddr;
            assign FPC_DistRdAddr[gv_fpc] = CCUFPS_CfgDistBaseAddr[IDX_WIDTH*gv_fpc +: IDX_WIDTH] + CntDistRdAddr;

        // HandShake

            // 1. MaskRdDat drivers s2(load0) and FPC_MaskWr(load1);
            // 2. Load0: MaskCheck_s2 MUST be invalid, then MaskRdDat can be transferred to MaskCheck_s2
            assign rdy_Mask_s1 = (ena_Mask_s2 & !vld_Mask_s2) & (LopCntLast_s1? GLBFPS_MaskWrDatRdy & ArbFPCMaskWrIdx==gv_fpc : 1'b1);
            assign handshake_Mask_s1 = rdy_Mask_s1 & vld_Mask_s1;
            assign ena_Mask_s1 = handshake_Mask_s1 | ~vld_Mask_s1;
            assign FPC_MaskRdDatRdy[gv_fpc] = rdy_Mask_s1;
            assign vld_Mask_s1 = GLBFPS_MaskRdDatVld & ArbFPCMaskRdIdx_d == gv_fpc;

            assign rdy_Crd_s1 = (ena_Crd_s2 & !vld_Crd_s2); 
            assign handshake_Crd_s1 = rdy_Crd_s1 & vld_Crd_s1;
            assign ena_Crd_s1 = handshake_Crd_s1 | ~vld_Crd_s1;
            assign FPC_CrdRdDatRdy[gv_fpc] = rdy_Crd_s1; 
            assign vld_Crd_s1 = GLBFPS_CrdRdDatVld & ArbFPCCrdRdIdx_d == gv_fpc;

            assign rdy_Dist_s1 = (ena_Dist_s2 & !vld_Dist_s2); 
            assign handshake_Dist_s1 = rdy_Dist_s1 & vld_Dist_s1;
            assign ena_Dist_s1 = handshake_Dist_s1 | ~vld_Dist_s1;
            assign FPC_DistRdDatRdy[gv_fpc] = rdy_Dist_s1; 
            assign vld_Dist_s1 = GLBFPS_DistRdDatVld & ArbFPCDistRdIdx_d == gv_fpc;

        // Reg Update
            reg [IDX_WIDTH      -1 : 0] FPC_MaskRdAddr_s1;
            reg [CNTMASK_WIDTH  -1 : 0] CntMaskRd_s1;
            reg [IDX_WIDTH      -1 : 0] CntCrdRdAddr_s1;
            reg [IDX_WIDTH      -1 : 0] CntCrdRdAddr_s2;
            reg [IDX_WIDTH      -1 : 0] CntDistRdAddr_s1;
            reg [IDX_WIDTH      -1 : 0] CntDistRdAddr_s2;
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {FPC_MaskRdAddr_s1, CntMaskRd_s1, LopCntLastMask_s1} <= 0;
                end else if (  ena_Mask_s1 ) begin
                    {FPC_MaskRdAddr_s1, CntMaskRd_s1, LopCntLastMask_s1} <= {FPC_MaskRdAddr[gv_fpc], CntMaskRd, LopCntLastMask};
                end
            end   
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    CntCrdRdAddr_s1 <= 0;
                end else if (  ena_Crd_s1 ) begin
                    CntCrdRdAddr_s1 <= CntCrdRdAddr;
                end
            end
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    CntDistRdAddr_s1 <= 0;
                end else if (  ena_Dist_s1 ) begin
                    CntDistRdAddr_s1 <= CntDistRdAddr;
                end
            end
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {CntCp_s1, CpLast_s1} <= 0;
                end else if (  ena_Crd_s1 ) begin
                    {CntCp_s1, CpLast_s1} <= {CntCp, CpLast};
                end
            end

        //=====================================================================================================================
        // Logic Design: Stage2
        //======================================================MaskCheck_s2_next===============================================================
        // Combinational Logic
            // Mask Pipeline
                wire [CUT_MASK_WIDTH        -1 : 0] Mask_s1;
                reg  [CUT_MASK_WIDTH        -1 : 0] MaskCheck_s2;
                reg  [CUT_MASK_WIDTH        -1 : 0] MaskCheck_s2_next;
                wire [$clog2(CUT_MASK_WIDTH)-1 : 0] VldIdx;
                wire [$clog2(CUT_MASK_WIDTH)-1 : 0] VldIdx_next;
                wire                               VldArbMask;
                // Current
                    assign Mask_s1 =  handshake_Mask_s1? GLBFPS_MaskRdDat[CUT_MASK_WIDTH*(CntMaskRd_s1 % (SRAM_WIDTH /CUT_MASK_WIDTH)) +: CUT_MASK_WIDTH] : MaskCheck_s2;
                    prior_arb#(
                        .REQ_WIDTH ( CUT_MASK_WIDTH )
                    )u_prior_arb_MaskCheck(
                        .req ( ~Mask_s1     ),
                        .gnt (              ),
                        .arb_port ( VldIdx  )
                    );
                    assign VldArbMask = !(&Mask_s1); // exist 0
                    assign CurIdx_s1 = VldArbMask? (CUT_MASK_WIDTH*CntMaskRd_s1 + VldIdx) : CUT_MASK_WIDTH*(CntMaskRd_s1+1)-1;// exist 0(valid? arbed Idx : last byte of current word
                // Next (for ahead MaskAddrVld=1)
                    always@(*) begin // set the arbed "0" to "1"
                        MaskCheck_s2_next = Mask_s1;
                        if (VldArbMask)
                            MaskCheck_s2_next[VldIdx] = 1'b1;
                    end
                    prior_arb#(
                        .REQ_WIDTH ( CUT_MASK_WIDTH )
                    )u_prior_arb_MaskCheck_next(
                        .req ( ~MaskCheck_s2_next   ),
                        .gnt (                      ),
                        .arb_port  ( VldIdx_next    )
                    ); 
                    assign VldArbMask_next = !(&MaskCheck_s2_next); // exist 0
                    assign CurIdx_s1_next = VldArbMask_next? (CUT_MASK_WIDTH*CntMaskRd_s1 + VldIdx_next) : CUT_MASK_WIDTH*(CntMaskRd_s1+1)-1;

            // Crd Pipeline
                wire [SRAM_WIDTH            -1 : 0] Crd_s1;
                reg  [SRAM_WIDTH            -1 : 0] Crd_s2;
                wire [SRAM_WIDTH            -1 : 0] Dist_s1;
                reg  [SRAM_WIDTH            -1 : 0] Dist_s2;
                assign Crd_s1 = handshake_Crd_s1? GLBFPS_CrdRdDat : Crd_s2;
                assign VldArbCrd = (CntCrdRdAddr_s1+1)*NUM_CRD_SRAM > CUT_MASK_WIDTH*CurIdx_s1;
                assign VldArbCrd_next   = (CntCrdRdAddr_s1+1)*NUM_CRD_SRAM > CUT_MASK_WIDTH*CurIdx_s1_next;
            // Dist Pipeline
                assign Dist_s1 = handshake_Dist_s1? GLBFPS_DistRdDat : Dist_s2;
                assign VldArbDist       = (CntDistRdAddr_s1+1)*NUM_DIST_SRAM > CUT_MASK_WIDTH*CurIdx_s1;
                assign VldArbDist_next  = (CntDistRdAddr_s1+1)*NUM_DIST_SRAM > CUT_MASK_WIDTH*CurIdx_s1_next;
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
                assign FPS_LastPsDist = VldArbMask? Dist_s1[DISTSQR_WIDTH*(CurIdx_s1 % NUM_DIST_SRAM) +: DISTSQR_WIDTH]: 0; 
                assign FPS_PsDist = FPS_LastPsDist > LopDist ? LopDist : FPS_LastPsDist;
                assign FPS_UpdMax = FPS_MaxDist < FPS_PsDist;
                assign {FPS_MaxDist_, FPS_MaxCrd_, FPS_MaxIdx_} = FPS_UpdMax ? {FPS_PsDist, LopPntCrd, LopPntIdx_s1} : {FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx};

            // Mask write back
                assign FPC_MaskWrAddr[gv_fpc] = FPC_MaskRdAddr_s1;
                always @ (*) begin
                    if(FPC_MaskWrDatVld[gv_fpc]) begin
                        FPC_MaskWrDat[gv_fpc] =  GLBFPS_MaskRdDat;
                        FPC_MaskWrDat[gv_fpc][FPS_MaxIdx_ % CUT_MASK_WIDTH] = 1'b1; // set 1
                    end else begin
                        FPC_MaskWrDat[gv_fpc] = 0;
                    end
                end
                assign FPC_MaskWrDatVld[gv_fpc] = LopCntLast_s1 & handshake_Mask_s1;

            assign LopCntLast_s1 = LopCntLastMask_s1 & !VldArbMask_next; // Last mask & no valid bit in the next clk;

        // HandShake

            // vld_Byte_s1 Must be s1 (s1==s3), becuase s2's load0 is s1
            assign vld_Byte_s1      = (VldArbMask & VldArbCrd & VldArbDist); 

            assign rdy_Max_s2 = (LopCntLast_s2? ena_Max_s3 : 1'b1) & vld_Byte_s1; // Two loads are rdy
            assign handshake_Max_s2 = rdy_Max_s2 & vld_Max_s2;
            assign ena_Max_s2 = handshake_Max_s2 | ~vld_Max_s2;

            assign rdy_Mask_s2 = vld_Byte_s1;
            assign handshake_Mask_s2 = rdy_Mask_s2 & vld_Mask_s2;
            assign ena_Mask_s2 = handshake_Mask_s2 | ~vld_Mask_s2;
            assign vld_Mask_s2 = !(&MaskCheck_s2); // In s2, whether MashCheck_s2 is valid

            assign rdy_Crd_s2 = vld_Byte_s1;
            assign handshake_Crd_s2 = rdy_Crd_s2 & vld_Crd_s2;
            assign ena_Crd_s2 = handshake_Crd_s2 | ~vld_Crd_s2;
            assign vld_Crd_s2 = (CntCrdRdAddr_s2 + 1)*NUM_CRD_SRAM > CUT_MASK_WIDTH*CurIdx_s1;

            assign rdy_Dist_s2 = vld_Byte_s1;
            assign handshake_Dist_s2 = rdy_Dist_s2 & vld_Dist_s2;
            assign ena_Dist_s2 = handshake_Dist_s2 | ~vld_Dist_s2;
            assign vld_Dist_s2 = (CntDistRdAddr_s2+1)*NUM_DIST_SRAM > CUT_MASK_WIDTH*CurIdx_s1;


        // Reg Updates
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    MaskCheck_s2 <= 0;
                end else if (ena_Mask_s2) begin
                        MaskCheck_s2 <= MaskCheck_s2_next;
                end
            end

            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {CntCrdRdAddr_s2, Crd_s2} <= 0;
                end else if (ena_Crd_s2) begin
                    {CntCrdRdAddr_s2, Crd_s2} <= {CntCrdRdAddr_s1, Crd_s1};
                end
            end
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {CntDistRdAddr_s2, Dist_s2} <= 0;
                end else if (ena_Dist_s2) begin
                    {CntDistRdAddr_s2, Dist_s2} <= {CntDistRdAddr_s1, Dist_s1};
                end
            end

            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {FPS_CpCrd, FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx, FPS_PsDist_s2, LopCntLast_s2, CntCp_s2, CpLast_s2, vld_Max_s2} <= 0;
                end else if (ena_Max_s2) begin
                    {FPS_CpCrd, FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx, FPS_PsDist_s2,LopCntLast_s2, CntCp_s2, vld_Max_s2} <= 
                    {(LopCntLast_s1 | CntCp_s1==0)? FPS_MaxCrd_ : FPS_CpCrd, FPS_MaxCrd_, FPS_MaxIdx_, FPS_PsDist, LopCntLast_s1, CntCp_s1, CpLast_s1, vld_Byte_s1};
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

            assign rdy_Max_s3 = SIPO_DistInRdy & SIPO_CrdInRdy & SIPO_IdxInRdy;
            assign handshake_Max_s3 = rdy_Max_s3 & vld_Max_s3;
            assign ena_Max_s3 = handshake_Max_s3 | ~vld_Max_s3;

        // Reg Update
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    {LopCntLast_s3, CntCp_s3, CpLast_s3} <= 0;
                end else if (ena_Max_s3) begin
                    {LopCntLast_s3, CntCp_s3, CpLast_s3} <= {LopCntLast_s2, CntCp_s2, CpLast_s2};
                end
            end

            // SIPO Dist
            wire [DISTSQR_WIDTH*NUM_DIST_SRAM   -1 : 0] SIPO_DistOutDat;
            SIPO#(
                .DATA_IN_WIDTH   ( DISTSQR_WIDTH  ), 
                .DATA_OUT_WIDTH  ( DISTSQR_WIDTH*NUM_DIST_SRAM  )
            )u_SIPO_DistWr(
                .CLK       ( clk                        ),
                .RST_N     ( rst_n                      ),
                .IN_VLD    ( vld_Max_s2 & LopCntLast_s2 ),
                .IN_LAST   (                            ),
                .IN_DAT    ( FPS_PsDist_s2              ),
                .IN_RDY    ( SIPO_DistInRdy             ),
                .OUT_DAT   ( SIPO_DistOutDat            ),
                .OUT_VLD   ( FPC_DistWrDatVld[gv_fpc]   ),
                .OUT_LAST  (                            ),
                .OUT_RDY   ( GLBFPS_DistWrDatRdy & gv_fpc == ArbFPCDistWrIdx )
            );
            assign FPC_DistWrDat[gv_fpc] = SIPO_DistOutDat;
            assign FPC_DistWrAddr[gv_fpc] = CCUFPS_CfgDistBaseAddr + CntCp_s3 / NUM_DIST_SRAM;

            // SIPO Crd
            wire [CRD_WIDTH*CRD_DIM*(SRAM_WIDTH/(CRD_WIDTH*CRD_DIM))  -1 : 0] SIPO_CrdOutDat;
            SIPO#(
                .DATA_IN_WIDTH   ( CRD_WIDTH*CRD_DIM  ), 
                .DATA_OUT_WIDTH  ( CRD_WIDTH*CRD_DIM*(SRAM_WIDTH/(CRD_WIDTH*CRD_DIM))  )
            )u_SIPO_CrdWr(
                .CLK       ( clk                    ),
                .RST_N     ( rst_n                  ),
                .IN_VLD    ( vld_Max_s2 & LopCntLast_s2 ),
                .IN_LAST   (                        ),
                .IN_DAT    ( FPS_MaxCrd             ),
                .IN_RDY    ( SIPO_CrdInRdy          ),
                .OUT_DAT   ( SIPO_CrdOutDat         ),
                .OUT_VLD   ( FPC_CrdWrDatVld[gv_fpc]),
                .OUT_LAST  (                        ),
                .OUT_RDY   ( GLBFPS_CrdWrDatRdy & gv_fpc == ArbFPCCrdWrIdx )
            );
            assign FPC_CrdWrDat[gv_fpc] = SIPO_CrdOutDat;
            assign FPC_CrdWrAddr[gv_fpc] = CCUFPS_CfgCrdBaseWrAddr[IDX_WIDTH*gv_fpc +: IDX_WIDTH] + CntCp_s3 / NUM_CRD_SRAM;

            // SIPO Idx
            SIPO#(
                .DATA_IN_WIDTH   ( IDX_WIDTH    ), 
                .DATA_OUT_WIDTH  ( SRAM_WIDTH   )
            )u_SIPO_IdxWr(
                .CLK       ( clk                        ),
                .RST_N     ( rst_n                      ),
                .IN_VLD    ( vld_Max_s2 & LopCntLast_s2 ),
                .IN_LAST   (                            ),
                .IN_DAT    ( FPS_MaxIdx                 ),
                .IN_RDY    ( SIPO_IdxInRdy              ),
                .OUT_DAT   ( FPC_IdxWrDat[gv_fpc]      ),
                .OUT_VLD   ( FPC_IdxWrDatVld[gv_fpc]    ),
                .OUT_LAST  (                            ),
                .OUT_RDY   ( GLBFPS_IdxWrDatRdy & gv_fpc == ArbFPCIdxWrIdx )
            );
            assign FPC_IdxWrAddr[gv_fpc] = CCUFPS_CfgIdxBaseWrAddr[IDX_WIDTH*gv_fpc +: IDX_WIDTH] + CntCp_s3 / (SRAM_WIDTH/IDX_WIDTH);

    end 

endgenerate


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================




endmodule
