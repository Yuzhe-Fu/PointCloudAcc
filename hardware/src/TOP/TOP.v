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



    )(
input                           I_SysRst_n    , 
input                           I_SysClk      , 
input                           I_BypAsysnFIFO, 
inout   [PORT_WIDTH     -1 : 0] IO_Dat        , 
inout                           IO_DatVld     , 
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
// Logic Design 2: Addr Gen.
//=====================================================================================================================



//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================
CCU#(
    .SRAM_WORD_ISA           ( 64 ),
    .SRAM_WIDTH              ( 256 ),
    .ADDR_WIDTH              ( 16 ),
    .NUM_RDPORT              ( 2 ),
    .NUM_WRPORT              ( 3 ),
    .IDX_WIDTH               ( 16 ),
    .CHN_WIDTH               ( 12 ),
    .ACT_WIDTH               ( 8 ),
    .MAP_WIDTH               ( 5 ),
    .MAXPAR                  ( 32 ),
    .NUM_BANK                ( 32 )
)u_CCU(
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .TOPCCU_start            ( TOPCCU_start            ),
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
    .CCUGLB_CfgWrPortParBank  ( CCUGLB_CfgWrPortParBank  )
);

GLB#(
    .NUM_BANK                ( 32 ),
    .SRAM_WIDTH              ( 256 ),
    .SRAM_WORD               ( 128 ),
    .ADDR_WIDTH              ( 16 ),
    .NUM_WRPORT              ( 3 ),
    .NUM_RDPORT              ( 4 ),
    .MAXPAR                  ( 32 ),
    .LOOP_WIDTH              ( 10 ),
    .CLOCK_PERIOD            ( 10 )
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
    .WrPortFull              ( WrPortFull              ),
    .WrPortReqNum            ( WrPortReqNum            ),
    .WrPortAddr              ( WrPortAddr              ),
    .RdPortDat               ( RdPortDat               ),
    .RdPortDatVld            ( RdPortDatVld            ),
    .RdPortDatRdy            ( RdPortDatRdy            ),
    .RdPortEmpty             ( RdPortEmpty             ),
    .RdPortReqNum            ( RdPortReqNum            ),
    .RdPortAddr              ( RdPortAddr              )
);

ITF#(
    .PORT_WIDTH       ( 128 ),
    .SRAM_WIDTH       ( 256 ),
    .ADDR_WIDTH       ( 16 ),
    .NUM_RDPORT       ( 2 ),
    .NUM_WRPORT       ( 3 )
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
    .GLBITF_EmptyFull ( GLBITF_EmptyFull ),
    .GLBITF_ReqNum    ( GLBITF_ReqNum    ),
    .GLBITF_Addr      ( GLBITF_Addr      ),
    .CCUITF_BaseAddr  ( CCUITF_BaseAddr  ),
    .GLBITF_Dat       ( GLBITF_Dat       ),
    .GLBITF_DatVld    ( GLBITF_DatVld    ),
    .ITFGLB_DatRdy    ( ITFGLB_DatRdy    ),
    .ITFGLB_Dat       ( ITFGLB_Dat       ),
    .ITFGLB_DatVld    ( ITFGLB_DatVld    ),
    .GLBITF_DatRdy    ( GLBITF_DatRdy    )
);

CTR#(
    .SRAM_WIDTH         ( 256 ),
    .IDX_WIDTH          ( 10 ),
    .SORT_LEN_WIDTH     ( 5 ),
    .CRD_WIDTH          ( 16 ),
    .CRD_DIM            ( 3 ),
    .DISTSQR_WIDTH      ( 12 ),
    .NUM_SORT_CORE      ( 8 )
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

SYA #(

)(
    .clk    
    .rst_n
    .CCUSYA_Rst
    .CCUSYA_CfgVld
    .SYACCU_CfgRdy
    .CCUSYA_CfgMod
    .CCUSYA_CfgNip
    .CCUSYA_CfgChi
    .CCUSYA_CfgScale
    .CCUSYA_CfgShift
    .CCUSYA_CfgZp
    .GLBSYA_Act   
    .GLBSYA_ActVld
    .SYAGLB_ActRdy
    .GLBSYA_Wgt   
    .GLBSYA_WgtVld
    .SYAGLB_WgtRdy
    .SYAGLB_Ofm   
    .SYAGLB_OfmVld
    .GLBSYA_OfmRdy
)

POL #(

)(
    
)
endmodule
