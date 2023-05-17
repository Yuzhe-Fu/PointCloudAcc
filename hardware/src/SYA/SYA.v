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
    input                                                   clk                     ,
    input                                                   rst_n                   ,
    input                                                   CCUSYA_CfgVld           ,
    output                                                  SYACCU_CfgRdy           ,
    input                                                   CCUSYA_CfgRstAll        ,
    input  [ACT_WIDTH                               -1 : 0] CCUSYA_CfgShift         ,
    input  [ACT_WIDTH                               -1 : 0] CCUSYA_CfgZp            ,
    input  [2                                       -1 : 0] CCUSYA_CfgMod           ,
    input                                                   CCUSYA_CfgOfmPhaseShift ,
    input  [IDX_WIDTH                               -1 : 0] CCUSYA_CfgNumGrpPerTile ,
    input  [IDX_WIDTH                               -1 : 0] CCUSYA_CfgNumTilIfm     ,
    input  [IDX_WIDTH                               -1 : 0] CCUSYA_CfgNumTilFlt     ,
    input                                                   CCUSYA_CfgLopOrd        ,
    input  [CHN_WIDTH                               -1 : 0] CCUSYA_CfgChn           ,
    input  [ADDR_WIDTH                              -1 : 0] CCUSYA_CfgActRdBaseAddr ,
    input  [ADDR_WIDTH                              -1 : 0] CCUSYA_CfgWgtRdBaseAddr ,
    input  [ADDR_WIDTH                              -1 : 0] CCUSYA_CfgOfmWrBaseAddr ,
    output [ADDR_WIDTH                              -1 : 0] SYAGLB_ActRdAddr        ,
    output                                                  SYAGLB_ActRdAddrVld     ,
    input                                                   GLBSYA_ActRdAddrRdy     ,
    input  [NUM_BANK-1:0][NUM_ROW   -1:0][ACT_WIDTH -1 : 0] GLBSYA_ActRdDat         ,
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
    input                                                   GLBSYA_OfmWrDatRdy           

  );

localparam  SYA_SIDEBANK = 2**($clog2(NUM_BANK) - 1); // SQURT(4) = 2
localparam  PSUM_WIDTH = ACT_WIDTH + WGT_WIDTH + CHN_WIDTH;
localparam NUMDIAG_WIDTH = $clog2(NUM_ROW*8);

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
wire [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][ACT_WIDTH   -1 : 0] SYA_OfmOut;
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

wire [ACT_WIDTH*NUM_ROW*SYA_SIDEBANK    -1 : 0] shift_din;
wire [1*NUM_ROW*SYA_SIDEBANK            -1 : 0] shift_din_vld;
reg  [1*NUM_ROW*SYA_SIDEBANK            -1 : 0] PartPsumVld;
wire                                            shift_din_rdy;
wire [ACT_WIDTH*NUM_ROW*SYA_SIDEBANK    -1 : 0] shift_dout;
wire                                            shift_dout_vld;
wire                                            shift_dout_rdy;
reg [ADDR_WIDTH                         -1 : 0] SYA_PsumOutAddr;
reg [ADDR_WIDTH                         -1 : 0] Cache_ShiftIn_OfmAddr;
reg [ACT_WIDTH*NUM_ROW*SYA_SIDEBANK    -1 : 0] ConcatDiagPsum;
wire                                SYA_PsumOutVld;
wire                                SYA_PsumOutRdy;

wire [NUMDIAG_WIDTH         -1 : 0] CntRmDiagPsum;
wire [NUMDIAG_WIDTH         -1 : 0] DefaultRmDiagPsum;
wire [NUMDIAG_WIDTH         -1 : 0] NumDiag;
integer                             i;
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
        INREGUL:if(CCUSYA_CfgVld)
                    next_state <= IDLE;
                else if( (Overflow_CntTilIfm & Overflow_CntTilFlt & Overflow_CntGrp & Overflow_CntChn) & handshake_s0)
                    next_state <= IDLE;
                else
                    next_state <= INREGUL;
        
        // INSHIFT :if( (CntChn == (SYA_MaxRowCol -1) -1) & handshake_s0 ) 
        //             next_state <= WAITOUT;
        //         else
        //             next_state <= INSHIFT;
        // WAITOUT     : if( !(|SYA_OutPsumVld) & !SYAGLB_OfmWrDatVld )
        //             next_state <= IDLE;
        //         else
        //             next_state <= WAITOUT;
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
assign RstAll = CCUSYA_CfgRstAll & state == IDLE;

