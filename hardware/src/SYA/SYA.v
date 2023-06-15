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
    parameter SYAISA_WIDTH = 384,
    parameter ACT_WIDTH  = 8,
    parameter WGT_WIDTH  = 8,
    parameter ACC_WIDTH  = ACT_WIDTH+ACT_WIDTH+10, //26
    parameter NUM_ROW    = 16,
    parameter NUM_COL    = 16,
    parameter NUM_BANK   = 4,
    parameter SRAM_WIDTH = 256,
    parameter ADDR_WIDTH = 16,
    parameter QNTSL_WIDTH= 8,
    parameter CHN_WIDTH  = 16,
    parameter IDX_WIDTH  = 16,
    parameter SYAMON_WIDTH = SYAISA_WIDTH + 3,
    parameter NUM_OUT    = NUM_BANK
  )(
    input                                                   clk                     ,
    input                                                   rst_n                   ,
    input                                                   CCUSYA_CfgVld           ,
    output                                                  SYACCU_CfgRdy           ,
    input [SYAISA_WIDTH                             -1 : 0] CCUSYA_CfgInfo          ,
    output [ADDR_WIDTH                              -1 : 0] SYAGLB_ActRdAddr        ,
    output                                                  SYAGLB_ActRdAddrVld     ,
    input                                                   GLBSYA_ActRdAddrRdy     ,
    input  [NUM_BANK-1:0][NUM_ROW  -1:0][ACT_WIDTH  -1 : 0] GLBSYA_ActRdDat         , // 512
    input                                                   GLBSYA_ActRdDatVld      ,
    output                                                  SYAGLB_ActRdDatRdy      ,
    output [ADDR_WIDTH                              -1 : 0] SYAGLB_WgtRdAddr        ,
    output                                                  SYAGLB_WgtRdAddrVld     ,
    input                                                   GLBSYA_WgtRdAddrRdy     ,
    input  [NUM_BANK -1:0][NUM_COL -1:0][WGT_WIDTH  -1 : 0] GLBSYA_WgtRdDat         ,
    input                                                   GLBSYA_WgtRdDatVld      ,
    output                                                  SYAGLB_WgtRdDatRdy      ,
    output [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1 : 0] SYAGLB_OfmWrDat         ,
    output [ADDR_WIDTH                              -1 : 0] SYAGLB_OfmWrAddr        ,
    output                                                  SYAGLB_OfmWrDatVld      ,
    input                                                   GLBSYA_OfmWrDatRdy      ,

    output [SYAMON_WIDTH                            -1 : 0] SYAMON_Dat                    

  );

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam  SYA_SIDEBANK    = 2**($clog2(NUM_BANK) - 1); // SQURT(4) = 2
localparam  PSUM_WIDTH      = ACT_WIDTH + WGT_WIDTH + CHN_WIDTH;
localparam  NUMDIAG_WIDTH   = $clog2(NUM_ROW*8);

