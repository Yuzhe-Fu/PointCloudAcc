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
module CTR #(
    parameter SRAM_WIDTH        = 256,
    parameter IDX_WIDTH         = 10,
    parameter SORT_LEN_WIDTH    = 5,
    parameter CRD_WIDTH         = 16,
    parameter CRD_DIM           = 3, 
    parameter DISTSQR_WIDTH     =  $clog2( CRD_WIDTH*2*$clog2(CRD_DIM) ),
    parameter NUM_SORT_CORE     = 8,
    parameter MASK_ADDR_WIDTH = $clog2(2**IDX_WIDTH*NUM_SORT_CORE/SRAM_WIDTH)
    )(
    input                               clk  ,
    input                               rst_n,

    // Configure
    input                               CCUCTR_Rst,
    input                               CCUCTR_CfgVld,
    output                              CTRCCU_CfgRdy,
    input                               CCUCTR_CfgMod,
    input [IDX_WIDTH            -1 : 0] CCUCTR_CfgNip,
    input [IDX_WIDTH            -1 : 0] CCUCTR_CfgNop,
    input [SORT_LEN_WIDTH       -1 : 0] CCUCTR_CfgK, 

    // Fetch Crd
    output [IDX_WIDTH           -1 : 0] CTRGLB_CrdAddr,   
    output                              CTRGLB_CrdAddrVld, 
    input                               GLBCTR_CrdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0 ]GLBCTR_Crd,        
    input                               GLBCTR_CrdVld,     
    output                              CTRGLB_CrdRdy,

    // Fetch Dist and Idx of FPS
    output [IDX_WIDTH           -1 : 0] CTRGLB_DistRdAddr, 
    output                              CTRGLB_DistRdAddrVld,
    input                               GLBCTR_DistRdAddrRdy,
    input  [DISTSQR_WIDTH+IDX_WIDTH-1 : 0] GLBCTR_DistIdx,    
    input                               GLBCTR_DistIdxVld,    
    output                              CTRGLB_DistIdxRdy,    

    output [IDX_WIDTH           -1 : 0] CTRGLB_DistWrAddr,
    output [DISTSQR_WIDTH+IDX_WIDTH-1 : 0] CTRGLB_DistIdx,   
    output reg                          CTRGLB_DistIdxVld,
    input                               GLBCTR_DistIdxRdy,

    output  [MASK_ADDR_WIDTH    -1 : 0] KNNGLB_MaskRdAddr,
    output                              KNNGLB_MaskRdAddrVld,
    input                               GLBKNN_MaskRdAddrRdy,
    input   [SRAM_WIDTH         -1 : 0] GLBKNN_MaskRdDat,
    input                               GLBKNN_MaskRdDatVld,
    output                              KNNGLB_MaskRdDatRdy,
    // Input Mask Bit
    output  [MASK_ADDR_WIDTH    -1 : 0] FPSGLB_MaskRdAddr,
    output                              FPSGLB_MaskRdAddrVld,
    input                               GLBFPS_MaskRdAddrRdy,
    input   [SRAM_WIDTH         -1 : 0] GLBFPS_MaskRdDat,
    input                               GLBFPS_MaskRdDatVld, // Not Used
    output                              FPSGLB_MaskRdDatRdy,  

    // Output Mask Bit
    output [MASK_ADDR_WIDTH     -1 : 0] FPSGLB_MaskWrAddr,
    output [SRAM_WIDTH          -1 : 0] FPSGLB_MaskWrBitEn,
    output                              FPSGLB_MaskWrDatVld,
    output [SRAM_WIDTH          -1 : 0] FPSGLB_MaskWrDat,
    input                               GLBFPS_MaskWrDatRdy,  // Not Used


    // Output Map of KNN
    output [SRAM_WIDTH          -1 : 0 ]CTRGLB_Map,   
    output                              CTRGLB_MapVld,     
    input                               GLBCTR_MapRdy     

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                            FPSCCU_CfgRdy;
wire                            KNNCCU_CfgRdy;
wire                            KNNGLB_CrdAddrVld;
wire                            FPSGLB_CrdAddrVld;
wire                            KNNGLB_CrdRdy;
wire                            FPSGLB_CrdRdy;
wire [IDX_WIDTH         -1 : 0] KNNGLB_CrdAddr;
wire [IDX_WIDTH         -1 : 0] FPSGLB_CrdAddr;

//=====================================================================================================================
// Logic Design 
//=====================================================================================================================
assign CTRCCU_CfgRdy = FPSCCU_CfgRdy & KNNCCU_CfgRdy;

assign CTRGLB_CrdAddr = CCUCTR_CfgMod ? KNNGLB_CrdAddr : FPSGLB_CrdAddr;  
assign CTRGLB_CrdAddrVld = CCUCTR_CfgMod ? KNNGLB_CrdAddrVld : FPSGLB_CrdAddrVld;  

assign CTRGLB_CrdRdy = CCUCTR_CfgMod ? KNNGLB_CrdRdy : FPSGLB_CrdRdy;



