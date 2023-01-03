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
module TOP #(
    parameter CLOCK_PERIOD   = 10,

    parameter PORT_WIDTH     = 128,
    parameter SRAM_WIDTH     = 256,
    parameter SRAM_BYTE_WIDTH= 8,
    parameter SRAM_WORD      = 128,
    parameter ADDR_WIDTH     = 16,
    parameter DRAM_ADDR_WIDTH= 32,  
    parameter ISA_SRAM_WORD  = 64,
    parameter ITF_NUM_RDPORT = 2,  
    parameter ITF_NUM_WRPORT = 5, // + CCU
    parameter GLB_NUM_RDPORT = 16,  // 11 + 5(POOL_CORE)
    parameter GLB_NUM_WRPORT = 9, 
    parameter MAXPAR         = 32,
    parameter NUM_BANK       = 32,
    parameter POOL_CORE      = 6,
    parameter POOL_COMP_CORE = 64, 

    // NetWork Parameters
    parameter IDX_WIDTH      = 16,
    parameter CHN_WIDTH      = 12,
    parameter ACT_WIDTH      = 8,
    parameter MAP_WIDTH      = 6,

    parameter CRD_WIDTH      = 16,   
    parameter CRD_DIM        = 3,   
    parameter NUM_SORT_CORE  = 8,

    parameter SYA_NUM_ROW    = 16,
    parameter SYA_NUM_COL    = 16,
    parameter SYA_NUM_BANK   = 4,
    parameter QNTSL_WIDTH    = 20,
    parameter MASK_ADDR_WIDTH = $clog2(2**IDX_WIDTH*NUM_SORT_CORE/SRAM_WIDTH)

    )(
    input                           I_SysRst_n    , 
    input                           I_SysClk      , 
    input                           I_StartPulse  ,
    input                           I_BypAsysnFIFO, 
    inout   [PORT_WIDTH     -1 : 0] IO_Dat        , 
    inout                           IO_DatVld     , 
    inout                           IO_DatLast    , 
    inout                           OI_DatRdy     , 
    output                          O_DatOE       ,
    output                          O_NetFnh  

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam GLBWRIDX_ITFACT = 0;
localparam GLBWRIDX_ITFWGT = 1;
localparam GLBWRIDX_ITFCRD = 2;
localparam GLBWRIDX_ITFMAP = 3;
localparam GLBWRIDX_SYAOFM = 4;
localparam GLBWRIDX_POLOFM = 5;
localparam GLBWRIDX_FPSDST = 6;
localparam GLBWRIDX_FPSFMK = 7; // FPS Writes Mask
localparam GLBWRIDX_KNNMAP = 8;


localparam GLBRDIDX_ITFMAP = 0;
localparam GLBRDIDX_ITFOFM = 1;
localparam GLBRDIDX_SYAACT = 2;
localparam GLBRDIDX_SYAWGT = 3;
localparam GLBRDIDX_FPSCRD = 4;
localparam GLBRDIDX_FPSDST = 5;
localparam GLBRDIDX_FPSFMK = 6; // FPS Read MASK
localparam GLBRDIDX_KNNCRD = 7;
localparam GLBRDIDX_KNNKMK = 8; // KNN Read MASK
localparam GLBRDIDX_POLMAP = 9;
localparam GLBRDIDX_POLOFM = 10;


localparam DISTSQR_WIDTH     =  $clog2( CRD_WIDTH*2*$clog2(CRD_DIM) );
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
// System
wire                            clk;
wire                            rst_n;
wire                            StartPulse_Deb;
wire                            StartPulse_Deb_d;
// ITF
wire [PORT_WIDTH        -1 : 0] ITFPAD_Dat;
wire [PORT_WIDTH        -1 : 0] PADITF_Dat;

wire                            ITFPAD_DatOE;
wire                            ITFPAD_DatVld;
wire                            ITFPAD_DatLast;
wire                            PADITF_DatRdy;

wire                            PADITF_DatVld;
wire                            PADITF_DatLast;
wire                            ITFPAD_DatRdy;

// TOP-ITF
wire [1*(ITF_NUM_RDPORT+ITF_NUM_WRPORT)           -1 : 0] TOPITF_EmptyFull;
wire [ADDR_WIDTH*(ITF_NUM_RDPORT+ITF_NUM_WRPORT)  -1 : 0] TOPITF_ReqNum;  
wire [ADDR_WIDTH*(ITF_NUM_RDPORT+ITF_NUM_WRPORT)  -1 : 0] TOPITF_Addr;    

wire [SRAM_WIDTH*ITF_NUM_RDPORT               -1 : 0] TOPITF_Dat;    
wire [ITF_NUM_RDPORT                          -1 : 0] TOPITF_DatVld;
wire [ITF_NUM_RDPORT                          -1 : 0] TOPITF_DatLast; 
wire [ITF_NUM_RDPORT                          -1 : 0] ITFTOP_DatRdy; 

wire [SRAM_WIDTH*ITF_NUM_WRPORT               -1 : 0] ITFTOP_Dat;    
wire [ITF_NUM_WRPORT                          -1 : 0] ITFTOP_DatVld; 
wire [ITF_NUM_WRPORT                          -1 : 0] ITFTOP_DatLast; 
wire [ITF_NUM_WRPORT                          -1 : 0] TOPITF_DatRdy;


// CCU
wire                                              TOPCCU_start;
wire                                              CCUITF_Empty ;
wire [ADDR_WIDTH                          -1 : 0] CCUITF_ReqNum;
wire [ADDR_WIDTH                          -1 : 0] CCUITF_Addr  ;
wire  [SRAM_WIDTH                         -1 : 0] ITFCCU_Dat;          
wire                                              ITFCCU_DatVld;          
wire                                              CCUITF_DatRdy;
wire  [DRAM_ADDR_WIDTH*(ITF_NUM_RDPORT+ITF_NUM_WRPORT) -1 : 0] CCUITF_BaseAddr;
wire                                              CCUSYA_Rst;  //
wire                                              CCUSYA_CfgVld;
wire                                              SYACCU_CfgRdy;
wire  [2                                  -1 : 0] CCUSYA_CfgMod;
wire  [IDX_WIDTH                          -1 : 0] CCUSYA_CfgNip; 
wire  [CHN_WIDTH                          -1 : 0] CCUSYA_CfgChi;         
wire  [QNTSL_WIDTH                        -1 : 0] CCUSYA_CfgScale;        
wire  [ACT_WIDTH                          -1 : 0] CCUSYA_CfgShift;        
wire  [ACT_WIDTH                          -1 : 0] CCUSYA_CfgZp;
wire                                              CCUPOL_Rst;
wire                                              CCUPOL_CfgVld;
wire                                              POLCCU_CfgRdy;
wire  [MAP_WIDTH                          -1 : 0] CCUPOL_CfgK;
wire  [IDX_WIDTH                          -1 : 0] CCUPOL_CfgNip;
wire  [CHN_WIDTH                          -1 : 0] CCUPOL_CfgChi;
wire  [IDX_WIDTH*POOL_CORE                -1 : 0] CCUPOL_AddrMin;
wire  [IDX_WIDTH*POOL_CORE                -1 : 0] CCUPOL_AddrMax;
wire                                              CCUFPS_Rst;
wire                                              CCUFPS_CfgVld;
wire                                              FPSCCU_CfgRdy;      
wire  [IDX_WIDTH                          -1 : 0] CCUFPS_CfgNip;                   
wire  [IDX_WIDTH                          -1 : 0] CCUFPS_CfgNop; 
     wire                                         CCUKNN_Rst;
wire                                              CCUKNN_CfgVld;
wire                                              KNNCCU_CfgRdy;      
wire  [IDX_WIDTH                          -1 : 0] CCUKNN_CfgNip;    
wire  [MAP_WIDTH                          -1 : 0] CCUKNN_CfgK;  
wire                                              CCUGLB_Rst;
wire [GLB_NUM_RDPORT + GLB_NUM_WRPORT     -1 : 0] CCUGLB_CfgVld;         
wire [GLB_NUM_RDPORT + GLB_NUM_WRPORT     -1 : 0] GLBCCU_CfgRdy;         
wire [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)* NUM_BANK -1 : 0] CCUGLB_CfgPortBankFlag;
wire [ADDR_WIDTH*(GLB_NUM_RDPORT+GLB_NUM_WRPORT)  -1 : 0] CCUGLB_CfgPortNum; 
wire [($clog2(MAXPAR) + 1)*(GLB_NUM_RDPORT+GLB_NUM_WRPORT)-1 : 0] CCUGLB_CfgPortParBank;
wire [GLB_NUM_RDPORT+GLB_NUM_WRPORT                     -1 : 0] CCUGLB_CfgPortLoop;

