// This is a simple example.
// You can make a your own header file and set its path to settings.
// (Preferences > Package Settings > Verilog Gadget > Settings - User)
//
//      "header": "Packages/Verilog Gadget/template/verilog_header.v"CRD_MAXDIM
//
// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : zhouchch@pku.edu.cn
// File   : CCU.v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------
`define CEIL(a, b) ( \
 (a % b)? (a / b + 1) : (a / b) \
)
module KNN #(
    parameter KNNISA_WIDTH      = 128*2,
    parameter SRAM_WIDTH        = 256,
    parameter SRAM_MAXPARA      = 1,
    parameter IDX_WIDTH         = 16,
    parameter MAP_WIDTH         = 5,
    parameter CRD_WIDTH         = 8,
    parameter NUM_SORT_CORE     = 8,
    parameter KNNMON_WIDTH      = 128,
    parameter CRDRDWIDTH        = SRAM_WIDTH*SRAM_MAXPARA,
    parameter CRD_MAXDIM        = CRDRDWIDTH/CRD_WIDTH, // 64
    parameter DISTSQR_WIDTH     = CRD_WIDTH*2 + $clog2(CRD_MAXDIM)
    )(
    input                               clk                 ,
    input                               rst_n               ,

    // Configure
    input                               CCUKNN_CfgVld       ,
    output                              KNNCCU_CfgRdy       ,
    input  [KNNISA_WIDTH        -1 : 0] CCUKNN_CfgInfo      ,

    // Fetch Crd
    output [IDX_WIDTH           -1 : 0] KNNGLB_CrdRdAddr    ,   
    output                              KNNGLB_CrdRdAddrVld , 
    input                               GLBKNN_CrdRdAddrRdy ,
    input  [CRDRDWIDTH          -1 : 0] GLBKNN_CrdRdDat     ,        
    input                               GLBKNN_CrdRdDatVld  ,     
    output                              KNNGLB_CrdRdDatRdy  ,

    // Fetch Mask of Output Points
    output [IDX_WIDTH           -1 : 0] KNNGLB_MaskRdAddr   ,
    output                              KNNGLB_MaskRdAddrVld,
    input                               GLBKNN_MaskRdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0] GLBKNN_MaskRdDat    ,    
    input                               GLBKNN_MaskRdDatVld ,  // ???????????????????? not used  
    output                              KNNGLB_MaskRdDatRdy ,   

    // Output Map of KNN
    output [IDX_WIDTH           -1 : 0] KNNGLB_MapWrAddr    ,
    output [SRAM_WIDTH          -1 : 0] KNNGLB_MapWrDat     ,   
    output                              KNNGLB_MapWrDatVld  ,     
    input                               GLBKNN_MapWrDatRdy  ,

    output [IDX_WIDTH           -1 : 0] KNNGLB_IdxMaskRdAddr   ,
    output                              KNNGLB_IdxMaskRdAddrVld,
    input                               GLBKNN_IdxMaskRdAddrRdy,// ???????????????????? not used  
    input  [SRAM_WIDTH          -1 : 0] GLBKNN_IdxMaskRdDat    ,    
    input                               GLBKNN_IdxMaskRdDatVld ,    
    output                              KNNGLB_IdxMaskRdDatRdy ,  

    output [KNNMON_WIDTH        -1 : 0] KNNMON_Dat                
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE   = 3'b000;
localparam CP     = 3'b001;
localparam LP     = 3'b010;
localparam WAITFNH= 3'b011;
localparam OUT    = 3'b100;

localparam SORT_LEN         = 2**MAP_WIDTH;
localparam NUM_SRAMWORD_MAP = (IDX_WIDTH*SORT_LEN)%SRAM_WIDTH == 0? (IDX_WIDTH*SORT_LEN)/SRAM_WIDTH : (IDX_WIDTH*SORT_LEN)/SRAM_WIDTH + 1;
localparam MASK_ADDR_WIDTH  = IDX_WIDTH - $clog2(SRAM_WIDTH);

parameter CRDBYTE_WIDTH     = 8;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

wire[IDX_WIDTH          -1 : 0] CntCpCrdRdAddr;  
reg [IDX_WIDTH          -1 : 0] CntCpCrdRdAddr_s1;  
wire                            CntCpCrdRdAddrLast;

wire                            CntLopCrdRdAddrLast;
reg                             CntCpCrdRdAddrLast_s1;
reg                             CntCpCrdRdAddrLast_s2;
reg                             CntLopCrdRdAddrLast_s1;
reg                             CntLopCrdRdAddrLast_s2;
wire [IDX_WIDTH         -1 : 0] CntLopCrdRdAddr;
reg  [IDX_WIDTH         -1 : 0] CntLopCrdRdAddr_s1;
wire                            pisoMapOutLast;
wire                            pisoMapInRdy;

wire                           INC_CntCpCrdRdAddr;
wire                           INC_CntLopCrdRdAddr;

wire                            rdy_s0;
wire                            rdy_s1;
wire                            rdy_s2;
wire                            vld_s0;
wire                            vld_s1;
wire                            vld_s2;
wire                            handshake_s0;
wire                            handshake_s1;
wire                            handshake_s2;
wire                            ena_s0;
wire                            ena_s1;
wire                            ena_s2;

wire  [NUM_SORT_CORE    -1 : 0] KNNINS_LopVld;
wire  [NUM_SORT_CORE    -1 : 0] INSKNN_LopRdy;
wire  [NUM_SORT_CORE    -1 : 0] INSKNN_MapVld;
wire  [NUM_SORT_CORE    -1 : 0] KNNINS_MapRdy;

wire [NUM_SORT_CORE     -1 : 0][NUM_SRAMWORD_MAP   -1 : 0][(SRAM_WIDTH + IDX_WIDTH) + 1 -1 : 0] pisoMapInDat;
wire [CRDRDWIDTH        -1 : 0] crdRdDat_s1;
wire [SRAM_WIDTH        -1 : 0] MaskRdDat_s1;
wire                            pisoLopCrdInRdy  ;
wire [CRDRDWIDTH        -1 : 0] pisoLopCrdOutDat ;
wire                            pisoLopCrdOutVld ;
wire                            pisoLopCrdOutLast;
wire                            pisoLopCrdOutRdy ;

wire [CRDBYTE_WIDTH     -1 : 0] MaxCntLopCrdByte;
wire [CRDBYTE_WIDTH     -1 : 0] CntLopCrdByte;
wire [CRDBYTE_WIDTH     -1 : 0] MaxCntCpCrdByte;
wire [CRDBYTE_WIDTH     -1 : 0] CntCpCrdByteTotal;
wire                            req_Mask;
wire                            INC_CntMaskAddr;
wire                            INC_CntIdxMaskAddr;
wire [MASK_ADDR_WIDTH   -1 : 0] CntMaskAddr;
wire [IDX_WIDTH         -1 : 0] CntIdxMaskAddr;
wire [IDX_WIDTH         -1 : 0] CCUKNN_CfgNip       ;
wire [(MAP_WIDTH + 1)   -1 : 0] CCUKNN_CfgK         ; 
wire [8                 -1 : 0] CCUKNN_CfgK_tmp     ; 
wire [8                 -1 : 0] CCUKNN_CfgCrdNumBankPar;
wire [8                 -1 : 0] CCUKNN_CfgCrdDim    ; 
wire [IDX_WIDTH         -1 : 0] CCUKNN_CfgCrdRdAddr ;
wire [IDX_WIDTH         -1 : 0] CCUKNN_CfgMaskRdAddr;
wire [IDX_WIDTH         -1 : 0] CCUKNN_CfgMapWrAddr ;
wire [IDX_WIDTH         -1 : 0] CCUKNN_CfgIdxMaskRdAddr ;
wire                            CCUKNN_CfgStop;

wire [$clog2(CRDRDWIDTH) + 1                        -1 : 0] bwcCpCrdInpBw;
wire [$clog2(CRD_WIDTH*CRD_MAXDIM*NUM_SORT_CORE) + 1-1 : 0] bwcCpCrdOutBw;
wire [$clog2(CRD_WIDTH*CRD_MAXDIM*NUM_SORT_CORE) + 1-1 : 0] bwcCnt;
wire [CRD_WIDTH*CRD_MAXDIM*NUM_SORT_CORE            -1 : 0] bwcCpCrdOutDat;
wire                                                        bwcCpCrdInRdy;
wire                                                        bwcCpCrdNfull;
wire                                                        bwcCpCrdOutVld;
wire                                                        bwcCpCrdOutLast;
wire                                                        bwcCpCrdOutRdy;
wire                                                        bwcCpCrdInVld;
integer                                     i;
wire                                        pisoMapOutVld;
genvar                                      gv_core;
genvar                                      gv_wd;
wire [SRAM_WIDTH/(IDX_WIDTH + 1)    -1 : 0][(IDX_WIDTH + 1) -1 : 0] IdxMaskRdDat_s1;
wire [$clog2(CRDRDWIDTH) + 1        -1 : 0] pisoLopCrdOutBw;
wire [$clog2(CRDRDWIDTH) + 1        -1 : 0] pisoLopCrdInpBw;
wire [SRAM_WIDTH + IDX_WIDTH + 1    -1 : 0] pisoMapOutDat;
wire [IDX_WIDTH                     -1 : 0] CntMapWr;
wire [IDX_WIDTH                     -1 : 0] MaxCntMapWr;

//=====================================================================================================================
// Logic Design: ISA Decode
//=====================================================================================================================
assign {
    CCUKNN_CfgIdxMaskRdAddr,// 16
    CCUKNN_CfgMapWrAddr ,   // 16
    CCUKNN_CfgMaskRdAddr,   // 16
    CCUKNN_CfgCrdRdAddr ,   // 16
    CCUKNN_CfgCrdNumBankPar,// 8
    CCUKNN_CfgCrdDim    ,   // 8
    CCUKNN_CfgK_tmp     ,   // 8
    CCUKNN_CfgNip           // 16
} = CCUKNN_CfgInfo[KNNISA_WIDTH -1 : 16];
assign CCUKNN_CfgK = CCUKNN_CfgK_tmp;
assign CCUKNN_CfgStop = CCUKNN_CfgInfo[9]; //[8]==1: Rst, [9]==1: Stop
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================
reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]next_state;
reg [ 3 -1:0 ]state_s1;
reg [ 3 -1:0 ]next_state_s1;
reg [ 3 -1:0 ]state_ds1;

always @(*) begin
    case ( state )
        IDLE :  if(KNNCCU_CfgRdy & (CCUKNN_CfgVld & !CCUKNN_CfgStop) )// 
                    next_state <= CP; //
                else
                    next_state <= IDLE;

        CP:     if(CCUKNN_CfgVld)
                    next_state <= IDLE;
                else if( bwcCpCrdNfull )
                    next_state <= LP;
                else
                    next_state <= CP;

        LP:     if(CCUKNN_CfgVld)
                    next_state <= IDLE;
                else if ( CntLopCrdRdAddrLast & KNNGLB_CrdRdAddrVld & (state == IDLE? 0 : GLBKNN_CrdRdAddrRdy) ) begin
                    if ( CntCpCrdRdAddrLast )
                        next_state <= WAITFNH;
                    else //
                        next_state <= CP;
                end else
                    next_state <= LP;
                    
        WAITFNH:if(CCUKNN_CfgVld)
                    next_state <= IDLE;
                else if(pisoMapOutLast & pisoMapOutVld & (state == IDLE? 0 : GLBKNN_MapWrDatRdy) )
                    next_state <= IDLE;
                else
                    next_state <= WAITFNH;

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

assign KNNCCU_CfgRdy = state==IDLE;

//=====================================================================================================================
// Logic Design: s0-Out Cnt(for Addr)
//=====================================================================================================================
assign INC_CntCpCrdRdAddr   = state == CP & ena_s0 & !CntCpCrdRdAddrLast;
assign INC_CntLopCrdRdAddr  = state == LP & ena_s0;
assign INC_CntIdxMaskAddr   = state == LP & ena_s0;
assign INC_CntMaskAddr      = handshake_s0 & req_Mask;

assign req_Mask = SRAM_WIDTH*CntMaskAddr                    <= NUM_SORT_CORE*CntCpCrdRdAddr;
assign req_Idx  = (SRAM_WIDTH/(IDX_WIDTH+1))*CntIdxMaskAddr <= NUM_SORT_CORE*CntCpCrdRdAddr;

// HandShake
assign rdy_s0       = (state == IDLE? 0 : GLBKNN_CrdRdAddrRdy) & (state == IDLE? 0 : GLBKNN_MaskRdAddrRdy); // Two loads
assign vld_s0       = state == CP | state == LP;
assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0       = handshake_s0 | ~vld_s0;

wire [IDX_WIDTH     -1 : 0] MaxCntCrdRdAddr = `CEIL(CRD_WIDTH*CCUKNN_CfgCrdDim*CCUKNN_CfgNip, SRAM_WIDTH*CCUKNN_CfgCrdNumBankPar) -1;
counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u0_counter_CntCp(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state == IDLE  ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}),
    .INC       ( INC_CntCpCrdRdAddr),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}),
    .MAX_COUNT (  MaxCntCrdRdAddr),
    .OVERFLOW  ( CntCpCrdRdAddrLast),
    .UNDERFLOW (                ),
    .COUNT     ( CntCpCrdRdAddr )
);

