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
`define CEIL(a, b) ( \
 (a % b)? (a / b + 1) : (a / b) \
)

module TOP #(
    // HW-Modules

    // FPS
    parameter NUM_FPC        = 16, 
    parameter NUMSRAM_RDCRD  = 2,
    parameter NUMSRAM_DIST   = 2,
    parameter NUMMASK_PROC   = 64, // Reduce BW
    
    // KNN
    parameter NUM_SORT_CORE  = 8, //
    parameter KNNCRD_MAXPARA = 1, // Max Number of SRAM for CrdRd
    parameter CRD_MAXDIM     = 64,

    // SYA
    parameter SYA_NUM_ROW    = 16,
    parameter SYA_NUM_COL    = 16,
    parameter SYA_NUM_BANK   = 2,

    // POL
    parameter POOL_CORE      = 4,
    parameter POOL_COMP_CORE = 32, // SRAM/BYTE 

    // ITF
    parameter PORT_WIDTH     = 128, 
    parameter DRAM_ADDR_WIDTH= 32, 
    parameter ASYNC_FIFO_ADDR_WIDTH = 4,
    parameter FBDIV_WIDTH    = 5,

    // GLB
    parameter SRAM_WIDTH     = 256, 
    parameter SRAM_WORD      = 128,
    parameter ADDR_WIDTH     = 16,
    parameter GLB_NUM_RDPORT = 13 + POOL_CORE - 1,
    parameter GLB_NUM_WRPORT = 10, 
    parameter NUM_BANK       = 16,

    // CCU
    parameter NUM_MODULE     = 6,
    parameter BYTE_WIDTH     = 8,
    parameter CCUISA_WIDTH   = PORT_WIDTH*1,
    parameter FPSISA_WIDTH   = PORT_WIDTH*16,
    parameter KNNISA_WIDTH   = PORT_WIDTH*2,
    parameter SYAISA_WIDTH   = PORT_WIDTH*3,
    parameter POLISA_WIDTH   = PORT_WIDTH*9,
    parameter GICISA_WIDTH   = PORT_WIDTH*2,
    parameter MONISA_WIDTH   = PORT_WIDTH*1,
    parameter MAXISA_WIDTH   = PORT_WIDTH*16,
    parameter FPSISAFIFO_ADDR_WIDTH = 1,
    parameter KNNISAFIFO_ADDR_WIDTH = 1,
    parameter SYAISAFIFO_ADDR_WIDTH = 1,
    parameter POLISAFIFO_ADDR_WIDTH = 1,
    parameter GICISAFIFO_ADDR_WIDTH = 1,
    parameter MONISAFIFO_ADDR_WIDTH = 1,

    // UNT
    parameter SHF_ADDR_WIDTH= 8,

    // MON
    parameter CCUMON_WIDTH  = 128*2,
    parameter GICMON_WIDTH  = 128*2,
    parameter GLBMON_WIDTH  = 128*11,
    parameter POLMON_WIDTH  = 128*2,
    parameter SYAMON_WIDTH  = 128*2,
    parameter KNNMON_WIDTH  = 128*2,
    parameter FPSMON_WIDTH  = 128*2,

    parameter MDUMONSUM_WIDTH  = CCUMON_WIDTH + GICMON_WIDTH + GLBMON_WIDTH + POLMON_WIDTH + SYAMON_WIDTH + KNNMON_WIDTH + FPSMON_WIDTH,
    parameter TOPMON_WIDTH     = PORT_WIDTH*`CEIL(MDUMONSUM_WIDTH, PORT_WIDTH),

    // NetWork Parameters
    parameter NUM_LAYER_WIDTH= 20,
    parameter CRD_WIDTH      = 8,   
    parameter CRD_DIM        = 3,  
    parameter IDX_WIDTH      = 16,
    parameter MAP_WIDTH      = 5,
    parameter ACT_WIDTH      = 8,
    parameter CHN_WIDTH      = 16,
    parameter QNTSL_WIDTH    = 16,
    parameter MASK_ADDR_WIDTH= $clog2(2**IDX_WIDTH*NUM_SORT_CORE/SRAM_WIDTH),
    parameter OPNUM          = NUM_MODULE
    )( // 5 + 6 + 128 + 20 = 159
    input                           I_BypAsysnFIFO_PAD,// Hyper
    input                           I_BypOE_PAD       , 
    input                           I_SysRst_n_PAD    , 
    input                           I_SwClk_PAD       ,
    input                           I_SysClk_PAD      , 
    input                           I_OffClk_PAD      ,
    output                          O_SysClk_PAD      ,
    output                          O_OffClk_PAD      ,

    output [OPNUM           -1 : 0] O_CfgRdy_PAD      , // Monitor
    output                          O_DatOE_PAD       ,

    input                           I_OffOE_PAD       , // Transfer-Control
    input                           I_DatVld_PAD      ,
    input                           I_DatLast_PAD     ,
    output                          O_DatRdy_PAD      ,
    output                          O_DatVld_PAD      , 
    output                          O_DatLast_PAD     , 
    input                           I_DatRdy_PAD      , 

    input                           I_ISAVld_PAD      , // Transfer-Data
    output                          O_CmdVld_PAD      ,
    inout   [PORT_WIDTH     -1 : 0] IO_Dat_PAD         

    // input                           I_BypPLL_PAD      , 
    // input [FBDIV_WIDTH      -1 : 0] I_FBDIV_PAD       ,
    // output                          O_PLLLock_PAD       

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam GLBWRIDX_GICGLB = 0; 
localparam GLBWRIDX_FPSMSK = 1; 
localparam GLBWRIDX_FPSCRD = 2; 
localparam GLBWRIDX_FPSDST = 3; // 2 SRAM BW 
localparam GLBWRIDX_FPSIDX = 5; 
localparam GLBWRIDX_KNNMAP = 6;
localparam GLBWRIDX_SYAOFM = 7;
localparam GLBWRIDX_POLOFM = 8;
localparam GLBWRIDX_POLIDM = 9;
                                
localparam GLBRDIDX_GICGLB = 0; 
localparam GLBRDIDX_FPSMSK = 1; 
localparam GLBRDIDX_FPSCRD = 2; // 2 SRAM BW
localparam GLBRDIDX_FPSDST = 4; // 2 SRAM BW
localparam GLBRDIDX_KNNCRD = 6; 
localparam GLBRDIDX_KNNMSK = 7; 
localparam GLBRDIDX_KNNIDM = 8; 
localparam GLBRDIDX_SYAACT = 9;
localparam GLBRDIDX_SYAWGT = 10; 
localparam GLBRDIDX_POLMAP = 11;
localparam GLBRDIDX_POLOFM = 12;

localparam DISTSQR_WIDTH     = CRD_WIDTH*2 + $clog2(CRD_DIM);
localparam SYAIOMAXWIDTH     = ACT_WIDTH*SYA_NUM_ROW*SYA_NUM_BANK;
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

// --------------------------------------------------------------------------------------------------------------------
// TOP
wire                            clk;
wire                            rst_n;
genvar                          gv_i;
wire [OPNUM             -1 : 0] CCUITF_CfgRdy ;

// --------------------------------------------------------------------------------------------------------------------
// CCU 
    // Configure
wire [PORT_WIDTH              -1 : 0] ITFCCU_ISARdDat   ;             
wire                                  ITFCCU_ISARdDatVld;          
wire                                  ITFCCU_ISARdDatLast;          
wire                                  CCUITF_ISARdDatRdy;
wire                                  CCUGIC_CfgVld     ;
wire                                  GICCCU_CfgRdy     ; 

wire [NUM_FPC                 -1 : 0] CCUFPS_CfgVld ;
wire [NUM_FPC                 -1 : 0] FPSCCU_CfgRdy ;        
wire                                  CCUKNN_CfgVld ;
wire                                  KNNCCU_CfgRdy ;        
wire                                  CCUSYA_CfgVld ;
wire                                  SYACCU_CfgRdy ;
wire  [POOL_CORE              -1 : 0] CCUPOL_CfgVld ;
wire  [POOL_CORE              -1 : 0] POLCCU_CfgRdy ;

wire                                  CCUMON_CfgVld;

wire  [GICISA_WIDTH           -1 : 0] CCUGIC_CfgInfo;
wire  [FPSISA_WIDTH           -1 : 0] CCUFPS_CfgInfo;     
wire  [KNNISA_WIDTH           -1 : 0] CCUKNN_CfgInfo;        
wire  [SYAISA_WIDTH           -1 : 0] CCUSYA_CfgInfo; 
wire  [POLISA_WIDTH           -1 : 0] CCUPOL_CfgInfo;        
wire  [MONISA_WIDTH           -1 : 0] CCUMON_CfgInfo;        

wire [CCUMON_WIDTH            -1 : 0] CCUMON_Dat;
// --------------------------------------------------------------------------------------------------------------------
// FPS
wire [IDX_WIDTH           -1 : 0] FPSGLB_MaskRdAddr       ;
wire                              FPSGLB_MaskRdAddrVld    ;
wire                              GLBFPS_MaskRdAddrRdy    ;
wire [SRAM_WIDTH          -1 : 0] GLBFPS_MaskRdDat        ;    
wire                              GLBFPS_MaskRdDatVld     ;    
wire                              FPSGLB_MaskRdDatRdy     ;    

wire [IDX_WIDTH           -1 : 0] FPSGLB_MaskWrAddr       ;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_MaskWrDat        ;   
wire                              FPSGLB_MaskWrDatVld     ;
wire                              GLBFPS_MaskWrDatRdy     ; 

wire [IDX_WIDTH           -1 : 0] FPSGLB_CrdRdAddr        ;
wire                              FPSGLB_CrdRdAddrVld     ;
wire                              GLBFPS_CrdRdAddrRdy     ;
wire [SRAM_WIDTH*NUMSRAM_RDCRD-1 : 0] GLBFPS_CrdRdDat         ;    
wire                              GLBFPS_CrdRdDatVld      ;    
wire                              FPSGLB_CrdRdDatRdy      ;    

wire [IDX_WIDTH           -1 : 0] FPSGLB_CrdWrAddr        ;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_CrdWrDat         ;   
wire                              FPSGLB_CrdWrDatVld      ;
wire                              GLBFPS_CrdWrDatRdy      ;  

wire [IDX_WIDTH           -1 : 0] FPSGLB_DistRdAddr       ;
wire                              FPSGLB_DistRdAddrVld    ;
wire                              GLBFPS_DistRdAddrRdy    ;
wire [SRAM_WIDTH*NUMSRAM_DIST-1 : 0] GLBFPS_DistRdDat        ;    
wire                              GLBFPS_DistRdDatVld     ;    
wire                              FPSGLB_DistRdDatRdy     ;    

wire [IDX_WIDTH           -1 : 0] FPSGLB_DistWrAddr       ;
wire [SRAM_WIDTH*NUMSRAM_DIST-1 : 0] FPSGLB_DistWrDat        ;   
wire                              FPSGLB_DistWrDatVld     ;
wire                              GLBFPS_DistWrDatRdy     ;

wire [IDX_WIDTH           -1 : 0] FPSGLB_IdxWrAddr        ;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_IdxWrDat         ;   
wire                              FPSGLB_IdxWrDatVld      ;
wire                              GLBFPS_IdxWrDatRdy      ;
wire [2                   -1 : 0] ArbIdx_FKNCIM;

// --------------------------------------------------------------------------------------------------------------------
// KNN
// Fetch Crd
wire [IDX_WIDTH           -1 : 0] KNNGLB_CrdRdAddr    ;   
wire                              KNNGLB_CrdRdAddrVld ; 
wire                              GLBKNN_CrdRdAddrRdy ;
wire [SRAM_WIDTH*KNNCRD_MAXPARA-1 : 0 ]GLBKNN_CrdRdDat     ;        
wire                              GLBKNN_CrdRdDatVld  ;     
wire                              KNNGLB_CrdRdDatRdy  ;

// Fetch Mask of Output Points
wire [IDX_WIDTH           -1 : 0] KNNGLB_MaskRdAddr   ;
wire                              KNNGLB_MaskRdAddrVld;
wire                              GLBKNN_MaskRdAddrRdy;
wire [SRAM_WIDTH          -1 : 0] GLBKNN_MaskRdDat    ;    
wire                              GLBKNN_MaskRdDatVld ;    
wire                              KNNGLB_MaskRdDatRdy ;  

// Output Map of KNN
wire [IDX_WIDTH           -1 : 0] KNNGLB_MapWrAddr    ;
wire [SRAM_WIDTH          -1 : 0] KNNGLB_MapWrDat     ;   
wire                              KNNGLB_MapWrDatVld  ;     
wire                              GLBKNN_MapWrDatRdy  ;

wire [IDX_WIDTH           -1 : 0] KNNGLB_IdxMaskRdAddr   ;
wire                              KNNGLB_IdxMaskRdAddrVld;
wire                              GLBKNN_IdxMaskRdAddrRdy;
wire [SRAM_WIDTH          -1 : 0] GLBKNN_IdxMaskRdDat    ;    
wire                              GLBKNN_IdxMaskRdDatVld ;    
wire                              KNNGLB_IdxMaskRdDatRdy ; 
wire                              Cfg_KNNBorrowFPS;
wire                              Cfg_PortSelPOL; // 1: Ports of FPS and KNN are allocated to POL
wire                              ArbIdx_KNNMIM;
// --------------------------------------------------------------------------------------------------------------------
// SYA
wire [ADDR_WIDTH                -1 : 0] SYAGLB_ActRdAddr          ;
wire                                    SYAGLB_ActRdAddrVld       ;
wire                                    GLBSYA_ActRdAddrRdy       ;
wire [SYAIOMAXWIDTH             -1 : 0] GLBSYA_ActRdDat           ;
wire                                    GLBSYA_ActRdDatVld        ;
wire                                    SYAGLB_ActRdDatRdy        ;

wire [ADDR_WIDTH                -1 : 0] SYAGLB_WgtRdAddr          ;
wire                                    SYAGLB_WgtRdAddrVld       ;
wire                                    GLBSYA_WgtRdAddrRdy       ;
wire [SYAIOMAXWIDTH             -1 : 0] GLBSYA_WgtRdDat           ;
wire                                    GLBSYA_WgtRdDatVld        ;
wire                                    SYAGLB_WgtRdDatRdy        ;

wire [SYAIOMAXWIDTH             -1 : 0] SYAGLB_OfmWrDat           ;
wire [ADDR_WIDTH                -1 : 0] SYAGLB_OfmWrAddr          ;
wire                                    SYAGLB_OfmWrDatVld        ;
wire                                    GLBSYA_OfmWrDatRdy        ;

// --------------------------------------------------------------------------------------------------------------------
// POL
wire [IDX_WIDTH                               -1 : 0] POLGLB_MapRdAddr      ;   
wire                                                  POLGLB_MapRdAddrVld   ; 
wire                                                  GLBPOL_MapRdAddrRdy   ;
wire                                                  GLBPOL_MapRdDatVld    ;
wire [SRAM_WIDTH                              -1 : 0] GLBPOL_MapRdDat       ;
wire                                                  POLGLB_MapRdDatRdy    ;

wire [POOL_CORE                               -1 : 0] POLGLB_OfmRdAddrVld   ;
wire [POOL_CORE -1 : 0][IDX_WIDTH             -1 : 0] POLGLB_OfmRdAddr      ;
wire [POOL_CORE                               -1 : 0] GLBPOL_OfmRdAddrRdy   ;
wire [POOL_CORE -1 : 0][(ACT_WIDTH*POOL_COMP_CORE) -1 : 0] GLBPOL_OfmRdDat  ;
wire [POOL_CORE                               -1 : 0] GLBPOL_OfmRdDatVld    ;
wire [POOL_CORE                               -1 : 0] POLGLB_OfmRdDatRdy    ;

wire [IDX_WIDTH                             -1 : 0] POLGLB_OfmWrAddr        ;
wire [(ACT_WIDTH*POOL_COMP_CORE)            -1 : 0] POLGLB_OfmWrDat         ;
wire                                                POLGLB_OfmWrDatVld      ;
wire                                                GLBPOL_OfmWrDatRdy      ;
wire [IDX_WIDTH                               -1 : 0] POLGLB_IdxMaskWrAddr  ;
wire [IDX_WIDTH + 1                           -1 : 0] POLGLB_IdxMaskWrDat   ;
wire                                                  POLGLB_IdxMaskWrDatVld;
wire                                                  GLBPOL_IdxMaskWrDatRdy;
// --------------------------------------------------------------------------------------------------------------------
// GIC
wire                                                GICITF_CmdVld   ;
wire [PORT_WIDTH                            -1 : 0] GICITF_Dat      ;
wire                                                GICITF_DatVld   ;
wire                                                GICITF_DatLast  ;
wire                                                ITFGIC_DatRdy   ;

wire [PORT_WIDTH                            -1 : 0] ITFGIC_Dat      ;
wire                                                ITFGIC_DatVld   ;
wire                                                ITFGIC_DatLast  ;
wire                                                GICITF_DatRdy   ;

wire [ADDR_WIDTH                            -1 : 0] GICGLB_RdAddr    ;
wire                                                GICGLB_RdAddrVld ;
wire                                                GLBGIC_RdAddrRdy ;
wire [SRAM_WIDTH                            -1 : 0] GLBGIC_RdDat     ;
wire                                                GLBGIC_RdDatVld  ;
wire                                                GICGLB_RdDatRdy  ;
wire                                                GLBGIC_RdEmpty   ;

wire [ADDR_WIDTH                            -1 : 0] GICGLB_WrAddr    ;
wire [SRAM_WIDTH                            -1 : 0] GICGLB_WrDat     ; 
wire                                                GICGLB_WrDatVld  ; 
wire                                                GLBGIC_WrDatRdy  ;
wire                                                GLBGIC_WrFull    ;

// --------------------------------------------------------------------------------------------------------------------
// GLB
// Configure
wire [(GLB_NUM_RDPORT + GLB_NUM_WRPORT) -1 : 0][NUM_BANK-1 : 0] TOPGLB_CfgPortBankFlag;
wire [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)                 -1 : 0] TOPGLB_CfgPortOffEmptyFull;
// Data
wire [GLB_NUM_WRPORT    -1 : 0][SRAM_WIDTH          -1 : 0] TOPGLB_WrPortDat    ;
wire [GLB_NUM_WRPORT                                -1 : 0] TOPGLB_WrPortDatVld ;
wire [GLB_NUM_WRPORT                                -1 : 0] GLBTOP_WrPortDatRdy ;
wire [GLB_NUM_WRPORT    -1 : 0][ADDR_WIDTH          -1 : 0] TOPGLB_WrPortAddr   ;
wire [GLB_NUM_WRPORT                                -1 : 0] GLBTOP_WrFull ;