// Combinational Logic
assign SYA_MaxRowCol= CCUSYA_CfgMod == 0 ? NUM_ROW*SYA_SIDEBANK : NUM_ROW*SYA_SIDEBANK*2;
assign SYACCU_CfgRdy= state == IDLE;

// HandShake
assign rdy_s0       = GLBSYA_ActRdAddrRdy & GLBSYA_WgtRdAddrRdy; // 2 loads
assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0       = handshake_s0 | ~vld_s0;
assign vld_s0       = state == INREGUL;

// Reg Update
assign MaxCntChn    = CCUSYA_CfgChn - 1; 
assign INC_CntChn   = handshake_s0;
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

assign MaxCntGrp  = CCUSYA_CfgNumGrpPerTile - 1; 
assign INC_CntGrp = Overflow_CntChn & INC_CntChn;
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

assign MaxCntTilFlt     = CCUSYA_CfgNumTilFlt - 1; 
assign INC_CntTilFlt    = CCUSYA_CfgLopOrd == 0? Overflow_CntGrp & INC_CntGrp : Overflow_CntTilIfm & INC_CntTilIfm;
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

assign MaxCntTilIfm     = CCUSYA_CfgNumTilIfm - 1;
assign INC_CntTilIfm    = CCUSYA_CfgLopOrd == 0? Overflow_CntTilFlt & INC_CntTilFlt : Overflow_CntGrp & INC_CntGrp;
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
// Logic Design:
//=====================================================================================================================
// Combinational Logic

assign SYAGLB_ActRdAddr     = CCUSYA_CfgActRdBaseAddr + CCUSYA_CfgChn*CCUSYA_CfgNumGrpPerTile*CntTilIfm + CCUSYA_CfgChn*CntGrp + CntChn;
assign SYAGLB_ActRdAddrVld  = vld_s0 & GLBSYA_WgtRdAddrRdy; // other load are ready
assign SYAGLB_WgtRdAddr     = CCUSYA_CfgWgtRdBaseAddr + CCUSYA_CfgChn*CCUSYA_CfgNumGrpPerTile*CntTilFlt + CCUSYA_CfgChn*CntGrp + CntChn;
assign SYAGLB_WgtRdAddrVld  = vld_s0 & GLBSYA_ActRdAddrRdy; // other load are ready
assign SYAGLB_ActRdDatRdy   = rdy_s1;
assign SYAGLB_WgtRdDatRdy   = rdy_s1;

assign rdy_s1 = SYA_PsumOutVld? ( CCUSYA_CfgOfmPhaseShift? &shift_din_rdy : GLBSYA_OfmWrDatRdy) & CntRmDiagPsum == 1 : 1'b1;

assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1       = handshake_s1 | ~vld_s1;
assign vld_s1       = GLBSYA_ActRdDatVld & GLBSYA_WgtRdDatVld;

// Reg Update


// Bank[0]
assign SYA_InAct_W          [0] = GLBSYA_ActRdDat[0];
assign SYA_InWgt_N          [0] = GLBSYA_WgtRdDat[0];

// Bank[1]
assign SYA_InAct_W          [1] = CCUSYA_CfgMod == 2? GLBSYA_ActRdDat[2]: SYA_OutAct_E[0];
assign SYA_InWgt_N          [1] = CCUSYA_CfgMod == 2? SYA_OutWgt_S[2]   : GLBSYA_WgtRdDat[1];

// Bank[2]
assign SYA_InAct_W          [2] = CCUSYA_CfgMod == 1? SYA_OutAct_E[1]    : GLBSYA_ActRdDat[1];
assign SYA_InWgt_N          [2] = CCUSYA_CfgMod == 1? GLBSYA_WgtRdDat[2] : SYA_OutWgtVld_S[0];

// Bank[3]
assign SYA_InAct_W          [3] = CCUSYA_CfgMod == 2? GLBSYA_ActRdDat[3] : SYA_OutAct_E[2];
assign SYA_InWgt_N          [3] = CCUSYA_CfgMod == 1? GLBSYA_WgtRdDat[3] : SYA_OutWgt_S[1];

//=====================================================================================================================
// Logic Design: SYA In
//=====================================================================================================================
wire [32    -1 : 0] CntMac;

