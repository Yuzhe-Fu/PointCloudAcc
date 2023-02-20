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
module SYA #(
    parameter ACT_WIDTH  = 8,
    parameter WGT_WIDTH  = 8,
    parameter ACC_WIDTH  = ACT_WIDTH+ACT_WIDTH+10, //26
    parameter NUM_ROW    = 16,
    parameter NUM_COL    = 16,
    parameter NUM_BANK   = 4,
    parameter SRAM_WIDTH = 256,
    parameter ADDR_WIDTH = 16,
    parameter QNTSL_WIDTH= 8,
    parameter CHN_WIDTH  = 10,
    parameter IDX_WIDTH  = 16,
    parameter NUM_OUT    = NUM_BANK
  )(
    input                                       clk                       ,
    input                                       rst_n                     ,

    input                                       CCUSYA_Rst                ,
    input                                       CCUSYA_CfgVld             ,
    output                                      SYACCU_CfgRdy             ,
    input  [ACT_WIDTH                   -1 : 0] CCUSYA_CfgShift           ,
    input  [ACT_WIDTH                   -1 : 0] CCUSYA_CfgZp              ,
    input  [2                           -1 : 0] CCUSYA_CfgMod             ,
    input  [IDX_WIDTH                   -1 : 0] CCUSYA_CfgNumGrpPerTile   ,
    input  [IDX_WIDTH                   -1 : 0] CCUSYA_CfgNumTilIfm       ,
    input  [IDX_WIDTH                   -1 : 0] CCUSYA_CfgNumTilFlt       ,
    input                                       CCUSYA_CfgLopOrd          ,
    input  [CHN_WIDTH                   -1 : 0] CCUSYA_CfgChn             ,

    input  [ADDR_WIDTH                  -1 : 0] CCUSYA_CfgActRdBaseAddr   ,
    input  [ADDR_WIDTH                  -1 : 0] CCUSYA_CfgWgtRdBaseAddr   ,
    input  [ADDR_WIDTH                  -1 : 0] CCUSYA_CfgOfmWrBaseAddr   ,
    
    output [ADDR_WIDTH                  -1 : 0] SYAGLB_ActRdAddr          ,
    output                                      SYAGLB_ActRdAddrVld       ,
    input                                       GLBSYA_ActRdAddrRdy       ,
    input  [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1:0] GLBSYA_ActRdDat ,
    input                                       GLBSYA_ActRdDatVld        ,
    output                                      SYAGLB_ActRdDatRdy        ,

    output [ADDR_WIDTH                  -1 : 0] SYAGLB_WgtRdAddr          ,
    output                                      SYAGLB_WgtRdAddrVld       ,
    input                                       GLBSYA_WgtRdAddrRdy       ,
    input  [NUM_BANK -1:0][NUM_COL -1:0][WGT_WIDTH  -1:0] GLBSYA_WgtRdDat ,
    input                                       GLBSYA_WgtRdDatVld        ,
    output                                      SYAGLB_WgtRdDatRdy        ,

    output [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1 : 0] SYAGLB_OfmWrDat,
    output [ADDR_WIDTH                  -1 : 0] SYAGLB_OfmWrAddr          ,
    output                                      SYAGLB_OfmWrDatVld        ,
    input                                       GLBSYA_OfmWrDatRdy         

  );

localparam  SYA_SIDEBANK = 2**($clog2(NUM_BANK) - 1); // SQURT(4) = 2

wire                        Overflow_CntChn;
wire                        Overflow_CntGrp;
wire                        Overflow_CntTilFlt;
wire                        Overflow_CntTilIfm;
wire [CHN_WIDTH     -1 : 0] CntChn;
wire [IDX_WIDTH     -1 : 0] CntTilIfm;
wire [CHN_WIDTH     -1 : 0] MaxCntChn;
wire                        INC_CntChn; 
wire [IDX_WIDTH     -1 : 0] CntGrp;
wire [IDX_WIDTH     -1 : 0] MaxCntGrp;
wire                        INC_CntGrp; 
wire [CHN_WIDTH     -1 : 0] CntTilFlt;
wire [CHN_WIDTH     -1 : 0] MaxCntTilFlt;
wire                        INC_CntTilFlt;
wire [IDX_WIDTH     -1 : 0] MaxCntTilIfm;
wire                        INC_CntTilIfm; 

