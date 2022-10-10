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
    parameter SRAM_BYTE_WIDTH = 8,
    parameter SRAM_WORD      = 128,
    parameter ADDR_WIDTH     = 16,
    parameter SRAM_WORD_ISA  = 64,
    parameter ITF_NUM_RDPORT = 2,
    parameter ITF_NUM_WRPORT = 3,
    parameter GLB_NUM_RDPORT = 5,
    parameter GLB_NUM_WRPORT = 4,
    parameter MAXPAR         = 32,
    parameter NUM_BANK       = 32,

    // NetWork Parameters
    parameter IDX_WIDTH      = 16,
    parameter CHN_WIDTH      = 12,
    parameter ACT_WIDTH      = 8,
    parameter MAP_WIDTH      = 5,

    parameter CRD_WIDTH      = 16,   
    parameter CRD_DIM        = 3,   
    parameter NUM_SORT_CORE  = 8,

    parameter SYA_NUM_ROW    = 16,
    parameter SYA_NUM_COL    = 16,
    parameter SYA_NUM_BANK   = 4

    )(
input                           I_SysRst_n    , 
input                           I_SysClk      , 
input                           I_BypAsysnFIFO, 
inout   [PORT_WIDTH     -1 : 0] IO_Dat        , 
inout                           IO_DatVld     , 
inout                           IO_DatLast    , 
inout                           OI_DatRdy     , 
output                          O_DatOE         

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
localparam GLBWRIDX_CTRDST = 6;
localparam GLBWRIDX_CTRMAP = 7;

localparam GLBRDIDX_ITFMAP = 0;
localparam GLBRDIDX_ITFOFM = 1;
localparam GLBRDIDX_SYAACT = 2;
localparam GLBRDIDX_SYAWGT = 3;
localparam GLBRDIDX_POLOFM = 4;
localparam GLBRDIDX_POLMAP = 5;
localparam GLBRDIDX_CTRCRD = 6;
localparam GLBRDIDX_CTRDST = 7;


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================



//=====================================================================================================================
// Logic Design
//=====================================================================================================================
assign {IO_Dat, IO_DatVld, IO_DatLast} = O_DatOE? {ITFPAD_Dat, ITFPAD_DatVld, ITFPAD_DatLast} : {PORT_WIDTH{1'bz}, 1'bz, 1'bz};
assign PADITF_DatRdy = OI_DatRdy;

assign {PADITF_Dat, PADITF_DatVld, PADITF_DatLast} = {IO_Dat, IO_DatVld, IO_DatLast};
assign OI_DatRdy = O_DatOE? 1'bz : ITFPAD_DatRdy;

assign clk  = I_SysClk;
assign rst_n= I_SysRst_n;


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

ITF#(
    .PORT_WIDTH       ( PORT_WIDTH ),
    .SRAM_WIDTH       ( SRAM_WIDTH ),
    .ADDR_WIDTH       ( ADDR_WIDTH ),
    .NUM_RDPORT       ( ITF_NUM_RDPORT ),
    .NUM_WRPORT       ( ITF_NUM_WRPORT )
)u_ITF(
    .clk              ( clk              ),
    .rst_n            ( rst_n            ),
    .ITFPAD_Dat       ( ITFPAD_Dat       ),
    .ITFPAD_DatVld    ( ITFPAD_DatVld    ),
    .ITFPAD_DatLast   ( ITFPAD_DatLast   ),
    .PADITF_DatRdy    ( PADITF_DatRdy    ),
    .PADITF_Dat       ( PADITF_Dat       ),
    .PADITF_DatVld    ( PADITF_DatVld    ),
    .PADITF_DatLast   ( PADITF_DatLast   ),
    .ITFPAD_DatRdy    ( ITFPAD_DatRdy    ),
    .GLBITF_EmptyFull ( TOPITF_EmptyFull ),
    .GLBITF_ReqNum    ( TOPITF_ReqNum    ),
    .GLBITF_Addr      ( TOPITF_Addr      ),
    .CCUITF_BaseAddr  ( CCUITF_BaseAddr  ),
    .GLBITF_Dat       ( TOPITF_Dat       ),
    .GLBITF_DatVld    ( TOPITF_DatVld    ),
    .GLBITF_DatVld    ( TOPITF_DatLast    ),
    .ITFGLB_DatRdy    ( ITFTOP_DatRdy    ),
    .ITFGLB_Dat       ( ITFTOP_Dat       ),
    .ITFGLB_DatVld    ( ITFTOP_DatVld    ),
    .ITFGLB_DatLast   ( ITFTOP_DatLast    ),
    .GLBITF_DatRdy    ( TOPITF_DatRdy    )
);

assign TOPITF_EmptyFull = {RdPortFull[0 +: 2], WrPortEmpty[0 +: 3], CCUITF_Empty};
assign TOPITF_ReqNum    = {RdPortReqNum[ADDR_WIDTH*0 +: ADDR_WIDTH*2], WrPortReqNum[0 +: ADDR_WIDTH*3], CCUITF_ReqNum};
assign TOPITF_Addr      = {RdPortAddr_Out[ADDR_WIDTH*0 +: ADDR_WIDTH*2], WrPortAddr_Out[0 +: ADDR_WIDTH*3], CCUITF_Addr};

assign TOPITF_Dat       = RdPortDat[SRAM_WIDTH*0 +: SRAM_WIDTH*2];
assign TOPITF_DatVld    = RdPortDatVld[0 +: 2];
assign TOPITF_DatLast   = RdPortDatLast[0 +: 2];
assign RdPortDatRdy[0 +: 2] = ITFTOP_DatRdy;

assign {WrPortDat[SRAM_WIDTH*0 +: SRAM_WIDTH*3], ITFCCU_Dat}= ITFTOP_Dat;
assign {WrPortDatVld[0 +: 3], ITFCCU_DatVld}                = ITFTOP_DatVld;
assign {WrPortDatLast[0 +: 3], ITFCCU_DatLast}              = ITFTOP_DatLast;
assign TOPITF_DatRdy                                        = {WrPortDatRdy[0 +: 3], CCUITF_DatRdy};

CCU#(
    .SRAM_WORD_ISA           ( SRAM_WORD_ISA ),
    .SRAM_WIDTH              ( SRAM_WIDTH ),
    .ADDR_WIDTH              ( ADDR_WIDTH ),
    .NUM_RDPORT              ( GLB_NUM_RDPORT ),
    .NUM_WRPORT              ( GLB_NUM_WRPORT ),
    .IDX_WIDTH               ( IDX_WIDTH ),
    .CHN_WIDTH               ( CHN_WIDTH ),
    .ACT_WIDTH               ( ACT_WIDTH ),
    .MAP_WIDTH               ( MAP_WIDTH ),
    .MAXPAR                  ( MAXPAR    ),
    .NUM_BANK                ( NUM_BANK  )
)u_CCU(
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .TOPCCU_start            ( TOPCCU_start            ),
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
    .CCUCTR_Rst              ( CCUCTR_Rst              ),
    .CCUCTR_CfgVld           ( CCUCTR_CfgVld           ),
    .CTRCCU_CfgRdy           ( CTRCCU_CfgRdy           ),
    .CCUCTR_CfgMod           ( CCUCTR_CfgMod           ),
    .CCUCTR_CfgNip           ( CCUCTR_CfgNip           ),
    .CCUCTR_CfgNop           ( CCUCTR_CfgNop           ),
    .CCUCTR_CfgK             ( CCUCTR_CfgK             ),
    .CCUGLB_Rst              ( CCUGLB_Rst              ),
    .CCUGLB_CfgVld           ( CCUGLB_CfgVld           ),
    .GLBCCU_CfgRdy           ( GLBCCU_CfgRdy           ),
    .CCUGLB_CfgBankPort      ( CCUGLB_CfgBankPort      ),
    .CCUGLB_CfgPort_AddrMax  ( CCUGLB_CfgPort_AddrMax  ),
    .CCUGLB_CfgRdPortParBank ( CCUGLB_CfgRdPortParBank ),
    .CCUGLB_CfgWrPortParBank ( CCUGLB_CfgWrPortParBank  )
);

GLB#(
    .NUM_BANK                ( NUM_BANK ),
    .SRAM_WIDTH              ( SRAM_WIDTH ),
    .SRAM_WORD               ( SRAM_WORD ),
    .ADDR_WIDTH              ( ADDR_WIDTH ),
    .NUM_WRPORT              ( GLB_NUM_WRPORT ),
    .NUM_RDPORT              ( GLB_NUM_RDPORT ),
    .MAXPAR                  ( MAXPAR ),
    .CLOCK_PERIOD            ( CLOCK_PERIOD )
)u_GLB(
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .CCUGLB_CfgVld           ( CCUGLB_CfgVld           ),
    .GLBCCU_CfgRdy           ( GLBCCU_CfgRdy           ),
    .CCUGLB_CfgBankPort      ( CCUGLB_CfgBankPort      ),
    .CCUGLB_CfgPort_AddrMax  ( CCUGLB_CfgPort_AddrMax  ),
    .CCUGLB_CfgRdPortParBank ( CCUGLB_CfgRdPortParBank ),
    .CCUGLB_CfgWrPortParBank ( CCUGLB_CfgWrPortParBank ),
    .WrPortDat               ( WrPortDat               ),
    .WrPortDatVld            ( WrPortDatVld            ),
    .WrPortDatRdy            ( WrPortDatRdy            ),
    .WrPortEmpty             ( WrPortEmpty             ),
    .WrPortReqNum            ( WrPortReqNum            ),
    .WrPortAddr_Out          ( WrPortAddr_Out          ),
    .WrPortUseAddr           ( WrPortUseAddr           ),
    .WrPortAddr              ( WrPortAddr              ),
    .RdPortDat               ( RdPortDat               ),
    .RdPortDatVld            ( RdPortDatVld            ),
    .RdPortDatLast           ( RdPortDatLast           ),
    .RdPortDatRdy            ( RdPortDatRdy            ),
    .RdPortFull              ( RdPortFull              ),
    .RdPortReqNum            ( RdPortReqNum            ),
    .RdPortAddr_Out          ( RdPortAddr_Out          ).
    .RdPortUseAddr           ( RdPortUseAddr            ),
    .RdPortAddr              ( RdPortAddr               ),
    .RdPortAddrVld           ( RdPortAddrVld            ),
    .RdPortAddrRdy           ( RdPortAddrRdy            )
);
wire [SRAM_WIDTH                                -1 : 0] GLBCTR_Crd;
wire [SRAM_WIDTH                                -1 : 0] GLBCTR_DistIdx;
wire [SRAM_WIDTH                                -1 : 0] CTRGLB_Map;
wire [SRAM_WIDTH                                -1 : 0] CTRGLB_DistIdx;

