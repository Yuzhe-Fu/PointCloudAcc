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
    parameter NUM_PE    = 16,
    parameter PSUM_WIDTH = ACT_WIDTH + WGT_WIDTH + CHN_WIDTH
  )(
    input                           clk,
    input                           rst_n,
    input                           CCUSYA_Rst     ,
    input  [ACT_WIDTH       -1 : 0] CCUSYA_CfgShift,
    input  [ACT_WIDTH       -1 : 0] CCUSYA_CfgZp   ,

    input                           InActVld_W,
    input                           InActChnLast_W,
    input  [ACT_WIDTH       -1 : 0] InAct_W,
    output                          OutActRdy_W,

    input  [NUM_PE          -1 : 0] InWgtVld_N,
    input  [NUM_PE          -1 : 0] InWgtChnLast_N,
    input  [WGT_WIDTH*NUM_PE-1 : 0] InWgt_N,
    output [NUM_PE          -1 : 0] OutWgtRdy_N,

    output                          OutActVld_E,
    output                          OutActChnLast_E,
    output [ACT_WIDTH       -1 : 0] OutAct_E,
    input                           InActRdy_E,

    output [NUM_PE          -1 : 0] OutWgtVld_S,
    output [NUM_PE          -1 : 0] OutWgtChnLast_S,
    output [WGT_WIDTH*NUM_PE-1 : 0] OutWgt_S,
    input  [NUM_PE          -1 : 0] InWgtRdy_S,

    output                          OutPsumVld,
    output [ACT_WIDTH       -1 : 0] OutPsum,
    input                           InPsumRdy

  );

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
wire [NUM_PE                    -1 : 0] ROW_OutActRdy_W;
wire [NUM_PE                    -1 : 0] ROW_OutActVld_E;
wire [NUM_PE                    -1 : 0] ROW_OutActChnLast_E;
wire [NUM_PE -1 : 0][ACT_WIDTH  -1 : 0] ROW_OutAct_E;
wire [NUM_PE                    -1 : 0] ROW_InActRdy_E;
wire [NUM_PE                    -1 : 0] ROW_OutPsumVld;
wire [NUM_PE -1 : 0][PSUM_WIDTH -1 : 0] ROW_OutPsum;
wire [NUM_PE                    -1 : 0] ROW_InPsumRdy;
wire [NUM_PE -1:0] ROW_InActVld_W              ;
wire [NUM_PE -1:0] ROW_InActChnLast_W          ;
wire [NUM_PE -1:0][ACT_WIDTH-1 : 0] ROW_InAct_W;

assign {OutActVld_E, ROW_InActVld_W}        = {ROW_OutActVld_E, InActVld_W};
assign {OutActChnLast_E, ROW_InActChnLast_W}= {ROW_OutActChnLast_E, InActChnLast_W};
assign {OutAct_E, ROW_InAct_W}              = {ROW_OutAct_E, InAct_W};
assign {ROW_InActRdy_E, OutActRdy_W}        = {InActRdy_E, ROW_OutActRdy_W};

PE#(
    .ACT_WIDTH       ( ACT_WIDTH ),
    .WGT_WIDTH       ( WGT_WIDTH ),
    .CHN_WIDTH       ( CHN_WIDTH )
)u_PE [NUM_PE   -1 : 0](
    .clk             ( clk             ),
    .rst_n           ( rst_n           ),
    .InActVld_W      ( ROW_InActVld_W    ),
    .InActChnLast_W  ( ROW_InActChnLast_W),
    .InAct_W         ( ROW_InAct_W       ),
    .OutActRdy_W     ( ROW_OutActRdy_W   ),
    .InWgtVld_N      ( InWgtVld_N      ),
    .InWgtChnLast_N  ( InWgtChnLast_N  ),
    .InWgt_N         ( InWgt_N         ),
    .OutWgtRdy_N     ( OutWgtRdy_N     ),
    .OutActVld_E     ( ROW_OutActVld_E ),
    .OutActChnLast_E ( ROW_OutActChnLast_E),
    .OutAct_E        ( ROW_OutAct_E    ),
    .InActRdy_E      ( ROW_InActRdy_E  ),
    .OutWgtVld_S     ( OutWgtVld_S     ),
    .OutWgtChnLast_S ( OutWgtChnLast_S ),
    .OutWgt_S        ( OutWgt_S        ),
    .InWgtRdy_S      ( InWgtRdy_S      ),
    .OutPsumVld      ( ROW_OutPsumVld  ),
    .OutPsum         ( ROW_OutPsum     ),
    .InPsumRdy       ( ROW_InPsumRdy   )
);
wire [$clog2(NUM_PE)    -1 : 0] ArbPEIdx;
wire [NUM_PE            -1 : 0] gnt;

RR_arbiter #(
    .REQ_WIDTH ( NUM_PE )
)u_RR_arbiter_PE(
    .clk        ( clk       ),
    .rst_n      ( rst_n     ),
    .arb_round  ( InPsumRdy & OutPsumVld),
    .req        ( ROW_OutPsumVld ),
    .gnt        ( gnt       ),
    .arb_port   ( ArbPEIdx  )
);
assign OutPsum = ROW_OutPsum[ArbPEIdx][PSUM_WIDTH - 1]? 0 : ROW_OutPsum[ArbPEIdx][CCUSYA_CfgShift +: ACT_WIDTH] + CCUSYA_CfgZp; // PE_OutPsum_PE is signed
assign OutPsumVld = |gnt;
// assign ROW_InPsumRdy = gnt & {NUM_PE{InPsumRdy}};
assign ROW_InPsumRdy = {NUM_PE{InPsumRdy}}; // ????????????


endmodule