wire [GLB_NUM_RDPORT    -1 : 0][ADDR_WIDTH          -1 : 0] TOPGLB_RdPortAddr   ;
wire [GLB_NUM_RDPORT                                -1 : 0] TOPGLB_RdPortAddrVld;
wire [GLB_NUM_RDPORT                                -1 : 0] GLBTOP_RdPortAddrRdy;
wire [GLB_NUM_RDPORT    -1 : 0][SRAM_WIDTH          -1 : 0] GLBTOP_RdPortDat    ;
wire [GLB_NUM_RDPORT                                -1 : 0] GLBTOP_RdPortDatVld ;
wire [GLB_NUM_RDPORT                                -1 : 0] TOPGLB_RdPortDatRdy ;
wire [GLB_NUM_RDPORT                                -1 : 0] GLBTOP_RdEmpty      ;

// --------------------------------------------------------------------------------------------------------------------
// MON
wire [GICMON_WIDTH  -1 : 0] GICMON_Dat;
wire [GLBMON_WIDTH  -1 : 0] GLBMON_Dat;
wire [POLMON_WIDTH  -1 : 0] POLMON_Dat;
wire [SYAMON_WIDTH  -1 : 0] SYAMON_Dat;
wire [KNNMON_WIDTH  -1 : 0] KNNMON_Dat;
wire [FPSMON_WIDTH  -1 : 0] FPSMON_Dat;
wire [TOPMON_WIDTH  -1 : 0] TOPMON_Dat;
wire [PORT_WIDTH    -1 : 0] MONITF_Dat;