// Read Crd
assign RdPortUseAddr[GLBRDIDX_CTRCRD] = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_CTRCRD +: ADDR_WIDTH] = CTRGLB_CrdAddr;
assign RdPortAddrVld[GLBRDIDX_CTRCRD] = CTRGLB_CrdAddrVld;
assign GLBCTR_CrdAddrRdy = RdPortAddrRdy[GLBRDIDX_CTRCRD];

assign GLBCTR_Crd = RdPortDat[SRAM_WIDTH*GLBRDIDX_CTRCRD +: SRAM_WIDTH];
assign GLBCTR_CrdVld = RdPortDatVld[GLBRDIDX_CTRCRD];
assign RdPortDatRdy[GLBRDIDX_CTRCRD] = CTRGLB_CrdRdy;

// Read Dist&Idx
assign RdPortUseAddr[GLBRDIDX_CTRDST] = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_CTRDST +: ADDR_WIDTH] = CTRGLB_DistRdAddr;
assign RdPortAddrVld[GLBRDIDX_CTRDST] = CTRGLB_DistAddrRdVld;
assign GLBCTR_DistRdAddrRdy = RdPortAddrRdy[GLBRDIDX_CTRDST];

assign GLBCTR_DistIdx = RdPortDat[SRAM_WIDTH*GLBRDIDX_CTRDST +: SRAM_WIDTH];
assign GLBCTR_DistIdxVld = RdPortDatVld[GLBRDIDX_CTRDST];
assign RdPortDatRdy[GLBRDIDX_CTRDST] = CTRGLB_DistIdxRdy;