// GLB
wire [SRAM_WIDTH*MAXPAR*GLB_NUM_WRPORT   -1: 0] WrPortDat;
wire [GLB_NUM_WRPORT                     -1: 0] WrPortDatVld;
wire [GLB_NUM_WRPORT                     -1: 0] WrPortDatLast;
wire [GLB_NUM_WRPORT                     -1: 0] WrPortDatRdy;
wire [GLB_NUM_WRPORT                     -1: 0] WrPortEmpty;
wire [ADDR_WIDTH*GLB_NUM_WRPORT          -1: 0] WrPortReqNum;
wire [ADDR_WIDTH*GLB_NUM_WRPORT          -1: 0] WrPortAddr_Out; // Detect
wire [GLB_NUM_WRPORT                     -1: 0] WrPortAddrUse; //  Mode1: Use Address
wire [ADDR_WIDTH*GLB_NUM_WRPORT          -1: 0] WrPortAddr;
wire [SRAM_WIDTH*MAXPAR*GLB_NUM_RDPORT   -1: 0] RdPortDat;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortDatVld;
// wire [GLB_NUM_RDPORT                     -1: 0] RdPortDatLast;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortDatRdy;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortFull;
wire [ADDR_WIDTH*GLB_NUM_RDPORT          -1: 0] RdPortReqNum;
wire [ADDR_WIDTH*GLB_NUM_RDPORT          -1: 0] RdPortAddr_Out;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortAddrUse;
wire [ADDR_WIDTH*GLB_NUM_RDPORT          -1: 0] RdPortAddr;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortAddrVld;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortAddrRdy;  

// CTR
wire [IDX_WIDTH           -1 : 0] FPSGLB_CrdAddr;   
wire                              FPSGLB_CrdAddrVld; 
wire                              GLBFPS_CrdAddrRdy;
wire [SRAM_WIDTH          -1 : 0 ]GLBFPS_Crd;        
wire                              GLBFPS_CrdVld;     
wire                              FPSGLB_CrdRdy;
wire [IDX_WIDTH           -1 : 0] FPSGLB_DistRdAddr; 
wire                              FPSGLB_DistRdAddrVld;
wire                              GLBFPS_DistRdAddrRdy;
wire [DISTSQR_WIDTH+IDX_WIDTH-1 : 0] GLBFPS_DistIdx;    
wire                              GLBFPS_DistIdxVld;    
wire                              FPSGLB_DistIdxRdy;    
wire [IDX_WIDTH           -1 : 0] FPSGLB_DistWrAddr;
wire [DISTSQR_WIDTH+IDX_WIDTH-1 : 0] FPSGLB_DistIdx;   
wire                              FPSGLB_DistIdxVld;
wire                              GLBFPS_DistIdxRdy;
    // Input Mask Bit
wire [MASK_ADDR_WIDTH    -1 : 0] FPSGLB_MaskRdAddr;
wire                             FPSGLB_MaskRdAddrVld;
wire                             GLBFPS_MaskRdAddrRdy;
wire [SRAM_WIDTH         -1 : 0] GLBFPS_MaskRdDat;
wire                             GLBFPS_MaskRdDatVld; // Not Used
wire                             FPSGLB_MaskRdDatRdy;  
    // Output Mask Bit
wire [MASK_ADDR_WIDTH     -1 : 0] FPSGLB_MaskWrAddr;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_MaskWrBitEn;
wire                              FPSGLB_MaskWrDatVld;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_MaskWrDat;
wire                              GLBFPS_MaskWrDatRdy;  // Not Used

wire [IDX_WIDTH           -1 : 0] KNNGLB_CrdAddr;   
wire                              KNNGLB_CrdAddrVld; 
wire                              GLBKNN_CrdAddrRdy;
wire [SRAM_WIDTH          -1 : 0 ]GLBKNN_Crd;        
wire                              GLBKNN_CrdVld;     
wire                              KNNGLB_CrdRdy;