wire                        MONITF_DatVld ;
wire                        MONITF_DatLast;
wire                        ITFMON_DatRdy ;

//=====================================================================================================================
// Logic Design： TOP
//=====================================================================================================================

//=====================================================================================================================
// Logic Design: CCU
//=====================================================================================================================
CCU#(
    .SRAM_WIDTH              ( SRAM_WIDTH       ),
    .PORT_WIDTH              ( PORT_WIDTH       ),
    .POOL_CORE               ( POOL_CORE        ),
    .ADDR_WIDTH              ( ADDR_WIDTH       ),
    .DRAM_ADDR_WIDTH         ( DRAM_ADDR_WIDTH  ),
    .GLB_NUM_RDPORT          ( GLB_NUM_RDPORT   ),
    .GLB_NUM_WRPORT          ( GLB_NUM_WRPORT   ),
    .IDX_WIDTH               ( IDX_WIDTH        ),
    .CHN_WIDTH               ( CHN_WIDTH        ),
    .QNTSL_WIDTH             ( QNTSL_WIDTH      ),
    .ACT_WIDTH               ( ACT_WIDTH        ),
    .MAP_WIDTH               ( MAP_WIDTH        ),
    .NUM_LAYER_WIDTH         ( NUM_LAYER_WIDTH  ),
    .NUM_MODULE              ( NUM_MODULE       ),
    .OPNUM                   ( OPNUM            ),
    .NUM_FPC                 ( NUM_FPC          ),
    .CCUISA_WIDTH            ( CCUISA_WIDTH     ),
    .FPSISA_WIDTH            ( FPSISA_WIDTH     ),
    .KNNISA_WIDTH            ( KNNISA_WIDTH     ),
    .SYAISA_WIDTH            ( SYAISA_WIDTH     ),
    .POLISA_WIDTH            ( POLISA_WIDTH     ),
    .GICISA_WIDTH            ( GICISA_WIDTH     ),
    .MONISA_WIDTH            ( MONISA_WIDTH     ),
    .MAXISA_WIDTH            ( MAXISA_WIDTH     ),
    .FPSISAFIFO_ADDR_WIDTH   ( FPSISAFIFO_ADDR_WIDTH ),
    .KNNISAFIFO_ADDR_WIDTH   ( KNNISAFIFO_ADDR_WIDTH ),
    .SYAISAFIFO_ADDR_WIDTH   ( SYAISAFIFO_ADDR_WIDTH ),
    .POLISAFIFO_ADDR_WIDTH   ( POLISAFIFO_ADDR_WIDTH ),
    .GICISAFIFO_ADDR_WIDTH   ( GICISAFIFO_ADDR_WIDTH ),
    .MONISAFIFO_ADDR_WIDTH   ( MONISAFIFO_ADDR_WIDTH ),
    .CCUMON_WIDTH            ( CCUMON_WIDTH          )
)u_CCU(
    .clk                     ( clk                  ),
    .rst_n                   ( rst_n                ),
    .CCUITF_CfgRdy           ( CCUITF_CfgRdy        ),
    .ITFCCU_ISARdDat         ( ITFCCU_ISARdDat      ),
    .ITFCCU_ISARdDatVld      ( ITFCCU_ISARdDatVld   ),
    .ITFCCU_ISARdDatLast     ( ITFCCU_ISARdDatLast  ),
    .CCUITF_ISARdDatRdy      ( CCUITF_ISARdDatRdy   ),
    .CCUGIC_CfgVld           ( CCUGIC_CfgVld        ),
    .GICCCU_CfgRdy           ( GICCCU_CfgRdy        ),
    .CCUGIC_CfgInfo          ( CCUGIC_CfgInfo       ),
    .CCUFPS_CfgVld           ( CCUFPS_CfgVld        ),
    .FPSCCU_CfgRdy           ( FPSCCU_CfgRdy        ),
    .CCUFPS_CfgInfo          ( CCUFPS_CfgInfo       ),
    .CCUKNN_CfgVld           ( CCUKNN_CfgVld        ),
    .KNNCCU_CfgRdy           ( KNNCCU_CfgRdy        ),
    .CCUKNN_CfgInfo          ( CCUKNN_CfgInfo       ),
    .CCUSYA_CfgVld           ( CCUSYA_CfgVld        ),
    .SYACCU_CfgRdy           ( SYACCU_CfgRdy        ),
    .CCUSYA_CfgInfo          ( CCUSYA_CfgInfo       ),
    .CCUPOL_CfgVld           ( CCUPOL_CfgVld        ),
    .POLCCU_CfgRdy           ( POLCCU_CfgRdy        ),
    .CCUPOL_CfgInfo          ( CCUPOL_CfgInfo       ),
    .CCUMON_CfgVld           ( CCUMON_CfgVld        ),
    .CCUMON_CfgInfo          ( CCUMON_CfgInfo       ),
    .MONCCU_CfgRdy           ( MONCCU_CfgRdy        ),
    .CCUMON_Dat              ( CCUMON_Dat           )
);

//=====================================================================================================================
// Logic Design: FPS
//=====================================================================================================================

// FPS Reads Mask from GLB
assign #0.2 TOPGLB_RdPortAddr[GLBRDIDX_FPSMSK]       = FPSGLB_MaskRdAddr;
assign #0.2 TOPGLB_RdPortAddrVld[GLBRDIDX_FPSMSK]    = FPSGLB_MaskRdAddrVld;
assign #0.2 GLBFPS_MaskRdAddrRdy                     = GLBTOP_RdPortAddrRdy[GLBRDIDX_FPSMSK];

assign #0.2 GLBFPS_MaskRdDat                         = GLBTOP_RdPortDat[GLBRDIDX_FPSMSK];
assign #0.2 GLBFPS_MaskRdDatVld                      = GLBTOP_RdPortDatVld[GLBRDIDX_FPSMSK];
assign #0.2 TOPGLB_RdPortDatRdy[GLBRDIDX_FPSMSK]     = FPSGLB_MaskRdDatRdy;

// FPS Writes Mask to GLB
assign #0.2 TOPGLB_WrPortAddr[GLBWRIDX_FPSMSK]       = FPSGLB_MaskWrAddr;
assign #0.2 TOPGLB_WrPortDat[GLBWRIDX_FPSMSK]        = FPSGLB_MaskWrDat;
assign #0.2 TOPGLB_WrPortDatVld[GLBWRIDX_FPSMSK]     = FPSGLB_MaskWrDatVld;
assign #0.2 GLBFPS_MaskWrDatRdy                      = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSMSK];