// Write(Update) Dist&Idx
assign WrPortUseAddr[GLBWRIDX_CTRDST] = 1'b1;
assign WrPortAddr[ADDR_WIDTH*GLBWRIDX_CTRDST +: ADDR_WIDTH] = CTRGLB_DistWrAddr;

assign WrPortDat[SRAM_WIDTH*GLBWRIDX_CTRDST +: SRAM_WIDTH] = CTRGLB_DistIdx;
assign WrPortDatVld[GLBWRIDX_CTRDST] = CTRGLB_DistIdxVld;
assign GLBCTR_DistIdxRdy = WrPortDatRdy[GLBWRIDX_CTRDST];

// Write MAP
assign WrPortDat[ADDR_WIDTH*6 +: ADDR_WIDTH] =  CTRGLB_Map;
assign WrPortDatVld[6] = CTRGLB_MapVld;
assign GLBCTR_MapRdy = WrPortDatRdy[6];

CTR#(
    .SRAM_WIDTH         ( SRAM_WIDTH    ),
    .IDX_WIDTH          ( IDX_WIDTH     ),
    .SORT_LEN_WIDTH     ( MAP_WIDTH     ),
    .CRD_WIDTH          ( CRD_WIDTH     ),
    .CRD_DIM            ( CRD_DIM       ),
    .DISTSQR_WIDTH      ( DISTSQR_WIDTH ),
    .NUM_SORT_CORE      ( NUM_SORT_CORE )
)u_CTR(
    .clk                ( clk                ),
    .rst_n              ( rst_n              ),
    .CCUCTR_Rst         ( CCUCTR_Rst         ),
    .CCUCTR_CfgVld      ( CCUCTR_CfgVld      ),
    .CTRCCU_CfgRdy      ( CTRCCU_CfgRdy      ),
    .CCUCTR_CfgMod      ( CCUCTR_CfgMod      ),
    .CCUCTR_CfgNip      ( CCUCTR_CfgNip      ),
    .CCUCTR_CfgNop      ( CCUCTR_CfgNop      ),
    .CCUCTR_CfgK        ( CCUCTR_CfgK        ),
    .CTRGLB_CrdAddr     ( CTRGLB_CrdAddr     ),
    .CTRGLB_CrdAddrVld  ( CTRGLB_CrdAddrVld  ),
    .GLBCTR_CrdAddrRdy  ( GLBCTR_CrdAddrRdy  ),
    .GLBCTR_Crd         ( GLBCTR_Crd         ),
    .GLBCTR_CrdVld      ( GLBCTR_CrdVld      ),
    .CTRGLB_CrdRdy      ( CTRGLB_CrdRdy      ),
    .CTRGLB_DistRdAddr   ( CTRGLB_DistRdAddr   ),
    .CTRGLB_DistRdAddrVld( CTRGLB_DistRdAddrVld),
    .GLBCTR_DistRdAddrRdy( GLBCTR_DistRdAddrRdy),
    .GLBCTR_DistIdx     ( GLBCTR_DistIdx     ),
    .GLBCTR_DistIdxVld  ( GLBCTR_DistIdxVld  ),
    .CTRGLB_DistIdxRdy  ( CTRGLB_DistIdxRdy  ),

    .CTRGLB_DistWrAddr  ( CTRGLB_DistWrAddr  ),
    .CTRGLB_DistIdx     ( CTRGLB_DistIdx     ),
    .CTRGLB_DistIdxVld  ( CTRGLB_DistIdxVld  ),
    .GLBCTR_DistIdxRdy  ( GLBCTR_DistIdxRdy  ),
    .CTRGLB_Map         ( CTRGLB_Map         ),
    .CTRGLB_MapVld      ( CTRGLB_MapVld      ),
    .GLBCTR_MapRdy      ( GLBCTR_MapRdy      )
);