localparam IDLE             = 3'b000;
localparam INREGUL          = 3'b001;
localparam INSHIFT          = 3'b010;
localparam WAITOUT          = 3'b011;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                                                        Overflow_CntChn;
wire                                                        Overflow_CntGrp;
wire                                                        Overflow_CntTilFlt;
wire                                                        Overflow_CntTilIfm;
wire [CHN_WIDTH                                     -1 : 0] CntChn;
wire [IDX_WIDTH                                     -1 : 0] CntTilIfm;
wire [CHN_WIDTH                                     -1 : 0] MaxCntChn;
wire                                                        INC_CntChn; 
wire [IDX_WIDTH                                     -1 : 0] CntGrp;
wire [IDX_WIDTH                                     -1 : 0] MaxCntGrp;
wire                                                        INC_CntGrp; 
wire [CHN_WIDTH                                     -1 : 0] CntTilFlt;
wire [CHN_WIDTH                                     -1 : 0] MaxCntTilFlt;
wire                                                        INC_CntTilFlt;
wire [IDX_WIDTH                                     -1 : 0] MaxCntTilIfm;
wire                                                        INC_CntTilIfm; 
wire                                                        rdy_s0;
wire                                                        vld_s0;
wire                                                        ena_s0;
wire                                                        handshake_s0;
wire                                                        rdy_s1;
wire                                                        vld_s1;
wire                                                        ena_s1;
wire                                                        handshake_s1;
wire                                                        rdy_s2;
wire                                                        vld_s2;
wire                                                        ena_s2;
wire                                                        handshake_s2;
wire                                                        rdy_s3;
wire                                                        vld_s3;
wire                                                        ena_s3;
wire                                                        handshake_s3;
wire                                                        handshake_Ofm;
reg [NUM_ROW*NUM_BANK                               -1 : 0] AllBank_InActChnLast_W;
reg [NUM_ROW*NUM_BANK                               -1 : 0] AllBank_InActVld_W;
reg [NUM_COL*NUM_BANK                               -1 : 0] AllBank_InWgtChnLast_N;
reg [NUM_COL*NUM_BANK                               -1 : 0] AllBank_InWgtVld_N;
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
wire [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][NUM_COL     -1 : 0][PSUM_WIDTH   -1 : 0] SYA_OutPsum;
reg  [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] OfmDiag;
reg  [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] OfmDiag_r;
wire [NUM_BANK  -1 : 0][NUM_ROW                     -1 : 0] SYA_InPsumRdy;
wire [NUM_BANK                                      -1 : 0] sync_out_vld;
wire [NUM_BANK                                      -1 : 0] sync_out_rdy;
wire [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] sync_out;
wire [$clog2(NUM_ROW*NUM_BANK) + 1                  -1 : 0] SYA_MaxRowCol;

reg  [NUM_ROW*NUM_BANK  -1 : 0][IDX_WIDTH           -1 : 0] AllBank_InCntTilIfm;
reg  [NUM_ROW*NUM_BANK  -1 : 0][CHN_WIDTH           -1 : 0] AllBank_InCntTilFlt;
reg  [NUM_ROW*NUM_BANK  -1 : 0][IDX_WIDTH           -1 : 0] AllBank_InCntGrp;

wire [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][NUM_COL   -1 : 0] SYA_Reset;
wire [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][NUM_COL   -1 : 0] SYA_En;

wire [ACT_WIDTH*NUM_ROW*NUM_BANK        -1 : 0] shift_din;
wire [1*NUM_ROW*NUM_BANK                -1 : 0] fwftOfm_din;
reg  [1*NUM_ROW*NUM_BANK                -1 : 0] PartPsumVld;
wire                                            fwftOfm_din_rdy;
wire [ACT_WIDTH*NUM_ROW*NUM_BANK        -1 : 0] shift_dout;
wire                                            fwftOfm_dout_vld;
wire                                            fwftOfm_dout_rdy;
reg [ADDR_WIDTH                         -1 : 0] SYA_PsumOutAddr_s2;
reg [ADDR_WIDTH                         -1 : 0] ShiftOut_OfmAddr_s3;
reg [ACT_WIDTH*NUM_ROW*NUM_BANK         -1 : 0] OfmDiagConcat;

wire [NUMDIAG_WIDTH                     -1 : 0] CntRmDiagPsum;
wire [NUMDIAG_WIDTH                     -1 : 0] CurPsumOutDiagIdx_s2;
wire [NUMDIAG_WIDTH                     -1 : 0] DefaultRmDiagPsum;
wire [NUMDIAG_WIDTH                     -1 : 0] NumDiag;
integer                                         i;
wire                                            RstAll_d;
reg [NUM_BANK   -1 : 0][NUM_ROW -1 : 0][NUM_COL -1 : 0][ACT_WIDTH  -1 : 0] SYA_OutPsum_RQ;
reg [$clog2(NUM_ROW*NUM_BANK + NUM_COL*NUM_BANK)  -1 : 0] travDiagIdx_tmp; // traverse

reg [3                                  -1 : 0] state;
reg [3                                  -1 : 0] next_state;

genvar                                          gv_bk;
genvar                                          gv_row;
genvar                                          gv_col;
integer                                         row;
integer                                         col;
integer                                         bank;

