//======================================================
// Copyright (C) 2020 By 
// All Rights Reserved
//======================================================
// Module : 
// Author : 
// Contact : 
// Date : 
//=======================================================
// Description :
//========================================================
module PE_ROW #(
    parameter ACT_WIDTH = 8,
    parameter WGT_WIDTH = 8,
    parameter CHN_WIDTH = 16,
    parameter QNTSL_WIDTH = 32,
    parameter NUM_PE     = 16,
    parameter PSUM_WIDTH = ACT_WIDTH + WGT_WIDTH + CHN_WIDTH
  )(
    input                           clk,
    input                           rst_n,
    input                                       CCUSYA_Rst                ,
    input  [QNTSL_WIDTH                 -1 : 0] CCUSYA_CfgScale           ,
    input  [ACT_WIDTH                   -1 : 0] CCUSYA_CfgShift           ,
    input  [ACT_WIDTH                   -1 : 0] CCUSYA_CfgZp              ,

    input                           InActVld_W,
    input                           InActChnLast_W,
    input [ACT_WIDTH        -1 : 0] InAct_W,
    output                          OutActRdy_W,

    input [NUM_PE        -1 : 0]    InWgtVld_N,
    input [NUM_PE        -1 : 0]    InWgtChnLast_N,
    input [WGT_WIDTH*NUM_PE -1 : 0] InWgt_N,
    output [NUM_PE        -1 : 0]   OutWgtRdy_N,

    output                          OutActVld_E,
    output                          OutActChnLast_E,
    output [ACT_WIDTH    -1 : 0] OutAct_E,
    input                           InActRdy_E,

    output [NUM_PE        -1 : 0]    OutWgtVld_S,
    output [NUM_PE        -1 : 0]    OutWgtChnLast_S,
    output [WGT_WIDTH*NUM_PE -1 : 0] OutWgt_S,
    input   [NUM_PE        -1 : 0]   InWgtRdy_S,

    output                          OutPsumVld,
    output     [ACT_WIDTH   -1 : 0] OutPsum,
    input                           InPsumRdy

  );

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================


PE#(
    .ACT_WIDTH       ( ACT_WIDTH ),
    .WGT_WIDTH       ( WGT_WIDTH ),
    .CHN_WIDTH       ( CHN_WIDTH )
)u_PE [NUM_PE   -1 : 0](
    .clk             ( clk             ),
    .rst_n           ( rst_n           ),
    .InActVld_W      ( InActVld_W      ),
    .InActChnLast_W  ( InActChnLast_W  ),
    .InAct_W         ( InAct_W         ),
    .OutActRdy_W     ( OutActRdy_W     ),
    .InWgtVld_N      ( InWgtVld_N      ),
    .InWgtChnLast_N  ( InWgtChnLast_N  ),
    .InWgt_N         ( InWgt_N         ),
    .OutWgtRdy_N     ( OutWgtRdy_N     ),
    .OutActVld_E     ( OutActVld_E     ),
    .OutActChnLast_E ( OutActChnLast_E ),
    .OutAct_E        ( ROW_OutAct        ),
    .InActRdy_E      ( InActRdy_E      ),
    .OutWgtVld_S     ( OutWgtVld_S     ),
    .OutWgtChnLast_S ( OutWgtChnLast_S ),
    .OutWgt_S        ( OutWgt_S        ),
    .InWgtRdy_S      ( InWgtRdy_S      ),
    .OutPsumVld      ( PE_OutPsumVld   ),
    .OutPsum         ( PE_OutPsum_PE   ),
    .InPsumRdy       ( PE_InPsumRdy    )
);

RR_arbiter #(
    .REQ_WIDTH ( NUM_PE )
)u_RR_arbiter_PE(
    .clk        ( clk       ),
    .rst_n      ( rst_n     ),
    .req        ( OutPsumVld ),
    .gnt        ( gnt       ),
    .arb_port   ( ArbPEIdx  )
);
assign OutPsum = PE_OutPsum_PE[ArbPEIdx];
assign OutPsumVld = &PE_OutPsumVld;
assign PE_InPsumRdy = gnt & InPsumRdy;


endmodule