// Read Crd
generate
    for(gv_i=0; gv_i<NUMSRAM_RDCRD; gv_i =gv_i +1) begin: GEN_FPSGLB_CrdRdPort
        assign #0.2 TOPGLB_RdPortAddr    [GLBRDIDX_FPSCRD + gv_i]    = Cfg_KNNBorrowFPS? KNNGLB_CrdRdAddr     : FPSGLB_CrdRdAddr;
        assign #0.2 TOPGLB_RdPortAddrVld [GLBRDIDX_FPSCRD + gv_i]    = Cfg_KNNBorrowFPS? KNNGLB_CrdRdAddrVld  : FPSGLB_CrdRdAddrVld;
        assign #0.2 TOPGLB_RdPortDatRdy  [GLBRDIDX_FPSCRD + gv_i]    = Cfg_KNNBorrowFPS? KNNGLB_CrdRdDatRdy   : FPSGLB_CrdRdDatRdy;
    end
endgenerate
assign #0.2 GLBFPS_CrdRdAddrRdy                      = GLBTOP_RdPortAddrRdy[GLBRDIDX_FPSCRD]; // one of
assign #0.2 GLBFPS_CrdRdDat                          = GLBTOP_RdPortDat    [GLBRDIDX_FPSCRD +: NUMSRAM_RDCRD];
assign #0.2 GLBFPS_CrdRdDatVld                       = GLBTOP_RdPortDatVld [GLBRDIDX_FPSCRD];

// Read Dist
generate
    for(gv_i=0; gv_i<NUMSRAM_DIST; gv_i =gv_i +1) begin: GEN_FPSGLB_DistRdPort
        assign #0.2 TOPGLB_RdPortAddr    [GLBRDIDX_FPSDST + gv_i]   = Cfg_KNNBorrowFPS & gv_i==0 ? KNNGLB_CrdRdAddr     : FPSGLB_DistRdAddr;
        assign #0.2 TOPGLB_RdPortAddrVld [GLBRDIDX_FPSDST + gv_i]   = Cfg_KNNBorrowFPS & gv_i==0 ? KNNGLB_CrdRdAddrVld  : FPSGLB_DistRdAddrVld;
        assign #0.2 TOPGLB_RdPortDatRdy  [GLBRDIDX_FPSDST + gv_i]   = Cfg_KNNBorrowFPS & gv_i==0 ? KNNGLB_CrdRdDatRdy   : FPSGLB_DistRdDatRdy;
    end
endgenerate
assign #0.2 GLBFPS_DistRdAddrRdy = GLBTOP_RdPortAddrRdy  [GLBRDIDX_FPSDST];
assign #0.2 GLBFPS_DistRdDat     = GLBTOP_RdPortDat      [GLBRDIDX_FPSDST +: NUMSRAM_RDCRD];
assign #0.2 GLBFPS_DistRdDatVld  = GLBTOP_RdPortDatVld   [GLBRDIDX_FPSDST];

// Write Crd
assign #0.2 TOPGLB_WrPortAddr   [GLBWRIDX_FPSCRD]   = FPSGLB_CrdWrAddr  ;
assign #0.2 TOPGLB_WrPortDat    [GLBWRIDX_FPSCRD]   = FPSGLB_CrdWrDat   ;
assign #0.2 TOPGLB_WrPortDatVld [GLBWRIDX_FPSCRD]   = FPSGLB_CrdWrDatVld;
assign #0.2 GLBFPS_CrdWrDatRdy                      = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSCRD];

// Write Dist
generate
    for(gv_i=0; gv_i<NUMSRAM_DIST; gv_i =gv_i +1) begin: GEN_FPSGLB_DistWrPort
        assign #0.2 TOPGLB_WrPortAddr    [GLBWRIDX_FPSDST + gv_i]    = FPSGLB_DistWrAddr;
        assign #0.2 TOPGLB_WrPortDat     [GLBWRIDX_FPSDST + gv_i]    = FPSGLB_DistWrDat[SRAM_WIDTH*gv_i +: SRAM_WIDTH];
        assign #0.2 TOPGLB_WrPortDatVld  [GLBWRIDX_FPSDST + gv_i]    = FPSGLB_DistWrDatVld;
    end
endgenerate
assign #0.2 GLBFPS_DistWrDatRdy  = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSDST];

// Write Idx
assign #0.2 TOPGLB_WrPortAddr   [GLBWRIDX_FPSIDX]   = FPSGLB_IdxWrAddr  ;
assign #0.2 TOPGLB_WrPortDat    [GLBWRIDX_FPSIDX]   = FPSGLB_IdxWrDat   ;
assign #0.2 TOPGLB_WrPortDatVld [GLBWRIDX_FPSIDX]   = FPSGLB_IdxWrDatVld;
assign #0.2 GLBFPS_IdxWrDatRdy                      = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSIDX];

FPS #(
    .FPSISA_WIDTH         ( FPSISA_WIDTH),
    .SRAM_WIDTH           ( SRAM_WIDTH  ),
    .IDX_WIDTH            ( IDX_WIDTH   ),
    .CRD_WIDTH            ( CRD_WIDTH   ),
    .CRD_DIM              ( CRD_DIM     ),
    .NUM_FPC              ( NUM_FPC     ),
    .NUMSRAM_RDCRD        ( NUMSRAM_RDCRD),
    .NUMSRAM_DIST         ( NUMSRAM_DIST ),
    .NUMMASK_PROC         ( NUMMASK_PROC),
    .FPSMON_WIDTH         ( FPSMON_WIDTH)
)u_FPS(
    .clk                    ( clk                   ),
    .rst_n                  ( rst_n                 ),
    .CCUFPS_CfgVld          ( CCUFPS_CfgVld         ),
    .FPSCCU_CfgRdy          ( FPSCCU_CfgRdy         ),
    .CCUFPS_CfgInfo         ( CCUFPS_CfgInfo        ),
    .FPSGLB_MaskRdAddr      ( FPSGLB_MaskRdAddr     ),
    .FPSGLB_MaskRdAddrVld   ( FPSGLB_MaskRdAddrVld  ),
    .GLBFPS_MaskRdAddrRdy   ( GLBFPS_MaskRdAddrRdy  ),
    .GLBFPS_MaskRdDat       ( GLBFPS_MaskRdDat      ),
    .GLBFPS_MaskRdDatVld    ( GLBFPS_MaskRdDatVld   ),
    .FPSGLB_MaskRdDatRdy    ( FPSGLB_MaskRdDatRdy   ),
    .FPSGLB_MaskWrAddr      ( FPSGLB_MaskWrAddr     ),
    .FPSGLB_MaskWrDat       ( FPSGLB_MaskWrDat      ),
    .FPSGLB_MaskWrDatVld    ( FPSGLB_MaskWrDatVld   ),
    .GLBFPS_MaskWrDatRdy    ( GLBFPS_MaskWrDatRdy   ),
    .FPSGLB_CrdRdAddr       ( FPSGLB_CrdRdAddr      ),
    .FPSGLB_CrdRdAddrVld    ( FPSGLB_CrdRdAddrVld   ),
    .GLBFPS_CrdRdAddrRdy    ( GLBFPS_CrdRdAddrRdy   ),
    .GLBFPS_CrdRdDat        ( GLBFPS_CrdRdDat       ),
    .GLBFPS_CrdRdDatVld     ( GLBFPS_CrdRdDatVld    ),
    .FPSGLB_CrdRdDatRdy     ( FPSGLB_CrdRdDatRdy    ),
    .FPSGLB_CrdWrAddr       ( FPSGLB_CrdWrAddr      ),
    .FPSGLB_CrdWrDat        ( FPSGLB_CrdWrDat       ),
    .FPSGLB_CrdWrDatVld     ( FPSGLB_CrdWrDatVld    ),
    .GLBFPS_CrdWrDatRdy     ( GLBFPS_CrdWrDatRdy    ),
    .FPSGLB_DistRdAddr      ( FPSGLB_DistRdAddr     ),
    .FPSGLB_DistRdAddrVld   ( FPSGLB_DistRdAddrVld  ),
    .GLBFPS_DistRdAddrRdy   ( GLBFPS_DistRdAddrRdy  ),
    .GLBFPS_DistRdDat       ( GLBFPS_DistRdDat      ),
    .GLBFPS_DistRdDatVld    ( GLBFPS_DistRdDatVld   ),
    .FPSGLB_DistRdDatRdy    ( FPSGLB_DistRdDatRdy   ),
    .FPSGLB_DistWrAddr      ( FPSGLB_DistWrAddr     ),
    .FPSGLB_DistWrDat       ( FPSGLB_DistWrDat      ),
    .FPSGLB_DistWrDatVld    ( FPSGLB_DistWrDatVld   ),
    .GLBFPS_DistWrDatRdy    ( GLBFPS_DistWrDatRdy   ),
    .FPSGLB_IdxWrAddr       ( FPSGLB_IdxWrAddr      ),
    .FPSGLB_IdxWrDat        ( FPSGLB_IdxWrDat       ),
    .FPSGLB_IdxWrDatVld     ( FPSGLB_IdxWrDatVld    ),
    .GLBFPS_IdxWrDatRdy     ( GLBFPS_IdxWrDatRdy    ),
    .FPSMON_Dat             ( FPSMON_Dat            )
);