wire [MASK_ADDR_WIDTH    -1 : 0] KNNGLB_MaskRdAddr;
wire                             KNNGLB_MaskRdAddrVld;
wire                             GLBKNN_MaskRdAddrRdy;
wire [SRAM_WIDTH         -1 : 0] GLBKNN_MaskRdDat;
wire                             GLBKNN_MaskRdDatVld;
wire                             KNNGLB_MaskRdDatRdy;

wire [SRAM_WIDTH          -1 : 0 ]KNNGLB_Map;   
wire                              KNNGLB_MapVld;     
wire                              GLBKNN_MapRdy; 

// SYA
wire [SRAM_BYTE_WIDTH*SYA_NUM_ROW*SYA_NUM_COL*SYA_NUM_BANK/16   -1 : 0] SYAGLB_Ofm;
wire [SYA_NUM_BANK                                              -1 : 0] SYAGLB_OfmVld;
wire [SYA_NUM_BANK                                              -1 : 0] GLBSYA_OfmRdy;
wire [SRAM_BYTE_WIDTH*SYA_NUM_ROW*SYA_NUM_BANK                  -1 : 0] GLBSYA_Act;
wire                                                                    GLBSYA_ActVld;
wire                                                                    SYAGLB_ActRdy ;
wire [SRAM_BYTE_WIDTH*SYA_NUM_COL*SYA_NUM_BANK                  -1 : 0] GLBSYA_Wgt;
wire                                                                    GLBSYA_WgtVld;
wire                                                                    SYAGLB_WgtRdy ;

// POOL
wire                                                    GLBPOL_MapVld ;
wire [SRAM_WIDTH                                -1 : 0] GLBPOL_Map    ;
wire                                                    POLGLB_MapRdy ;
wire [POOL_CORE                                 -1 : 0] POLGLB_AddrVld;
wire [ADDR_WIDTH*POOL_CORE                      -1 : 0] POLGLB_Addr   ;
wire [POOL_CORE                                 -1 : 0] GLBPOL_AddrRdy;
wire [SRAM_BYTE_WIDTH*POOL_COMP_CORE*POOL_CORE  -1 : 0] GLBPOL_Ofm     ;
wire [POOL_CORE                                 -1 : 0] GLBPOL_OfmVld  ;
wire [POOL_CORE                                 -1 : 0] POLGLB_OfmRdy  ;
wire [SRAM_BYTE_WIDTH*POOL_COMP_CORE            -1 : 0] POLGLB_Ofm     ;
wire                                                    POLGLB_OfmVld  ;
wire                                                    GLBPOL_OfmRdy  ;

//=====================================================================================================================
// Logic Design: Debounce
//=====================================================================================================================
DEB #(
    .FREQ  ( 50    )
)u_DEB(
    .CLK   ( clk            ),
    .RST_N ( rst_n          ),
    .BTN   ( I_StartPulse   ),
    .SIGNAL( StartPulse_Deb )
);

assign TOPCCU_start = !StartPulse_Deb & StartPulse_Deb_d; // negedge