wire [SRAM_BYTE_WIDTH*SYA_NUM_ROW*SYA_NUM_COL*SYA_NUM_BANK/16   -1 : 0] SYAGLB_Ofm;
wire [SRAM_BYTE_WIDTH*SYA_NUM_ROW*SYA_NUM_BANK                  -1 : 0] GLBSYA_Act;
wire [SRAM_BYTE_WIDTH*SYA_NUM_COL*SYA_NUM_BANK                  -1 : 0] GLBSYA_Wgt;

assign GLBSYA_Act = RdPortDat[ (SRAM_WIDTH*MAXPAR)*GLBRDIDX_SYAACT +: (SRAM_WIDTH*MAXPAR)];
assign GLBSYA_ActVld = RdPortDatVld[GLBRDIDX_SYAACT];
assign RdPortDatRdy[GLBRDIDX_SYAACT] = SYAGLB_ActRdy;

assign GLBSYA_Wgt = RdPortDat[(SRAM_WIDTH*MAXPAR)*GLBRDIDX_SYAWGT +: (SRAM_WIDTH*MAXPAR)];
assign GLBSYA_WgtVld = RdPortDatVld[GLBRDIDX_SYAWGT];
assign RdPortDatRdy[GLBRDIDX_SYAWGT] = SYAGLB_WgtRdy;