//=====================================================================================================================
// Logic Design: KNN
//=====================================================================================================================
// Read Crd
assign #0.2 TOPGLB_RdPortAddr[GLBRDIDX_KNNCRD]       = KNNGLB_CrdRdAddr;
assign #0.2 TOPGLB_RdPortAddrVld[GLBRDIDX_KNNCRD]    = KNNGLB_CrdRdAddrVld;
assign #0.2 GLBKNN_CrdRdAddrRdy                      = GLBTOP_RdPortAddrRdy[GLBRDIDX_KNNCRD];
assign #0.2 GLBKNN_CrdRdDat                          = {GLBTOP_RdPortDat[GLBRDIDX_FPSDST], GLBTOP_RdPortDat[GLBRDIDX_FPSCRD +: NUMSRAM_RDCRD], GLBTOP_RdPortDat[GLBRDIDX_KNNCRD]}; // Borrow
assign #0.2 GLBKNN_CrdRdDatVld                       = GLBTOP_RdPortDatVld[GLBRDIDX_KNNCRD];
assign #0.2 TOPGLB_RdPortDatRdy[GLBRDIDX_KNNCRD]     = KNNGLB_CrdRdDatRdy;

// Read Mask
assign #0.2 TOPGLB_RdPortAddr   [GLBRDIDX_KNNMSK]    = KNNGLB_MaskRdAddr   ;
assign #0.2 TOPGLB_RdPortAddrVld[GLBRDIDX_KNNMSK]    = KNNGLB_MaskRdAddrVld;
assign #0.2 TOPGLB_RdPortDatRdy [GLBRDIDX_KNNMSK]    = KNNGLB_MaskRdDatRdy ;
assign #0.2 GLBKNN_MaskRdAddrRdy                     = GLBTOP_RdPortAddrRdy [GLBRDIDX_KNNMSK];
assign #0.2 GLBKNN_MaskRdDat                         = GLBTOP_RdPortDat     [GLBRDIDX_KNNMSK];
assign #0.2 GLBKNN_MaskRdDatVld                      = GLBTOP_RdPortDatVld  [GLBRDIDX_KNNMSK];

// Read IdxMask (Point Pruning)
assign #0.2 TOPGLB_RdPortAddr   [GLBRDIDX_KNNIDM]    = KNNGLB_IdxMaskRdAddr;
assign #0.2 TOPGLB_RdPortAddrVld[GLBRDIDX_KNNIDM]    = KNNGLB_IdxMaskRdAddrVld;
assign #0.2 TOPGLB_RdPortDatRdy [GLBRDIDX_KNNIDM]    = KNNGLB_IdxMaskRdDatRdy;
assign #0.2 GLBKNN_IdxMaskRdAddrRdy                  = GLBTOP_RdPortAddrRdy[GLBRDIDX_KNNIDM];
assign #0.2 GLBKNN_IdxMaskRdDat                      = GLBTOP_RdPortDat    [GLBRDIDX_KNNIDM];
assign #0.2 GLBKNN_IdxMaskRdDatVld                   = GLBTOP_RdPortDatVld [GLBRDIDX_KNNIDM];


// Write Map
assign #0.2 TOPGLB_WrPortAddr   [GLBWRIDX_KNNMAP]   = KNNGLB_MapWrAddr;
assign #0.2 TOPGLB_WrPortDat    [GLBWRIDX_KNNMAP]   = KNNGLB_MapWrDat;
assign #0.2 TOPGLB_WrPortDatVld [GLBWRIDX_KNNMAP]   = KNNGLB_MapWrDatVld;
assign #0.2 GLBKNN_MapWrDatRdy                      = GLBTOP_WrPortDatRdy[GLBWRIDX_KNNMAP];

assign Cfg_KNNBorrowFPS = CCUKNN_CfgInfo[10];

KUA#(
    .KNNISA_WIDTH         ( KNNISA_WIDTH    ),
    .SRAM_WIDTH           ( SRAM_WIDTH      ),
    .KNNCRD_MAXPARA       ( KNNCRD_MAXPARA  ),
    .IDX_WIDTH            ( IDX_WIDTH       ),
    .MAP_WIDTH            ( MAP_WIDTH       ),
    .CRD_WIDTH            ( CRD_WIDTH       ),
    .NUM_SORT_CORE        ( NUM_SORT_CORE   ),
    .KNNMON_WIDTH         ( KNNMON_WIDTH    ),
    .CRD_MAXDIM           ( CRD_MAXDIM      ),
    .DATA_WIDTH           ( BYTE_WIDTH      ),
    .SHF_ADDR_WIDTH       ( SHF_ADDR_WIDTH  ),
    .ADDR_WIDTH           ( ADDR_WIDTH      ) 
)u_KUA(
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .CCUKNN_CfgVld      ( CCUKNN_CfgVld         ),
    .KNNCCU_CfgRdy      ( KNNCCU_CfgRdy         ),
    .CCUKNN_CfgInfo     ( CCUKNN_CfgInfo        ),
    .KNNGLB_CrdRdAddr   ( KNNGLB_CrdRdAddr      ),
    .KNNGLB_CrdRdAddrVld( KNNGLB_CrdRdAddrVld   ),
    .GLBKNN_CrdRdAddrRdy( GLBKNN_CrdRdAddrRdy   ),
    .GLBKNN_CrdRdDat    ( GLBKNN_CrdRdDat       ),
    .GLBKNN_CrdRdDatVld ( GLBKNN_CrdRdDatVld    ),
    .KNNGLB_CrdRdDatRdy ( KNNGLB_CrdRdDatRdy    ),
    .KNNGLB_MaskRdAddr   ( KNNGLB_MaskRdAddr    ),
    .KNNGLB_MaskRdAddrVld( KNNGLB_MaskRdAddrVld ),
    .GLBKNN_MaskRdAddrRdy( GLBKNN_MaskRdAddrRdy ),
    .GLBKNN_MaskRdDat    ( GLBKNN_MaskRdDat     ),
    .GLBKNN_MaskRdDatVld ( GLBKNN_MaskRdDatVld  ),
    .KNNGLB_MaskRdDatRdy ( KNNGLB_MaskRdDatRdy  ),
    .KNNGLB_MapWrAddr   ( KNNGLB_MapWrAddr      ),
    .KNNGLB_MapWrDat    ( KNNGLB_MapWrDat       ),
    .KNNGLB_MapWrDatVld ( KNNGLB_MapWrDatVld    ),
    .GLBKNN_MapWrDatRdy ( GLBKNN_MapWrDatRdy    ),
    .KNNGLB_IdxMaskRdAddr   ( KNNGLB_IdxMaskRdAddr   ),
    .KNNGLB_IdxMaskRdAddrVld( KNNGLB_IdxMaskRdAddrVld),
    .GLBKNN_IdxMaskRdAddrRdy( GLBKNN_IdxMaskRdAddrRdy),
    .GLBKNN_IdxMaskRdDat    ( GLBKNN_IdxMaskRdDat    ),
    .GLBKNN_IdxMaskRdDatVld ( GLBKNN_IdxMaskRdDatVld ),
    .KNNGLB_IdxMaskRdDatRdy ( KNNGLB_IdxMaskRdDatRdy ),
    .KNNMON_Dat         ( KNNMON_Dat            )
);

//=====================================================================================================================
// Logic Design: SYA
//=====================================================================================================================
// Read Act
generate
    for(gv_i=0; gv_i<SYAIOMAXWIDTH/SRAM_WIDTH; gv_i =gv_i +1) begin: GEN_SYAGLB_ActRdPort
        assign #0.2 TOPGLB_RdPortAddrVld [GLBRDIDX_SYAACT + gv_i]    = SYAGLB_ActRdAddrVld;
        assign #0.2 TOPGLB_RdPortAddr    [GLBRDIDX_SYAACT + gv_i]    = SYAGLB_ActRdAddr;
        assign #0.2 TOPGLB_RdPortDatRdy  [GLBRDIDX_SYAACT + gv_i]    = SYAGLB_ActRdDatRdy;
    end
endgenerate

assign #0.2 GLBSYA_ActRdAddrRdy      = GLBTOP_RdPortAddrRdy [GLBRDIDX_SYAACT]; // low 1 bit is enough
assign #0.2 GLBSYA_ActRdDat          = GLBTOP_RdPortDat     [GLBRDIDX_SYAACT];
assign #0.2 GLBSYA_ActRdDatVld       = GLBTOP_RdPortDatVld  [GLBRDIDX_SYAACT];