FPS#(
    .SRAM_WIDTH           ( SRAM_WIDTH   ),
    .IDX_WIDTH            ( IDX_WIDTH    ),
    .CRD_WIDTH            ( CRD_WIDTH    ),
    .CRD_DIM              ( CRD_DIM      ),
    .NUM_SORT_CORE        ( NUM_SORT_CORE),
    .DISTSQR_WIDTH        ( DISTSQR_WIDTH)
)u_FPS(
    .clk                  ( clk                  ),
    .rst_n                ( rst_n                ),
    .CCUCTR_Rst           ( CCUCTR_Rst           ),
    .CCUCTR_CfgVld        ( CCUCTR_CfgVld & !CCUCTR_CfgMod        ),
    .FPSCCU_CfgRdy        ( FPSCCU_CfgRdy        ),
    .CCUCTR_CfgNip        ( CCUCTR_CfgNip        ),
    .CCUCTR_CfgNop        ( CCUCTR_CfgNop        ),
    .FPSGLB_CrdAddr       ( FPSGLB_CrdAddr       ),
    .FPSGLB_CrdAddrVld    ( FPSGLB_CrdAddrVld    ),
    .GLBFPS_CrdAddrRdy    ( GLBCTR_CrdAddrRdy & !CCUCTR_CfgMod    ),
    .GLBFPS_Crd           ( GLBCTR_Crd           ),
    .GLBFPS_CrdVld        ( GLBCTR_CrdVld        ),
    .FPSGLB_CrdRdy        ( FPSGLB_CrdRdy        ),
    .CTRGLB_DistRdAddr    ( CTRGLB_DistRdAddr    ),
    .CTRGLB_DistRdAddrVld ( CTRGLB_DistRdAddrVld ),
    .GLBCTR_DistRdAddrRdy ( GLBCTR_DistRdAddrRdy ),
    .GLBCTR_DistIdx       ( GLBCTR_DistIdx       ),
    .GLBCTR_DistIdxVld    ( GLBCTR_DistIdxVld    ),
    .CTRGLB_DistIdxRdy    ( CTRGLB_DistIdxRdy    ),
    .CTRGLB_DistWrAddr    ( CTRGLB_DistWrAddr    ),
    .CTRGLB_DistIdx       ( CTRGLB_DistIdx       ),
    .CTRGLB_DistIdxVld    ( CTRGLB_DistIdxVld    ),
    .GLBCTR_DistIdxRdy    ( GLBCTR_DistIdxRdy    ),
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


KNN#(
    .SRAM_WIDTH        ( SRAM_WIDTH    ),
    .IDX_WIDTH         ( IDX_WIDTH     ),
    .SORT_LEN_WIDTH    ( SORT_LEN_WIDTH),
    .CRD_WIDTH         ( CRD_WIDTH     ),
    .CRD_DIM           ( CRD_DIM       ),
    .DISTSQR_WIDTH     ( DISTSQR_WIDTH ),
    .NUM_SORT_CORE     ( NUM_SORT_CORE )
)u_KNN(
    .clk               ( clk               ),
    .rst_n             ( rst_n             ),
    .CCUCTR_Rst        ( CCUCTR_Rst        ),
    .CCUCTR_CfgVld     ( CCUCTR_CfgVld & CCUCTR_CfgMod     ),
    .KNNCCU_CfgRdy     ( KNNCCU_CfgRdy     ),
    .CCUCTR_CfgNip     ( CCUCTR_CfgNip     ),
    .CCUCTR_CfgK       ( CCUCTR_CfgK       ),
    .KNNGLB_CrdAddr    ( KNNGLB_CrdAddr    ),
    .KNNGLB_CrdAddrVld ( KNNGLB_CrdAddrVld ),
    .GLBKNN_CrdAddrRdy ( GLBCTR_CrdAddrRdy & CCUCTR_CfgMod ),
    .GLBKNN_Crd        ( GLBCTR_Crd        ),
    .GLBKNN_CrdVld     ( GLBCTR_CrdVld & CCUCTR_CfgMod   ),
    .KNNGLB_CrdRdy     ( KNNGLB_CrdRdy     ),
    .PSSGLB_MaskRdAddr      ( KNNGLB_MaskRdAddr    ),
    .PSSGLB_MaskRdAddrVld   ( KNNGLB_MaskRdAddrVld ),
    .GLBPSS_MaskRdAddrRdy   ( GLBKNN_MaskRdAddrRdy ),
    .GLBPSS_MaskDatOut      ( GLBKNN_MaskRdDat    ),
    .GLBPSS_MaskDatOutVld   ( GLBKNN_MaskRdDatVld ),
    .PSSGLB_MaskDatRdy      ( KNNGLB_MaskRdDatRdy    ),
    .PSSCTR_Map        ( CTRGLB_Map        ),
    .PSSCTR_MapVld     ( CTRGLB_MapVld     ),
    .CTRPSS_MapRdy     ( GLBCTR_MapRdy     )
);



endmodule