counter#(
    .COUNT_WIDTH ( 32 )
)u1_counter_CntMac( // Total MAC
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( RstAll             ), // ???
    .DEFAULT   ( {32{1'b0}}  ),
    .INC       ( handshake_s1             ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {32{1'b0}}  ),
    .MAX_COUNT ( {32{1'b1}}  ),
    .OVERFLOW  (                    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntMac             )
);

assign DefaultRmDiagPsum = (CntMac % NumDiag) / CCUSYA_CfgChn + 1;
counter#(
    .COUNT_WIDTH ( NUMDIAG_WIDTH )
)u1_counter_CntRmDiagPsum( // Remained Diagnonal Psum to output
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( handshake_s1 | RstAll),
    .DEFAULT   ( DefaultRmDiagPsum ),
    .INC       ( 1'b0               ),
    .DEC       ( SYA_PsumOutVld & SYA_PsumOutRdy  ),
    .MIN_COUNT ( {NUMDIAG_WIDTH{1'b0}}  ),
    .MAX_COUNT ( {NUMDIAG_WIDTH{1'b1}}       ),
    .OVERFLOW  (                    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntRmDiagPsum          )
);

assign NumDiag  = CCUSYA_CfgMod == 0? 63 : 79; // 32 + 31 : 64 + 15;
assign SYA_En   = {NUM_COL*NUM_ROW*NUM_BANK{handshake_s1}} ;

genvar gv_bk;
genvar gv_row;
genvar gv_col;

assign CurPsumOutDiagIdx = ( (CntMac - CCUSYA_CfgChn) % NumDiag ) - (DefaultRmDiagPsum - CntRmDiagPsum);
generate
    for(gv_bk=0; gv_bk<NUM_BANK; gv_bk=gv_bk+1) begin
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
                assign SYA_Reset[gv_bk][gv_row][gv_col] = (axis_x + axis_y == CurPsumOutDiagIdx) & (SYA_PsumOutVld & SYA_PsumOutRdy) | RstAll;
            end
        end
    end
endgenerate

localparam FIFO_DATA_WIDTH = IDX_WIDTH*2 + CHN_WIDTH + ACT_WIDTH*2 + 4;
wire                            push;
wire                            pop;
wire [FIFO_DATA_WIDTH   -1 : 0] fifo_data_in;
wire [FIFO_DATA_WIDTH   -1 : 0] fifo_data_out;

wire [IDX_WIDTH         -1 : 0] fifo_out_CfgNumTilFlt;
wire [IDX_WIDTH         -1 : 0] fifo_out_CfgNumGrpPerTile;
wire [CHN_WIDTH         -1 : 0] fifo_out_CfgChn; 
wire [ACT_WIDTH         -1 : 0] fifo_out_CfgZp; 
wire [ACT_WIDTH         -1 : 0] fifo_out_CfgShift; 
wire                            fifo_out_CfgOfmPhaseShift;
wire                            fifo_out_CfgLopOrd;
wire [2                 -1 : 0] fifo_out_CfgMod;

assign push         = SYA_Reset[0][0]; // The last channel of the 00 PE
assign fifo_data_in = { CCUSYA_CfgNumTilFlt, CCUSYA_CfgNumGrpPerTile, CCUSYA_CfgChn, CCUSYA_CfgShift, CCUSYA_CfgZp, CCUSYA_CfgOfmPhaseShift, CCUSYA_CfgLopOrd, CCUSYA_CfgMod };
assign pop          = SYA_PsumOutVld & SYA_PsumOutRdy;
assign {fifo_out_CfgNumTilFlt, fifo_out_CfgNumGrpPerTile, fifo_out_CfgChn, fifo_out_CfgShift, fifo_out_CfgZp, fifo_out_CfgOfmPhaseShift, fifo_out_CfgLopOrd, fifo_out_CfgMod} = fifo_data_out;

FIFO_FWFT#(
    .DATA_WIDTH ( FIFO_DATA_WIDTH ),
    .ADDR_WIDTH ( $clog2(NUM_ROW*NUM_BANK) ) // Max
)u_FIFO_FWFT_Cfg(
    .clk        ( clk        ),
    .Reset      ( RstAll     ),
    .rst_n      ( rst_n      ),
    .push       ( push       ),
    .pop        ( pop        ),
    .data_in    ( fifo_data_in    ),
    .data_out   ( fifo_data_out),
    .empty      (           ),
    .full       (           ),
    .fifo_count (           )
);

//=====================================================================================================================
// Logic Design: SYA Out
//=====================================================================================================================
assign SYA_PsumOutVld   = ( (CntMac >= fifo_out_CfgChn) & 0 <= CntMac % fifo_out_CfgChn & CntMac % fifo_out_CfgChn <= NumDiag ) & CntRmDiagPsum > 0;
assign NumFltPal        = fifo_out_CfgMod == 0? 32 : fifo_out_CfgMod == 1? 64 : 16;
assign Cho              = fifo_out_CfgNumGrpPerTile*fifo_out_CfgNumTilFlt;
assign SYA_PsumOutAddr  = (CntMac % fifo_out_CfgChn - fifo_out_CfgChn) + fifo_out_CfgLopOrd == 0? Cho*(DefaultRmDiagPsum - CntRmDiagPsum)
                                                                            : NumFltPal*(DefaultRmDiagPsum - CntRmDiagPsum);
assign SYA_PsumOutRdy = fifo_out_CfgOfmPhaseShift? &shift_din_rdy : GLBSYA_OfmWrDatRdy;

generate
    for (gv_row=0; gv_row<NUM_ROW*NUM_BANK; gv_row=gv_row + 1) begin
        wire [PSUM_WIDTH            -1 : 0] OutPsum_tmp;
        assign OutPsum_tmp          = SYA_OutPsum[gv_row/NUM_ROW][gv_row%NUM_ROW][CurPsumOutDiagIdx - gv_row]; // ??????????
        assign SYA_OfmOut[gv_row/NUM_ROW][gv_row%NUM_ROW]   = OutPsum_tmp[PSUM_WIDTH - 1]? 0 : OutPsum_tmp[fifo_out_CfgShift +: ACT_WIDTH] + fifo_out_CfgZp;
    end
endgenerate

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
// Logic Design: Shift
//=====================================================================================================================
SHIFT #(
    .DATA_WIDTH(ACT_WIDTH),
    .SIDE_LEN  (NUM_ROW*SYA_SIDEBANK) // 32
) u_SHIFT_OFM (               
    .clk                 ( clk          ),
    .rst_n               ( rst_n        ),
    .Rst                 ( RstAll       ),  
    .shift               ( fifo_out_CfgOfmPhaseShift),                      
    .shift_din           ( shift_din     ),
    .shift_din_vld       ( shift_din_vld ),
    .shift_din_rdy       ( shift_din_rdy ),                        
    .shift_dout          ( shift_dout    ),
    .shift_dout_vld      ( shift_dout_vld),
    .shift_dout_rdy      ( shift_dout_rdy) 
);

assign shift_din     = SYA_OfmOut;

always @(*) begin // Select partial psums at Diag<32 of the next loop
    PartPsumVld = 0;
    for(i=0; i<CurPsumOutDiagIdx; i=i+1) begin
        PartPsumVld[i] = SYA_PsumOutVld;
    end
end
assign shift_din_vld = fifo_out_CfgOfmPhaseShift? (CurPsumOutDiagIdx > NUM_ROW*SYA_SIDEBANK? PartPsumVld : 0): {NUM_ROW*SYA_SIDEBANK{SYA_PsumOutVld}}; // Write a part

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        Cache_ShiftIn_OfmAddr <= 0;
    end else if(RstAll) begin
        Cache_ShiftIn_OfmAddr <= 0;
    end else if(shift_din_vld & shift_din_rdy) begin // cache the address of the first din
        Cache_ShiftIn_OfmAddr <= SYA_PsumOutAddr;
    end
end

assign shift_dout_rdy   = GLBSYA_OfmWrDatRdy;
assign ShiftOut_OfmAddr = Cache_ShiftIn_OfmAddr + (NUM_BANK*NUM_ROW - 1);
//=====================================================================================================================
// Logic Design: GLB_OfmWr
//=====================================================================================================================
always @(*) begin // Concate psums at Diag<32 of the next loop with Diag>32 of the current loop
    ConcatDiagPsum = SYA_OfmOut;
    for(i=0; i<CurPsumOutDiagIdx; i=i+1) begin
        ConcatDiagPsum[ACT_WIDTH*i +: ACT_WIDTH] = shift_dout[ACT_WIDTH*i +: ACT_WIDTH];
    end
end

assign SYAGLB_OfmWrDat      = fifo_out_CfgOfmPhaseShift? shift_dout       : ConcatDiagPsum;
assign SYAGLB_OfmWrDatVld   = fifo_out_CfgOfmPhaseShift? |shift_dout_vld  
                                : (CurPsumOutDiagIdx <= NUM_ROW*SYA_SIDEBANK) & SYA_PsumOutVld & |shift_dout_vld;
assign SYAGLB_OfmWrAddr     = (fifo_out_CfgOfmPhaseShift | CurPsumOutDiagIdx > NUM_ROW*SYA_SIDEBANK)? ShiftOut_OfmAddr
                                : SYA_PsumOutAddr; // Ref to HW-SYA

endmodule