wire [MASK_ADDR_WIDTH   -1 : 0 ] MaxCntMaskAddr = `CEIL(CCUKNN_CfgNip, SRAM_WIDTH) -1;

counter#(
    .COUNT_WIDTH ( MASK_ADDR_WIDTH )
)u0_counter_CntMaskAddr(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state == IDLE  ),
    .DEFAULT   ( {MASK_ADDR_WIDTH{1'b0}}),
    .INC       ( INC_CntMaskAddr),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {MASK_ADDR_WIDTH{1'b0}}),
    .MAX_COUNT (  MaxCntMaskAddr),
    .OVERFLOW  (                ),
    .UNDERFLOW (                ),
    .COUNT     ( CntMaskAddr    )
);

counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_CntCrdRdAddr(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CntCpCrdRdAddr | state == IDLE ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
    .INC       ( INC_CntLopCrdRdAddr),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
    .MAX_COUNT ( MaxCntCrdRdAddr    ),
    .OVERFLOW  ( CntLopCrdRdAddrLast),
    .UNDERFLOW (                    ),
    .COUNT     ( CntLopCrdRdAddr    )
);

counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_CntIdxMaskAddr(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CntCpCrdRdAddr | state == IDLE ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
    .INC       ( INC_CntIdxMaskAddr ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
    .MAX_COUNT ( {IDX_WIDTH{1'b1}}  ),
    .OVERFLOW  (                    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntIdxMaskAddr     ) // Similar to Mask
);

//=====================================================================================================================
// Logic Design: s1-Out Crd
//=====================================================================================================================
// Combinational Logic
assign KNNGLB_CrdRdAddr     = state == IDLE? 0 : CCUKNN_CfgCrdRdAddr + (state == CP ? CntCpCrdRdAddr : CntLopCrdRdAddr);
assign KNNGLB_CrdRdAddrVld  = state == IDLE? 0 : vld_s0 & (req_Mask? (state == IDLE? 0 : GLBKNN_MaskRdAddrRdy) : 1'b1);
assign KNNGLB_MaskRdAddr    = state == IDLE? 0 : CCUKNN_CfgMaskRdAddr + CntMaskAddr;
assign KNNGLB_MaskRdAddrVld = state == IDLE? 0 : vld_s0 & ((state == IDLE? 0 : GLBKNN_CrdRdAddrRdy) & req_Mask);

assign KNNGLB_IdxMaskRdAddr     = state == IDLE? 0 : CCUKNN_CfgIdxMaskRdAddr + CntIdxMaskAddr;
assign KNNGLB_IdxMaskRdAddrVld  = state == IDLE? 0 : vld_s0 & (req_Idx & (state == IDLE? 0 : GLBKNN_MaskRdAddrRdy) & (state == IDLE? 0 : GLBKNN_CrdRdAddrRdy));

always @(*) begin
    case ( state_s1 )
        CP:     if( bwcCpCrdOutVld & bwcCpCrdOutRdy ) // after CpCrd being output
                    next_state_s1 <= LP;
                else
                    next_state_s1 <= CP;

        LP:     if (pisoLopCrdOutVld & pisoLopCrdOutLast & pisoLopCrdOutRdy) // Last LopCrd 
                    next_state_s1 <= OUT;
                else
                    next_state_s1 <= LP;
        OUT:    if( handshake_s2 ) // Map to PISO
                    next_state_s1 <= CP;
                else 
                    next_state_s1 <= OUT;

        default: next_state_s1 <= CP;
    endcase
end

// HandShake
assign rdy_s1       = (state_s1 == CP & bwcCpCrdInRdy & state_ds1 == CP) | (state_s1 == LP & pisoLopCrdInRdy & state_ds1 == LP);
assign vld_s1       = state == IDLE? 0 : GLBKNN_CrdRdDatVld;
assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1       = handshake_s1 | ~vld_s1;

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {CntLopCrdRdAddr_s1, CntLopCrdRdAddrLast_s1, CntCpCrdRdAddr_s1, CntCpCrdRdAddrLast_s1} <= 0;
    end else if ( state == IDLE ) begin
        {CntLopCrdRdAddr_s1, CntLopCrdRdAddrLast_s1, CntCpCrdRdAddr_s1, CntCpCrdRdAddrLast_s1} <= 0;
    end else if(handshake_s0) begin
        if( state == CP ) begin
        CntCpCrdRdAddr_s1       <= CntCpCrdRdAddr;
        CntCpCrdRdAddrLast_s1   <= CntCpCrdRdAddrLast;
        end else if(state == LP) begin
            CntLopCrdRdAddr_s1      <= CntLopCrdRdAddr;
            CntLopCrdRdAddrLast_s1  <= CntLopCrdRdAddrLast;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state_ds1 <= 0;
    end else if ( state == IDLE ) begin
        state_ds1 <= 0;
    end else if(handshake_s0) begin
        state_ds1 <= state;
    end
end

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state_s1 <= CP;
    end else if( state == IDLE ) begin
        state_s1 <= CP;
    end else begin
        state_s1 <= next_state_s1;
    end
end
//========================================================================================================== ===========
// Logic Design: S2 (No cache)
//=====================================================================================================================
// Combinational Logic
assign crdRdDat_s1      = state == IDLE? 0 : GLBKNN_CrdRdDat;
assign MaskRdDat_s1     = state == IDLE? 0 : GLBKNN_MaskRdDat;
assign IdxMaskRdDat_s1  = state == IDLE? 0 : GLBKNN_IdxMaskRdDat;

assign KNNGLB_CrdRdDatRdy       = state == IDLE? 1 : rdy_s1;
assign KNNGLB_MaskRdDatRdy      = state == IDLE? 1 : rdy_s1;
assign KNNGLB_IdxMaskRdDatRdy   = state == IDLE? 1 : rdy_s1;

//---------------------------------------------------------------------------------------------------------------------
// Crd Width Conversion
//---------------------------------------------------------------------------------------------------------------------
// LopCrd 
assign pisoLopCrdInpBw = SRAM_WIDTH*CCUKNN_CfgCrdNumBankPar;
assign pisoLopCrdOutBw = CRD_WIDTH*CCUKNN_CfgCrdDim;

PISO_NOCACHE_FLEX#(
    .DATA_IN_WIDTH   ( CRDRDWIDTH )
)u_PISO_Crd(
    .CLK       ( clk                ),
    .RST_N     ( rst_n              ),
    .RESET     ( state == IDLE      ),
    .INP_BW    ( pisoLopCrdInpBw    ),
    .OUT_BW    ( pisoLopCrdOutBw    ),
    .IN_VLD    ( state_s1 == LP & vld_s1 & state_ds1 == LP),
    .IN_LAST   ( CntLopCrdRdAddrLast_s1 ),
    .IN_DAT    ( crdRdDat_s1       ),
    .IN_RDY    ( pisoLopCrdInRdy   ),
    .OUT_DAT   ( pisoLopCrdOutDat  ),
    .OUT_VLD   ( pisoLopCrdOutVld  ),
    .OUT_LAST  ( pisoLopCrdOutLast ),
    .OUT_RDY   ( pisoLopCrdOutRdy  )
);
assign pisoLopCrdOutRdy = state_s1 == LP & (&INSKNN_LopRdy);

assign MaxCntLopCrdByte = (SRAM_WIDTH*CCUKNN_CfgCrdNumBankPar)/(CRD_WIDTH*CCUKNN_CfgCrdDim) - 1;
counter#(
    .COUNT_WIDTH ( CRDBYTE_WIDTH )
)u1_counter_LopCrdByte(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CntLopCrdRdAddr | state == IDLE ),
    .DEFAULT   ( {CRDBYTE_WIDTH{1'b0}} ),
    .INC       ( pisoLopCrdOutVld & pisoLopCrdOutRdy ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {CRDBYTE_WIDTH{1'b0}} ),
    .MAX_COUNT ( MaxCntLopCrdByte   ),
    .OVERFLOW  (                    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntLopCrdByte      )
);

//---------------------------------------------------------------------------------------------------------------------
// CpCrd 
assign bwcCpCrdInpBw = SRAM_WIDTH*CCUKNN_CfgCrdNumBankPar;
assign bwcCpCrdOutBw = CRD_WIDTH*CCUKNN_CfgCrdDim*NUM_SORT_CORE;
assign bwcCpCrdInVld = state_s1 == CP & vld_s1 & state_ds1 == CP;
assign bwcCpCrdNfull = bwcCpCrdOutBw >= bwcCpCrdInpBw?
                        (bwcCpCrdInVld & bwcCpCrdInRdy) & (bwcCnt == bwcCpCrdOutBw - bwcCpCrdInpBw) // NearFull: Next clk is full
                        : (bwcCpCrdInVld & bwcCpCrdInRdy) | bwcCnt >= bwcCpCrdOutBw; // one word is enough
BWC #( // Bit Width Conversion
    .DATA_IN_WIDTH   ( CRDRDWIDTH ), // 256bit*4=1024bit
    .DATA_OUT_WIDTH  ( CRD_WIDTH*CRD_MAXDIM*NUM_SORT_CORE ) // 8bit*64*8=4096bit
)u_BWC_CpCrd(
    .CLK       ( clk            ),
    .RST_N     ( rst_n          ),
    .RESET     ( state == IDLE  ),
    .INP_BW    ( bwcCpCrdInpBw  ),
    .OUT_BW    ( bwcCpCrdOutBw  ),
    .IN_VLD    ( bwcCpCrdInVld  ),
    .IN_LAST   ( 1'b0           ),
    .IN_DAT    ( crdRdDat_s1    ),
    .IN_RDY    ( bwcCpCrdInRdy  ),
    .IN_NFULL  (                ), 
    .OUT_DAT   ( bwcCpCrdOutDat ),
    .OUT_VLD   ( bwcCpCrdOutVld ),
    .OUT_LAST  (                ),
    .OUT_RDY   ( bwcCpCrdOutRdy ),
    .OUT_CNT   ( bwcCnt         )
);
assign bwcCpCrdOutRdy = state_s1 == CP & ena_s2; // ????? New Add

assign MaxCntCpCrdByte = 2**CRDBYTE_WIDTH -1;
counter#(
    .COUNT_WIDTH ( CRDBYTE_WIDTH )
)u1_counter_CpCrdByte(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( state == IDLE      ),
    .DEFAULT   ( {CRDBYTE_WIDTH{1'b0}} ),
    .INC       ( bwcCpCrdOutVld & bwcCpCrdOutRdy ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {CRDBYTE_WIDTH{1'b0}} ),
    .MAX_COUNT ( MaxCntCpCrdByte   ),
    .OVERFLOW  (                    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntCpCrdByteTotal      )
);

//---------------------------------------------------------------------------------------------------------------------
// HandShake
assign rdy_s2       = pisoMapInRdy;
assign vld_s2       = state_s1 == OUT;
assign handshake_s2 = rdy_s2 & vld_s2;
assign ena_s2       = handshake_s2 | ~vld_s2;

generate
    for(gv_core=0; gv_core<NUM_SORT_CORE; gv_core=gv_core+1) begin: GEN_INS

        wire [CRD_WIDTH*CRD_MAXDIM  -1 : 0] LopCrd_s1;
        wire [IDX_WIDTH             -1 : 0] LopIdx_s1;
        wire [IDX_WIDTH             -1 : 0] CpIdx_s1;
        wire [DISTSQR_WIDTH         -1 : 0] LopDist_s1;
        reg  [IDX_WIDTH             -1 : 0] CpIdx_s2;
        reg  [CRD_WIDTH*CRD_MAXDIM  -1 : 0] CpCrd_s2;
        reg                                 CpVld_s2;
        wire [NUM_SRAMWORD_MAP      -1 : 0][SRAM_WIDTH -1 : 0] INSKNN_Map;

        // GEN Block Combinational Logic-FromS1
        assign CpIdx_s1         = NUM_SORT_CORE*CntCpCrdByteTotal + gv_core;
        assign LopIdx_s1        = (pisoLopCrdInpBw*CntLopCrdRdAddr_s1 + pisoLopCrdOutBw*CntLopCrdByte)/pisoLopCrdOutBw;
        assign LopCrd_s1        = pisoLopCrdOutDat;
        assign KNNINS_LopVld[gv_core] = state_s1 == LP & (pisoLopCrdOutVld & pisoLopCrdOutRdy);
        
        EDC#(
            .CRD_WIDTH ( CRD_WIDTH  ),
            .CRD_DIM   ( CRD_MAXDIM )
        )u_EDC(
            .Crd0      ( CpVld_s2? CpCrd_s2 : {CRD_WIDTH{1'b0}} ), // Cp
            .Crd1      ( LopCrd_s1  ), // Np
            .DistSqr   ( LopDist_s1 )
        );

        // GEN Block Reg Update-S1toS2
        INS#(
            .SORT_LEN_WIDTH     ( MAP_WIDTH     ),
            .IDX_WIDTH          ( IDX_WIDTH     ),
            .DATA_WIDTH         ( DISTSQR_WIDTH )
        )u_INS(
            .clk                 ( clk                 ),
            .rst_n               ( rst_n               ),
            .reset               ( state == IDLE       ),
            .KNNINS_CfgK         ( CCUKNN_CfgK         ),
            .KNNINS_LopLast      ( pisoLopCrdOutLast & CpVld_s2  ),
            .KNNINS_Lop          ( {LopDist_s1, LopIdx_s1}),
            .KNNINS_LopVld       ( KNNINS_LopVld[gv_core] & CpVld_s2),
            .INSKNN_LopRdy       ( INSKNN_LopRdy[gv_core]),
            .INSKNN_Map          ( INSKNN_Map           ),
            .INSKNN_MapVld       ( INSKNN_MapVld[gv_core]),
            .KNNINS_MapRdy       ( KNNINS_MapRdy[gv_core])
        );
        
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                CpCrd_s2 <= 0;
                CpIdx_s2 <= 0;
                CpVld_s2 <= 1;
            end else if ( state == IDLE ) begin
                CpCrd_s2 <= 0;
                CpIdx_s2 <= 0;
                CpVld_s2 <= 1;
            end else if (ena_s2) begin
                if(state_s1 == CP) begin // Update Cp
            // end else if(bwcCpCrdOutVld & bwcCpCrdOutRdy) begin
                    for(i=0; i<CRD_WIDTH*CRD_MAXDIM; i=i+1) begin
                        if (i<CRD_WIDTH*CCUKNN_CfgCrdDim)
                            CpCrd_s2[i] <= bwcCpCrdOutDat[(CRD_WIDTH*CCUKNN_CfgCrdDim)*gv_core + i];
                        else
                            CpCrd_s2[i] <= 1'b0;
                    end
                    CpIdx_s2 <= CpIdx_s1;
                    CpVld_s2 <= MaskRdDat_s1[CpIdx_s1 % SRAM_WIDTH];
                end
            end 
        end

        // GEN Block Combinational Logic-ToS3
        for (gv_wd=0; gv_wd < NUM_SRAMWORD_MAP; gv_wd=gv_wd+1) begin: GEN_MAPSRAMWORD
            wire [IDX_WIDTH     -1 : 0] MapWrAddr_tmp;
            assign MapWrAddr_tmp = CCUKNN_CfgMapWrAddr + NUM_SRAMWORD_MAP*CpIdx_s2 + gv_wd;
            assign pisoMapInDat[gv_core][gv_wd] = {INSKNN_Map[gv_wd], MapWrAddr_tmp, CpVld_s2};
        end
        assign KNNINS_MapRdy[gv_core]   = handshake_s2;

    end
endgenerate

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {CntLopCrdRdAddrLast_s2, CntCpCrdRdAddrLast_s2} <= 0;
    end else if ( state == IDLE ) begin
        {CntLopCrdRdAddrLast_s2, CntCpCrdRdAddrLast_s2} <= 0;
    end else if(ena_s2) begin
        {CntLopCrdRdAddrLast_s2, CntCpCrdRdAddrLast_s2}  <= {CntLopCrdRdAddrLast_s1, CntCpCrdRdAddrLast_s1};
    end 
end

//=====================================================================================================================
// Logic Design: s3-out
//=====================================================================================================================
wire pisoMapOutRdy;
PISO_NOCACHE#(
    .DATA_IN_WIDTH   ( (SRAM_WIDTH + IDX_WIDTH + 1)*NUM_SRAMWORD_MAP*NUM_SORT_CORE ), 
    .DATA_OUT_WIDTH  ( SRAM_WIDTH + IDX_WIDTH + 1)
)u_PISO_MAP(
    .CLK       ( clk            ),
    .RST_N     ( rst_n          ),
    .RESET     ( state == IDLE  ),
    .IN_VLD    ( vld_s2         ),
    .IN_LAST   ( CntCpCrdRdAddrLast_s2 &  CntLopCrdRdAddrLast_s2 ),
    .IN_DAT    ( pisoMapInDat     ),
    .IN_RDY    ( pisoMapInRdy    ),
    .OUT_DAT   ( pisoMapOutDat   ),
    .OUT_VLD   ( pisoMapOutVld   ),
    .OUT_LAST  ( pisoMapOutLast  ),
    .OUT_RDY   ( pisoMapOutRdy )
);
assign KNNGLB_MapWrDatVld= state == IDLE? 0 : pisoMapOutVld & pisoMapOutDat[0];
assign pisoMapOutRdy = KNNGLB_MapWrDatVld? (state == IDLE? 0 : GLBKNN_MapWrDatRdy) : 1'b1;
`ifdef PSEUDO_DATA
    assign KNNGLB_MapWrAddr = CntMapWr[0 +: 6]; // low 4 bit
`else
    assign KNNGLB_MapWrAddr = state == IDLE? 0 : CCUKNN_CfgMapWrAddr + CntMapWr;
`endif

assign KNNGLB_MapWrDat  = state == IDLE? 0 : KNNGLB_MapWrDatVld? pisoMapOutDat[1 + IDX_WIDTH +: SRAM_WIDTH] : 0;

assign MaxCntMapWr = 2**IDX_WIDTH -1;
counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_MapWr(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( state == IDLE      ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}} ),
    .INC       ( KNNGLB_MapWrDatVld & (state == IDLE? 1'b0 : GLBKNN_MapWrDatRdy) ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}} ),
    .MAX_COUNT ( MaxCntMapWr        ),
    .OVERFLOW  (                    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntMapWr           )
);

//=====================================================================================================================
// Logic Design: Monitor
//=====================================================================================================================
assign KNNMON_Dat = {
    CCUKNN_CfgInfo, 
    CCUKNN_CfgVld,
    KNNCCU_CfgRdy,
    CntLopCrdByte, 
    CntLopCrdRdAddr, 
    CntMaskAddr, 
    CntCpCrdRdAddr, 
    state};

endmodule
