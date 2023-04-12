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
    // CCU
    parameter NUM_MODULE     = 6,
    parameter BYTE_WIDTH     = 8,

    // FPS
    parameter NUM_FPC        = 16, 
    parameter CUTMASK_WIDTH  = 64, // Reduce BW
    
    // KNN
    parameter NUM_SORT_CORE  = 10, // Decided by SRAM/Crd

    // SYA
    parameter SYA_NUM_ROW    = 16,
    parameter SYA_NUM_COL    = 16,
    parameter SYA_NUM_BANK   = 4,

    // POL
    parameter POOL_CORE      = 8,
    parameter POOL_COMP_CORE = 32, // SRAM/BYTE 

    // ITF
    parameter PORT_WIDTH     = 128, 
    parameter DRAM_ADDR_WIDTH= 32, 

    // GLB
    parameter SRAM_WIDTH     = 256, 
    parameter SRAM_WORD      = 128,
    parameter ADDR_WIDTH     = 16,
    parameter GLB_NUM_RDPORT = 9 + POOL_CORE - 1,
    parameter GLB_NUM_WRPORT = 8, 
    parameter NUM_BANK       = 32,

    // NetWork Parameters
    parameter NUM_LAYER_WIDTH= 20,
    parameter CRD_WIDTH      = 8,   
    parameter CRD_DIM        = 3,  
    parameter IDX_WIDTH      = 16,
    parameter MAP_WIDTH      = 5,
    parameter ACT_WIDTH      = 8,
    parameter CHN_WIDTH      = 16,
    parameter QNTSL_WIDTH    = 16,
    parameter MASK_ADDR_WIDTH = $clog2(2**IDX_WIDTH*NUM_SORT_CORE/SRAM_WIDTH),
    parameter OPNUM         = NUM_MODULE
    )(
    input                           I_SysRst_n_PAD    , 
    input                           I_SysClk_PAD      , 
    input                           I_BypAsysnFIFO_PAD, 
    output [OPNUM           -1 : 0] O_CfgRdy_PAD      ,
    input                           I_ISAVld_PAD      ,
    inout   [PORT_WIDTH     -1 : 0] IO_Dat_PAD        , 
    inout                           IO_DatVld_PAD     ,
    inout                           OI_DatRdy_PAD     , 
    output                          O_DatOE_PAD       ,
    output                          O_CmdVld_PAD      

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
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

localparam DISTSQR_WIDTH     =  CRD_WIDTH*2 + $clog2(CRD_DIM);
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

// --------------------------------------------------------------------------------------------------------------------
// TOP
wire                            clk;
wire                            rst_n;
genvar                          gv_i;

localparam INPUT_PAD = 1'b1, OUTPUT_PAD = 1'b0;

wire                          I_SysRst_n    ; 
wire                          I_SysClk      ; 
wire                          I_BypAsysnFIFO; 
wire [OPNUM           -1 : 0] O_CfgRdy      ;
wire                          I_ISAVld      ;
wire                          O_DatOE       ;
wire                          O_CmdVld     ;

wire   [PORT_WIDTH          -1 : 0] I_Dat   ; 
wire   [PORT_WIDTH          -1 : 0] O_Dat   ; 
wire                                I_DatVld;
wire                                O_DatVld;
wire                                O_DatRdy; 
wire                                I_DatRdy; 

// --------------------------------------------------------------------------------------------------------------------
// CCU 
wire                                  CCUTOP_NetFnh;

    // Configure
wire [PORT_WIDTH              -1 : 0] TOPCCU_ISARdDat     ;             
wire                                  TOPCCU_ISARdDatVld  ;          
wire                                  CCUTOP_ISARdDatRdy  ;
wire                                  CCUITF_CfgVld       ;
wire                                  ITFCCU_CfgRdy       ; 
wire  [BYTE_WIDTH             -1 : 0] CCUITF_CfgInOut        ; 
wire  [DRAM_ADDR_WIDTH        -1 : 0] CCUITF_CfgDRAMBaseAddr ;
wire  [IDX_WIDTH              -1 : 0] CCUITF_CfgGLBBaseAddr  ;
wire  [IDX_WIDTH              -1 : 0] CCUITF_CfgNum          ; 

wire [NUM_FPC             -1 : 0] CCUFPS_CfgVld;
wire [NUM_FPC             -1 : 0] FPSCCU_CfgRdy;        
wire [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgNip;                    
wire [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgNop; 
wire [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgCrdBaseRdAddr ;
wire [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgCrdBaseWrAddr ;
wire [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgIdxBaseWrAddr ;
wire [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgMaskBaseAddr  ;   
wire [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgDistBaseAddr  ;

wire                             CCUKNN_CfgVld;
wire                             KNNCCU_CfgRdy;        
wire [IDX_WIDTH          -1 : 0] CCUKNN_CfgNip;                    
wire [(MAP_WIDTH + 1)    -1 : 0] CCUKNN_CfgK  ; 
wire [IDX_WIDTH          -1 : 0] CCUKNN_CfgCrdRdAddr;
wire [IDX_WIDTH          -1 : 0] CCUKNN_CfgMapWrAddr;

wire                              CCUSYA_CfgVld           ;
wire                              SYACCU_CfgRdy           ;
wire [2                   -1 : 0] CCUSYA_CfgMod           ;
wire                              CCUSYA_CfgOfmPhaseShift    ;
wire [CHN_WIDTH           -1 : 0] CCUSYA_CfgChn           ;         
wire [QNTSL_WIDTH         -1 : 0] CCUSYA_CfgScale         ;        
wire [ACT_WIDTH           -1 : 0] CCUSYA_CfgShift         ;        
wire [ACT_WIDTH           -1 : 0] CCUSYA_CfgZp            ;
wire [IDX_WIDTH           -1 : 0] CCUSYA_CfgNumGrpPerTile;   
wire [IDX_WIDTH           -1 : 0] CCUSYA_CfgNumTilIfm    ;   
wire [IDX_WIDTH           -1 : 0] CCUSYA_CfgNumTilFlt    ;   
wire                              CCUSYA_CfgLopOrd       ;   
wire [ADDR_WIDTH          -1 : 0] CCUSYA_CfgActRdBaseAddr ;
wire [ADDR_WIDTH          -1 : 0] CCUSYA_CfgWgtRdBaseAddr ;
wire [ADDR_WIDTH          -1 : 0] CCUSYA_CfgOfmWrBaseAddr ;

wire  [POOL_CORE              -1 : 0] CCUPOL_CfgVld           ;
wire  [POOL_CORE              -1 : 0] POLCCU_CfgRdy           ;
wire  [(MAP_WIDTH+1)*POOL_CORE-1 : 0] CCUPOL_CfgK             ;
wire  [IDX_WIDTH*POOL_CORE    -1 : 0] CCUPOL_CfgNip           ;
wire  [CHN_WIDTH*POOL_CORE    -1 : 0] CCUPOL_CfgChn           ;
            
wire [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)*NUM_BANK              -1 : 0] CCUTOP_CfgPortBankFlag;
wire [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)                 -1 : 0] CCUTOP_CfgPortOffEmptyFull;
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
wire [SRAM_WIDTH          -1 : 0] GLBFPS_CrdRdDat         ;    
wire                              GLBFPS_CrdRdDatVld      ;    
wire                              FPSGLB_CrdRdDatRdy      ;    

wire [IDX_WIDTH           -1 : 0] FPSGLB_CrdWrAddr        ;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_CrdWrDat         ;   
wire                              FPSGLB_CrdWrDatVld      ;
wire                              GLBFPS_CrdWrDatRdy      ;  

wire [IDX_WIDTH           -1 : 0] FPSGLB_DistRdAddr       ;
wire                              FPSGLB_DistRdAddrVld    ;
wire                              GLBFPS_DistRdAddrRdy    ;
wire [SRAM_WIDTH          -1 : 0] GLBFPS_DistRdDat        ;    
wire                              GLBFPS_DistRdDatVld     ;    
wire                              FPSGLB_DistRdDatRdy     ;    

wire [IDX_WIDTH           -1 : 0] FPSGLB_DistWrAddr       ;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_DistWrDat        ;   
wire                              FPSGLB_DistWrDatVld     ;
wire                              GLBFPS_DistWrDatRdy     ;

wire [IDX_WIDTH           -1 : 0] FPSGLB_IdxWrAddr        ;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_IdxWrDat         ;   
wire                              FPSGLB_IdxWrDatVld      ;
wire                              GLBFPS_IdxWrDatRdy      ;

// --------------------------------------------------------------------------------------------------------------------
// KNN
// Fetch Crd
wire [IDX_WIDTH           -1 : 0] KNNGLB_CrdRdAddr    ;   
wire                              KNNGLB_CrdRdAddrVld ; 
wire                              GLBKNN_CrdRdAddrRdy ;
wire [SRAM_WIDTH          -1 : 0 ]GLBKNN_CrdRdDat     ;        
wire                              GLBKNN_CrdRdDatVld  ;     
wire                              KNNGLB_CrdRdDatRdy  ;

// Output Map of KNN
wire [IDX_WIDTH           -1 : 0] KNNGLB_MapWrAddr    ;
wire [SRAM_WIDTH          -1 : 0] KNNGLB_MapWrDat     ;   
wire                              KNNGLB_MapWrDatVld  ;     
wire                              GLBKNN_MapWrDatRdy  ;

// --------------------------------------------------------------------------------------------------------------------
// SYA
wire [ADDR_WIDTH                  -1:0] SYAGLB_ActRdAddr          ;
wire                                    SYAGLB_ActRdAddrVld       ;
wire                                    GLBSYA_ActRdAddrRdy       ;
wire [ACT_WIDTH*SYA_NUM_ROW*SYA_NUM_BANK  -1:0] GLBSYA_ActRdDat           ;
wire                                    GLBSYA_ActRdDatVld        ;
wire                                    SYAGLB_ActRdDatRdy        ;

wire [ADDR_WIDTH                  -1:0] SYAGLB_WgtRdAddr          ;
wire                                    SYAGLB_WgtRdAddrVld       ;
wire                                    GLBSYA_WgtRdAddrRdy       ;
wire [ACT_WIDTH*SYA_NUM_COL*SYA_NUM_BANK  -1:0] GLBSYA_WgtRdDat           ;
wire                                    GLBSYA_WgtRdDatVld        ;
wire                                    SYAGLB_WgtRdDatRdy        ;

wire [ACT_WIDTH*SYA_NUM_ROW*SYA_NUM_BANK  -1:0] SYAGLB_OfmWrDat           ;
wire [ADDR_WIDTH                  -1:0] SYAGLB_OfmWrAddr          ;
wire                                    SYAGLB_OfmWrDatVld        ;
wire                                    GLBSYA_OfmWrDatRdy        ;

// --------------------------------------------------------------------------------------------------------------------
// POL
wire [IDX_WIDTH                               -1 : 0] POLGLB_MapRdAddr    ;   
wire                                                  POLGLB_MapRdAddrVld ; 
wire                                                  GLBPOL_MapRdAddrRdy ;
wire                                                  GLBPOL_MapRdDatVld     ;
wire [SRAM_WIDTH                              -1 : 0] GLBPOL_MapRdDat     ;
wire                                                  POLGLB_MapRdDatRdy     ;

wire [POOL_CORE                               -1 : 0] POLGLB_OfmRdAddrVld ;
wire [POOL_CORE -1 : 0][IDX_WIDTH             -1 : 0] POLGLB_OfmRdAddr    ;
wire [POOL_CORE                               -1 : 0] GLBPOL_OfmRdAddrRdy ;
wire [POOL_CORE -1 : 0][(ACT_WIDTH*POOL_COMP_CORE) -1 : 0] GLBPOL_OfmRdDat     ;
wire [POOL_CORE                               -1 : 0] GLBPOL_OfmRdDatVld     ;
wire [POOL_CORE                               -1 : 0] POLGLB_OfmRdDatRdy     ;

wire [IDX_WIDTH                             -1 : 0] POLGLB_OfmWrAddr    ;
wire [(ACT_WIDTH*POOL_COMP_CORE)            -1 : 0] POLGLB_OfmWrDat     ;
wire                                                POLGLB_OfmWrDatVld     ;
wire                                                GLBPOL_OfmWrDatRdy     ;

// --------------------------------------------------------------------------------------------------------------------
// ITF
wire                                                ITFPAD_DatOE    ;
wire                                                ITFPAD_CmdVld   ;
wire [PORT_WIDTH                            -1 : 0] ITFPAD_Dat      ;
wire                                                ITFPAD_DatVld   ;
wire                                                PADITF_DatRdy   ;

wire [PORT_WIDTH                            -1 : 0] PADITF_Dat      ;
wire                                                PADITF_DatVld   ;
wire                                                ITFPAD_DatRdy   ;

wire [ADDR_WIDTH                            -1 : 0] ITFGLB_RdAddr    ;
wire                                                ITFGLB_RdAddrVld ;
wire                                                GLBITF_RdAddrRdy ;
wire [SRAM_WIDTH                            -1 : 0] GLBITF_RdDat     ;
wire                                                GLBITF_RdDatVld  ;
wire                                                ITFGLB_RdDatRdy  ;
wire                                                GLBITF_RdEmpty   ;

wire [ADDR_WIDTH                            -1 : 0] ITFGLB_WrAddr    ;
wire [SRAM_WIDTH                            -1 : 0] ITFGLB_WrDat     ; 
wire                                                ITFGLB_WrDatVld  ; 
wire                                                GLBITF_WrDatRdy  ;
wire                                                GLBITF_WrFull    ;

// --------------------------------------------------------------------------------------------------------------------
// GLB
// Configure
wire [NUM_BANK * (GLB_NUM_RDPORT + GLB_NUM_WRPORT)      -1 : 0] TOPGLB_CfgPortBankFlag;
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

//=====================================================================================================================
// Logic Design： TOP
//=====================================================================================================================
assign clk  = I_SysClk;
assign rst_n= I_SysRst_n;


PDUW08DGZ_V_G inst_I_SysRst_n_PAD        (.I(1'b0               ), .OEN(INPUT_PAD),  .REN(1'b0),  .PAD(I_SysRst_n_PAD        ), .C(I_SysRst_n        ));
PDUW08DGZ_V_G inst_I_SysClk_PAD      (.I(1'b0               ), .OEN(INPUT_PAD),  .REN(1'b0),  .PAD(I_SysClk_PAD      ), .C(I_SysClk      ));
PDUW08DGZ_V_G inst_I_BypAsysnFIFO_PAD          (.I(1'b0               ), .OEN(INPUT_PAD),  .REN(1'b0),  .PAD(I_BypAsysnFIFO_PAD          ), .C(I_BypAsysnFIFO          ));
PDUW08DGZ_V_G inst_I_ISAVld_PAD    (.I(1'b0               ), .OEN(INPUT_PAD),  .REN(1'b0),  .PAD(I_ISAVld_PAD    ), .C(I_ISAVld    ));

PDUW08DGZ_V_G inst_O_DatOE_PAD     (.I(O_DatOE     ), .OEN(OUTPUT_PAD), .REN(1'b0),  .PAD(O_DatOE_PAD     ), .C(    ));
PDUW08DGZ_V_G inst_O_CmdVld_PAD    (.I(O_CmdVld    ), .OEN(OUTPUT_PAD), .REN(1'b0),  .PAD(O_CmdVld_PAD    ), .C(    ));

PDUW08DGZ_V_G inst_IO_DatVld_PAD (.I(O_DatVld), .OEN(O_DatOE), .REN(1'b0), .PAD(IO_DatVld_PAD), .C(I_DatVld));
PDUW08DGZ_V_G inst_OI_DatRdy_PAD (.I(O_DatRdy), .OEN(!O_DatOE), .REN(1'b0), .PAD(OI_DatRdy_PAD), .C(I_DatRdy));

generate
    for (gv_i = 0; gv_i < OPNUM; gv_i = gv_i + 1) begin: GEN_O_CfgRdy_PAD
        PDUW08DGZ_V_G inst_O_CfgRdy_PAD    (.I(O_CfgRdy[gv_i]    ), .OEN(OUTPUT_PAD), .REN(1'b0),  .PAD(O_CfgRdy_PAD[gv_i]    ), .C( ));
    end 
endgenerate

generate
    for (gv_i = 0; gv_i < 20; gv_i = gv_i + 1) begin: IO_Dat_PAD_0_19
        PDUW08DGZ_V_G inst_IO_Dat_PAD_0_19 (.I(O_Dat[gv_i]), .OEN(O_DatOE), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate

generate
    for (gv_i = 20; gv_i < 60; gv_i = gv_i + 1) begin: IO_Dat_PAD_20_59
        PDUW08DGZ_H_G inst_IO_Dat_PAD_20_59 (.I(O_Dat[gv_i]), .OEN(O_DatOE), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate

generate
    for (gv_i = 60; gv_i < 90; gv_i = gv_i + 1) begin: IO_Dat_PAD_60_89
        PDUW08DGZ_V_G inst_IO_Dat_PAD_60_89 (.I(O_Dat[gv_i]), .OEN(O_DatOE), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate

generate
    for (gv_i = 90; gv_i < 128; gv_i = gv_i + 1) begin: IO_Dat_PAD_90_127
        PDUW08DGZ_H_G inst_IO_Dat_PAD_90_127 (.I(O_Dat[gv_i]), .OEN(O_DatOE), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate


//=====================================================================================================================
// Logic Design: CCU
//=====================================================================================================================

assign TOPCCU_ISARdDat      = I_ISAVld? I_Dat : 0;
assign TOPCCU_ISARdDatVld   = I_ISAVld? I_DatVld : 0;

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
    .NUM_BANK                ( NUM_BANK         ),
    .NUM_FPC                 ( NUM_FPC          )
)u_CCU(
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .TOPCCU_ISARdDat         ( TOPCCU_ISARdDat         ),
    .TOPCCU_ISARdDatVld      ( TOPCCU_ISARdDatVld      ),
    .CCUTOP_ISARdDatRdy      ( CCUTOP_ISARdDatRdy      ),
    .CCUITF_CfgVld           ( CCUITF_CfgVld           ),
    .ITFCCU_CfgRdy           ( ITFCCU_CfgRdy           ),
    .CCUITF_CfgInOut         ( CCUITF_CfgInOut         ),
    .CCUITF_CfgDRAMBaseAddr  ( CCUITF_CfgDRAMBaseAddr  ),
    .CCUITF_CfgGLBBaseAddr   ( CCUITF_CfgGLBBaseAddr   ),
    .CCUITF_CfgNum           ( CCUITF_CfgNum           ),
    .CCUFPS_CfgVld           ( CCUFPS_CfgVld           ),
    .FPSCCU_CfgRdy           ( FPSCCU_CfgRdy           ),
    .CCUFPS_CfgNip           ( CCUFPS_CfgNip           ),
    .CCUFPS_CfgNop           ( CCUFPS_CfgNop           ),
    .CCUFPS_CfgCrdBaseRdAddr ( CCUFPS_CfgCrdBaseRdAddr ),
    .CCUFPS_CfgCrdBaseWrAddr ( CCUFPS_CfgCrdBaseWrAddr ),
    .CCUFPS_CfgIdxBaseWrAddr ( CCUFPS_CfgIdxBaseWrAddr ),
    .CCUFPS_CfgMaskBaseAddr  ( CCUFPS_CfgMaskBaseAddr  ),
    .CCUFPS_CfgDistBaseAddr  ( CCUFPS_CfgDistBaseAddr  ),
    .CCUKNN_CfgVld           ( CCUKNN_CfgVld           ),
    .KNNCCU_CfgRdy           ( KNNCCU_CfgRdy           ),
    .CCUKNN_CfgNip           ( CCUKNN_CfgNip           ),
    .CCUKNN_CfgK             ( CCUKNN_CfgK             ),
    .CCUKNN_CfgCrdRdAddr     ( CCUKNN_CfgCrdRdAddr     ),
    .CCUKNN_CfgMapWrAddr     ( CCUKNN_CfgMapWrAddr     ),
    .CCUSYA_CfgVld           ( CCUSYA_CfgVld           ),
    .SYACCU_CfgRdy           ( SYACCU_CfgRdy           ),
    .CCUSYA_CfgMod           ( CCUSYA_CfgMod           ),
    .CCUSYA_CfgOfmPhaseShift ( CCUSYA_CfgOfmPhaseShift ),
    .CCUSYA_CfgChn           ( CCUSYA_CfgChn           ),
    .CCUSYA_CfgScale         ( CCUSYA_CfgScale         ),
    .CCUSYA_CfgShift         ( CCUSYA_CfgShift         ),
    .CCUSYA_CfgZp            ( CCUSYA_CfgZp            ),
    .CCUSYA_CfgNumGrpPerTile ( CCUSYA_CfgNumGrpPerTile ),
    .CCUSYA_CfgNumTilIfm     ( CCUSYA_CfgNumTilIfm     ),
    .CCUSYA_CfgNumTilFlt     ( CCUSYA_CfgNumTilFlt     ),
    .CCUSYA_CfgLopOrd        ( CCUSYA_CfgLopOrd        ),
    .CCUSYA_CfgActRdBaseAddr ( CCUSYA_CfgActRdBaseAddr ),
    .CCUSYA_CfgWgtRdBaseAddr ( CCUSYA_CfgWgtRdBaseAddr ),
    .CCUSYA_CfgOfmWrBaseAddr ( CCUSYA_CfgOfmWrBaseAddr ),
    .CCUPOL_CfgVld           ( CCUPOL_CfgVld           ),
    .POLCCU_CfgRdy           ( POLCCU_CfgRdy           ),
    .CCUPOL_CfgK             ( CCUPOL_CfgK             ),
    .CCUPOL_CfgNip           ( CCUPOL_CfgNip           ),
    .CCUPOL_CfgChn           ( CCUPOL_CfgChn           ),   
    .CCUTOP_CfgPortBankFlag  ( CCUTOP_CfgPortBankFlag  ),
    .CCUTOP_CfgPortOffEmptyFull( CCUTOP_CfgPortOffEmptyFull),
    .CCUTOP_CfgRdy           ( O_CfgRdy                 )
);

//=====================================================================================================================
// Logic Design: FPS
//=====================================================================================================================

// FPS Reads Mask from GLB
assign TOPGLB_RdPortAddr[GLBRDIDX_FPSMSK]       = FPSGLB_MaskRdAddr;
assign TOPGLB_RdPortAddrVld[GLBRDIDX_FPSMSK]    = FPSGLB_MaskRdAddrVld;
assign GLBFPS_MaskRdAddrRdy                     = GLBTOP_RdPortAddrRdy[GLBRDIDX_FPSMSK];

assign GLBFPS_MaskRdDat                         = GLBTOP_RdPortDat[GLBRDIDX_FPSMSK];
assign GLBFPS_MaskRdDatVld                      = GLBTOP_RdPortDatVld[GLBRDIDX_FPSMSK];
assign TOPGLB_RdPortDatRdy[GLBRDIDX_FPSMSK]     = FPSGLB_MaskRdDatRdy;

// FPS Writes Mask to GLB
assign TOPGLB_WrPortAddr[GLBWRIDX_FPSMSK]       = FPSGLB_MaskWrAddr;
assign TOPGLB_WrPortDat[GLBWRIDX_FPSMSK]        = FPSGLB_MaskWrDat;
assign TOPGLB_WrPortDatVld[GLBWRIDX_FPSMSK]     = FPSGLB_MaskWrDatVld;
assign GLBFPS_MaskWrDatRdy                      = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSMSK];

// Read Crd
assign TOPGLB_RdPortAddr[GLBRDIDX_FPSCRD]       = FPSGLB_CrdRdAddr;
assign TOPGLB_RdPortAddrVld[GLBRDIDX_FPSCRD]    = FPSGLB_CrdRdAddrVld;
assign GLBFPS_CrdRdAddrRdy                      = GLBTOP_RdPortAddrRdy[GLBRDIDX_FPSCRD];
assign GLBFPS_CrdRdDat                          = GLBTOP_RdPortDat[GLBRDIDX_FPSCRD];
assign GLBFPS_CrdRdDatVld                       = GLBTOP_RdPortDatVld[GLBRDIDX_FPSCRD];
assign TOPGLB_RdPortDatRdy[GLBRDIDX_FPSCRD]     = FPSGLB_CrdRdDatRdy;

// Write Crd
assign TOPGLB_WrPortAddr[GLBWRIDX_FPSCRD]       = FPSGLB_CrdWrAddr;
assign TOPGLB_WrPortDat[GLBWRIDX_FPSCRD]        = FPSGLB_CrdWrDat;
assign TOPGLB_WrPortDatVld[GLBWRIDX_FPSCRD]     = FPSGLB_CrdWrDatVld;
assign GLBFPS_CrdWrDatRdy                       = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSCRD];

// Read Dist
assign TOPGLB_RdPortAddr[GLBRDIDX_FPSDST]       = FPSGLB_DistRdAddr;
assign TOPGLB_RdPortAddrVld[GLBRDIDX_FPSDST]    = FPSGLB_DistRdAddrVld;
assign GLBFPS_DistRdAddrRdy                     = GLBTOP_RdPortAddrRdy[GLBRDIDX_FPSDST];
assign GLBFPS_DistRdDat                         = GLBTOP_RdPortDat[GLBRDIDX_FPSDST];
assign GLBFPS_DistRdDatVld                      = GLBTOP_RdPortDatVld[GLBRDIDX_FPSDST];
assign TOPGLB_RdPortDatRdy[GLBRDIDX_FPSDST]     = FPSGLB_DistRdDatRdy;

// Write Dist
assign TOPGLB_WrPortAddr[GLBWRIDX_FPSDST]       = FPSGLB_DistWrAddr;
assign TOPGLB_WrPortDat[GLBWRIDX_FPSDST]        = FPSGLB_DistWrDat;
assign TOPGLB_WrPortDatVld[GLBWRIDX_FPSDST]     = FPSGLB_DistWrDatVld;
assign GLBFPS_DistWrDatRdy                      = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSDST];

// Write Idx
assign TOPGLB_WrPortAddr[GLBWRIDX_FPSIDX]       = FPSGLB_IdxWrAddr;
assign TOPGLB_WrPortDat[GLBWRIDX_FPSIDX]        = FPSGLB_IdxWrDat;
assign TOPGLB_WrPortDatVld[GLBWRIDX_FPSIDX]     = FPSGLB_IdxWrDatVld;
assign GLBFPS_IdxWrDatRdy                       = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSIDX];

FPS #(
    .SRAM_WIDTH           ( SRAM_WIDTH  ),
    .IDX_WIDTH            ( IDX_WIDTH   ),
    .CRD_WIDTH            ( CRD_WIDTH   ),
    .CRD_DIM              ( CRD_DIM     ),
    .NUM_FPC              ( NUM_FPC     ),
    .CUTMASK_WIDTH        ( CUTMASK_WIDTH)
)u_FPS(
    .clk                  ( clk                  ),
    .rst_n                ( rst_n                ),
    .CCUFPS_CfgVld        ( CCUFPS_CfgVld        ),
    .FPSCCU_CfgRdy        ( FPSCCU_CfgRdy        ),
    .CCUFPS_CfgNip        ( CCUFPS_CfgNip        ),
    .CCUFPS_CfgNop        ( CCUFPS_CfgNop        ),
    .CCUFPS_CfgCrdBaseRdAddr( CCUFPS_CfgCrdBaseRdAddr ),
    .CCUFPS_CfgCrdBaseWrAddr( CCUFPS_CfgCrdBaseWrAddr ),
    .CCUFPS_CfgIdxBaseWrAddr( CCUFPS_CfgIdxBaseWrAddr ),
    .CCUFPS_CfgMaskBaseAddr ( CCUFPS_CfgMaskBaseAddr  ),
    .CCUFPS_CfgDistBaseAddr ( CCUFPS_CfgDistBaseAddr  ),
    .FPSGLB_MaskRdAddr       ( FPSGLB_MaskRdAddr       ),
    .FPSGLB_MaskRdAddrVld    ( FPSGLB_MaskRdAddrVld    ),
    .GLBFPS_MaskRdAddrRdy    ( GLBFPS_MaskRdAddrRdy    ),
    .GLBFPS_MaskRdDat        ( GLBFPS_MaskRdDat        ),
    .GLBFPS_MaskRdDatVld     ( GLBFPS_MaskRdDatVld     ),
    .FPSGLB_MaskRdDatRdy     ( FPSGLB_MaskRdDatRdy     ),
    .FPSGLB_MaskWrAddr       ( FPSGLB_MaskWrAddr       ),
    .FPSGLB_MaskWrDat        ( FPSGLB_MaskWrDat        ),
    .FPSGLB_MaskWrDatVld     ( FPSGLB_MaskWrDatVld     ),
    .GLBFPS_MaskWrDatRdy     ( GLBFPS_MaskWrDatRdy     ),
    .FPSGLB_CrdRdAddr        ( FPSGLB_CrdRdAddr        ),
    .FPSGLB_CrdRdAddrVld     ( FPSGLB_CrdRdAddrVld     ),
    .GLBFPS_CrdRdAddrRdy     ( GLBFPS_CrdRdAddrRdy     ),
    .GLBFPS_CrdRdDat         ( GLBFPS_CrdRdDat         ),
    .GLBFPS_CrdRdDatVld      ( GLBFPS_CrdRdDatVld      ),
    .FPSGLB_CrdRdDatRdy      ( FPSGLB_CrdRdDatRdy      ),
    .FPSGLB_CrdWrAddr        ( FPSGLB_CrdWrAddr        ),
    .FPSGLB_CrdWrDat         ( FPSGLB_CrdWrDat         ),
    .FPSGLB_CrdWrDatVld      ( FPSGLB_CrdWrDatVld      ),
    .GLBFPS_CrdWrDatRdy      ( GLBFPS_CrdWrDatRdy      ),
    .FPSGLB_DistRdAddr       ( FPSGLB_DistRdAddr       ),
    .FPSGLB_DistRdAddrVld    ( FPSGLB_DistRdAddrVld    ),
    .GLBFPS_DistRdAddrRdy    ( GLBFPS_DistRdAddrRdy    ),
    .GLBFPS_DistRdDat        ( GLBFPS_DistRdDat        ),
    .GLBFPS_DistRdDatVld     ( GLBFPS_DistRdDatVld     ),
    .FPSGLB_DistRdDatRdy     ( FPSGLB_DistRdDatRdy     ),
    .FPSGLB_DistWrAddr       ( FPSGLB_DistWrAddr       ),
    .FPSGLB_DistWrDat        ( FPSGLB_DistWrDat        ),
    .FPSGLB_DistWrDatVld     ( FPSGLB_DistWrDatVld     ),
    .GLBFPS_DistWrDatRdy     ( GLBFPS_DistWrDatRdy     ),
    .FPSGLB_IdxWrAddr        ( FPSGLB_IdxWrAddr        ),
    .FPSGLB_IdxWrDat         ( FPSGLB_IdxWrDat         ),
    .FPSGLB_IdxWrDatVld      ( FPSGLB_IdxWrDatVld      ),
    .GLBFPS_IdxWrDatRdy      ( GLBFPS_IdxWrDatRdy      )
);

//=====================================================================================================================
// Logic Design: KNN
//=====================================================================================================================
// Read Crd
assign TOPGLB_RdPortAddr[GLBRDIDX_KNNCRD]       = KNNGLB_CrdRdAddr;
assign TOPGLB_RdPortAddrVld[GLBRDIDX_KNNCRD]    = KNNGLB_CrdRdAddrVld;
assign GLBKNN_CrdRdAddrRdy                      = GLBTOP_RdPortAddrRdy[GLBRDIDX_KNNCRD];
assign GLBKNN_CrdRdDat                          = GLBTOP_RdPortDat[GLBRDIDX_KNNCRD];
assign GLBKNN_CrdRdDatVld                       = GLBTOP_RdPortDatVld[GLBRDIDX_KNNCRD];
assign TOPGLB_RdPortDatRdy[GLBRDIDX_KNNCRD]     = KNNGLB_CrdRdDatRdy;

// Write Map
assign TOPGLB_WrPortAddr[GLBWRIDX_KNNMAP]       = KNNGLB_MapWrAddr;
assign TOPGLB_WrPortDat[GLBWRIDX_KNNMAP]        = KNNGLB_MapWrDat;
assign TOPGLB_WrPortDatVld[GLBWRIDX_KNNMAP]     = KNNGLB_MapWrDatVld;
assign GLBKNN_MapWrDatRdy                       = GLBTOP_WrPortDatRdy[GLBWRIDX_KNNMAP];

KNN#(
    .SRAM_WIDTH           ( SRAM_WIDTH      ),
    .IDX_WIDTH            ( IDX_WIDTH       ),
    .MAP_WIDTH            ( MAP_WIDTH       ),
    .CRD_WIDTH            ( CRD_WIDTH       ),
    .CRD_DIM              ( CRD_DIM         ),
    .NUM_SORT_CORE        ( NUM_SORT_CORE   )
)u_KNN(
    .clk                 ( clk                 ),
    .rst_n               ( rst_n               ),
    .CCUKNN_CfgVld       ( CCUKNN_CfgVld       ),
    .KNNCCU_CfgRdy       ( KNNCCU_CfgRdy       ),
    .CCUKNN_CfgNip       ( CCUKNN_CfgNip       ),
    .CCUKNN_CfgK         ( CCUKNN_CfgK         ),
    .CCUKNN_CfgCrdRdAddr ( CCUKNN_CfgCrdRdAddr ),
    .CCUKNN_CfgMapWrAddr ( CCUKNN_CfgMapWrAddr ),
    .KNNGLB_CrdRdAddr    ( KNNGLB_CrdRdAddr    ),
    .KNNGLB_CrdRdAddrVld ( KNNGLB_CrdRdAddrVld ),
    .GLBKNN_CrdRdAddrRdy ( GLBKNN_CrdRdAddrRdy ),
    .GLBKNN_CrdRdDat     ( GLBKNN_CrdRdDat     ),
    .GLBKNN_CrdRdDatVld  ( GLBKNN_CrdRdDatVld  ),
    .KNNGLB_CrdRdDatRdy  ( KNNGLB_CrdRdDatRdy  ),
    .KNNGLB_MapWrAddr    ( KNNGLB_MapWrAddr    ),
    .KNNGLB_MapWrDat     ( KNNGLB_MapWrDat     ),
    .KNNGLB_MapWrDatVld  ( KNNGLB_MapWrDatVld  ),
    .GLBKNN_MapWrDatRdy  ( GLBKNN_MapWrDatRdy  )
);

//=====================================================================================================================
// Logic Design: SYA
//=====================================================================================================================
// Read Act
assign TOPGLB_RdPortAddrVld[GLBRDIDX_SYAACT]    = SYAGLB_ActRdAddrVld;
assign TOPGLB_RdPortAddr[GLBRDIDX_SYAACT]       = SYAGLB_ActRdAddr;
assign GLBSYA_ActRdAddrRdy                      = GLBTOP_RdPortAddrRdy[GLBRDIDX_SYAACT];
assign GLBSYA_ActRdDat                          = GLBTOP_RdPortDat[GLBRDIDX_SYAACT];
assign GLBSYA_ActRdDatVld                       = GLBTOP_RdPortDatVld[GLBRDIDX_SYAACT];
assign TOPGLB_RdPortDatRdy[GLBRDIDX_SYAACT]     = SYAGLB_ActRdDatRdy;

// Read Wgt
assign TOPGLB_RdPortAddrVld[GLBRDIDX_SYAWGT]    = SYAGLB_WgtRdAddrVld;
assign TOPGLB_RdPortAddr[GLBRDIDX_SYAWGT]       = SYAGLB_WgtRdAddr;
assign GLBSYA_WgtRdAddrRdy                      = GLBTOP_RdPortAddrRdy[GLBRDIDX_SYAWGT];
assign GLBSYA_WgtRdDat                          = GLBTOP_RdPortDat[GLBRDIDX_SYAWGT];
assign GLBSYA_WgtRdDatVld                       = GLBTOP_RdPortDatVld[GLBRDIDX_SYAWGT];
assign TOPGLB_RdPortDatRdy[GLBRDIDX_SYAWGT]     = SYAGLB_WgtRdDatRdy;

// Write Ofm
assign TOPGLB_WrPortAddr[GLBWRIDX_SYAOFM]       = SYAGLB_OfmWrAddr;
assign TOPGLB_WrPortDat[GLBWRIDX_SYAOFM]        = SYAGLB_OfmWrDat;
assign TOPGLB_WrPortDatVld[GLBWRIDX_SYAOFM]     = &SYAGLB_OfmWrDatVld; // ????????????????????????????? BUG 4bit to 1 bit
assign GLBSYA_OfmWrDatRdy                       = {NUM_BANK{GLBTOP_WrPortDatRdy[GLBWRIDX_SYAOFM]}};

SYA#(
    .ACT_WIDTH ( ACT_WIDTH      ), 
    .WGT_WIDTH ( ACT_WIDTH      ),
    .NUM_ROW   ( SYA_NUM_ROW    ), 
    .NUM_COL   ( SYA_NUM_COL    ), 
    .NUM_BANK  ( SYA_NUM_BANK   ), 
    .SRAM_WIDTH( SRAM_WIDTH     ),
    .ADDR_WIDTH( ADDR_WIDTH     ),
    .QNTSL_WIDTH( QNTSL_WIDTH   ),
    .CHN_WIDTH ( CHN_WIDTH      ),
    .IDX_WIDTH ( IDX_WIDTH      )
)u_SYA(
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .CCUSYA_CfgVld           ( CCUSYA_CfgVld           ),
    .SYACCU_CfgRdy           ( SYACCU_CfgRdy           ),
    .CCUSYA_CfgMod           ( CCUSYA_CfgMod           ),
    .CCUSYA_CfgOfmPhaseShift    ( CCUSYA_CfgOfmPhaseShift    ),
    .CCUSYA_CfgChn           ( CCUSYA_CfgChn           ),
    .CCUSYA_CfgShift         ( CCUSYA_CfgShift         ),
    .CCUSYA_CfgZp            ( CCUSYA_CfgZp            ),
    .CCUSYA_CfgNumGrpPerTile ( CCUSYA_CfgNumGrpPerTile ),
    .CCUSYA_CfgNumTilIfm     ( CCUSYA_CfgNumTilIfm     ),
    .CCUSYA_CfgNumTilFlt     ( CCUSYA_CfgNumTilFlt     ),
    .CCUSYA_CfgLopOrd        ( CCUSYA_CfgLopOrd        ),
    .CCUSYA_CfgActRdBaseAddr ( CCUSYA_CfgActRdBaseAddr ),
    .CCUSYA_CfgWgtRdBaseAddr ( CCUSYA_CfgWgtRdBaseAddr ),
    .CCUSYA_CfgOfmWrBaseAddr ( CCUSYA_CfgOfmWrBaseAddr ),
    .SYAGLB_ActRdAddr        ( SYAGLB_ActRdAddr        ),
    .SYAGLB_ActRdAddrVld     ( SYAGLB_ActRdAddrVld     ),
    .GLBSYA_ActRdAddrRdy     ( GLBSYA_ActRdAddrRdy     ),
    .GLBSYA_ActRdDat         ( GLBSYA_ActRdDat         ),
    .GLBSYA_ActRdDatVld      ( GLBSYA_ActRdDatVld      ),
    .SYAGLB_ActRdDatRdy      ( SYAGLB_ActRdDatRdy      ),
    .SYAGLB_WgtRdAddr        ( SYAGLB_WgtRdAddr        ),
    .SYAGLB_WgtRdAddrVld     ( SYAGLB_WgtRdAddrVld     ),
    .GLBSYA_WgtRdAddrRdy     ( GLBSYA_WgtRdAddrRdy     ),
    .GLBSYA_WgtRdDat         ( GLBSYA_WgtRdDat         ),
    .GLBSYA_WgtRdDatVld      ( GLBSYA_WgtRdDatVld      ),
    .SYAGLB_WgtRdDatRdy      ( SYAGLB_WgtRdDatRdy      ),
    .SYAGLB_OfmWrDat         ( SYAGLB_OfmWrDat         ),
    .SYAGLB_OfmWrAddr        ( SYAGLB_OfmWrAddr        ),
    .SYAGLB_OfmWrDatVld      ( SYAGLB_OfmWrDatVld      ),
    .GLBSYA_OfmWrDatRdy      ( GLBSYA_OfmWrDatRdy      )
);

//=====================================================================================================================
// Logic Design: POL
//=====================================================================================================================
// Read Map
assign TOPGLB_RdPortAddrVld[GLBRDIDX_POLMAP]    = POLGLB_MapRdAddrVld;
assign TOPGLB_RdPortAddr[GLBRDIDX_POLMAP]       = POLGLB_MapRdAddr;
assign GLBPOL_MapRdAddrRdy                      = GLBTOP_RdPortAddrRdy[GLBRDIDX_POLMAP];
assign GLBPOL_MapRdDat                          = GLBTOP_RdPortDat[GLBRDIDX_POLMAP];
assign GLBPOL_MapRdDatVld                       = GLBTOP_RdPortDatVld[GLBRDIDX_POLMAP];
assign TOPGLB_RdPortDatRdy[GLBRDIDX_POLMAP]     = POLGLB_MapRdDatRdy;

// Read Ofm
generate
    for(gv_i = 0; gv_i < POOL_CORE; gv_i = gv_i + 1) begin: GEN_Port_GLBPOL_OfmRd
        assign TOPGLB_RdPortAddr[GLBRDIDX_POLOFM + gv_i]    = POLGLB_OfmRdAddr[gv_i];
        assign GLBPOL_OfmRdDat  [gv_i]                      = GLBTOP_RdPortDat[GLBRDIDX_POLOFM + gv_i];
    end
endgenerate
assign TOPGLB_RdPortAddrVld[GLBRDIDX_POLOFM +: POOL_CORE]   = POLGLB_OfmRdAddrVld;
assign GLBPOL_OfmRdAddrRdy                                  = GLBTOP_RdPortAddrRdy[GLBRDIDX_POLOFM +: POOL_CORE];
assign GLBPOL_OfmRdDatVld                                   = GLBTOP_RdPortDatVld[GLBRDIDX_POLOFM +: POOL_CORE];
assign TOPGLB_RdPortDatRdy[GLBRDIDX_POLOFM +: POOL_CORE]    = POLGLB_OfmRdDatRdy;

// Write Ofm
assign TOPGLB_WrPortAddr[GLBWRIDX_POLOFM]   = POLGLB_OfmWrAddr;
assign TOPGLB_WrPortDat[GLBWRIDX_POLOFM]    = POLGLB_OfmWrDat;
assign TOPGLB_WrPortDatVld[GLBWRIDX_POLOFM] = POLGLB_OfmWrDatVld;
assign GLBPOL_OfmWrDatRdy                   = GLBTOP_WrPortDatRdy[GLBWRIDX_POLOFM];

POL#(
    .IDX_WIDTH            ( IDX_WIDTH       ),
    .ACT_WIDTH            ( ACT_WIDTH       ),
    .POOL_COMP_CORE       ( POOL_COMP_CORE  ),
    .MAP_WIDTH            ( MAP_WIDTH       ),
    .POOL_CORE            ( POOL_CORE       ),
    .CHN_WIDTH            ( CHN_WIDTH       ),
    .SRAM_WIDTH           ( SRAM_WIDTH      ) 
)u_POL(
    .clk                 ( clk                 ),
    .rst_n               ( rst_n               ),
    .CCUPOL_CfgVld       ( CCUPOL_CfgVld       ),
    .POLCCU_CfgRdy       ( POLCCU_CfgRdy       ),
    .CCUPOL_CfgK         ( CCUPOL_CfgK         ),
    .CCUPOL_CfgNip       ( CCUPOL_CfgNip       ),
    .CCUPOL_CfgChn       ( CCUPOL_CfgChn       ),
    .POLGLB_MapRdAddr    ( POLGLB_MapRdAddr    ),
    .POLGLB_MapRdAddrVld ( POLGLB_MapRdAddrVld ),
    .GLBPOL_MapRdAddrRdy ( GLBPOL_MapRdAddrRdy ),
    .GLBPOL_MapRdDatVld  ( GLBPOL_MapRdDatVld  ),
    .GLBPOL_MapRdDat     ( GLBPOL_MapRdDat     ),
    .POLGLB_MapRdDatRdy  ( POLGLB_MapRdDatRdy  ),
    .POLGLB_OfmRdAddrVld ( POLGLB_OfmRdAddrVld ),
    .POLGLB_OfmRdAddr    ( POLGLB_OfmRdAddr    ),
    .GLBPOL_OfmRdAddrRdy ( GLBPOL_OfmRdAddrRdy ),
    .GLBPOL_OfmRdDat     ( GLBPOL_OfmRdDat     ),
    .GLBPOL_OfmRdDatVld  ( GLBPOL_OfmRdDatVld  ),
    .POLGLB_OfmRdDatRdy  ( POLGLB_OfmRdDatRdy  ),
    .POLGLB_OfmWrAddr    ( POLGLB_OfmWrAddr    ),
    .POLGLB_OfmWrDat     ( POLGLB_OfmWrDat     ),
    .POLGLB_OfmWrDatVld  ( POLGLB_OfmWrDatVld  ),
    .GLBPOL_OfmWrDatRdy  ( GLBPOL_OfmWrDatRdy  )
);

//=====================================================================================================================
// Logic Design: ITF
//=====================================================================================================================

// PAD
assign {O_Dat, O_DatVld}          = O_DatOE? {ITFPAD_Dat, ITFPAD_DatVld} : { {PORT_WIDTH{1'bz}}, 1'bz};
assign PADITF_DatRdy                = I_DatRdy;
assign {PADITF_Dat, PADITF_DatVld}  = {I_Dat, I_DatVld};
assign O_DatRdy                    = I_ISAVld? CCUTOP_ISARdDatRdy : (O_DatOE? 1'bz : ITFPAD_DatRdy);
assign O_DatOE                      = I_ISAVld? 1'b0 : ITFPAD_DatOE;
assign O_CmdVld                     = ITFPAD_CmdVld;

// GLB RdPort
assign TOPGLB_RdPortAddr   [GLBRDIDX_ITFGLB]= ITFGLB_RdAddr;
assign TOPGLB_RdPortAddrVld[GLBRDIDX_ITFGLB]= ITFGLB_RdAddrVld;
assign GLBITF_RdAddrRdy                     = GLBTOP_RdPortAddrRdy  [GLBRDIDX_ITFGLB];
assign GLBITF_RdDat                         = GLBTOP_RdPortDat      [GLBRDIDX_ITFGLB];
assign GLBITF_RdDatVld                      = GLBTOP_RdPortDatVld   [GLBRDIDX_ITFGLB];
assign TOPGLB_RdPortDatRdy [GLBRDIDX_ITFGLB]= ITFGLB_RdDatRdy;
assign GLBITF_RdEmpty                       = GLBTOP_RdEmpty        [GLBRDIDX_ITFGLB];

// GLB WrPort
assign TOPGLB_WrPortAddr    [GLBWRIDX_ITFGLB]   = ITFGLB_WrAddr;
assign TOPGLB_WrPortDat     [GLBWRIDX_ITFGLB]   = ITFGLB_WrDat;
assign TOPGLB_WrPortDatVld  [GLBWRIDX_ITFGLB]   = ITFGLB_WrDatVld;
assign GLBITF_WrDatRdy                          = GLBTOP_WrPortDatRdy   [GLBWRIDX_ITFGLB];
assign GLBITF_WrFull                            = GLBTOP_WrFull         [GLBWRIDX_ITFGLB];

// Config 1 bank
// !Full To avoid ITF over-write ISARAM of GLB

ITF#(
    .PORT_WIDTH       ( PORT_WIDTH      ),
    .SRAM_WIDTH       ( SRAM_WIDTH      ),
    .ADDR_WIDTH       ( ADDR_WIDTH      ),
    .DRAM_ADDR_WIDTH  ( DRAM_ADDR_WIDTH )
)u_ITF(
    .clk                 ( clk                 ),
    .rst_n               ( rst_n               ),
    .CCUITF_CfgVld       (  CCUITF_CfgVld         ),
    .ITFCCU_CfgRdy       (  ITFCCU_CfgRdy         ),
    .CCUITF_CfgInOut     (  CCUITF_CfgInOut       ),
    .CCUITF_CfgDRAMBaseAddr(CCUITF_CfgDRAMBaseAddr),
    .CCUITF_CfgGLBBaseAddr (CCUITF_CfgGLBBaseAddr ),
    .CCUITF_CfgNum         (CCUITF_CfgNum         ),
    .ITFPAD_DatOE        ( ITFPAD_DatOE        ),
    .ITFPAD_CmdVld       ( ITFPAD_CmdVld       ),
    .ITFPAD_Dat          ( ITFPAD_Dat          ),
    .ITFPAD_DatVld       ( ITFPAD_DatVld       ),
    .PADITF_DatRdy       ( PADITF_DatRdy       ),
    .PADITF_Dat          ( PADITF_Dat          ),
    .PADITF_DatVld       ( PADITF_DatVld       ),
    .ITFPAD_DatRdy       ( ITFPAD_DatRdy       ),
    .ITFGLB_RdAddr       ( ITFGLB_RdAddr       ),
    .ITFGLB_RdAddrVld    ( ITFGLB_RdAddrVld    ),
    .GLBITF_RdAddrRdy    ( GLBITF_RdAddrRdy    ),
    .GLBITF_RdDat        ( GLBITF_RdDat        ),
    .GLBITF_RdDatVld     ( GLBITF_RdDatVld     ),
    .ITFGLB_RdDatRdy     ( ITFGLB_RdDatRdy     ),
    .GLBITF_RdEmpty      ( GLBITF_RdEmpty      ),
    .ITFGLB_WrAddr       ( ITFGLB_WrAddr       ),
    .ITFGLB_WrDat        ( ITFGLB_WrDat        ),
    .ITFGLB_WrDatVld     ( ITFGLB_WrDatVld     ),
    .GLBITF_WrDatRdy     ( GLBITF_WrDatRdy     ),
    .GLBITF_WrFull       ( GLBITF_WrFull       )
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
    .NUM_RDPORT              ( GLB_NUM_RDPORT   )
)u_GLB(
    .clk                    ( clk                    ),
    .rst_n                  ( rst_n                  ),
    .TOPGLB_CfgPortBankFlag ( TOPGLB_CfgPortBankFlag ),
    .TOPGLB_CfgPortOffEmptyFull(TOPGLB_CfgPortOffEmptyFull),
    .TOPGLB_WrPortDat       ( TOPGLB_WrPortDat       ),
    .TOPGLB_WrPortDatVld    ( TOPGLB_WrPortDatVld    ),
    .GLBTOP_WrPortDatRdy    ( GLBTOP_WrPortDatRdy    ),
    .TOPGLB_WrPortAddr      ( TOPGLB_WrPortAddr      ),
    .GLBTOP_WrFull          ( GLBTOP_WrFull          ),
    .TOPGLB_RdPortAddr      ( TOPGLB_RdPortAddr      ),
    .TOPGLB_RdPortAddrVld   ( TOPGLB_RdPortAddrVld   ),
    .GLBTOP_RdPortAddrRdy   ( GLBTOP_RdPortAddrRdy   ),
    .GLBTOP_RdPortDat       ( GLBTOP_RdPortDat       ),
    .GLBTOP_RdPortDatVld    ( GLBTOP_RdPortDatVld    ),
    .TOPGLB_RdPortDatRdy    ( TOPGLB_RdPortDatRdy    ),
    .GLBTOP_RdEmpty         ( GLBTOP_RdEmpty         )
);
assign TOPGLB_CfgPortBankFlag = CCUTOP_CfgPortBankFlag;
assign TOPGLB_CfgPortOffEmptyFull  = CCUTOP_CfgPortOffEmptyFull;


endmodule