reg                                             CCUSYA_CfgRstAll        ;
reg   [ACT_WIDTH                        -1 : 0] CCUSYA_CfgShift         ;
reg   [ACT_WIDTH                        -1 : 0] CCUSYA_CfgZp            ;
reg   [2                                -1 : 0] CCUSYA_CfgMod           ;
reg   [3                                -1 : 0] CCUSYA_CfgOfmPhaseShift ;
reg   [IDX_WIDTH                        -1 : 0] CCUSYA_CfgNumGrpPerTile ;
reg   [IDX_WIDTH                        -1 : 0] CCUSYA_CfgNumTilIfm     ;
reg   [IDX_WIDTH                        -1 : 0] CCUSYA_CfgNumTilFlt     ;
reg                                             CCUSYA_CfgLopOrd        ;
reg   [CHN_WIDTH                        -1 : 0] CCUSYA_CfgChn           ;
reg   [ADDR_WIDTH                       -1 : 0] CCUSYA_CfgActRdBaseAddr ;
reg   [ADDR_WIDTH                       -1 : 0] CCUSYA_CfgWgtRdBaseAddr ;
reg   [ADDR_WIDTH                       -1 : 0] CCUSYA_CfgOfmWrBaseAddr ;

//=====================================================================================================================
// Logic Design: ISA Decode
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin // Initialize
        CCUSYA_CfgOfmWrBaseAddr <=  0; // 16
        CCUSYA_CfgActRdBaseAddr <=  0; // 16
        CCUSYA_CfgWgtRdBaseAddr <=  0; // 16
        CCUSYA_CfgNumTilIfm     <=  1; // 16
        CCUSYA_CfgNumTilFlt     <=  1; // 16
        CCUSYA_CfgNumGrpPerTile <=  1; // 16
        CCUSYA_CfgChn           <=  1; // 16
        CCUSYA_CfgShift         <=  0; // 8
        CCUSYA_CfgZp            <=  0; // 8
        CCUSYA_CfgOfmPhaseShift <=  0; // 3
        CCUSYA_CfgLopOrd        <=  0; // 1
        CCUSYA_CfgMod           <=  0; // 2
        CCUSYA_CfgRstAll        <=  1; // 1
    end else if( state == IDLE & next_state == INREGUL) begin // Config
        {
        CCUSYA_CfgOfmWrBaseAddr ,   // 16
        CCUSYA_CfgActRdBaseAddr ,   // 16
        CCUSYA_CfgWgtRdBaseAddr ,   // 16
        CCUSYA_CfgNumTilIfm     ,   // 16
        CCUSYA_CfgNumTilFlt     ,   // 16
        CCUSYA_CfgNumGrpPerTile ,   // 16
        CCUSYA_CfgChn           ,   // 16
        CCUSYA_CfgShift         ,   // 8
        CCUSYA_CfgZp            ,   // 8
        
        CCUSYA_CfgOfmPhaseShift ,   // 3
        CCUSYA_CfgLopOrd        ,   // 1

        CCUSYA_CfgMod           ,   // 2
        CCUSYA_CfgRstAll            // 1
        } <= CCUSYA_CfgInfo[SYAISA_WIDTH -1 : 9];
    end
end
wire CCUSYA_CfgRstAll_wire = CCUSYA_CfgInfo[9];

//=====================================================================================================================
// Logic Design: FSM
//=====================================================================================================================
always @(*) begin
    case ( state )
        IDLE :  if(CCUSYA_CfgVld & SYACCU_CfgRdy)
                    next_state <= INREGUL; //
                else
                    next_state <= IDLE;

        INREGUL:if(CCUSYA_CfgVld)
                    next_state <= IDLE;
                else if( (Overflow_CntTilIfm & Overflow_CntTilFlt & Overflow_CntGrp & Overflow_CntChn) & handshake_s0)
                    next_state <= IDLE;
                else
                    next_state <= INREGUL;

        default:    next_state <= IDLE;

    endcase
end
always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

//=====================================================================================================================
// Logic Design: S0
//=====================================================================================================================
// --------------------------------------------------------------------------------------------------------------------
// Combinational Logic
// --------------------------------------------------------------------------------------------------------------------
assign RstAll       = CCUSYA_CfgRstAll_wire & (state == IDLE & next_state == INREGUL); // Pulse
assign SYA_MaxRowCol= CCUSYA_CfgMod == 0 ? NUM_ROW*SYA_SIDEBANK : NUM_ROW*SYA_SIDEBANK*2;
assign SYACCU_CfgRdy= state == IDLE;

