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
    parameter ACC_WIDTH  = ACT_WIDTH+WGT_WIDTH+10, //26
    parameter NUM_ROW    = 16,
    parameter NUM_COL    = 16,
    parameter NUM_BANK   = 4,
    parameter SRAM_WIDTH = 256,
    parameter ADDR_WIDTH = 16,
    parameter QNT_WIDTH  = 8,
    parameter CHI_WIDTH  = 10,
    parameter IDX_WIDTH  = 16,
    parameter NUM_OUT    = NUM_BANK
  )(
    input                                     clk,
    input                                     rst_n,

    input                                     CCUSYA_Rst,
    
    input                                     CCUSYA_CfgVld,
    output                                    SYACCU_CfgRdy,
    
    input  [2                           -1:0] CCUSYA_CfgMod,
    input  [IDX_WIDTH                   -1:0] CCUSYA_CfgNip,
    input  [CHI_WIDTH                   -1:0] CCUSYA_CfgChi,
    
    input  [QNT_WIDTH                   -1:0] CCUSYA_CfgScale,
    input  [ACT_WIDTH                   -1:0] CCUSYA_CfgShift,
    input  [ACT_WIDTH                   -1:0] CCUSYA_CfgZp,
    input  [ADDR_WIDTH                  -1:0] CCUSYA_CfgActRdBaseAddr,
    input  [ADDR_WIDTH                  -1:0] CCUSYA_CfgWgtRdBaseAddr,
    input  [ADDR_WIDTH                  -1:0] CCUSYA_CfgOfmWrBaseAddr,
    
    output [ADDR_WIDTH                  -1:0] GLBSYA_ActRdAddr,
    output                                    GLBSYA_ActRdAddrVld,
    input                                     SYAGLB_ActRdAddrRdy,
    input  [ACT_WIDTH*NUM_ROW*NUM_BANK  -1:0] GLBSYA_ActRdDat,
    input                                     GLBSYA_ActRdDatVld,
    output                                    SYAGLB_ActRdDatRdy,

    output [ADDR_WIDTH                  -1:0] GLBSYA_WgtRdAddr,
    output                                    GLBSYA_WgtRdAddrVld,
    input                                     SYAGLB_WgtRdAddrRdy,
    input  [WGT_WIDTH*NUM_COL*NUM_BANK  -1:0] GLBSYA_WgtRdDat,
    input                                     GLBSYA_WgtRdDatVld,
    output                                    SYAGLB_WgtRdDatRdy,

    output [ACT_WIDTH*NUM_ROW*NUM_BANK  -1:0] SYAGLB_OfmWrDat,
    output [ADDR_WIDTH                  -1:0] SYAGLB_OfmWrAddr,
    output [NUM_OUT                     -1:0] SYAGLB_OfmWrDatVld,
    input  [NUM_OUT                     -1:0] GLBSYA_OfmWrDatRdy
  );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam  FM_WIDTH = ACT_WIDTH;
localparam  BANK_SQRT = 2**($clog2(NUM_BANK) - 1); // SQURT(4) = 2

localparam IDLE     = 3'b000;
localparam WAITFNH  = 3'b001;
localparam FNH      = 3'b001;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire cfg_vld = CCUSYA_CfgVld;
wire cfg_rdy = 'd1;

wire [2         -1:0] cfg_mod;
wire [IDX_WIDTH -1:0] cfg_nip;
wire [CHI_WIDTH -1:0] cfg_chi;
// the number of the final PE Column finishes all input channels 
wire [CHI_WIDTH   :0] cfg_chi_cnt = cfg_chi + NUM_COL-1; //cfg_mod == 'd0 ? cfg_chi + NUM_COL*2 : ( cfg_mod == 'd1 ? cfg_chi + NUM_COL : cfg_chi + NUM_COL*4);

wire [QNT_WIDTH -1:0] quant_scale;
wire [ACT_WIDTH -1:0] quant_shift;
wire [ACT_WIDTH -1:0] quant_zerop;

wire act_en = GLBSYA_ActRdDatVld & SYAGLB_ActRdDatRdy;
wire wgt_en = GLBSYA_WgtRdDatVld & SYAGLB_WgtRdDatRdy;

wire bank_en = act_en && wgt_en;

wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH -1:0] bank_out_fm;