//=====================================================================================================================
// Logic Design
//=====================================================================================================================
assign {IO_Dat, IO_DatVld, IO_DatLast} = O_DatOE? {ITFPAD_Dat, ITFPAD_DatVld, ITFPAD_DatLast} : { {PORT_WIDTH{1'bz}}, 1'bz, 1'bz};
assign PADITF_DatRdy = OI_DatRdy;

assign {PADITF_Dat, PADITF_DatVld, PADITF_DatLast} = {IO_Dat, IO_DatVld, IO_DatLast};
assign OI_DatRdy = O_DatOE? 1'bz : ITFPAD_DatRdy;

assign clk  = I_SysClk;
assign rst_n= I_SysRst_n;


//=====================================================================================================================
// Logic Design: ITF
//=====================================================================================================================

ITF#(
    .PORT_WIDTH       ( PORT_WIDTH      ),
    .SRAM_WIDTH       ( SRAM_WIDTH      ),
    .ADDR_WIDTH       ( ADDR_WIDTH      ),
    .DRAM_ADDR_WIDTH  ( DRAM_ADDR_WIDTH ),
    .ITF_NUM_RDPORT   ( ITF_NUM_RDPORT  ),
    .ITF_NUM_WRPORT   ( ITF_NUM_WRPORT  )
)u_ITF(
    .clk              ( clk              ),
    .rst_n            ( rst_n            ),
    .ITFPAD_DatOE     ( ITFPAD_DatOE     ),
    .ITFPAD_Dat       ( ITFPAD_Dat       ),
    .ITFPAD_DatVld    ( ITFPAD_DatVld    ),
    .ITFPAD_DatLast   ( ITFPAD_DatLast   ),
    .PADITF_DatRdy    ( PADITF_DatRdy    ),
    .PADITF_Dat       ( PADITF_Dat       ),
    .PADITF_DatVld    ( PADITF_DatVld    ),
    .PADITF_DatLast   ( PADITF_DatLast   ),
    .ITFPAD_DatRdy    ( ITFPAD_DatRdy    ),
    .TOPITF_EmptyFull ( TOPITF_EmptyFull ),
    .TOPITF_ReqNum    ( TOPITF_ReqNum    ),
    .TOPITF_Addr      ( TOPITF_Addr      ),
    .CCUITF_BaseAddr  ( CCUITF_BaseAddr  ),
    .TOPITF_Dat       ( TOPITF_Dat       ),
    .TOPITF_DatVld    ( TOPITF_DatVld    ),
    // .TOPITF_DatLast    ( TOPITF_DatLast   ),
    .ITFTOP_DatRdy    ( ITFTOP_DatRdy    ),
    .ITFTOP_Dat       ( ITFTOP_Dat       ),
    .ITFTOP_DatVld    ( ITFTOP_DatVld    ),
    .ITFTOP_DatLast   ( ITFTOP_DatLast   ),
    .TOPITF_DatRdy    ( TOPITF_DatRdy    )
);

assign TOPITF_EmptyFull = {RdPortFull[0 +: 2], WrPortEmpty[0 +: 4], CCUITF_Empty};
assign TOPITF_ReqNum    = {RdPortReqNum[ADDR_WIDTH*0 +: ADDR_WIDTH*2]*SRAM_WIDTH/PORT_WIDTH, WrPortReqNum[0 +: ADDR_WIDTH*4]*SRAM_WIDTH/PORT_WIDTH, CCUITF_ReqNum};
assign TOPITF_Addr      = {RdPortAddr_Out[ADDR_WIDTH*0 +: ADDR_WIDTH*2], WrPortAddr_Out[0 +: ADDR_WIDTH*4], CCUITF_Addr};

// First 2 port (GLBRDIDX_ITFMAP, GLBRDIDX_ITFOFM) directly connected to ITF and arbed inside ITF
assign TOPITF_Dat[0          +: SRAM_WIDTH]       = RdPortDat[0                     +: (SRAM_WIDTH*MAXPAR)]; 
assign TOPITF_Dat[SRAM_WIDTH +: SRAM_WIDTH]       = RdPortDat[(SRAM_WIDTH*MAXPAR)   +: (SRAM_WIDTH*MAXPAR)]; 
assign TOPITF_DatVld    = RdPortDatVld[0 +: 2];
// assign TOPITF_DatLast   = RdPortDatLast[0 +: 2];
assign RdPortDatRdy[0 +: 2] = ITFTOP_DatRdy;

assign RdPortAddrUse[GLBRDIDX_ITFMAP] = 1'b0;
assign RdPortAddrVld[GLBRDIDX_ITFMAP] = 1'b0;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_ITFMAP +: ADDR_WIDTH] = 0;
assign RdPortAddrUse[GLBRDIDX_ITFOFM] = 1'b0;
assign RdPortAddrVld[GLBRDIDX_ITFOFM] = 1'b0;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_ITFOFM +: ADDR_WIDTH] = 0;


assign WrPortAddrUse[0 +: 4] = {4{1'b0}};
assign WrPortAddr[ADDR_WIDTH*0 +: ADDR_WIDTH*4] = 'd0;
assign ITFCCU_Dat= ITFTOP_Dat[0 +: SRAM_WIDTH];
assign WrPortDat[0                      +:  (SRAM_WIDTH*MAXPAR)]= ITFTOP_Dat[SRAM_WIDTH     +: SRAM_WIDTH];
assign WrPortDat[(SRAM_WIDTH*MAXPAR)    +:  (SRAM_WIDTH*MAXPAR)]= ITFTOP_Dat[SRAM_WIDTH*2   +: SRAM_WIDTH];
assign WrPortDat[(SRAM_WIDTH*MAXPAR)*2  +:  (SRAM_WIDTH*MAXPAR)]= ITFTOP_Dat[SRAM_WIDTH*3   +: SRAM_WIDTH];
assign WrPortDat[(SRAM_WIDTH*MAXPAR)*3  +:  (SRAM_WIDTH*MAXPAR)]= ITFTOP_Dat[SRAM_WIDTH*4   +: SRAM_WIDTH];
assign {WrPortDatVld[0 +: 4], ITFCCU_DatVld}                = ITFTOP_DatVld;
assign {WrPortDatLast[0 +: 4], ITFCCU_DatLast}              = ITFTOP_DatLast;
assign TOPITF_DatRdy                                        = {WrPortDatRdy[0 +: 4], CCUITF_DatRdy};

assign O_DatOE = ITFPAD_DatOE;

//=====================================================================================================================
// Logic Design: CCU
//=====================================================================================================================
CCU#(
    .ISA_SRAM_WORD           ( ISA_SRAM_WORD    ),
    .SRAM_WIDTH              ( SRAM_WIDTH       ),
    .PORT_WIDTH              ( PORT_WIDTH       ),
    .POOL_CORE               ( POOL_CORE        ),
    .ADDR_WIDTH              ( ADDR_WIDTH       ),
    .DRAM_ADDR_WIDTH         ( DRAM_ADDR_WIDTH  ),
    .GLB_NUM_RDPORT          ( GLB_NUM_RDPORT   ),
    .GLB_NUM_WRPORT          ( GLB_NUM_WRPORT   ),
    .IDX_WIDTH               ( IDX_WIDTH        ),
    .CHN_WIDTH               ( CHN_WIDTH        ),
    .QNTSL_WIDTH             ( QNTSL_WIDTH        ),
    .ACT_WIDTH               ( ACT_WIDTH        ),
    .MAP_WIDTH               ( MAP_WIDTH        ),
    .MAXPAR                  ( MAXPAR           ),
    .NUM_BANK                ( NUM_BANK         ),
    .ITF_NUM_RDPORT          ( ITF_NUM_RDPORT   ),
    .ITF_NUM_WRPORT          ( ITF_NUM_WRPORT   )
)u_CCU(
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .TOPCCU_start            ( TOPCCU_start            ),
    .CCUTOP_NetFnh           ( O_NetFnh                ),
    .CCUITF_Empty            ( CCUITF_Empty            ),
    .CCUITF_ReqNum           ( CCUITF_ReqNum           ),
    .CCUITF_Addr             ( CCUITF_Addr             ),
    .ITFCCU_Dat              ( ITFCCU_Dat              ),
    .ITFCCU_DatVld           ( ITFCCU_DatVld           ),
    .CCUITF_DatRdy           ( CCUITF_DatRdy           ),
    .CCUITF_BaseAddr         ( CCUITF_BaseAddr         ),
    .CCUSYA_Rst              ( CCUSYA_Rst              ),
    .CCUSYA_CfgVld           ( CCUSYA_CfgVld           ),
    .SYACCU_CfgRdy           ( SYACCU_CfgRdy           ),
    .CCUSYA_CfgMod           ( CCUSYA_CfgMod           ),
    .CCUSYA_CfgNip           ( CCUSYA_CfgNip           ),
    .CCUSYA_CfgChi           ( CCUSYA_CfgChi           ),
    .CCUSYA_CfgScale         ( CCUSYA_CfgScale         ),
    .CCUSYA_CfgShift         ( CCUSYA_CfgShift         ),
    .CCUSYA_CfgZp            ( CCUSYA_CfgZp            ),
    .CCUPOL_Rst              ( CCUPOL_Rst              ),
    .CCUPOL_CfgVld           ( CCUPOL_CfgVld           ),
    .POLCCU_CfgRdy           ( POLCCU_CfgRdy           ),
    .CCUPOL_CfgK             ( CCUPOL_CfgK             ),
    .CCUPOL_CfgNip           ( CCUPOL_CfgNip           ),
    .CCUPOL_CfgChi           ( CCUPOL_CfgChi           ),
    .CCUPOL_AddrMin          ( CCUPOL_AddrMin          ),
    .CCUPOL_AddrMax          ( CCUPOL_AddrMax          ),    
    .CCUFPS_Rst              ( CCUFPS_Rst              ),
    .CCUFPS_CfgVld           ( CCUFPS_CfgVld           ),
    .FPSCCU_CfgRdy           ( FPSCCU_CfgRdy           ),
    .CCUFPS_CfgNip           ( CCUFPS_CfgNip           ),
    .CCUFPS_CfgNop           ( CCUFPS_CfgNop           ),
    .CCUKNN_Rst              ( CCUKNN_Rst              ),
    .CCUKNN_CfgVld           ( CCUKNN_CfgVld           ),
    .KNNCCU_CfgRdy           ( KNNCCU_CfgRdy           ),
    .CCUKNN_CfgNip           ( CCUKNN_CfgNip           ),
    .CCUKNN_CfgK             ( CCUKNN_CfgK             ),
    .CCUGLB_Rst              ( CCUGLB_Rst              ),
    .CCUGLB_CfgVld           ( CCUGLB_CfgVld           ),
    .GLBCCU_CfgRdy           ( GLBCCU_CfgRdy           ),
    .CCUGLB_CfgPortBankFlag  ( CCUGLB_CfgPortBankFlag  ),
    .CCUGLB_CfgPortNum       ( CCUGLB_CfgPortNum       ),
    .CCUGLB_CfgPortParBank   ( CCUGLB_CfgPortParBank   ),
    .CCUGLB_CfgPortLoop      ( CCUGLB_CfgPortLoop      )
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
    .MAXPAR                  ( MAXPAR           ),
    .CLOCK_PERIOD            ( CLOCK_PERIOD     ) 
)u_GLB(
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .CCUGLB_CfgVld           ( CCUGLB_CfgVld           ),
    .GLBCCU_CfgRdy           ( GLBCCU_CfgRdy           ),
    .CCUGLB_CfgPortBankFlag  ( CCUGLB_CfgPortBankFlag  ),
    .CCUGLB_CfgPortNum  ( CCUGLB_CfgPortNum  ),
    .CCUGLB_CfgPortParBank   ( CCUGLB_CfgPortParBank ),
    .CCUGLB_CfgPortLoop   ( CCUGLB_CfgPortLoop ),
    .WrPortDat               ( WrPortDat               ),
    .WrPortDatVld            ( WrPortDatVld            ),
    // .WrPortDatLast           ( WrPortDatLast           ),
    .WrPortDatRdy            ( WrPortDatRdy            ),
    .WrPortEmpty             ( WrPortEmpty             ),
    .WrPortReqNum            ( WrPortReqNum            ),
    .WrPortAddr_Out          ( WrPortAddr_Out          ),
    .WrPortAddrUse           ( WrPortAddrUse           ),
    .WrPortAddr              ( WrPortAddr              ),
    .RdPortDat               ( RdPortDat               ),
    .RdPortDatVld            ( RdPortDatVld            ),
    // .RdPortDatLast           ( RdPortDatLast           ),
    .RdPortDatRdy            ( RdPortDatRdy            ),
    .RdPortFull              ( RdPortFull              ),
    .RdPortReqNum            ( RdPortReqNum            ),
    .RdPortAddr_Out          ( RdPortAddr_Out          ),
    .RdPortAddrUse           ( RdPortAddrUse           ),
    .RdPortAddr              ( RdPortAddr              ),
    .RdPortAddrVld           ( RdPortAddrVld           ),
    .RdPortAddrRdy           ( RdPortAddrRdy           ) 
);

//=====================================================================================================================
// Logic Design: FPS
//=====================================================================================================================
// Read Crd
assign RdPortAddrUse[GLBRDIDX_FPSCRD] = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_FPSCRD +: ADDR_WIDTH] = FPSGLB_CrdAddr;
assign RdPortAddrVld[GLBRDIDX_FPSCRD] = FPSGLB_CrdAddrVld;
assign GLBFPS_CrdAddrRdy = RdPortAddrRdy[GLBRDIDX_FPSCRD];

assign GLBFPS_Crd = RdPortDat[SRAM_WIDTH*GLBRDIDX_FPSCRD +: SRAM_WIDTH];
assign GLBFPS_CrdVld = RdPortDatVld[GLBRDIDX_FPSCRD];
assign RdPortDatRdy[GLBRDIDX_FPSCRD] = FPSGLB_CrdRdy;

// Read Dist&Idx
assign RdPortAddrUse[GLBRDIDX_FPSDST] = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_FPSDST +: ADDR_WIDTH] = FPSGLB_DistRdAddr;
assign RdPortAddrVld[GLBRDIDX_FPSDST] = FPSGLB_DistRdAddrVld;
assign GLBFPS_DistRdAddrRdy = RdPortAddrRdy[GLBRDIDX_FPSDST];

assign GLBFPS_DistIdx = RdPortDat[SRAM_WIDTH*GLBRDIDX_FPSDST +: SRAM_WIDTH];
assign GLBFPS_DistIdxVld = RdPortDatVld[GLBRDIDX_FPSDST];
assign RdPortDatRdy[GLBRDIDX_FPSDST] = FPSGLB_DistIdxRdy;

// Write back(Update) Dist&Idx
assign WrPortAddrUse[GLBWRIDX_FPSDST] = 1'b1;
assign WrPortAddr[ADDR_WIDTH*GLBWRIDX_FPSDST +: ADDR_WIDTH] = FPSGLB_DistWrAddr;

assign WrPortDat[ (SRAM_WIDTH*MAXPAR)*GLBWRIDX_FPSDST +:  (SRAM_WIDTH*MAXPAR)] = FPSGLB_DistIdx;
assign WrPortDatVld[GLBWRIDX_FPSDST] = FPSGLB_DistIdxVld;
assign GLBFPS_DistIdxRdy = WrPortDatRdy[GLBWRIDX_FPSDST];


// FPS Writes Mask to GLB
assign WrPortAddrUse[GLBWRIDX_FPSFMK] = 1'b1;
assign WrPortAddr[ADDR_WIDTH*GLBWRIDX_FPSFMK +: ADDR_WIDTH] = FPSGLB_MaskWrAddr;

assign WrPortDat[ (SRAM_WIDTH*MAXPAR)*GLBWRIDX_FPSFMK +:  (SRAM_WIDTH*MAXPAR)] = FPSGLB_MaskWrDat;
assign WrPortDatVld[GLBWRIDX_FPSFMK] = FPSGLB_MaskWrDatVld;
assign GLBFPS_MaskWrDatRdy = WrPortDatRdy[GLBWRIDX_FPSFMK];

// FPS Reads Mask from GLB
assign RdPortAddrUse[GLBRDIDX_FPSFMK] = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_FPSFMK +: ADDR_WIDTH] = FPSGLB_MaskRdAddr;
assign RdPortAddrVld[GLBRDIDX_FPSFMK] = FPSGLB_MaskRdAddrVld;
assign GLBFPS_MaskRdAddrRdy = RdPortAddrRdy[GLBRDIDX_FPSFMK];

