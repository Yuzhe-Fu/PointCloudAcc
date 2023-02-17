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
module PE_BANK #(
    parameter ACT_WIDTH = 8,
    parameter WGT_WIDTH = 8,
    parameter CHN_WIDTH = 16,
    parameter NUM_ROW   = 16,
    parameter NUM_COL   = 16
  )(
    input                                       clk,
    input                                       rst_n,
    input                                       CCUSYA_Rst     ,
    input  [ACT_WIDTH                   -1 : 0] CCUSYA_CfgShift,
    input  [ACT_WIDTH                   -1 : 0] CCUSYA_CfgZp   ,

    input  [NUM_ROW                     -1 : 0] InActVld_W,
    input  [NUM_ROW                     -1 : 0] InActChnLast_W,
    input  [NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] InAct_W,
    output [NUM_ROW                     -1 : 0] OutActRdy_W,

    input  [NUM_COL                     -1 : 0] InWgtVld_N,
    input  [NUM_COL                     -1 : 0] InWgtChnLast_N,
    input  [NUM_COL -1 : 0][WGT_WIDTH   -1 : 0] InWgt_N,
    output [NUM_COL                     -1 : 0] OutWgtRdy_N,

    output [NUM_ROW                     -1 : 0] OutActVld_E,
    output [NUM_ROW                     -1 : 0] OutActChnLast_E,
    output [NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] OutAct_E,
    input  [NUM_ROW                     -1 : 0] InActRdy_E,

    output [NUM_COL                     -1 : 0] OutWgtVld_S,
    output [NUM_COL                     -1 : 0] OutWgtChnLast_S,
    output [NUM_COL -1 : 0][WGT_WIDTH   -1 : 0] OutWgt_S,
    input  [NUM_COL                     -1 : 0] InWgtRdy_S,

    output [NUM_ROW                     -1 : 0] OutPsumVld,
    output [NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] OutPsum,
    input  [NUM_ROW                     -1 : 0] InPsumRdy

  );
wire [NUM_ROW -1:0][NUM_COL -1:0]                   Bank_OutWgtVld_S;
wire [NUM_ROW -1:0][NUM_COL -1:0]                   Bank_OutWgtChnLast_S;
wire [NUM_ROW -1:0][NUM_COL -1:0]                   Bank_OutWgtRdy_N;
wire [NUM_ROW -1:0][NUM_COL -1:0]                   Bank_InWgtRdy_S;
wire [NUM_ROW -1:0][NUM_COL -1:0][WGT_WIDTH  -1:0] Bank_OutWgt_S;

wire [NUM_ROW -1:0][NUM_COL -1:0] Bank_InWgtVld_N       = {Bank_OutWgtVld_S[NUM_ROW - 2 : 0], InWgtVld_N};
wire [NUM_ROW -1:0][NUM_COL -1:0] Bank_InWgtChnLast_N   = {Bank_OutWgtChnLast_S[NUM_ROW - 2 : 0], InWgtChnLast_N};
wire [NUM_ROW -1:0][NUM_COL -1:0][WGT_WIDTH -1 : 0] Bank_InWgt_N          = {Bank_OutWgt_S[NUM_ROW - 2 : 0], InWgt_N};
assign {Bank_InWgtRdy_S[NUM_ROW - 2 : 0], OutWgtRdy_N}  = Bank_OutWgtRdy_N;

PE_ROW #(
    .ACT_WIDTH       ( ACT_WIDTH ),
    .WGT_WIDTH       ( WGT_WIDTH ),
    .CHN_WIDTH       ( CHN_WIDTH ),
    .NUM_PE          ( NUM_COL   )
)u_PE_ROW [NUM_ROW  - 1 : 0](
    .clk             ( clk             ),
    .rst_n           ( rst_n           ),
    .CCUSYA_Rst      ( CCUSYA_Rst      ),
    .CCUSYA_CfgShift ( CCUSYA_CfgShift ),
    .CCUSYA_CfgZp    ( CCUSYA_CfgZp    ),
    .InActVld_W      ( InActVld_W      ),
    .InActChnLast_W  ( InActChnLast_W  ),
    .InAct_W         ( InAct_W         ),
    .OutActRdy_W     ( OutActRdy_W     ),
    .InWgtVld_N      ( Bank_InWgtVld_N      ),
    .InWgtChnLast_N  ( Bank_InWgtChnLast_N  ),
    .InWgt_N         ( Bank_InWgt_N         ),
    .OutWgtRdy_N     ( Bank_OutWgtRdy_N     ),
    .OutActVld_E     ( OutActVld_E     ),
    .OutActChnLast_E ( OutActChnLast_E ),
    .OutAct_E        ( OutAct_E        ),
    .InActRdy_E      ( InActRdy_E      ),
    .OutWgtVld_S     ( Bank_OutWgtVld_S     ),
    .OutWgtChnLast_S ( Bank_OutWgtChnLast_S ),
    .OutWgt_S        ( Bank_OutWgt_S        ),
    .InWgtRdy_S      ( Bank_InWgtRdy_S      ),
    .OutPsumVld      ( OutPsumVld      ),
    .OutPsum         ( OutPsum         ),
    .InPsumRdy       ( InPsumRdy       )
);

endmodule