assign WrPortDat[ (SRAM_WIDTH*MAXPAR)*GLBWRIDX_SYAOFM +: (SRAM_WIDTH*MAXPAR) ] = SYAGLB_Ofm;
assign WrPortDatVld[GLBWRIDX_SYAOFM] = SYAGLB_OfmVld;
assign GLBSYA_OfmRdy = WrPortDatRdy[GLBWRIDX_SYAOFM];

SYA #(
    .ACT_WIDTH ( ACT_WIDTH), 
    .WGT_WIDTH ( ACT_WIDTH), 
    .NUM_ROW   ( SYA_NUM_ROW  ), 
    .NUM_COL   ( SYA_NUM_COL  ), 
    .NUM_BANK  ( SYA_NUM_BANK ), 
    .SRAM_WIDTH( SRAM_WIDTH) 
)(
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

wire [SRAM_BYTE_WIDTH*POOL_COMP_CORE            -1 : 0] POLGLB_Fm;
wire [SRAM_BYTE_WIDTH*POOL_COMP_CORE*POOL_CORE  -1 : 0] GLBPOL_Fm;
wire [SRAM_WIDTH                                -1 : 0] GLBPOL_Map;

assign GLBPOL_Map                                     = RdPortDat[(SRAM_WIDTH*MAXPAR)*GLBRDIDX_POLMAP +: (SRAM_WIDTH*MAXPAR)];
assign GLBPOL_MapVld                                  = RdPortDatVld[GLBRDIDX_POLMAP];
assign RdPortDatVld[GLBRDIDX_POLMAP]                  = POLGLB_MapRdy;

assign RdPortUseAddr[GLBRDIDX_POLOFM]                 = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_POLOFM + : ADDR_WIDTH]= POLGLB_Addr;
assign RdPortAddrVld[GLBRDIDX_POLOFM]                 = POLGLB_AddrVld;
assign GLBPOL_AddrRdy                                 = RdPortAddrRdy[GLBRDIDX_POLOFM];

assign GLBPOL_Fm                                      = RdPortDat[(SRAM_WIDTH*MAXPAR)*GLBRDIDX_POLOFM +: (SRAM_WIDTH*MAXPAR)];
assign GLBPOL_FmVld                                   = RdPortDatVld[GLBRDIDX_POLOFM];
assign RdPortDatRdy[GLBRDIDX_POLOFM]                  = POLGLB_FmRdy;

assign WrPortDat[(SRAM_WIDTH*MAXPAR)*GLBWRIDX_POLOFM +: (SRAM_WIDTH*MAXPAR)]= POLGLB_Fm;
assign WrPortDatVld[GLBWRIDX_POLOFM]                  = POLGLB_Fm;
assign GLBPOL_FmRdy                                   = WrPortDatRdy[GLBWRIDX_POLOFM];


POL#(
    .IDX_WIDTH            ( IDX_WIDTH ),
    .ACT_WIDTH            ( ACT_WIDTH ),
    .POOL_COMP_CORE       ( POOL_COMP_CORE ),
    .POOL_MAP_DEPTH_WIDTH ( MAP_WIDTH ),
    .POOL_CORE            ( POOL_CORE )
)u_POL(
    .clk                  ( clk                  ),
    .rst_n                ( rst_n                ),
    .CCUPOL_Rst           ( CCUPOL_Rst           ),
    .CCUPOL_CfgVld        ( CCUPOL_CfgVld        ),
    .POLCCU_CfgRdy        ( POLCCU_CfgRdy        ),
    .CCUPOL_CfgK          ( CCUPOL_CfgK          ),
    .CCUPOL_CfgNip        ( CCUPOL_CfgNip        ),
    .CCUPOL_CfgChi        ( CCUPOL_CfgChi        ),
    .GLBPOL_MapVld        ( GLBPOL_MapVld        ),
    .GLBPOL_Map           ( GLBPOL_Map           ),
    .POLGLB_MapRdy        ( POLGLB_MapRdy        ),
    .POLGLB_AddrVld       ( POLGLB_AddrVld       ),
    .POLGLB_Addr          ( POLGLB_Addr          ),
    .GLBPOL_AddrRdy       ( GLBPOL_AddrRdy       ),
    .GLBPOL_Fm            ( GLBPOL_Fm            ),
    .GLBPOL_FmVld         ( GLBPOL_FmVld         ),
    .POLGLB_FmRdy         ( POLGLB_FmRdy         ),
    .POLGLB_Fm            ( POLGLB_Fm            ),
    .POLGLB_FmVld         ( POLGLB_FmVld         ),
    .GLBPOL_FmRdy         ( GLBPOL_FmRdy         )
);


endmodule