assign GLBFPS_MaskRdDat = RdPortDat[SRAM_WIDTH*GLBRDIDX_FPSFMK +: SRAM_WIDTH];
assign GLBFPS_MaskRdDatVld = RdPortDatVld[GLBRDIDX_FPSFMK];
assign RdPortDatRdy[GLBRDIDX_FPSFMK] = FPSGLB_MaskRdDatRdy;

FPS #(
    .SRAM_WIDTH           ( SRAM_WIDTH  ),
    .IDX_WIDTH            ( IDX_WIDTH   ),
    .CRD_WIDTH            ( CRD_WIDTH   ),
    .CRD_DIM              ( CRD_DIM     ),
    .NUM_LAYER            ( NUM_SORT_CORE)
)u_FPS(
    .clk                  ( clk                  ),
    .rst_n                ( rst_n                ),
    .CCUFPS_Rst           ( CCUFPS_Rst           ),
    .CCUFPS_CfgVld        ( CCUFPS_CfgVld        ),
    .FPSCCU_CfgRdy        ( FPSCCU_CfgRdy        ),
    .CCUFPS_CfgNip        ( CCUFPS_CfgNip        ),
    .CCUFPS_CfgNop        ( CCUFPS_CfgNop        ),
    .FPSGLB_CrdAddr       ( FPSGLB_CrdAddr       ),
    .FPSGLB_CrdAddrVld    ( FPSGLB_CrdAddrVld    ),
    .GLBFPS_CrdAddrRdy    ( GLBFPS_CrdAddrRdy    ),
    .GLBFPS_Crd           ( GLBFPS_Crd           ),
    .GLBFPS_CrdVld        ( GLBFPS_CrdVld        ),
    .FPSGLB_CrdRdy        ( FPSGLB_CrdRdy        ),
    .FPSGLB_DistRdAddr    ( FPSGLB_DistRdAddr    ),
    .FPSGLB_DistRdAddrVld ( FPSGLB_DistRdAddrVld ),
    .GLBFPS_DistRdAddrRdy ( GLBFPS_DistRdAddrRdy ),
    .GLBFPS_DistIdx       ( GLBFPS_DistIdx       ),
    .GLBFPS_DistIdxVld    ( GLBFPS_DistIdxVld    ),
    .FPSGLB_DistIdxRdy    ( FPSGLB_DistIdxRdy    ),
    .FPSGLB_DistWrAddr    ( FPSGLB_DistWrAddr    ),
    .FPSGLB_DistIdx       ( FPSGLB_DistIdx       ),
    .FPSGLB_DistIdxVld    ( FPSGLB_DistIdxVld    ),
    .GLBFPS_DistIdxRdy    ( GLBFPS_DistIdxRdy    ),
    .FPSGLB_MaskRdAddr    ( FPSGLB_MaskRdAddr    ),
    .FPSGLB_MaskRdAddrVld ( FPSGLB_MaskRdAddrVld ),
    .GLBFPS_MaskRdAddrRdy ( GLBFPS_MaskRdAddrRdy ),
    .GLBFPS_MaskRdDat     ( GLBFPS_MaskRdDat     ),
    .GLBFPS_MaskRdDatVld  ( GLBFPS_MaskRdDatVld  ),
    .FPSGLB_MaskRdDatRdy  ( FPSGLB_MaskRdDatRdy  ),
    .FPSGLB_MaskWrAddr    ( FPSGLB_MaskWrAddr    ),
    .FPSGLB_MaskWrBitEn   ( FPSGLB_MaskWrBitEn   ),
    .FPSGLB_MaskWrDatVld  ( FPSGLB_MaskWrDatVld  ),
    .FPSGLB_MaskWrDat     ( FPSGLB_MaskWrDat     ),
    .GLBFPS_MaskWrDatRdy  ( GLBFPS_MaskWrDatRdy  )
);