// Read Wgt
assign #0.2 TOPGLB_RdPortAddrVld[GLBRDIDX_SYAWGT]    = SYAGLB_WgtRdAddrVld;
assign #0.2 TOPGLB_RdPortAddr[GLBRDIDX_SYAWGT]       = SYAGLB_WgtRdAddr;
assign #0.2 GLBSYA_WgtRdAddrRdy                      = GLBTOP_RdPortAddrRdy[GLBRDIDX_SYAWGT];
assign #0.2 GLBSYA_WgtRdDat                          = GLBTOP_RdPortDat[GLBRDIDX_SYAWGT];
assign #0.2 GLBSYA_WgtRdDatVld                       = GLBTOP_RdPortDatVld[GLBRDIDX_SYAWGT];
assign #0.2 TOPGLB_RdPortDatRdy[GLBRDIDX_SYAWGT]     = SYAGLB_WgtRdDatRdy;

// Write Ofm
generate 
    for(gv_i=0; gv_i<SYAIOMAXWIDTH/SRAM_WIDTH; gv_i=gv_i+1) begin: GEN_SYAGLB_OfmWrPort
        assign #0.2 TOPGLB_WrPortAddr  [GLBWRIDX_SYAOFM + gv_i]      = SYAGLB_OfmWrAddr;
        assign #0.2 TOPGLB_WrPortDat   [GLBWRIDX_SYAOFM + gv_i]      = SYAGLB_OfmWrDat[SRAM_WIDTH*gv_i +: SRAM_WIDTH];
        assign #0.2 TOPGLB_WrPortDatVld[GLBWRIDX_SYAOFM + gv_i]      = SYAGLB_OfmWrDatVld;
    end
endgenerate
assign #0.2 GLBSYA_OfmWrDatRdy                       = GLBTOP_WrPortDatRdy[GLBWRIDX_SYAOFM]; // 1 port is enough

SYA#(
    .SYAISA_WIDTH(SYAISA_WIDTH  ),
    .ACT_WIDTH ( ACT_WIDTH      ), 
    .WGT_WIDTH ( ACT_WIDTH      ),
    .NUM_ROW   ( SYA_NUM_ROW    ), 
    .NUM_COL   ( SYA_NUM_COL    ), 
    .NUM_BANK  ( SYA_NUM_BANK   ), 
    .SRAM_WIDTH( SRAM_WIDTH     ),
    .ADDR_WIDTH( ADDR_WIDTH     ),
    .QNTSL_WIDTH( QNTSL_WIDTH   ),
    .CHN_WIDTH ( CHN_WIDTH      ),
    .IDX_WIDTH ( IDX_WIDTH      ),
    .SYAMON_WIDTH(SYAMON_WIDTH  )
)u_SYA(
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .CCUSYA_CfgVld      ( CCUSYA_CfgVld         ),
    .SYACCU_CfgRdy      ( SYACCU_CfgRdy         ),
    .CCUSYA_CfgInfo     ( CCUSYA_CfgInfo        ),
    .SYAGLB_ActRdAddr   ( SYAGLB_ActRdAddr      ),
    .SYAGLB_ActRdAddrVld( SYAGLB_ActRdAddrVld   ),
    .GLBSYA_ActRdAddrRdy( GLBSYA_ActRdAddrRdy   ),
    .GLBSYA_ActRdDat    ( GLBSYA_ActRdDat       ),
    .GLBSYA_ActRdDatVld ( GLBSYA_ActRdDatVld    ),
    .SYAGLB_ActRdDatRdy ( SYAGLB_ActRdDatRdy    ),
    .SYAGLB_WgtRdAddr   ( SYAGLB_WgtRdAddr      ),
    .SYAGLB_WgtRdAddrVld( SYAGLB_WgtRdAddrVld   ),
    .GLBSYA_WgtRdAddrRdy( GLBSYA_WgtRdAddrRdy   ),
    .GLBSYA_WgtRdDat    ( GLBSYA_WgtRdDat       ),
    .GLBSYA_WgtRdDatVld ( GLBSYA_WgtRdDatVld    ),
    .SYAGLB_WgtRdDatRdy ( SYAGLB_WgtRdDatRdy    ),
    .SYAGLB_OfmWrDat    ( SYAGLB_OfmWrDat       ),
    .SYAGLB_OfmWrAddr   ( SYAGLB_OfmWrAddr      ),
    .SYAGLB_OfmWrDatVld ( SYAGLB_OfmWrDatVld    ),
    .GLBSYA_OfmWrDatRdy ( GLBSYA_OfmWrDatRdy    ),
    .SYAMON_Dat         ( SYAMON_Dat            )
);

//=====================================================================================================================
// Logic Design: POL
//=====================================================================================================================
// Read Map
assign #0.2 TOPGLB_RdPortAddrVld[GLBRDIDX_POLMAP]    = POLGLB_MapRdAddrVld;
assign #0.2 TOPGLB_RdPortAddr[GLBRDIDX_POLMAP]       = POLGLB_MapRdAddr;
assign #0.2 GLBPOL_MapRdAddrRdy                      = GLBTOP_RdPortAddrRdy[GLBRDIDX_POLMAP];
assign #0.2 GLBPOL_MapRdDat                          = GLBTOP_RdPortDat[GLBRDIDX_POLMAP];
assign #0.2 GLBPOL_MapRdDatVld                       = GLBTOP_RdPortDatVld[GLBRDIDX_POLMAP];
assign #0.2 TOPGLB_RdPortDatRdy[GLBRDIDX_POLMAP]     = POLGLB_MapRdDatRdy;

// Read Ofm
generate
    for(gv_i = 0; gv_i < POOL_CORE; gv_i = gv_i + 1) begin: GEN_POLGLB_OfmRdPort
        assign #0.2 TOPGLB_RdPortAddr[GLBRDIDX_POLOFM + gv_i]    = POLGLB_OfmRdAddr[gv_i];
        assign #0.2 GLBPOL_OfmRdDat  [gv_i]                      = GLBTOP_RdPortDat[GLBRDIDX_POLOFM + gv_i];
    end
endgenerate
assign #0.2 TOPGLB_RdPortAddrVld[GLBRDIDX_POLOFM +: POOL_CORE]   = POLGLB_OfmRdAddrVld;
assign #0.2 GLBPOL_OfmRdAddrRdy                                  = GLBTOP_RdPortAddrRdy[GLBRDIDX_POLOFM +: POOL_CORE];
assign #0.2 GLBPOL_OfmRdDatVld                                   = GLBTOP_RdPortDatVld[GLBRDIDX_POLOFM +: POOL_CORE];
assign #0.2 TOPGLB_RdPortDatRdy[GLBRDIDX_POLOFM +: POOL_CORE]    = POLGLB_OfmRdDatRdy;

// Write Ofm
assign #0.2 TOPGLB_WrPortAddr[GLBWRIDX_POLOFM]   = POLGLB_OfmWrAddr;
assign #0.2 TOPGLB_WrPortDat[GLBWRIDX_POLOFM]    = POLGLB_OfmWrDat;
assign #0.2 TOPGLB_WrPortDatVld[GLBWRIDX_POLOFM] = POLGLB_OfmWrDatVld;
assign #0.2 GLBPOL_OfmWrDatRdy                   = GLBTOP_WrPortDatRdy[GLBWRIDX_POLOFM];

assign #0.2 TOPGLB_WrPortAddr[GLBWRIDX_POLIDM]   = POLGLB_IdxMaskWrAddr;
assign #0.2 TOPGLB_WrPortDat[GLBWRIDX_POLIDM]    = POLGLB_IdxMaskWrDat;
assign #0.2 TOPGLB_WrPortDatVld[GLBWRIDX_POLIDM] = POLGLB_IdxMaskWrDatVld;
assign #0.2 GLBPOL_IdxMaskWrDatRdy               = GLBTOP_WrPortDatRdy[GLBWRIDX_POLIDM];

