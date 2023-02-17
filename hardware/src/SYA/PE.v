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
module PE #(
    parameter ACT_WIDTH = 8,
    parameter WGT_WIDTH = 8,
    parameter CHN_WIDTH = 16,
    parameter PSUM_WIDTH = ACT_WIDTH + WGT_WIDTH + CHN_WIDTH
  )(
    input                           clk,
    input                           rst_n,

    input                           InActVld_W,
    input                           InActChnLast_W,
    input [ACT_WIDTH        -1 : 0] InAct_W,
    output                          OutActRdy_W,

    input                           InWgtVld_N,
    input                           InWgtChnLast_N,
    input [WGT_WIDTH        -1 : 0] InWgt_N,
    output                          OutWgtRdy_N,

    output                          OutActVld_E,
    output                          OutActChnLast_E,
    output reg[ACT_WIDTH    -1 : 0] OutAct_E,
    input                           InActRdy_E,

    output                          OutWgtVld_S,
    output                          OutWgtChnLast_S,
    output reg [WGT_WIDTH   -1 : 0] OutWgt_S,
    input                           InWgtRdy_S,

    output                          OutPsumVld,
    output reg signed [PSUM_WIDTH  -1 : 0] OutPsum,
    input                           InPsumRdy

  );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
wire                InVld;
wire                rdy;
reg                 vld;
wire                ena;
reg                 OutChnLast;
// 
assign InVld        = InActVld_W & InWgt_N;
assign OutActRdy_W  = ena & InVld;
assign OutWgtRdy_N  = ena & InVld;

wire signed [PSUM_WIDTH     -1 : 0] Signed_Mul = $signed(InAct_W) * $signed(InWgt_N);
//
assign rdy          = InActRdy_E & InWgtRdy_S & (OutPsumVld? InPsumRdy : 1'b1);
assign handshake    = rdy & vld;
assign ena          = handshake | ~vld;

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        {OutPsum, OutWgt_S, OutAct_E, OutChnLast, vld} <= 0;
    end else if(ena) begin
        {OutPsum, OutAct_E, OutAct_E, OutChnLast, vld} <= {
            InVld? (OutChnLast? Signed_Mul : OutPsum + Signed_Mul) : OutPsum, 
            InWgt_N, 
            InAct_W, 
            InVld & (InActChnLast_W & InWgtChnLast_N), 
            InVld};
    end
end

assign OutActVld_E      = vld;
assign OutWgtVld_S      = vld;
assign OutPsumVld       = vld & (OutWgtChnLast_S & OutActChnLast_E);
assign OutActChnLast_E  = OutChnLast;
assign OutWgtChnLast_S  = OutChnLast;

endmodule