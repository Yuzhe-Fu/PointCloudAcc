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
    parameter CLOCK_PERIOD = 10,

    parameter PORT_WIDTH = 128,
    parameter SRAM_WIDTH = 256,
    parameter SRAM_WORD = 128,
    parameter ADDR_WIDTH = 16,
    parameter SRAM_WORD_ISA = 64,
    parameter ITF_NUM_RDPORT = 2,
    parameter ITF_NUM_WRPORT = 3,
    parameter GLB_NUM_RDPORT = 5,
    parameter GLB_NUM_WRPORT = 4,
    parameter MAXPAR        = 32,
    parameter NUM_BANK      = 32,

    // NetWork Parameters
    parameter IDX_WIDTH = 16,
    parameter CHN_WIDTH = 12,
    parameter ACT_WIDTH = 8,
    parameter MAP_WIDTH = 5,

    parameter CRD_WIDTH = 16,   
    parameter CRD_DIM   = 3,   
    parameter NUM_SORT_CORE = 8,

    parameter SYA_NUM_ROW  = 16,
    parameter SYA_NUM_COL  = 16,
    parameter SYA_NUM_BANK = 4,





    )(
input                           I_SysRst_n    , 
input                           I_SysClk      , 
input                           I_BypAsysnFIFO, 
inout   [PORT_WIDTH     -1 : 0] IO_Dat        , 
inout                           IO_DatVld     , 
inout                           IO_DatLast     , 
inout                           OI_DatRdy     , 
output                          O_DatOE         

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

//=====================================================================================================================
// Logic Design 1: FSM
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

assign TOPITF_EmptyFull = {RdPortFull[4 +: 2], WrPortEmpty[0 +: 2], CCUITF_Empty};
assign TOPITF_ReqNum    = {RdPortReqNum[ADDR_WIDTH*4 +: ADDR_WIDTH*2], WrPortReqNum[0 +: ADDR_WIDTH*2], CCUITF_ReqNum};
assign TOPITF_Addr      = {RdPortAddr[ADDR_WIDTH*4 +: ADDR_WIDTH*2], RdPortAddr[0 +: ADDR_WIDTH*2], CCUITF_Addr};

assign TOPITF_Dat       = RdPortDat[SRAM_WIDTH*4 +: SRAM_WIDTH*2];
assign TOPITF_DatVld    = RdPortDatVld[4 +: 2];
assign TOPITF_DatLast   = RdPortDatLast[4 +: 2];
assign RdPortDatRdy[4 +: 2] = ITFTOP_DatRdy;

assign {WrPortDat[SRAM_WIDTH*0 +: SRAM_WIDTH*2], ITFCCU_Dat}= ITFTOP_Dat;
assign {WrPortDatVld[0 +: 2], ITFCCU_DatVld}                = ITFTOP_DatVld;
assign {WrPortDatLast[0 +: 2], ITFCCU_DatLast}              = ITFTOP_DatLast;
assign TOPITF_DatRdy                                        = {WrPortDatRdy[0 +: 2], CCUITF_DatRdy};

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
    .WrPortAddr              ( WrPortAddr              ),
    .RdPortDat               ( RdPortDat               ),
    .RdPortDatVld            ( RdPortDatVld            ),
    .RdPortDatLast           ( RdPortDatLast           ),
    .RdPortDatRdy            ( RdPortDatRdy            ),
    .RdPortFull              ( RdPortFull              ),
    .RdPortReqNum            ( RdPortReqNum            ),
    .RdPortAddr              ( RdPortAddr              )
);


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
    .CTRGLB_CrdAddr     ( CTRGLB_CrdAddr     ), ?????????????????????????
    .CTRGLB_CrdAddrVld  ( CTRGLB_CrdAddrVld  ),
    .GLBCTR_CrdAddrRdy  ( GLBCTR_CrdAddrRdy  ),
    .GLBCTR_Crd         ( GLBCTR_Crd         ),
    .GLBCTR_CrdVld      ( GLBCTR_CrdVld      ),
    .CTRGLB_CrdRdy      ( CTRGLB_CrdRdy      ),
    .CTRGLB_DistAddr    ( CTRGLB_DistAddr    ),
    .CTRGLB_DistAddrVld ( CTRGLB_DistAddrVld ),
    .GLBCTR_DistAddrRdy ( GLBCTR_DistAddrRdy ),
    .GLBCTR_DistIdx     ( GLBCTR_DistIdx     ),
    .GLBCTR_DistIdxVld  ( GLBCTR_DistIdxVld  ),
    .CTRGLB_DistIdxRdy  ( CTRGLB_DistIdxRdy  ),
    .CTRGLB_Idx         ( CTRGLB_Idx         ),
    .CTRGLB_IdxVld      ( CTRGLB_IdxVld      ),
    .CTRGLB_IdxRdy      ( CTRGLB_IdxRdy      )
);

assign GLBSYA_Act = RdPortDat[ (SRAM_WIDTH*MAXPAR)*2 +: (SRAM_WIDTH*MAXPAR)];
assign GLBSYA_ActVld = RdPortDatVld[2];
assign RdPortDatRdy[2] = SYAGLB_ActRdy;

assign GLBSYA_Wgt = RdPortDat[c];
assign GLBSYA_WgtVld = RdPortDatVld[3];
assign RdPortDatRdy[3] = SYAGLB_WgtRdy;

assign WrPortDat[ (SRAM_WIDTH*MAXPAR)*2 +: (SRAM_WIDTH*MAXPAR) ] = SYAGLB_Ofm;
assign WrPortDatVld[2] = SYAGLB_OfmVld;
assign GLBSYA_OfmRdy = WrPortDatRdy[2];


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
)

assign GLBPOL_Idx = RdPortDat[(SRAM_WIDTH*MAXPAR)*0 +: (SRAM_WIDTH*MAXPAR)];
assign GLBPOL_IdxVld = RdPortDatVld[0];
assign RdPortDatVld[0] = POLGLB_IdxRdy;

assign GLBPOL_Fm = RdPortDat[(SRAM_WIDTH*MAXPAR)*4 +: (SRAM_WIDTH*MAXPAR)];
assign GLBPOL_FmVld = RdPortDatVld[4];
assign RdPortDatRdy[4] = POLGLB_FmRdy;

assign WrPortDat[(SRAM_WIDTH*MAXPAR)*3 +: (SRAM_WIDTH*MAXPAR)] = POLGLB_Fm;
assign WrPortDatVld[3] = POLGLB_Fm;
assign GLBPOL_FmRdy = WrPortDatRdy[3];


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
    .GLBPOL_IdxVld        ( GLBPOL_IdxVld        ),
    .GLBPOL_Idx           ( GLBPOL_Idx           ),
    .POLGLB_IdxRdy        ( POLGLB_IdxRdy        ),
    .POLGLB_AddrVld       ( POLGLB_AddrVld       ),
    .POLGLB_Addr          ( POLGLB_Addr          ),????????????????????????????
    .GLBPOL_AddrRdy       ( GLBPOL_AddrRdy       ),
    .GLBPOL_Fm            ( GLBPOL_Fm            ),
    .GLBPOL_FmVld         ( GLBPOL_FmVld         ),
    .POLGLB_FmRdy         ( POLGLB_FmRdy         ),
    .POLGLB_Fm            ( POLGLB_Fm            ),
    .POLGLB_FmVld         ( POLGLB_FmVld         ),
    .GLBPOL_FmRdy         ( GLBPOL_FmRdy         )
);



endmodule