assign Cfg_PortSelPOL = CCUPOL_CfgInfo[10];
POL#(
    .POLISA_WIDTH         ( POLISA_WIDTH    ),
    .IDX_WIDTH            ( IDX_WIDTH       ),
    .ACT_WIDTH            ( ACT_WIDTH       ),
    .POOL_COMP_CORE       ( POOL_COMP_CORE  ),
    .MAP_WIDTH            ( MAP_WIDTH       ),
    .POOL_CORE            ( POOL_CORE       ),
    .CHN_WIDTH            ( CHN_WIDTH       ),
    .SRAM_WIDTH           ( SRAM_WIDTH      ),
    .POLMON_WIDTH         ( POLMON_WIDTH    ) 
)u_POL(
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .CCUPOL_CfgVld      ( CCUPOL_CfgVld         ),
    .POLCCU_CfgRdy      ( POLCCU_CfgRdy         ),
    .CCUPOL_CfgInfo     ( CCUPOL_CfgInfo        ),
    .POLGLB_MapRdAddr   ( POLGLB_MapRdAddr      ),
    .POLGLB_MapRdAddrVld( POLGLB_MapRdAddrVld   ),
    .GLBPOL_MapRdAddrRdy( GLBPOL_MapRdAddrRdy   ),
    .GLBPOL_MapRdDatVld ( GLBPOL_MapRdDatVld    ),
    .GLBPOL_MapRdDat    ( GLBPOL_MapRdDat       ),
    .POLGLB_MapRdDatRdy ( POLGLB_MapRdDatRdy    ),
    .POLGLB_OfmRdAddrVld( POLGLB_OfmRdAddrVld   ),
    .POLGLB_OfmRdAddr   ( POLGLB_OfmRdAddr      ),
    .GLBPOL_OfmRdAddrRdy( GLBPOL_OfmRdAddrRdy   ),
    .GLBPOL_OfmRdDat    ( GLBPOL_OfmRdDat       ),
    .GLBPOL_OfmRdDatVld ( GLBPOL_OfmRdDatVld    ),
    .POLGLB_OfmRdDatRdy ( POLGLB_OfmRdDatRdy    ),
    .POLGLB_OfmWrAddr   ( POLGLB_OfmWrAddr      ),
    .POLGLB_OfmWrDat    ( POLGLB_OfmWrDat       ),
    .POLGLB_OfmWrDatVld ( POLGLB_OfmWrDatVld    ),
    .GLBPOL_OfmWrDatRdy ( GLBPOL_OfmWrDatRdy    ),
    .POLGLB_IdxMaskWrAddr  ( POLGLB_IdxMaskWrAddr  ),
    .POLGLB_IdxMaskWrDat   ( POLGLB_IdxMaskWrDat   ),
    .POLGLB_IdxMaskWrDatVld( POLGLB_IdxMaskWrDatVld),
    .GLBPOL_IdxMaskWrDatRdy( GLBPOL_IdxMaskWrDatRdy),
    .POLMON_Dat         ( POLMON_Dat            )
);

//=====================================================================================================================
// Logic Design: GLB
//=====================================================================================================================
GLB#(
    .NUM_BANK                ( NUM_BANK         ),
    .SRAM_WIDTH              ( SRAM_WIDTH       ),
    .SRAM_WORD               ( SRAM_WORD        ),
    .ADDR_WIDTH              ( ADDR_WIDTH       ),
    .NUM_WRPORT              ( GLB_NUM_WRPORT   ),
    .NUM_RDPORT              ( GLB_NUM_RDPORT   ),
    .GLBMON_WIDTH            ( GLBMON_WIDTH     )
)u_GLB(
    .clk                        ( clk                       ),
    .rst_n                      ( rst_n                     ),
    .TOPGLB_CfgPortBankFlag     ( TOPGLB_CfgPortBankFlag    ),
    .TOPGLB_CfgPortOffEmptyFull ( TOPGLB_CfgPortOffEmptyFull),
    .TOPGLB_WrPortDat           ( TOPGLB_WrPortDat          ),
    .TOPGLB_WrPortDatVld        ( TOPGLB_WrPortDatVld       ),
    .GLBTOP_WrPortDatRdy        ( GLBTOP_WrPortDatRdy       ),
    .TOPGLB_WrPortAddr          ( TOPGLB_WrPortAddr         ),
    .GLBTOP_WrFull              ( GLBTOP_WrFull             ),
    .TOPGLB_RdPortAddr          ( TOPGLB_RdPortAddr         ),
    .TOPGLB_RdPortAddrVld       ( TOPGLB_RdPortAddrVld      ),
    .GLBTOP_RdPortAddrRdy       ( GLBTOP_RdPortAddrRdy      ),
    .GLBTOP_RdPortDat           ( GLBTOP_RdPortDat          ),
    .GLBTOP_RdPortDatVld        ( GLBTOP_RdPortDatVld       ),
    .TOPGLB_RdPortDatRdy        ( TOPGLB_RdPortDatRdy       ),
    .GLBTOP_RdEmpty             ( GLBTOP_RdEmpty            ),
    .GLBMON_Dat                 ( GLBMON_Dat                )
);

assign #0.2 {
    TOPGLB_CfgPortOffEmptyFull[GLBWRIDX_FPSCRD                 ],
    TOPGLB_CfgPortOffEmptyFull[GLBWRIDX_FPSIDX                 ],
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSDST +: NUMSRAM_DIST],
    TOPGLB_CfgPortOffEmptyFull[GLBWRIDX_FPSDST                  +: NUMSRAM_DIST],
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSMSK],
    TOPGLB_CfgPortOffEmptyFull[GLBWRIDX_FPSMSK                 ],
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSCRD +: NUMSRAM_RDCRD] 
} = CCUFPS_CfgInfo[FPSISA_WIDTH -1 -: 16];
assign #0.2 {
    TOPGLB_CfgPortBankFlag    [GLBWRIDX_FPSCRD                 ],
    TOPGLB_CfgPortBankFlag    [GLBWRIDX_FPSIDX                 ],
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_FPSDST+: NUMSRAM_DIST],
    TOPGLB_CfgPortBankFlag    [GLBWRIDX_FPSDST                 +: NUMSRAM_DIST],
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_FPSMSK],
    TOPGLB_CfgPortBankFlag    [GLBWRIDX_FPSMSK                 ],
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_FPSCRD+: NUMSRAM_RDCRD] 
} = CCUFPS_CfgInfo[FPSISA_WIDTH -17 -: NUM_BANK*(4 + NUMSRAM_RDCRD + NUMSRAM_DIST*2)];

assign #0.2 {
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_KNNIDM],
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_KNNMSK],
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_KNNCRD],
    TOPGLB_CfgPortOffEmptyFull[GLBWRIDX_KNNMAP                 ]
} = CCUKNN_CfgInfo[KNNISA_WIDTH -1 -: 8];
assign #0.2 {
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_KNNIDM],
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_KNNMSK],
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_KNNCRD],
    TOPGLB_CfgPortBankFlag    [GLBWRIDX_KNNMAP                 ]
} = CCUKNN_CfgInfo[KNNISA_WIDTH -9 -: NUM_BANK*4];

assign #0.2 {
    TOPGLB_CfgPortOffEmptyFull[GLBWRIDX_SYAOFM                  ], 
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_SYAWGT ], 
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_SYAACT ]  
} = CCUSYA_CfgInfo[SYAISA_WIDTH -1 -: 8];
assign #0.2 {
    TOPGLB_CfgPortBankFlag    [GLBWRIDX_SYAOFM +: SYAIOMAXWIDTH/SRAM_WIDTH],  
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_SYAWGT +: SYAIOMAXWIDTH/SRAM_WIDTH],  
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_SYAACT +: SYAIOMAXWIDTH/SRAM_WIDTH]   
} = CCUSYA_CfgInfo[SYAISA_WIDTH -9 -: NUM_BANK*(SYAIOMAXWIDTH/SRAM_WIDTH)*3];

assign #0.2 {
    TOPGLB_CfgPortOffEmptyFull  [GLB_NUM_WRPORT + GLBRDIDX_POLOFM +: POOL_CORE] ,  
    TOPGLB_CfgPortOffEmptyFull  [GLB_NUM_WRPORT + GLBRDIDX_POLMAP],
    TOPGLB_CfgPortOffEmptyFull  [GLBWRIDX_POLIDM                 ],                  
    TOPGLB_CfgPortOffEmptyFull  [GLBWRIDX_POLOFM                 ]                  
} = CCUPOL_CfgInfo[POLISA_WIDTH -1 -: 16];
assign #0.2 {
    TOPGLB_CfgPortBankFlag      [GLB_NUM_WRPORT + GLBRDIDX_POLOFM +: POOL_CORE] ,  
    TOPGLB_CfgPortBankFlag      [GLB_NUM_WRPORT + GLBRDIDX_POLMAP],
    TOPGLB_CfgPortBankFlag      [GLBWRIDX_POLIDM                 ],                  
    TOPGLB_CfgPortBankFlag      [GLBWRIDX_POLOFM                 ]                  
} = CCUPOL_CfgInfo[POLISA_WIDTH -17 -: NUM_BANK*(3 + POOL_CORE)];

assign #0.2 { 
    TOPGLB_CfgPortOffEmptyFull  [GLB_NUM_WRPORT + GLBRDIDX_GICGLB   ],
    TOPGLB_CfgPortOffEmptyFull  [GLBWRIDX_GICGLB                    ]
} = CCUGIC_CfgInfo[GICISA_WIDTH -1 -: 8];
assign #0.2 {
    TOPGLB_CfgPortBankFlag      [GLB_NUM_WRPORT + GLBRDIDX_GICGLB   ],
    TOPGLB_CfgPortBankFlag      [GLBWRIDX_GICGLB                    ]
} = CCUGIC_CfgInfo[GICISA_WIDTH -9 -: NUM_BANK*2];