wire        rdy_s0;
wire        vld_s0;
wire        ena_s0;
wire        handshake_s0;
wire        rdy_s1;
wire        vld_s1;
wire        ena_s1;
wire        handshake_s1;
wire        handshake_Ofm;
reg [NUM_ROW*NUM_BANK   -1 : 0] AllBank_InActChnLast_W;
reg [NUM_ROW*NUM_BANK   -1 : 0] AllBank_InActVld_W;
reg [NUM_COL*NUM_BANK   -1 : 0] AllBank_InWgtChnLast_N;
reg [NUM_COL*NUM_BANK   -1 : 0] AllBank_InWgtVld_N;

wire [NUM_BANK  -1 : 0][NUM_ROW                     -1 : 0] SYA_InActVld_W;
wire [NUM_BANK  -1 : 0][NUM_ROW                     -1 : 0] SYA_InActChnLast_W;
wire [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] SYA_InAct_W;
wire [NUM_BANK  -1 : 0][NUM_ROW                     -1 : 0] SYA_OutActRdy_W;

wire [NUM_BANK  -1 : 0][NUM_COL                     -1 : 0] SYA_InWgtVld_N;
wire [NUM_BANK  -1 : 0][NUM_COL                     -1 : 0] SYA_InWgtChnLast_N;
wire [NUM_BANK  -1 : 0][NUM_COL -1 : 0][WGT_WIDTH   -1 : 0] SYA_InWgt_N;
wire [NUM_BANK  -1 : 0][NUM_COL                     -1 : 0] SYA_OutWgtRdy_N;

wire [NUM_BANK  -1 : 0][NUM_ROW                     -1 : 0] SYA_OutActVld_E;
wire [NUM_BANK  -1 : 0][NUM_ROW                     -1 : 0] SYA_OutActChnLast_E;
wire [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] SYA_OutAct_E;
wire [NUM_BANK  -1 : 0][NUM_ROW                     -1 : 0] SYA_InActRdy_E;

wire [NUM_BANK  -1 : 0][NUM_COL                     -1 : 0] SYA_OutWgtVld_S;
wire [NUM_BANK  -1 : 0][NUM_COL                     -1 : 0] SYA_OutWgtChnLast_S;
wire [NUM_BANK  -1 : 0][NUM_COL -1 : 0][WGT_WIDTH   -1 : 0] SYA_OutWgt_S;
wire [NUM_BANK  -1 : 0][NUM_COL                     -1 : 0] SYA_InWgtRdy_S;

wire [NUM_BANK  -1 : 0][NUM_ROW                     -1 : 0] SYA_OutPsumVld;
wire [NUM_BANK  -1 : 0]                                     din_data_vld;
wire [NUM_BANK  -1 : 0]                                     din_data_rdy;
wire [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] SYA_OutPsum;
wire [NUM_BANK  -1 : 0][NUM_ROW                     -1 : 0] SYA_InPsumRdy;

wire [NUM_BANK  -1 : 0] sync_out_vld;
wire [NUM_BANK  -1 : 0] sync_out_rdy;
wire [NUM_BANK  -1 : 0][NUM_ROW -1:0][ACT_WIDTH  -1 : 0] sync_out;
wire [$clog2(NUM_ROW*NUM_BANK) + 1  -1 : 0] SYA_MaxRowCol;

//=====================================================================================================================
// Logic Design :s0
//=====================================================================================================================
localparam IDLE     = 3'b000;
localparam INREGUL  = 3'b001;
localparam INSHIFT  = 3'b010;
localparam WAITOUT  = 3'b011;

reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE :  if(CCUSYA_CfgVld & SYACCU_CfgRdy)
                    next_state <= INREGUL; //
                else
                    next_state <= IDLE;
        INREGUL:if( (Overflow_CntTilIfm & Overflow_CntTilFlt & Overflow_CntGrp & Overflow_CntChn) & handshake_s0)
                    next_state <= INSHIFT;
                else
                    next_state <= INREGUL;
        
        INSHIFT :if( (CntChn == (SYA_MaxRowCol -1) -1) & handshake_s0 ) 
                    next_state <= WAITOUT;
                else
                    next_state <= INSHIFT;
        WAITOUT     : if( 1'b0 ) // !(|SYA_OutPsumVld) & !(|sync_out_vld)
                    next_state <= IDLE;
                else
                    next_state <= WAITOUT;
        default: next_state <= IDLE;
    endcase
end
always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Combinational Logic
assign SYACCU_CfgRdy = state == IDLE;

// HandShake
assign rdy_s0 = GLBSYA_ActRdAddrRdy & GLBSYA_WgtRdAddrRdy; // 2 loads
assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0 = handshake_s0 | ~vld_s0;

// Reg Update
assign vld_s0 = state == INREGUL | state == INSHIFT;

assign SYA_MaxRowCol = CCUSYA_CfgMod == 0 ? NUM_ROW*SYA_SIDEBANK : NUM_ROW*SYA_SIDEBANK*2;

assign MaxCntChn  = CCUSYA_CfgChn- 1; 
assign INC_CntChn = handshake_s0;
counter#(
    .COUNT_WIDTH ( CHN_WIDTH )
)u1_counter_CntChn(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( CCUSYA_Rst | state == IDLE        ),
    .DEFAULT   ( {CHN_WIDTH{1'b0}}  ),
    .INC       ( INC_CntChn         ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {CHN_WIDTH{1'b0}}  ),
    .MAX_COUNT ( MaxCntChn          ),
    .OVERFLOW  ( Overflow_CntChn    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntChn             )
);



assign MaxCntGrp  = CCUSYA_CfgNumGrpPerTile - 1; 
              
assign INC_CntGrp = Overflow_CntChn & INC_CntChn;
counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u1_counter_CntGrp(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( CCUSYA_Rst | state == IDLE         ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}} ),
    .INC       ( INC_CntGrp       ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {ADDR_WIDTH{1'b0}} ),
    .MAX_COUNT ( MaxCntGrp        ),
    .OVERFLOW  ( Overflow_CntGrp  ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntGrp           )
);



assign MaxCntTilFlt  = CCUSYA_CfgNumTilFlt - 1; 
assign                        INC_CntTilFlt = CCUSYA_CfgLopOrd == 0? Overflow_CntGrp & INC_CntGrp : Overflow_CntTilIfm & INC_CntTilIfm;
counter#(
    .COUNT_WIDTH ( CHN_WIDTH )
)u1_counter_CntTilFlt(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( CCUSYA_Rst | state == IDLE         ),
    .DEFAULT   ( {CHN_WIDTH{1'b0}} ),
    .INC       ( INC_CntTilFlt       ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {CHN_WIDTH{1'b0}} ),
    .MAX_COUNT ( MaxCntTilFlt        ),
    .OVERFLOW  ( Overflow_CntTilFlt  ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntTilFlt           )
);



assign MaxCntTilIfm  = CCUSYA_CfgNumTilIfm - 1;
assign INC_CntTilIfm = CCUSYA_CfgLopOrd == 0? Overflow_CntTilFlt & INC_CntTilFlt : Overflow_CntGrp & INC_CntGrp;
counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_CntTilIfm(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( CCUSYA_Rst | state == IDLE ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}} ),
    .INC       ( INC_CntTilIfm       ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}} ),
    .MAX_COUNT ( MaxCntTilIfm        ),
    .OVERFLOW  ( Overflow_CntTilIfm  ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntTilIfm           )
);

assign SYAGLB_ActRdAddr = CCUSYA_CfgActRdBaseAddr + CCUSYA_CfgChn*CCUSYA_CfgNumGrpPerTile*CntTilIfm + CCUSYA_CfgChn*CntGrp + CntChn;
assign SYAGLB_ActRdAddrVld = vld_s0 & GLBSYA_WgtRdAddrRdy; // other load are ready

assign SYAGLB_WgtRdAddr = CCUSYA_CfgWgtRdBaseAddr + CCUSYA_CfgChn*CCUSYA_CfgNumGrpPerTile*CntTilFlt + CCUSYA_CfgChn*CntGrp + CntChn;
assign SYAGLB_WgtRdAddrVld = vld_s0 & GLBSYA_ActRdAddrRdy; // other load are ready

//=====================================================================================================================
// Logic Design : s1
//=====================================================================================================================
// Combinational Logic
assign SYAGLB_ActRdDatRdy   = rdy_s1;
assign SYAGLB_WgtRdDatRdy   = rdy_s1;

// HandShake
assign rdy_s1 = (
                    CCUSYA_CfgMod == 0? ({SYA_OutActRdy_W[2], SYA_OutActRdy_W[0]} & {SYA_InActVld_W[2], SYA_InActVld_W[0]} == {SYA_InActVld_W[2], SYA_InActVld_W[0]}) 
                    : CCUSYA_CfgMod == 1? (SYA_OutActRdy_W[0] & SYA_InActVld_W[0] == SYA_InActVld_W[0]) 
                    : ({SYA_OutActRdy_W[0], SYA_OutActRdy_W[2], SYA_OutActRdy_W[1], SYA_OutActRdy_W[3]} & {SYA_InActVld_W[0], SYA_InActVld_W[2], SYA_InActVld_W[1], SYA_InActVld_W[3]} == {SYA_InActVld_W[0], SYA_InActVld_W[2], SYA_InActVld_W[1], SYA_InActVld_W[3]}) 
                ) & (
                    CCUSYA_CfgMod == 0? ({SYA_OutWgtRdy_N[0], SYA_OutWgtRdy_N[1]} & {SYA_InActVld_W[0], SYA_InActVld_W[1]} == {SYA_InActVld_W[0], SYA_InActVld_W[1]}) 
                    : CCUSYA_CfgMod == 1? ({SYA_OutWgtRdy_N[0], SYA_OutWgtRdy_N[1], SYA_OutWgtRdy_N[2], SYA_OutWgtRdy_N[3]} & {SYA_InActVld_W[0], SYA_InActVld_W[1], SYA_InActVld_W[2], SYA_InActVld_W[3]} == {SYA_InActVld_W[0], SYA_InActVld_W[1], SYA_InActVld_W[2], SYA_InActVld_W[3]}) 
                    : (SYA_OutWgtRdy_N[0] & SYA_InActVld_W[0] == SYA_InActVld_W[0] )
                );
assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1 = handshake_s1 | ~vld_s1;
assign vld_s1 = GLBSYA_ActRdDatVld & GLBSYA_WgtRdDatVld;

// Reg Update
always @ ( posedge clk or negedge rst_n )begin
    if( !rst_n )
    {AllBank_InWgtChnLast_N, AllBank_InWgtVld_N, AllBank_InActChnLast_W, AllBank_InActVld_W} <= 'd0;
    else if( handshake_s1 )
    {AllBank_InWgtChnLast_N, AllBank_InWgtVld_N, AllBank_InActChnLast_W, AllBank_InActVld_W} <= {
        {AllBank_InWgtChnLast_N[NUM_COL*NUM_BANK  -2:0], Overflow_CntChn},
        {AllBank_InWgtVld_N[NUM_COL*NUM_BANK  -2:0], handshake_s1},
        {AllBank_InActChnLast_W[NUM_ROW*NUM_BANK  -2:0], Overflow_CntChn},
        {AllBank_InActVld_W[NUM_ROW*NUM_BANK  -2:0], handshake_s1 }}; // 
end

// Bank[0]
assign SYA_InActVld_W       [0] = {AllBank_InActVld_W[0 +: NUM_ROW -1] & {(NUM_ROW -1){ rdy_s1}}, handshake_s1};
assign SYA_InActChnLast_W   [0] = {AllBank_InActChnLast_W[0 +: NUM_ROW -1], Overflow_CntChn};
assign SYA_InAct_W          [0] = GLBSYA_ActRdDat[0];
assign SYA_InActRdy_E       [0] = CCUSYA_CfgMod == 2? {NUM_ROW{1'b1}} : SYA_OutActRdy_W[1];

assign SYA_InWgtVld_N       [0] = {AllBank_InWgtVld_N[0 +: NUM_COL -1] & {(NUM_COL -1){ rdy_s1}}, handshake_s1};
assign SYA_InWgtChnLast_N   [0] = {AllBank_InWgtChnLast_N[0 +: NUM_COL -1], Overflow_CntChn};
assign SYA_InWgt_N          [0] = GLBSYA_WgtRdDat[0];
assign SYA_InWgtRdy_S       [0] = CCUSYA_CfgMod == 1? {NUM_COL{1'b1}} : SYA_OutWgtRdy_N[2];

// Bank[1]
assign SYA_InActVld_W       [1] = CCUSYA_CfgMod == 2? AllBank_InActVld_W[NUM_ROW*2 -1 +: NUM_ROW] & {NUM_ROW{ rdy_s1}}    : SYA_OutActVld_E[0];
assign SYA_InActChnLast_W   [1] = CCUSYA_CfgMod == 2? AllBank_InActChnLast_W[NUM_ROW*2 -1 +: NUM_ROW]    : SYA_OutActChnLast_E[0];
assign SYA_InAct_W          [1] = CCUSYA_CfgMod == 2? GLBSYA_ActRdDat[2]    : SYA_OutAct_E[0];
assign SYA_InActRdy_E       [1] = CCUSYA_CfgMod == 1? SYA_OutActRdy_W[2]    : {NUM_ROW{1'b1}};

assign SYA_InWgtVld_N       [1] = CCUSYA_CfgMod == 2? SYA_OutWgtVld_S[2]    : AllBank_InWgtVld_N[NUM_COL -1 +: NUM_COL] & {NUM_COL{ rdy_s1}};
assign SYA_InWgtChnLast_N   [1] = CCUSYA_CfgMod == 2? SYA_OutWgtChnLast_S[2]    : AllBank_InWgtChnLast_N[NUM_COL -1 +: NUM_COL];
assign SYA_InWgt_N          [1] = CCUSYA_CfgMod == 2? SYA_OutWgt_S[2]       : GLBSYA_WgtRdDat[1];
assign SYA_InWgtRdy_S       [1] = CCUSYA_CfgMod == 1? {NUM_COL{1'b1}} : SYA_OutWgtRdy_N[3];

// Bank[2]
assign SYA_InActVld_W       [2] = CCUSYA_CfgMod == 1? SYA_OutActVld_E[1] : AllBank_InActVld_W[NUM_ROW -1 +: NUM_ROW] & {NUM_ROW{ rdy_s1}};
assign SYA_InActChnLast_W   [2] = CCUSYA_CfgMod == 1? SYA_OutActChnLast_E[1] : AllBank_InActChnLast_W[NUM_ROW -1 +: NUM_ROW];
assign SYA_InAct_W          [2] = CCUSYA_CfgMod == 1? SYA_OutAct_E[1] : GLBSYA_ActRdDat[1];
assign SYA_InActRdy_E       [2] = CCUSYA_CfgMod == 2? {NUM_ROW{1'b1}} : SYA_OutActRdy_W[3];

assign SYA_InWgtVld_N       [2] = CCUSYA_CfgMod == 1? AllBank_InWgtVld_N[NUM_COL*2 -1 +: NUM_COL] & {NUM_COL{ rdy_s1}} : SYA_OutWgtVld_S[0];
assign SYA_InWgtChnLast_N   [2] = CCUSYA_CfgMod == 1? AllBank_InWgtChnLast_N[NUM_COL*2 -1 +: NUM_COL] : SYA_OutWgtChnLast_S[0];
assign SYA_InWgt_N          [2] = CCUSYA_CfgMod == 1? GLBSYA_WgtRdDat[2] : SYA_OutWgtVld_S[0];
assign SYA_InWgtRdy_S       [2] = CCUSYA_CfgMod == 2? SYA_OutWgtRdy_N[1]    : {NUM_COL{1'b1}};

// Bank[3]
assign SYA_InActVld_W       [3] = CCUSYA_CfgMod == 2? AllBank_InActVld_W[NUM_ROW*3 -1 +: NUM_ROW] & {NUM_ROW{ rdy_s1}} : SYA_OutActVld_E[2];
assign SYA_InActChnLast_W   [3] = CCUSYA_CfgMod == 2? AllBank_InActChnLast_W[NUM_ROW*3 -1 +: NUM_ROW] : SYA_OutActChnLast_E[2];
assign SYA_InAct_W          [3] = CCUSYA_CfgMod == 2? GLBSYA_ActRdDat[3] : SYA_OutAct_E[2];
assign SYA_InActRdy_E       [3] = {NUM_ROW{1'b1}};

assign SYA_InWgtVld_N       [3] = CCUSYA_CfgMod == 1? AllBank_InWgtVld_N[NUM_COL*3 -1 +: NUM_COL] & {NUM_COL{ rdy_s1}}: SYA_OutWgtVld_S[1];
assign SYA_InWgtChnLast_N   [3] = CCUSYA_CfgMod == 1? AllBank_InWgtChnLast_N[NUM_COL*3 -1 +: NUM_COL]: SYA_OutWgtChnLast_S[1];
assign SYA_InWgt_N          [3] = CCUSYA_CfgMod == 1? GLBSYA_WgtRdDat[3] : SYA_OutWgt_S[1];
assign SYA_InWgtRdy_S       [3] = {NUM_COL{1'b1}};

PE_BANK#(
    .ACT_WIDTH       ( ACT_WIDTH ),
    .WGT_WIDTH       ( WGT_WIDTH ),
    .CHN_WIDTH       ( CHN_WIDTH ),
    .NUM_ROW         ( NUM_ROW   ),
    .NUM_COL         ( NUM_COL   )
)u_PE_BANK [NUM_BANK -1 : 0](
    .clk             ( clk             ),
    .rst_n           ( rst_n           ),
    .CCUSYA_Rst      ( CCUSYA_Rst      ),
    .CCUSYA_CfgShift ( CCUSYA_CfgShift ),
    .CCUSYA_CfgZp    ( CCUSYA_CfgZp    ),
    .InActVld_W      ( SYA_InActVld_W      ),
    .InActChnLast_W  ( SYA_InActChnLast_W  ),
    .InAct_W         ( SYA_InAct_W         ),
    .OutActRdy_W     ( SYA_OutActRdy_W     ),
    .InWgtVld_N      ( SYA_InWgtVld_N      ),
    .InWgtChnLast_N  ( SYA_InWgtChnLast_N  ),
    .InWgt_N         ( SYA_InWgt_N         ),
    .OutWgtRdy_N     ( SYA_OutWgtRdy_N     ),
    .OutActVld_E     ( SYA_OutActVld_E     ),
    .OutActChnLast_E ( SYA_OutActChnLast_E ),
    .OutAct_E        ( SYA_OutAct_E        ),
    .InActRdy_E      ( SYA_InActRdy_E      ),
    .OutWgtVld_S     ( SYA_OutWgtVld_S     ),
    .OutWgtChnLast_S ( SYA_OutWgtChnLast_S ),
    .OutWgt_S        ( SYA_OutWgt_S        ),
    .InWgtRdy_S      ( SYA_InWgtRdy_S      ),
    .OutPsumVld      ( SYA_OutPsumVld      ),
    .OutPsum         ( SYA_OutPsum         ),
    .InPsumRdy       ( SYA_InPsumRdy       )
);


SYNC_SHAPE #(
    .ACT_WIDTH           ( ACT_WIDTH  ),
    .NUM_BANK            ( NUM_BANK   ),
    .NUM_ROW             ( NUM_ROW    ),
    .ADDR_WIDTH          ( 4          )
) SYNC_SHAPE_U (               

    .clk                 ( clk        ),
    .rst_n               ( rst_n      ),
    .Rst                 ( state == IDLE),
                        
    .din_data            ( SYA_OutPsum    ),
    .din_data_vld        ( din_data_vld ),
    .din_data_rdy        ( din_data_rdy  ),
                        
    .out_data            ( sync_out   ),
    .out_data_vld        ( sync_out_vld),
    .out_data_rdy        ( sync_out_rdy)
);
// ?????????? {NUM_ROW*NUM_BANK{SYA_OutPsumVld == ReqVld}}; ofm in specific channels are valid(rhomboid sibianxing)
assign din_data_vld = {|SYA_OutPsumVld[3], |SYA_OutPsumVld[2], |SYA_OutPsumVld[1], |SYA_OutPsumVld[0]}; 
assign SYA_InPsumRdy = { {NUM_ROW{din_data_rdy[3]}}, {NUM_ROW{din_data_rdy[3]}}, {NUM_ROW{din_data_rdy[3]}}, {NUM_ROW{din_data_rdy[3]}} };

assign SYAGLB_OfmWrDatVld   = &sync_out_vld;
assign SYAGLB_OfmWrDat      = sync_out;
assign SYAGLB_OfmWrAddr = CCUSYA_CfgOfmWrBaseAddr + ( (CCUSYA_CfgNumGrpPerTile*CCUSYA_CfgNumTilFlt) *CCUSYA_CfgNumGrpPerTile)*CntTilIfm + (CCUSYA_CfgNumGrpPerTile*CCUSYA_CfgNumTilFlt)*CntGrp;// ????????????
assign sync_out_rdy         = {NUM_BANK{GLBSYA_OfmWrDatRdy}};

endmodule