//=====================================================================================================================
// Logic Design: KNN
//=====================================================================================================================
// Read Crd
assign RdPortAddrUse[GLBRDIDX_KNNCRD] = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_KNNCRD +: ADDR_WIDTH] = KNNGLB_CrdAddr;
assign RdPortAddrVld[GLBRDIDX_KNNCRD] = KNNGLB_CrdAddrVld;
assign GLBKNN_CrdAddrRdy = RdPortAddrRdy[GLBRDIDX_KNNCRD];

assign GLBKNN_Crd = RdPortDat[SRAM_WIDTH*GLBRDIDX_KNNCRD +: SRAM_WIDTH];
assign GLBKNN_CrdVld = RdPortDatVld[GLBRDIDX_KNNCRD];
assign RdPortDatRdy[GLBRDIDX_KNNCRD] = KNNGLB_CrdRdy;

// KNN Reads Mask from GLB
assign RdPortAddrUse[GLBRDIDX_KNNKMK] = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_KNNKMK +: ADDR_WIDTH] = KNNGLB_MaskRdAddr;
assign RdPortAddrVld[GLBRDIDX_KNNKMK] = KNNGLB_MaskRdAddrVld;
assign GLBKNN_MaskRdAddrRdy = RdPortAddrRdy[GLBRDIDX_KNNKMK];