assign MaxCntChn    = CCUSYA_CfgChn - 1; 
assign INC_CntChn   = handshake_s0;
assign MaxCntGrp    = CCUSYA_CfgNumGrpPerTile - 1; 
assign INC_CntGrp   = Overflow_CntChn & INC_CntChn;
assign MaxCntTilFlt = CCUSYA_CfgNumTilFlt - 1; 
assign INC_CntTilFlt= CCUSYA_CfgLopOrd == 0? Overflow_CntGrp & INC_CntGrp : Overflow_CntTilIfm & INC_CntTilIfm;
assign MaxCntTilIfm = CCUSYA_CfgNumTilIfm - 1;
assign INC_CntTilIfm= CCUSYA_CfgLopOrd == 0? Overflow_CntTilFlt & INC_CntTilFlt : Overflow_CntGrp & INC_CntGrp;

// HandShake
assign rdy_s0       = GLBSYA_ActRdAddrRdy & GLBSYA_WgtRdAddrRdy; // 2 loads
assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0       = handshake_s0 | ~vld_s0;
assign vld_s0       = state == INREGUL;

// --------------------------------------------------------------------------------------------------------------------
// Reg Update

counter#(
    .COUNT_WIDTH ( CHN_WIDTH )
)u1_counter_CntChn(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( state == IDLE      ),
    .DEFAULT   ( {CHN_WIDTH{1'b0}}  ),
    .INC       ( INC_CntChn         ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {CHN_WIDTH{1'b0}}  ),
    .MAX_COUNT ( MaxCntChn          ),
    .OVERFLOW  ( Overflow_CntChn    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntChn             )
);

counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u1_counter_CntGrp(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( state == IDLE      ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}} ),
    .INC       ( INC_CntGrp         ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {ADDR_WIDTH{1'b0}} ),
    .MAX_COUNT ( MaxCntGrp          ),
    .OVERFLOW  ( Overflow_CntGrp    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntGrp             ) 
);

counter#(
    .COUNT_WIDTH ( CHN_WIDTH )
)u1_counter_CntTilFlt(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( state == IDLE      ),
    .DEFAULT   ( {CHN_WIDTH{1'b0}}  ),
    .INC       ( INC_CntTilFlt      ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {CHN_WIDTH{1'b0}}  ),
    .MAX_COUNT ( MaxCntTilFlt       ),
    .OVERFLOW  ( Overflow_CntTilFlt ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntTilFlt          ) 
);

counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_CntTilIfm(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( state == IDLE      ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
    .INC       ( INC_CntTilIfm      ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
    .MAX_COUNT ( MaxCntTilIfm       ),
    .OVERFLOW  ( Overflow_CntTilIfm ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntTilIfm          )
);

//=====================================================================================================================
// Logic Design: S1: RdAct/WgtDat
//=====================================================================================================================
// Combinational Logic
assign SYAGLB_ActRdAddr     = state == IDLE? 0 : CCUSYA_CfgActRdBaseAddr + CCUSYA_CfgChn*CCUSYA_CfgNumGrpPerTile*CntTilIfm + CCUSYA_CfgChn*CntGrp + CntChn;
assign SYAGLB_ActRdAddrVld  = state == IDLE? 0 : vld_s0 & GLBSYA_WgtRdAddrRdy; // other load are ready
assign SYAGLB_WgtRdAddr     = state == IDLE? 0 : CCUSYA_CfgWgtRdBaseAddr + CCUSYA_CfgChn*CCUSYA_CfgNumGrpPerTile*CntTilFlt + CCUSYA_CfgChn*CntGrp + CntChn;
assign SYAGLB_WgtRdAddrVld  = state == IDLE? 0 : vld_s0 & GLBSYA_ActRdAddrRdy; // other load are ready
assign SYAGLB_ActRdDatRdy   = state == IDLE? 0 : rdy_s1;
assign SYAGLB_WgtRdDatRdy   = state == IDLE? 0 : rdy_s1;

assign rdy_s1       = ena_s2;
assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1       = handshake_s1 | ~vld_s1;
assign vld_s1       = GLBSYA_ActRdDatVld & GLBSYA_WgtRdDatVld;

// --------------------------------------------------------------------------------------------------------------------
// Reg Update

//=====================================================================================================================
// Logic Design: S2: Compute Psum
//=====================================================================================================================
// --------------------------------------------------------------------------------------------------------------------
// Combinational Logic
wire [32    -1 : 0] CntMac;
assign NumDiag  = CCUSYA_CfgMod == 0? 63 : 79; // 32 + 31 : 64 + 15;

// Generate SYA Input signals: SYA_In
// Bank[0]
assign SYA_InAct_W          [0] = GLBSYA_ActRdDat[0];
assign SYA_InWgt_N          [0] = GLBSYA_WgtRdDat[0];

// Bank[1]
assign SYA_InAct_W          [1] = CCUSYA_CfgMod == 2? GLBSYA_ActRdDat[2]: SYA_OutAct_E[0];
assign SYA_InWgt_N          [1] = CCUSYA_CfgMod == 2? SYA_OutWgt_S[2]   : GLBSYA_WgtRdDat[1];

// Bank[2]
assign SYA_InAct_W          [2] = CCUSYA_CfgMod == 1? SYA_OutAct_E[1]    : GLBSYA_ActRdDat[1];
assign SYA_InWgt_N          [2] = CCUSYA_CfgMod == 1? GLBSYA_WgtRdDat[2] : SYA_OutWgt_S[0];

// Bank[3]
assign SYA_InAct_W          [3] = CCUSYA_CfgMod == 2? GLBSYA_ActRdDat[3] : SYA_OutAct_E[2];
assign SYA_InWgt_N          [3] = CCUSYA_CfgMod == 1? GLBSYA_WgtRdDat[3] : SYA_OutWgt_S[1];

// Generate SYA Input signals: SYA_En, SYA_Reset
assign SYA_En   = {NUM_COL*NUM_ROW*NUM_BANK{handshake_s1}} ;
generate
    for(gv_bk=0; gv_bk<NUM_BANK; gv_bk=gv_bk+1) begin: GEN_SYA_Reset
        for(gv_row=0; gv_row<NUM_ROW; gv_row=gv_row+1) begin
            for(gv_col=0; gv_col<NUM_COL; gv_col=gv_col+1) begin
                wire [$clog2(NUM_ROW*NUM_BANK)  -1 : 0] axis_x;
                wire [$clog2(NUM_ROW*NUM_BANK)  -1 : 0] axis_y;

                assign axis_x = CCUSYA_CfgMod == 0? NUM_ROW*(gv_bk/2) + gv_row
                                    : CCUSYA_CfgMod == 1? gv_row
                                        : NUM_ROW*gv_bk + gv_row;
                assign axis_y = CCUSYA_CfgMod == 0? NUM_COL*(gv_bk%2) + gv_col
                                    : CCUSYA_CfgMod == 1? NUM_COL*gv_bk + gv_col
                                        : gv_col;
                assign SYA_Reset[gv_bk][gv_row][gv_col] = (axis_x + axis_y == CurPsumOutDiagIdx_s2) & (handshake_s2) | RstAll;
            end
        end
    end
endgenerate

// --------------------------------------------------------------------------------------------------------------------
// Cfg Cache
localparam FIFO_DATA_WIDTH = IDX_WIDTH*2 + CHN_WIDTH + ACT_WIDTH*2 + 4;
wire                            push;
wire                            pop;
wire [FIFO_DATA_WIDTH   -1 : 0] fifo_data_in;
wire [FIFO_DATA_WIDTH   -1 : 0] fifo_data_out;

wire [IDX_WIDTH         -1 : 0] fifo_out_CfgNumTilFlt;
wire [IDX_WIDTH         -1 : 0] fifo_out_CfgNumGrpPerTile;
wire [CHN_WIDTH         -1 : 0] fifo_out_CfgChn; 
wire [CHN_WIDTH         -1 : 0] fifo_out_CfgChn_tmp; 
wire [ACT_WIDTH         -1 : 0] fifo_out_CfgZp; 
wire [ACT_WIDTH         -1 : 0] fifo_out_CfgShift; 
wire                            fifo_out_CfgOfmPhaseShift;
wire                            fifo_out_CfgLopOrd;
wire [2                 -1 : 0] fifo_out_CfgMod;

// The last channel of the 00 PE or RstAll-> push 1st
assign push         = SYA_Reset[0][0] | RstAll_d; 
assign fifo_data_in = {
    CCUSYA_CfgNumTilFlt, 
    CCUSYA_CfgNumGrpPerTile, 
    CCUSYA_CfgChn, 
    CCUSYA_CfgShift, 
    CCUSYA_CfgZp, 
    CCUSYA_CfgOfmPhaseShift[0], 
    CCUSYA_CfgLopOrd, 
    CCUSYA_CfgMod
    };
assign pop          = handshake_s2;

// HandShake
// SYA_PsumOutRdy: 2 loads: shift_din or GLB
assign rdy_s2       = fifo_out_CfgOfmPhaseShift? &fwftOfm_din_rdy : GLBSYA_OfmWrDatRdy; 
// SYA_PsumOutVld
assign vld_s2       = ( (CntMac >= fifo_out_CfgChn) & 0 <= CntMac % fifo_out_CfgChn & CntMac % fifo_out_CfgChn <= NumDiag ) & CntRmDiagPsum > 0;
assign handshake_s2 = rdy_s2 & vld_s2;
assign ena_s2       = handshake_s2 | ~vld_s2;

// --------------------------------------------------------------------------------------------------------------------
// Reg Update
counter#(
    .COUNT_WIDTH ( 32 )
)u1_counter_CntMac( // Total MAC
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( RstAll         ),
    .DEFAULT   ( {32{1'b0}}     ),
    .INC       ( handshake_s1   ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {32{1'b0}}     ),
    .MAX_COUNT ( {32{1'b1}}     ),
    .OVERFLOW  (                ),
    .UNDERFLOW (                ),
    .COUNT     ( CntMac         )
);

counter#(
    .COUNT_WIDTH ( NUMDIAG_WIDTH ),
    .DEFAULT_VAR ( 1             ) 
)u1_counter_CntRmDiagPsum( // Remained Diagnonal Psum to output
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( handshake_s1 | RstAll),
    .DEFAULT   ( state == IDLE? {NUMDIAG_WIDTH{1'b0}} : DefaultRmDiagPsum ),
    .INC       ( 1'b0               ),
    .DEC       ( handshake_s2       ),
    .MIN_COUNT ( {NUMDIAG_WIDTH{1'b0}} ),
    .MAX_COUNT ( {NUMDIAG_WIDTH{1'b1}} ),
    .OVERFLOW  (                    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntRmDiagPsum      )
);

FIFO_FWFT#(
    .DATA_WIDTH ( FIFO_DATA_WIDTH ),
    .ADDR_WIDTH ( $clog2(NUM_ROW*NUM_BANK) ) // Max
)u_FIFO_FWFT_Cfg(
    .clk        ( clk       ),
    .Reset      ( RstAll    ),
    .rst_n      ( rst_n     ),
    .push       ( push      ),
    .pop        ( pop       ),
    .data_in    ( fifo_data_in),
    .data_out   ( fifo_data_out),
    .empty      (           ),
    .full       (           ),
    .fifo_count (           )
);

DELAY#(
    .NUM_STAGES ( 1 ),
    .DATA_WIDTH ( 1 )
)u_DELAY_RstAll_d(
    .CLK        ( clk       ),
    .RST_N      ( rst_n     ),
    .DIN        ( RstAll    ),
    .DOUT       ( RstAll_d  ) 
);

PE_BANK #(
    .ACT_WIDTH       ( ACT_WIDTH ),
    .WGT_WIDTH       ( WGT_WIDTH ),
    .CHN_WIDTH       ( CHN_WIDTH ),
    .NUM_ROW         ( NUM_ROW   ),
    .NUM_COL         ( NUM_COL   )
)u_PE_BANK [NUM_BANK -1 : 0] (
    .clk       ( clk            ),
    .rst_n     ( rst_n          ),
    .En        ( SYA_En         ),
    .Reset     ( SYA_Reset      ),
    .InAct_W   ( SYA_InAct_W    ),
    .InWgt_N   ( SYA_InWgt_N    ),
    .OutAct_E  ( SYA_OutAct_E   ),
    .OutWgt_S  ( SYA_OutWgt_S   ),
    .OutPsum   ( SYA_OutPsum    )
);

//=====================================================================================================================
// Logic Design: S3: Shift Psum In
//=====================================================================================================================
// --------------------------------------------------------------------------------------------------------------------
// Combinational Logic
assign DefaultRmDiagPsum    = (CntMac % NumDiag) / CCUSYA_CfgChn + 1;
assign CurPsumOutDiagIdx_s2 = ( (CntMac - CCUSYA_CfgChn) % NumDiag ) - (DefaultRmDiagPsum - CntRmDiagPsum);

// Generate OfmDiag
assign NumFltPal            = fifo_out_CfgMod == 0? 32 : fifo_out_CfgMod == 1? 64 : 16;
assign Cho_s2               = fifo_out_CfgNumGrpPerTile*fifo_out_CfgNumTilFlt;
assign SYA_PsumOutAddr_s2   = CntMac % fifo_out_CfgChn + 
                                (fifo_out_CfgLopOrd == 0? 
                                    Cho_s2*(DefaultRmDiagPsum - CntRmDiagPsum)*(CCUSYA_CfgNumGrpPerTile*CntTilIfm + CntGrp)
                                    : NumFltPal*(DefaultRmDiagPsum - CntRmDiagPsum)*(CCUSYA_CfgNumGrpPerTile*CntTilFlt + CntGrp)
                                );
always@(*) begin
    OfmDiag  = OfmDiag_r;
    for(bank=0; bank<NUM_BANK; bank=bank+1) begin
        for (row=0; row<NUM_ROW; row=row + 1) begin
            for(col=0; col<NUM_COL; col=col+1) begin
                SYA_OutPsum_RQ[bank][row][col]   = SYA_OutPsum[bank][row][col][PSUM_WIDTH -1]? 
                                                    0 
                                                    : SYA_OutPsum[bank][row][col][fifo_out_CfgShift +: ACT_WIDTH] + fifo_out_CfgZp; 
                                                    // ReLU and Quant at first.
                // Only when 2x2 case: Diag of Current looped PE
                travDiagIdx_tmp = ((bank/2)*NUM_ROW + row + (bank%2)*NUM_COL + col); 
                if (travDiagIdx_tmp == CurPsumOutDiagIdx_s2) begin 
                    // Match, Psum should be output
                    OfmDiag[bank][row]   = SYA_OutPsum_RQ[bank][row][col];
                end
            end
        end
    end
end

DELAY#(
    .NUM_STAGES ( 1 ),
    .DATA_WIDTH ( ACT_WIDTH*NUM_ROW*NUM_BANK )
)u_DELAY_OfmDiag(
    .CLK        ( clk       ),
    .RST_N      ( rst_n     ),
    .DIN        ( OfmDiag   ),
    .DOUT       ( OfmDiag_r )
);

assign {
    fifo_out_CfgNumTilFlt, 
    fifo_out_CfgNumGrpPerTile, 
    fifo_out_CfgChn_tmp, 
    fifo_out_CfgShift, 
    fifo_out_CfgZp, 
    fifo_out_CfgOfmPhaseShift, 
    fifo_out_CfgLopOrd, 
    fifo_out_CfgMod
    } = fifo_data_out;
assign fifo_out_CfgChn = fifo_out_CfgChn_tmp == 0? 1 : fifo_out_CfgChn_tmp;

// --------------------------------------------------------------------------------------------------------------------
// Current Diag Psum Should be Out to GLB at Diag <32; 
// otherwise should be cached into SHIFT at Diag > 32;
assign DiagOut = CurPsumOutDiagIdx_s2 <= NUM_ROW*SYA_SIDEBANK; 

// Generate shift_din
assign shift_din    = OfmDiag;
assign fwftOfm_din  = fifo_out_CfgOfmPhaseShift? 
                        (DiagOut? 0 : PartPsumVld)
                        : {NUM_ROW*NUM_BANK{vld_s2}}; // Write a part

// PartPsumVld: Select partial psums at Diag<32 of the next loop
// OfmDiagConcat: Concate psums at Diag<32 of the next loop with Diag>32 of the current loop
always @(*) begin 
    PartPsumVld = 0;
    OfmDiagConcat = OfmDiag;
    for(i=0; i<CurPsumOutDiagIdx_s2; i=i+1) begin
        PartPsumVld[i] = vld_s2;
        OfmDiagConcat[ACT_WIDTH*i +: ACT_WIDTH] = vld_s3? shift_dout[ACT_WIDTH*i +: ACT_WIDTH] : 0;
    end
end

// HandShake
assign rdy_s3       = GLBSYA_OfmWrDatRdy;
assign vld_s3       = fwftOfm_dout_vld;
assign handshake_s3 = rdy_s3 & vld_s3;
assign ena_s3       = handshake_s3 | ~vld_s3;

assign fwftOfm_dout_rdy   = rdy_s3 & SYAGLB_OfmWrDatVld;
// --------------------------------------------------------------------------------------------------------------------
// Reg Update
wire                        fwftOfm_push;
wire                        fwftOfm_pop;
wire                        fwftOfm_empty;
wire                        fwftOfm_full;

assign fwftOfm_push     = fwftOfm_din & fwftOfm_din_rdy;
assign fwftOfm_din_rdy  = !fwftOfm_full;
assign fwftOfm_pop      = fwftOfm_dout_vld & fwftOfm_dout_rdy;
assign fwftOfm_dout_vld = !fwftOfm_empty;

FIFO_FWFT#(
    .DATA_WIDTH ( ACT_WIDTH*NUM_ROW*NUM_BANK ), // 64B
    .ADDR_WIDTH ( $clog2(NUM_ROW*NUM_BANK)  )   // Max: 64
)u_FIFO_FWFT_OFM(
    .clk        ( clk           ),
    .Reset      ( RstAll        ),
    .rst_n      ( rst_n         ),
    .push       ( fwftOfm_push  ),
    .pop        ( fwftOfm_pop   ),
    .data_in    ( shift_din     ),
    .data_out   ( shift_dout    ),
    .empty      ( fwftOfm_empty ),
    .full       ( fwftOfm_full  ),
    .fifo_count (               )
);

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        ShiftOut_OfmAddr_s3 <= 0;
    end else if(RstAll) begin
        ShiftOut_OfmAddr_s3 <= 0;
    end else if(fwftOfm_din & fwftOfm_din_rdy) begin
        // cache the address of the first din
        ShiftOut_OfmAddr_s3 <= SYA_PsumOutAddr_s2 + (NUM_ROW*NUM_BANK - 1);
    end
end

//=====================================================================================================================
// Logic Design: S4: Psum Out
//=====================================================================================================================
// --------------------------------------------------------------------------------------------------------------------
// Combinational Logic

// --------------------------------------------------------------------------------------------------------------------
// Write Ofm to GLB 
assign SYAGLB_OfmWrDat      = state == IDLE? 0 : fifo_out_CfgOfmPhaseShift? 
                                shift_dout       
                                : OfmDiagConcat;
assign SYAGLB_OfmWrDatVld   = state == IDLE? 0 : fifo_out_CfgOfmPhaseShift? 
                                vld_s3  
                                : DiagOut & vld_s2; // Concate
assign SYAGLB_OfmWrAddr     = state == IDLE? 0 : (fifo_out_CfgOfmPhaseShift | !DiagOut)? 
                                ShiftOut_OfmAddr_s3
                                : SYA_PsumOutAddr_s2; // Ref to HW-SYA

//=====================================================================================================================
// Logic Design: Monitor
//=====================================================================================================================
assign SYAMON_Dat = {
    CCUSYA_CfgVld       ,
    SYACCU_CfgRdy       ,
    SYAGLB_ActRdAddrVld ,
    GLBSYA_ActRdAddrRdy ,
    GLBSYA_ActRdDatVld  ,
    SYAGLB_ActRdDatRdy  ,
    SYAGLB_WgtRdAddrVld ,
    GLBSYA_WgtRdAddrRdy , 
    GLBSYA_WgtRdDatVld  ,
    SYAGLB_WgtRdDatRdy  , 
    SYAGLB_OfmWrDatVld  ,
    GLBSYA_OfmWrDatRdy  , 
    CntRmDiagPsum       , 
    CntMac              , 
    CntTilFlt           , 
    CntTilIfm           ,
    CntGrp              , 
    CntChn              , 
    CCUSYA_CfgInfo      , 
    state                
};

endmodule