reg  [NUM_BANK -1:0][NUM_COL -1:0] bank_ena_you;
reg  [NUM_BANK -1:0][NUM_ROW -1:0] bank_ena_xia;
reg  [NUM_BANK -1:0] bank_din_vld;
wire [NUM_BANK -1:0] bank_din_rdy;
wire [NUM_BANK -1:0] bank_din_rdy_d;
reg  [NUM_BANK -1:0] bank_din_rdy_tmp;
wire [NUM_BANK -1:0] bank_din_ena = bank_din_vld & bank_din_rdy;
wire [NUM_BANK -1:0] bank_din_ena_d;
wire [NUM_BANK -1:0][NUM_ROW -1:0] bank_din_ena_s;
wire [NUM_BANK -1:0] bank_din_run;
wire [NUM_BANK -1:0] bank_din_don;
wire [NUM_BANK -1:0] bank_act_rdy;
wire [NUM_BANK -1:0] bank_wgt_rdy;
reg  [NUM_BANK -1:0] bank_act_rdy_tmp;
reg  [NUM_BANK -1:0] bank_wgt_rdy_tmp;

wire pe_idle = ~|{bank_ena_you, bank_ena_xia};

wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1:0] bank_pkg_act = GLBSYA_ActRdDat;
wire [NUM_BANK -1:0][NUM_ROW -1:0][WGT_WIDTH  -1:0] bank_pkg_wgt = GLBSYA_WgtRdDat;

reg  [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1:0] bank_din_act;
wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1:0] bank_out_act;

reg  [NUM_BANK -1:0][NUM_COL -1:0][WGT_WIDTH  -1:0] bank_din_wgt;
wire [NUM_BANK -1:0][NUM_COL -1:0][WGT_WIDTH  -1:0] bank_out_wgt;

wire [NUM_BANK -1:0] bank_you_rst;
wire [NUM_BANK -1:0] bank_xia_rst;
reg  [NUM_BANK -1:0] bank_din_rst;
reg  [NUM_BANK -1:0] [CHI_WIDTH  :0] bank_acc_cnt;
reg  bank_acc_rdy;
wire [NUM_BANK -1:0] bank_acc_run;
wire [NUM_BANK -1:0] bank_acc_out;
reg  [NUM_BANK -1:0][NUM_ROW -1:0] bank_out_ena;
reg  [NUM_BANK -1:0][NUM_ROW -1:0] bank_row_out_ena;

wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1:0] sync_din = bank_out_fm;
wire [NUM_BANK -1:0][NUM_ROW -1:0] sync_din_vld = bank_row_out_ena & bank_out_ena & bank_din_ena_s; // bit-wise AND of conditions: whether acc of each row is valid & After all channels are input into PE(0,0) & Whether next bank is ready to fetch the act and wgt of the current bank (There are two loads of ofm: bank and reshape)
wire [NUM_BANK -1:0][NUM_ROW -1:0] sync_din_rdy;

wire [NUM_OUT*SRAM_WIDTH/2           -1:0]  sync_out;
wire [NUM_OUT                        -1:0]  sync_out_vld;
wire [NUM_OUT                        -1:0]  sync_out_rdy = GLBSYA_OfmWrDatRdy;

wire cfg_en = cfg_vld && cfg_rdy;

wire rst_reset = CCUSYA_Rst;

wire        Overflow_CntActRd;
wire        Overflow_CntOfmWr;

wire        rdy_Act_s0;
wire        vld_Act_s0;
wire        ena_Act_s0;
wire        handshake_Act_s0;
wire        handshake_Ofm;

//=====================================================================================================================
// Logic Design :
//=====================================================================================================================
reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE :  if(CCUSYA_CfgVld & SYACCU_CfgRdy)
                    next_state <= WAITFNH; //
                else
                    next_state <= IDLE;
        WAITFNH :if(Overflow_CntActRd & handshake_Act_s0 ) 
                    next_state <= FNH;
                else
                    next_state <= WAITFNH;
        FNH     : if(Overflow_CntOfmWr & handshake_Ofm )
                    next_state <= IDLE;
                else
                    next_state <= FNH;
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

// HandShake
assign rdy_Act_s0 = SYAGLB_ActRdAddrRdy & SYAGLB_WgtRdAddrRdy;
assign handshake_Act_s0 = rdy_Act_s0 & vld_Act_s0;
assign ena_Act_s0 = handshake_Act_s0 | ~vld_Act_s0;
assign vld_Act_s0 = state == WAITFNH;