assign GLBKNN_MaskRdDat = RdPortDat[SRAM_WIDTH*GLBRDIDX_KNNKMK +: SRAM_WIDTH];
assign GLBKNN_MaskRdDatVld = RdPortDatVld[GLBRDIDX_KNNKMK];
assign RdPortDatRdy[GLBRDIDX_KNNKMK] = KNNGLB_MaskRdDatRdy;


// Write MAP
assign WrPortAddrUse[GLBWRIDX_KNNMAP] = 1'b0;
assign WrPortAddr[ADDR_WIDTH*GLBWRIDX_KNNMAP +: ADDR_WIDTH] = 'd0;
assign WrPortDat[(SRAM_WIDTH*MAXPAR)*GLBWRIDX_KNNMAP +:  (SRAM_WIDTH*MAXPAR)] =  KNNGLB_Map;
assign WrPortDatVld[GLBWRIDX_KNNMAP] = KNNGLB_MapVld;
assign GLBKNN_MapRdy = WrPortDatRdy[GLBWRIDX_KNNMAP];


KNN#(
    .SRAM_WIDTH           ( SRAM_WIDTH      ),
    .IDX_WIDTH            ( IDX_WIDTH       ),
    .MAP_WIDTH            ( MAP_WIDTH       ),
    .CRD_WIDTH            ( CRD_WIDTH       ),
    .CRD_DIM              ( CRD_DIM         ),
    .NUM_SORT_CORE        ( NUM_SORT_CORE   )
)u_KNN(
    .clk                  ( clk                  ),
    .rst_n                ( rst_n                ),
    .CCUKNN_Rst           ( CCUKNN_Rst           ),
    .CCUKNN_CfgVld        ( CCUKNN_CfgVld        ),
    .KNNCCU_CfgRdy        ( KNNCCU_CfgRdy        ),
    .CCUKNN_CfgNip        ( CCUKNN_CfgNip        ),
    .CCUKNN_CfgK          ( CCUKNN_CfgK          ),
    .KNNGLB_CrdAddr       ( KNNGLB_CrdAddr       ),
    .KNNGLB_CrdAddrVld    ( KNNGLB_CrdAddrVld    ),
    .GLBKNN_CrdAddrRdy    ( GLBKNN_CrdAddrRdy    ),
    .GLBKNN_Crd           ( GLBKNN_Crd           ),
    .GLBKNN_CrdVld        ( GLBKNN_CrdVld        ),
    .KNNGLB_CrdRdy        ( KNNGLB_CrdRdy        ),
    .KNNGLB_MaskRdAddr    ( KNNGLB_MaskRdAddr    ),
    .KNNGLB_MaskRdAddrVld ( KNNGLB_MaskRdAddrVld ),
    .GLBKNN_MaskRdAddrRdy ( GLBKNN_MaskRdAddrRdy ),
    .GLBKNN_MaskRdDat     ( GLBKNN_MaskRdDat    ),
    .GLBKNN_MaskRdDatVld  ( GLBKNN_MaskRdDatVld ),
    .KNNGLB_MaskRdDatRdy  ( KNNGLB_MaskRdDatRdy    ),
    .KNNGLB_Map           ( KNNGLB_Map           ),
    .KNNGLB_MapVld        ( KNNGLB_MapVld        ),
    .GLBKNN_MapRdy        ( GLBKNN_MapRdy        )
);

//=====================================================================================================================
// Logic Design: SYA
//=====================================================================================================================
assign RdPortAddrUse[GLBRDIDX_SYAACT] = 1'b0;
assign RdPortAddrVld[GLBRDIDX_SYAACT] = 1'b0;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_SYAACT +: ADDR_WIDTH] = 0;
assign GLBSYA_Act = RdPortDat[ (SRAM_WIDTH*MAXPAR)*GLBRDIDX_SYAACT +: (SRAM_WIDTH*MAXPAR)];
assign GLBSYA_ActVld = RdPortDatVld[GLBRDIDX_SYAACT];
assign RdPortDatRdy[GLBRDIDX_SYAACT] = SYAGLB_ActRdy;

assign RdPortAddrUse[GLBRDIDX_SYAWGT] = 1'b0;
assign RdPortAddrVld[GLBRDIDX_SYAWGT] = 1'b0;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_SYAWGT +: ADDR_WIDTH] = 0;
assign GLBSYA_Wgt = RdPortDat[(SRAM_WIDTH*MAXPAR)*GLBRDIDX_SYAWGT +: (SRAM_WIDTH*MAXPAR)];
assign GLBSYA_WgtVld = RdPortDatVld[GLBRDIDX_SYAWGT];
assign RdPortDatRdy[GLBRDIDX_SYAWGT] = SYAGLB_WgtRdy;

assign WrPortAddrUse[GLBWRIDX_SYAOFM] = 1'b0;
assign WrPortAddr[ADDR_WIDTH*GLBWRIDX_SYAOFM +: ADDR_WIDTH] = 'd0;
assign WrPortDat[ (SRAM_WIDTH*MAXPAR)*GLBWRIDX_SYAOFM +: (SRAM_WIDTH*MAXPAR) ] = SYAGLB_Ofm;
assign WrPortDatVld[GLBWRIDX_SYAOFM] = &SYAGLB_OfmVld; // ????????????????????????????? BUG 4bit to 1 bit
assign WrPortDatLast[GLBWRIDX_SYAOFM] = 1'b0;
assign GLBSYA_OfmRdy = {NUM_BANK{WrPortDatRdy[GLBWRIDX_SYAOFM]}};