//=====================================================================================================================
// Logic Design: GIC
//=====================================================================================================================
// GLB RdPort
assign #0.2 TOPGLB_RdPortAddr   [GLBRDIDX_GICGLB]= GICGLB_RdAddr;
assign #0.2 TOPGLB_RdPortAddrVld[GLBRDIDX_GICGLB]= GICGLB_RdAddrVld;
assign #0.2 GLBGIC_RdAddrRdy                     = GLBTOP_RdPortAddrRdy  [GLBRDIDX_GICGLB];
assign #0.2 GLBGIC_RdDat                         = GLBTOP_RdPortDat      [GLBRDIDX_GICGLB];
assign #0.2 GLBGIC_RdDatVld                      = GLBTOP_RdPortDatVld   [GLBRDIDX_GICGLB];
assign #0.2 TOPGLB_RdPortDatRdy [GLBRDIDX_GICGLB]= GICGLB_RdDatRdy;
assign #0.2 GLBGIC_RdEmpty                       = GLBTOP_RdEmpty        [GLBRDIDX_GICGLB];

// GLB WrPort
assign #0.2 TOPGLB_WrPortAddr    [GLBWRIDX_GICGLB]   = GICGLB_WrAddr;
assign #0.2 TOPGLB_WrPortDat     [GLBWRIDX_GICGLB]   = GICGLB_WrDat;
assign #0.2 TOPGLB_WrPortDatVld  [GLBWRIDX_GICGLB]   = GICGLB_WrDatVld;
assign #0.2 GLBGIC_WrDatRdy                          = GLBTOP_WrPortDatRdy   [GLBWRIDX_GICGLB];
assign #0.2 GLBGIC_WrFull                            = GLBTOP_WrFull         [GLBWRIDX_GICGLB];

GIC#(
    .GICISA_WIDTH     ( GICISA_WIDTH    ),
    .PORT_WIDTH       ( PORT_WIDTH      ),
    .SRAM_WIDTH       ( SRAM_WIDTH      ),
    .ADDR_WIDTH       ( ADDR_WIDTH      ),
    .DRAM_ADDR_WIDTH  ( DRAM_ADDR_WIDTH ),
    .GICMON_WIDTH     ( GICMON_WIDTH    )
)u_GIC(
    .clk                ( clk               ),
    .rst_n              ( rst_n             ),
    .CCUGIC_CfgVld      ( CCUGIC_CfgVld     ),
    .GICCCU_CfgRdy      ( GICCCU_CfgRdy     ),
    .CCUGIC_CfgInfo     ( CCUGIC_CfgInfo    ),
    .GICITF_CmdVld      ( GICITF_CmdVld     ),
    .GICITF_Dat         ( GICITF_Dat        ),
    .GICITF_DatVld      ( GICITF_DatVld     ),
    .GICITF_DatLast     ( GICITF_DatLast    ),
    .ITFGIC_DatRdy      ( ITFGIC_DatRdy     ),
    .ITFGIC_Dat         ( ITFGIC_Dat        ),
    .ITFGIC_DatVld      ( ITFGIC_DatVld     ),
    .ITFGIC_DatLast     ( ITFGIC_DatLast    ),
    .GICITF_DatRdy      ( GICITF_DatRdy     ),
    .GICGLB_RdAddr      ( GICGLB_RdAddr     ),
    .GICGLB_RdAddrVld   ( GICGLB_RdAddrVld  ),
    .GLBGIC_RdAddrRdy   ( GLBGIC_RdAddrRdy  ),
    .GLBGIC_RdDat       ( GLBGIC_RdDat      ),
    .GLBGIC_RdDatVld    ( GLBGIC_RdDatVld   ),
    .GICGLB_RdDatRdy    ( GICGLB_RdDatRdy   ),
    .GLBGIC_RdEmpty     ( GLBGIC_RdEmpty    ),
    .GICGLB_WrAddr      ( GICGLB_WrAddr     ),
    .GICGLB_WrDat       ( GICGLB_WrDat      ),
    .GICGLB_WrDatVld    ( GICGLB_WrDatVld   ),
    .GLBGIC_WrDatRdy    ( GLBGIC_WrDatRdy   ),
    .GLBGIC_WrFull      ( GLBGIC_WrFull     ),
    .GICMON_Dat         ( GICMON_Dat        )
);

//=====================================================================================================================
// Logic Design: ITF
//=====================================================================================================================
ITF #(
    .PORT_WIDTH             ( PORT_WIDTH            ),
    .OPNUM                  ( OPNUM                 ),
    .ASYNC_FIFO_ADDR_WIDTH  ( ASYNC_FIFO_ADDR_WIDTH ),
    .FBDIV_WIDTH            ( FBDIV_WIDTH           ) 
) u_ITF(
    .I_BypAsysnFIFO_PAD ( I_BypAsysnFIFO_PAD),
    .I_BypOE_PAD        ( I_BypOE_PAD       ),
    .I_SwClk_PAD        ( I_SwClk_PAD       ),
    .O_SysClk_PAD       ( O_SysClk_PAD      ),
    .O_OffClk_PAD       ( O_OffClk_PAD      ),
    .I_SysRst_n_PAD     ( I_SysRst_n_PAD    ),
    .I_SysClk_PAD       ( I_SysClk_PAD      ),
    .I_OffClk_PAD       ( I_OffClk_PAD      ),
    .O_CfgRdy_PAD       ( O_CfgRdy_PAD      ),
    .O_DatOE_PAD        ( O_DatOE_PAD       ),
    .I_OffOE_PAD        ( I_OffOE_PAD       ),
    .I_DatVld_PAD       ( I_DatVld_PAD      ),
    .I_DatLast_PAD      ( I_DatLast_PAD     ),
    .O_DatRdy_PAD       ( O_DatRdy_PAD      ),
    .O_DatVld_PAD       ( O_DatVld_PAD      ),
    .O_DatLast_PAD      ( O_DatLast_PAD     ),
    .I_DatRdy_PAD       ( I_DatRdy_PAD      ),
    .I_ISAVld_PAD       ( I_ISAVld_PAD      ),
    .O_CmdVld_PAD       ( O_CmdVld_PAD      ),
    .IO_Dat_PAD         ( IO_Dat_PAD        ),
    // .I_BypPLL_PAD       ( I_BypPLL_PAD      ),
    // .I_FBDIV_PAD        ( I_FBDIV_PAD       ),
    // .O_PLLLock_PAD      ( O_PLLLock_PAD     ),
    .CCUITF_CfgRdy      ( CCUITF_CfgRdy     ),
    .ITFCCU_ISARdDat    ( ITFCCU_ISARdDat   ),
    .ITFCCU_ISARdDatVld ( ITFCCU_ISARdDatVld),
    .ITFCCU_ISARdDatLast( ITFCCU_ISARdDatLast),
    .CCUITF_ISARdDatRdy ( CCUITF_ISARdDatRdy),
    .GICITF_Dat         ( GICITF_Dat        ),
    .GICITF_DatVld      ( GICITF_DatVld     ),
    .GICITF_DatLast     ( GICITF_DatLast    ),
    .GICITF_CmdVld      ( GICITF_CmdVld     ),
    .ITFGIC_DatRdy      ( ITFGIC_DatRdy     ),
    .ITFGIC_Dat         ( ITFGIC_Dat        ),
    .ITFGIC_DatVld      ( ITFGIC_DatVld     ),
    .ITFGIC_DatLast     ( ITFGIC_DatLast    ),
    .GICITF_DatRdy      ( GICITF_DatRdy     ),
    .MONITF_Dat         ( MONITF_Dat        ),
    .MONITF_DatVld      ( MONITF_DatVld     ),
    .MONITF_DatLast     ( MONITF_DatLast    ),
    .ITFMON_DatRdy      ( ITFMON_DatRdy     ),
    .clk                ( clk               ),
    .rst_n              ( rst_n             )
);

//=====================================================================================================================
// Logic Design: Monitor
//=====================================================================================================================
MON#(
    .MONISA_WIDTH    ( MONISA_WIDTH ),
    .PORT_WIDTH      ( PORT_WIDTH   ),
    .MON_WIDTH       ( TOPMON_WIDTH )
)u_MON(
    .clk             ( clk             ),
    .rst_n           ( rst_n           ),
    .CCUMON_CfgVld   ( CCUMON_CfgVld   ),
    .MONCCU_CfgRdy   ( MONCCU_CfgRdy   ),
    .CCUMON_CfgInfo  ( CCUMON_CfgInfo  ),
    .TOPMON_Dat      ( TOPMON_Dat      ),
    .MONITF_Dat      ( MONITF_Dat      ),
    .MONITF_DatVld   ( MONITF_DatVld   ),
    .MONITF_DatLast  ( MONITF_DatLast  ),
    .ITFMON_DatRdy   ( ITFMON_DatRdy   )
);
assign #0.2 TOPMON_Dat = {CCUMON_Dat, GICMON_Dat, GLBMON_Dat, POLMON_Dat, SYAMON_Dat, KNNMON_Dat, FPSMON_Dat};

endmodule