// Reg Update
wire [$clog2(NUM_ROW*NUM_BANK)      : 0] SYA_Num_Row = (cfg_mod == 0 ? NUM_ROW*BANK_SQRT : cfg_mod == 1? NUM_ROW*BANK_SQRT/2 : NUM_ROW*BANK_SQRT*2);
wire [ADDR_WIDTH     -1 : 0] MaxCntActRd = ( cfg_chi*( cfg_nip / SYA_Num_Row ) +  SYA_Num_Row - 1 ) - 1; // 
wire INC_CntActRd = handshake_Act_s0;

wire [ADDR_WIDTH    -1 : 0] CntActRd;
counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u1_counter_CntActRd(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( CCUSYA_Rst         ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}} ),
    .INC       ( INC_CntActRd       ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {ADDR_WIDTH{1'b0}} ),
    .MAX_COUNT ( MaxCntActRd        ),
    .OVERFLOW  ( Overflow_CntActRd  ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntActRd           )
);
assign GLBSYA_ActRdAddr = CCUSYA_CfgActRdBaseAddr + CntActRd;
assign GLBSYA_ActRdAddrVld = handshake_Act_s0;

assign GLBSYA_WgtRdAddr = CCUSYA_CfgWgtRdBaseAddr + CntActRd;
assign GLBSYA_WgtRdAddrVld = handshake_Act_s0;


CPM_REG_E #( 2         ) CFG_MODE_REG0 ( clk, rst_n, cfg_en, CCUSYA_CfgMod, cfg_mod);
CPM_REG_E #( IDX_WIDTH ) CFG_MODE_REG1 ( clk, rst_n, cfg_en, CCUSYA_CfgNip, cfg_nip);
CPM_REG_E #( CHI_WIDTH ) CFG_MODE_REG2 ( clk, rst_n, cfg_en, CCUSYA_CfgChi, cfg_chi);

CPM_REG_E #( QNT_WIDTH ) CFG_MODE_REG3 ( clk, rst_n, cfg_en, CCUSYA_CfgScale, quant_scale);
CPM_REG_E #( ACT_WIDTH ) CFG_MODE_REG4 ( clk, rst_n, cfg_en, CCUSYA_CfgShift, quant_shift);
CPM_REG_E #( ACT_WIDTH ) CFG_MODE_REG5 ( clk, rst_n, cfg_en, CCUSYA_CfgZp   , quant_zerop);

CPM_REG #( NUM_BANK ) BANK_BIN_RDY_REG5 ( clk, rst_n, bank_din_rdy, bank_din_rdy_d);


genvar gen_i;
generate
  for( gen_i=0 ; gen_i < NUM_BANK; gen_i = gen_i+1 ) begin : BANK_BLOCK
  
    always @ ( posedge clk or negedge rst_n )begin
      if( ~rst_n )
        bank_ena_you[gen_i] <= 'd0;
      else if( bank_din_rdy[gen_i] )
        bank_ena_you[gen_i] <= {bank_ena_you[gen_i][NUM_COL-2:0], bank_din_vld[gen_i]};// right-shift (bank_din_vld&bank_din_rdy) to control when the left column output to the right column
    end

    always @ ( posedge clk or negedge rst_n )begin
      if( ~rst_n )
        bank_ena_xia[gen_i] <= 'd0;
      else if( bank_din_rdy[gen_i] )
        bank_ena_xia[gen_i] <= {bank_ena_xia[gen_i][NUM_ROW-2:0], bank_din_vld[gen_i]}; // 
    end

    always @ ( posedge clk or negedge rst_n )begin
    if( ~rst_n )
      bank_acc_cnt[gen_i] <= 'd0;
    else if( CCUSYA_Rst )
      bank_acc_cnt[gen_i] <= 'd0;
    else if( bank_din_vld[gen_i] && bank_din_rdy[gen_i] )
      bank_acc_cnt[gen_i] <= bank_acc_cnt[gen_i] + 'd1;
    end
  
    always @ ( posedge clk or negedge rst_n )begin
    if( ~rst_n )
      bank_out_ena[gen_i] <= 'd0;
    else if( CCUSYA_Rst )
      bank_out_ena[gen_i] <= 'd0;
    else if( (bank_acc_cnt[gen_i] == cfg_chi && |cfg_chi) && (bank_din_vld[gen_i] && bank_din_rdy[gen_i]) ) // bank_out_ena is valid after PE(0, 0) finishes the final channel input, do not care the name
      bank_out_ena[gen_i] <= {NUM_ROW{1'd1}};
    end
    
    always @ ( posedge clk or negedge rst_n )begin
    if( ~rst_n )
      bank_row_out_ena[gen_i] <= 'd0;
    else if( CCUSYA_Rst )
      bank_row_out_ena[gen_i] <= 'd0;
    else if( bank_din_rdy[gen_i] )
      bank_row_out_ena[gen_i] <= bank_row_out_ena[gen_i][NUM_ROW -1] ? {bank_row_out_ena[gen_i][NUM_ROW -2:0], bank_acc_out[gen_i]} & bank_row_out_ena[gen_i] : 
                                                                       {bank_row_out_ena[gen_i][NUM_ROW -2:0], bank_acc_out[gen_i]} | bank_row_out_ena[gen_i];// the each row is lighted one by one(acc is valid)
    end
    
    assign bank_din_ena_s[gen_i] = {NUM_ROW{bank_din_rdy_d[gen_i]}};
    
    assign bank_acc_run[gen_i] = bank_acc_cnt[gen_i] <= cfg_chi_cnt && bank_acc_rdy; // is ready (whether is blocked): the PEs ahead digonal do not consider bank_acc_rdy
    assign bank_acc_out[gen_i] = bank_acc_cnt[gen_i] % cfg_chi == 0; // Whether PE(0, 0) finishes all channels, when out is valid
    
    assign bank_din_run[gen_i] = bank_acc_cnt[gen_i] <= cfg_chi_cnt;
    assign bank_din_don[gen_i] = bank_acc_cnt[gen_i] >  cfg_chi_cnt; //Whether diagonal PEs finishes all channels，done 
    
    assign bank_din_rdy[gen_i] = bank_acc_rdy && &sync_din_rdy[gen_i] && bank_din_rdy_tmp[gen_i]; // back-pressure bank_din_rdy of two loads: Whether reshape is ready to fetch ofm & Whether next bank is ready to fetch activation and weight
    assign bank_act_rdy[gen_i] = bank_acc_rdy && &sync_din_rdy[gen_i] && bank_act_rdy_tmp[gen_i];
    assign bank_wgt_rdy[gen_i] = bank_acc_rdy && &sync_din_rdy[gen_i] && bank_wgt_rdy_tmp[gen_i];
end
endgenerate

always @ ( posedge clk or negedge rst_n )begin
if( ~rst_n )
  bank_acc_rdy <= 'd0;
else if( CCUSYA_Rst )
  bank_acc_rdy <= 'd0;
else if( cfg_en ) // whether acc can be done 
  bank_acc_rdy <= 'd1;
end

always @ (*)
begin
  bank_act_rdy_tmp[1] = bank_act_rdy_tmp[0];
  bank_act_rdy_tmp[2] = bank_act_rdy_tmp[0];
  bank_act_rdy_tmp[3] = bank_act_rdy_tmp[0];
end

always @ (*)
begin
  
  bank_wgt_rdy_tmp[1] = bank_wgt_rdy_tmp[0];
  bank_wgt_rdy_tmp[2] = bank_wgt_rdy_tmp[0];
  bank_wgt_rdy_tmp[3] = bank_wgt_rdy_tmp[0];
end

always @ (*)
begin
  bank_act_rdy_tmp[0] = bank_din_don[0] ? 'd1 : GLBSYA_WgtRdDatVld;
  bank_wgt_rdy_tmp[0] = bank_din_don[0] ? 'd1 : GLBSYA_ActRdDatVld;
end

always @ (*)
begin
  if( cfg_mod == 'd0 )
    bank_din_rdy_tmp[0] = bank_din_don[0] ? bank_din_rdy_tmp[1] && bank_din_rdy_tmp[2] : GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld; // Whether bank is ready to receive act and wgt: After act and wgt is transferred over diagonal PEs, & down bank is ready & right bank is ready : before diagonal, directly input act and wgt
  else
    bank_din_rdy_tmp[0] = bank_din_don[0] ? bank_din_rdy_tmp[1] : GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld;
end

always @ (*)
begin
  if( cfg_mod == 'd0 )
    bank_din_rdy_tmp[1] = bank_din_don[1] ? bank_din_rdy_tmp[3] : GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld;
  else if( cfg_mod == 'd1 )
    bank_din_rdy_tmp[1] = bank_din_don[0] ? (bank_din_don[1] ? bank_din_rdy_tmp[2] : GLBSYA_WgtRdDatVld) : GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld;
  else
    bank_din_rdy_tmp[1] = bank_din_don[0] ? (bank_din_don[1] ? bank_din_rdy_tmp[2] : GLBSYA_ActRdDatVld) : GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld;
end

always @ (*)
begin
  if( cfg_mod == 'd0 )
    bank_din_rdy_tmp[2] = bank_din_don[2] ? bank_din_rdy_tmp[3] : GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld;
  else if( cfg_mod == 'd1 )
    bank_din_rdy_tmp[2] = bank_din_don[0] ? (bank_din_don[2] ? bank_din_rdy_tmp[3] : GLBSYA_WgtRdDatVld) : GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld;
  else
    bank_din_rdy_tmp[2] = bank_din_don[0] ? (bank_din_don[2] ? bank_din_rdy_tmp[3] : GLBSYA_ActRdDatVld) : GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld;
end

always @ (*)
begin
  if( cfg_mod == 'd0 )
    bank_din_rdy_tmp[3] = bank_din_don[1] || (GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld);
  else if( cfg_mod == 'd1 )
    bank_din_rdy_tmp[3] = bank_din_don[0] ? (bank_din_don[3] ? 'd1 : GLBSYA_WgtRdDatVld) : GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld;
  else
    bank_din_rdy_tmp[3] = bank_din_don[0] ? (bank_din_don[3] ? 'd1 : GLBSYA_ActRdDatVld) : GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld;
end

always @ (*)
begin
    bank_din_act[0] = bank_pkg_act[0];
    bank_din_wgt[0] = GLBSYA_WgtRdDat;
    bank_din_rst[0] = bank_out_ena[0][0];
    bank_din_vld[0] = GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld && bank_acc_run[0]; 
    
    bank_din_act[1] = cfg_mod == 'd2 ? bank_pkg_act[1] : bank_out_act[0];
    bank_din_wgt[1] = cfg_mod == 'd2 ? bank_out_wgt[0] : bank_pkg_wgt[1];
    bank_din_rst[1] = cfg_mod == 'd2 ? bank_xia_rst[0] : bank_you_rst[0];
    bank_din_vld[1] =(cfg_mod == 'd2 ? bank_ena_xia[0][NUM_COL -1] && GLBSYA_ActRdDatVld: bank_ena_you[0][NUM_COL -1] && GLBSYA_WgtRdDatVld ) && bank_acc_run[1]; // final row
    
end

always @ (*)
begin
    bank_din_act[2] = cfg_mod == 'd1 ? bank_out_act[1] : bank_pkg_act[2];
    bank_din_wgt[2] = cfg_mod == 'd0 ? bank_out_wgt[0] : cfg_mod == 'd1 ? bank_pkg_wgt[2] : bank_out_wgt[1];
    bank_din_rst[2] = cfg_mod == 'd0 ? bank_xia_rst[0] : cfg_mod == 'd1 ? bank_you_rst[1] : bank_xia_rst[1];
    bank_din_vld[2] =(cfg_mod == 'd0 ? bank_ena_xia[0][NUM_COL -1] && GLBSYA_ActRdDatVld: cfg_mod == 'd1 ? bank_ena_you[1][NUM_COL -1] && GLBSYA_WgtRdDatVld : bank_ena_xia[1][NUM_COL -1] && GLBSYA_ActRdDatVld ) && bank_acc_run[2];

    bank_din_act[3] = cfg_mod == 'd2 ? bank_pkg_act[3] : bank_out_act[2];
    bank_din_wgt[3] = cfg_mod == 'd0 ? bank_out_wgt[1] : cfg_mod == 'd1 ? bank_pkg_wgt[3] : bank_out_wgt[2];
    bank_din_rst[3] = cfg_mod == 'd0 ? bank_xia_rst[1] : cfg_mod == 'd1 ? bank_you_rst[2] : bank_xia_rst[2];
    bank_din_vld[3] =(cfg_mod == 'd0 ? bank_ena_xia[1][NUM_COL -1] && (bank_din_don[1] ? bank_din_rdy_tmp[3] : GLBSYA_ActRdDatVld && GLBSYA_WgtRdDatVld) : 
                      cfg_mod == 'd1 ? bank_ena_you[2][NUM_COL -1] && GLBSYA_WgtRdDatVld: bank_ena_xia[2][NUM_COL -1] && GLBSYA_ActRdDatVld ) && bank_acc_run[3];
end

//=====================================================================================================================
// Logic Design :
//=====================================================================================================================

    PE_BANK #(
      .NUM_ROW             ( NUM_ROW            ),
      .NUM_COL             ( NUM_COL            ),
      .QNT_WIDTH           ( QNT_WIDTH          ),
      .ACT_WIDTH           ( ACT_WIDTH          ),
      .WGT_WIDTH           ( WGT_WIDTH          ),
      .PSUM_WIDTH          ( ACC_WIDTH          ),
      .FM_WIDTH            ( ACT_WIDTH          )
    ) PE_BANK_U_I [NUM_BANK -1:0] (               

      .clk                 ( clk                ),
      .rst_n               ( rst_n              ),
      
      .rst_reset           ( rst_reset          ),
                           
      .quant_scale         ( quant_scale        ),
      .quant_shift         ( quant_shift        ),
      .quant_zero_point    ( quant_zerop        ),
                           
      .in_vld_left         ( bank_din_vld       ),
      .in_rdy_left         ( bank_din_rdy       ),
      
      .out_fm              ( bank_out_fm        ),
                           
      .in_act_left         ( bank_din_act       ),
      .out_act_right       ( bank_out_act       ),
                           
      .in_wgt_above        ( bank_din_wgt       ),
      .out_wgt_below       ( bank_out_wgt       ),
                           
      .in_acc_reset_left   ( bank_din_rst       ),
      .out_acc_reset_right ( bank_you_rst       ),
      .out_acc_reset_below ( bank_xia_rst       )
    );

    SYNC_SHAPE #(
      .ACT_WIDTH           ( ACT_WIDTH          ),
      .SRAM_WIDTH          ( SRAM_WIDTH         ),
      .NUM_BANK            ( NUM_BANK           ),
      .NUM_ROW             ( NUM_ROW            ),
      .NUM_OUT             ( NUM_OUT            )
    ) SYNC_SHAPE_U (               

      .clk                 ( clk                ),
      .rst_n               ( rst_n              ),
                           
      .din_data            ( sync_din           ),
      .din_data_vld        ( sync_din_vld       ),
      .din_data_rdy        ( sync_din_rdy       ),
                           
      .out_data            ( sync_out           ),
      .out_data_vld        ( sync_out_vld       ),
      .out_data_rdy        ( sync_out_rdy       )
    );

assign SYACCU_CfgRdy = cfg_rdy && pe_idle;
assign SYAGLB_ActRdDatRdy = &bank_din_rdy;
assign SYAGLB_WgtRdDatRdy = &bank_din_rdy;
assign SYAGLB_OfmWrDatVld = sync_out_vld;
assign SYAGLB_OfmWrDat = sync_out;

wire [$clog2(NUM_COL*NUM_BANK)      : 0] SYA_Num_Col = (cfg_mod == 0 ? NUM_ROW*BANK_SQRT : cfg_mod == 1? NUM_ROW*BANK_SQRT*2 : NUM_ROW*BANK_SQRT/2);
wire [ADDR_WIDTH     -1 : 0] MaxCntOfmWr = cfg_nip*SYA_Num_Col - 1; // 
assign handshake_Ofm = sync_out_vld & sync_out_rdy;
wire [ADDR_WIDTH    -1 : 0] CntOfmWr;
counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u1_counter_CntOfmWr(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( CCUSYA_Rst         ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}} ),
    .INC       ( handshake_Ofm      ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {ADDR_WIDTH{1'b0}} ),
    .MAX_COUNT ( MaxCntOfmWr        ),
    .OVERFLOW  ( Overflow_CntOfmWr  ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntOfmWr           )
);
assign SYAGLB_OfmWrAddr = CCUSYA_CfgOfmWrBaseAddr + CntOfmWr;

endmodule