SYA #(
    .ACT_WIDTH ( ACT_WIDTH      ), 
    .WGT_WIDTH ( ACT_WIDTH      ), 
    .NUM_ROW   ( SYA_NUM_ROW    ), 
    .NUM_COL   ( SYA_NUM_COL    ), 
    .NUM_BANK  ( SYA_NUM_BANK   ), 
    .SRAM_WIDTH( SRAM_WIDTH     ),
    .CHI_WIDTH ( CHN_WIDTH      ),
    .QNT_WIDTH ( QNTSL_WIDTH    )
) u_SYA(
    .clk            (clk            ),
    .rst_n          (rst_n          ),
    .CCUSYA_Rst     (CCUSYA_Rst     ),
    .CCUSYA_CfgVld  (CCUSYA_CfgVld  ),
    .SYACCU_CfgRdy  (SYACCU_CfgRdy  ),
    .CCUSYA_CfgMod  (CCUSYA_CfgMod  ),
    .CCUSYA_CfgNip  (CCUSYA_CfgNip  ),
    .CCUSYA_CfgChi  (CCUSYA_CfgChi  ),
    .CCUSYA_CfgScale(CCUSYA_CfgScale),
    .CCUSYA_CfgShift(CCUSYA_CfgShift),
    .CCUSYA_CfgZp   (CCUSYA_CfgZp   ),
    .GLBSYA_Act     (GLBSYA_Act     ), 
    .GLBSYA_ActVld  (GLBSYA_ActVld  ),
    .SYAGLB_ActRdy  (SYAGLB_ActRdy  ),
    .GLBSYA_Wgt     (GLBSYA_Wgt     ),
    .GLBSYA_WgtVld  (GLBSYA_WgtVld  ),
    .SYAGLB_WgtRdy  (SYAGLB_WgtRdy  ),
    .SYAGLB_Ofm     (SYAGLB_Ofm     ),
    .SYAGLB_OfmVld  (SYAGLB_OfmVld  ),
    .GLBSYA_OfmRdy  (GLBSYA_OfmRdy  )
);

//=====================================================================================================================
// Logic Design: POL
//=====================================================================================================================
assign RdPortAddrUse[GLBRDIDX_POLMAP] = 1'b0;
assign RdPortAddrVld[GLBRDIDX_POLMAP] = 1'b0;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_POLMAP +: ADDR_WIDTH] = 0;
assign GLBPOL_Map                                   = RdPortDat[(SRAM_WIDTH*MAXPAR)*GLBRDIDX_POLMAP +: (SRAM_WIDTH*MAXPAR)];
assign GLBPOL_MapVld                                = RdPortDatVld[GLBRDIDX_POLMAP];
assign RdPortDatRdy[GLBRDIDX_POLMAP]                = POLGLB_MapRdy;

assign RdPortAddrUse[GLBRDIDX_POLOFM +: POOL_CORE]  = {POOL_CORE{1'b1}};
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_POLOFM +: ADDR_WIDTH*POOL_CORE]= POLGLB_Addr;
assign RdPortAddrVld[GLBRDIDX_POLOFM +: POOL_CORE]  = POLGLB_AddrVld;
assign GLBPOL_AddrRdy                               = RdPortAddrRdy[GLBRDIDX_POLOFM +: POOL_CORE];

assign GLBPOL_Ofm                                   = RdPortDat[(SRAM_WIDTH*MAXPAR)*GLBRDIDX_POLOFM +: (SRAM_WIDTH*MAXPAR)*POOL_CORE];
assign GLBPOL_OfmVld                                = RdPortDatVld[GLBRDIDX_POLOFM +: POOL_CORE];
assign RdPortDatRdy[GLBRDIDX_POLOFM +: POOL_CORE]   = POLGLB_OfmRdy;

assign WrPortAddrUse[GLBWRIDX_POLOFM] = 1'b0;
assign WrPortAddr[ADDR_WIDTH*GLBWRIDX_POLOFM +: ADDR_WIDTH] = 'd0;
assign WrPortDat[(SRAM_WIDTH*MAXPAR)*GLBWRIDX_POLOFM +: (SRAM_WIDTH*MAXPAR)]= POLGLB_Ofm;
assign WrPortDatVld[GLBWRIDX_POLOFM]                = POLGLB_Ofm;
assign GLBPOL_OfmRdy                                = WrPortDatRdy[GLBWRIDX_POLOFM];


POL#(
    .IDX_WIDTH            ( IDX_WIDTH       ),
    .ACT_WIDTH            ( ACT_WIDTH       ),
    .POOL_COMP_CORE       ( POOL_COMP_CORE  ),
    .POOL_MAP_DEPTH_WIDTH ( MAP_WIDTH       ),
    .POOL_CORE            ( POOL_CORE       ),
    .CHN_WIDTH            ( CHN_WIDTH       ),
    .SRAM_WIDTH           ( SRAM_WIDTH      ) 
)u_POL(
    .clk                  ( clk                  ),
    .rst_n                ( rst_n                ),
    .CCUPOL_Rst           ( CCUPOL_Rst           ),
    .CCUPOL_CfgVld        ( CCUPOL_CfgVld        ),
    .POLCCU_CfgRdy        ( POLCCU_CfgRdy        ),
    .CCUPOL_CfgK          ( CCUPOL_CfgK          ),
    .CCUPOL_CfgNip        ( CCUPOL_CfgNip        ),
    .CCUPOL_CfgChi        ( CCUPOL_CfgChi        ),
    .CCUPOL_AddrMin       ( CCUPOL_AddrMin       ),
    .CCUPOL_AddrMax       ( CCUPOL_AddrMax       ),
    .GLBPOL_MapVld        ( GLBPOL_MapVld        ),
    .GLBPOL_Map           ( GLBPOL_Map           ),
    .POLGLB_MapRdy        ( POLGLB_MapRdy        ),
    .POLGLB_AddrVld       ( POLGLB_AddrVld       ),
    .POLGLB_Addr          ( POLGLB_Addr          ),
    .GLBPOL_AddrRdy       ( GLBPOL_AddrRdy       ),
    .GLBPOL_Ofm           ( GLBPOL_Ofm           ),
    .GLBPOL_OfmVld        ( GLBPOL_OfmVld        ),
    .POLGLB_OfmRdy        ( POLGLB_OfmRdy        ),
    .POLGLB_Ofm           ( POLGLB_Ofm           ),
    .POLGLB_OfmVld        ( POLGLB_OfmVld        ),
    .GLBPOL_OfmRdy        ( GLBPOL_OfmRdy        )
);

//=====================================================================================================================
// Logic Design: Debug
//=====================================================================================================================
DELAY#(
    .NUM_STAGES ( 1 ),
    .DATA_WIDTH ( 1 )
)u_DELAY_StartPulse_Deb(
    .CLK        ( clk        ),
    .RST_N      ( rst_n      ),
    .DIN        ( StartPulse_Deb        ),
    .DOUT       ( StartPulse_Deb_d       )
);

endmodule
