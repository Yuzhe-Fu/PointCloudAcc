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

module POL #(
    parameter IDX_WIDTH             = 16,
    parameter ACT_WIDTH             = 8,
    parameter POOL_COMP_CORE        = 64,
    parameter MAP_WIDTH             = 5,
    parameter POOL_CORE             = 8,
    parameter CHN_WIDTH             = 12,
    parameter SRAM_WIDTH            = 256
    )(
    input                                                   clk                 ,
    input                                                   rst_n               ,

    // Configure
    input  [POOL_CORE                               -1 : 0] CCUPOL_Rst          ,
    input  [POOL_CORE                               -1 : 0] CCUPOL_CfgVld       ,
    output [POOL_CORE                               -1 : 0] POLCCU_CfgRdy       ,
    input  [POOL_CORE   -1 : 0][(MAP_WIDTH+1)       -1 : 0] CCUPOL_CfgK         , // 24
    input  [POOL_CORE   -1 : 0][IDX_WIDTH           -1 : 0] CCUPOL_CfgNip       , // 1024
    input  [POOL_CORE   -1 : 0][CHN_WIDTH           -1 : 0] CCUPOL_CfgChn       , // 64

    output [IDX_WIDTH                               -1 : 0] POLGLB_MapRdAddr    ,   
    output                                                  POLGLB_MapRdAddrVld , 
    input                                                   GLBPOL_MapRdAddrRdy ,
    input                                                   GLBPOL_MapRdDatVld     ,
    input  [SRAM_WIDTH                              -1 : 0] GLBPOL_MapRdDat     ,
    output                                                  POLGLB_MapRdDatRdy     ,

    output [POOL_CORE                               -1 : 0] POLGLB_OfmRdAddrVld ,
    output [POOL_CORE   -1 : 0][IDX_WIDTH           -1 : 0] POLGLB_OfmRdAddr    ,
    input  [POOL_CORE                               -1 : 0] GLBPOL_OfmRdAddrRdy ,
    input  [POOL_CORE   -1 : 0][(ACT_WIDTH*POOL_COMP_CORE)-1 : 0] GLBPOL_OfmRdDat     ,
    input  [POOL_CORE                               -1 : 0] GLBPOL_OfmRdDatVld     ,
    output [POOL_CORE                               -1 : 0] POLGLB_OfmRdDatRdy     ,

    output [IDX_WIDTH                               -1 : 0] POLGLB_OfmWrAddr    ,
    output [(ACT_WIDTH*POOL_COMP_CORE)              -1 : 0] POLGLB_OfmWrDat     ,
    output                                                  POLGLB_OfmWrDatVld  ,
    input                                                   GLBPOL_OfmWrDatRdy       
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================

parameter CHNGRP_WIDTH  = CHN_WIDTH - $clog2(POOL_COMP_CORE);
parameter MAPWORD_WIDTH = $clog2(IDX_WIDTH*(2**MAP_WIDTH)/SRAM_WIDTH);

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

wire [POOL_CORE -1 : 0][IDX_WIDTH   -1 : 0] PLC_MapRdAddr;
wire [$clog2(POOL_CORE)             -1 : 0] ArbPLCIdx_MapRd;
wire [$clog2(POOL_CORE)             -1 : 0] ArbPLCIdx_MapRd_d;
wire [POOL_CORE                     -1 : 0] PLC_MapRdAddrVld;
wire [POOL_CORE                     -1 : 0] PLC_MapRdDatRdy;

wire [POOL_CORE   -1 : 0][IDX_WIDTH                 -1 : 0] PLC_OfmWrAddr;
wire [POOL_CORE   -1 : 0][ACT_WIDTH*POOL_COMP_CORE  -1 : 0] PLC_OfmWrDat;
wire [POOL_CORE                                     -1 : 0] PLC_OfmWrDatVld;
wire [$clog2(POOL_CORE)                             -1 : 0] ArbPLCIdxWrOfm;

genvar gv_plc;
genvar gv_cmp;
//=====================================================================================================================
// Logic Design
//=====================================================================================================================
// s0 -----------------------------------------------------------------------------------------------------------------
ArbCore#(
    .NUM_CORE    ( POOL_CORE    ),
    .ADDR_WIDTH  ( IDX_WIDTH    ),
    .DATA_WIDTH  ( SRAM_WIDTH   )
)u_ArbCore_PLCRdMap(
    .clk         ( clk                  ),
    .rst_n       ( rst_n                ),
    .CoreOutVld  ( PLC_MapRdAddrVld     ),
    .CoreOutAddr ( PLC_MapRdAddr        ),
    .CoreOutDat  (                      ),
    .CoreOutRdy  ( PLC_MapRdDatRdy      ),
    .TopOutVld   ( POLGLB_MapRdAddrVld  ),
    .TopOutAddr  ( POLGLB_MapRdAddr     ),
    .TopOutDat   (                      ),
    .TopOutRdy   ( POLGLB_MapRdDatRdy   ),
    .TOPInRdy    ( GLBPOL_MapRdAddrRdy  ),
    .ArbCoreIdx  ( ArbPLCIdx_MapRd      ),
    .ArbCoreIdx_d( ArbPLCIdx_MapRd_d    )
);

//  -----------------------------------------------------------------------------------------------------------------
ArbCore#(
    .NUM_CORE    ( POOL_CORE                ),
    .ADDR_WIDTH  ( IDX_WIDTH                ),
    .DATA_WIDTH  ( ACT_WIDTH*POOL_COMP_CORE )
)u_ArbCore_PLCWrOfm(
    .clk         ( clk                  ),
    .rst_n       ( rst_n                ),
    .CoreOutVld  ( PLC_OfmWrDatVld      ),
    .CoreOutAddr ( PLC_OfmWrAddr        ),
    .CoreOutDat  ( PLC_OfmWrDat         ),
    .CoreOutRdy  (                      ),
    .TopOutVld   ( POLGLB_OfmWrDatVld   ),
    .TopOutAddr  ( POLGLB_OfmWrAddr     ),
    .TopOutDat   ( POLGLB_OfmWrDat      ),
    .TopOutRdy   (                      ),
    .TOPInRdy    ( GLBPOL_OfmWrDatRdy   ),
    .ArbCoreIdx  ( ArbPLCIdxWrOfm       ),
    .ArbCoreIdx_d(                      )
);

//  -----------------------------------------------------------------------------------------------------------------
generate
    for(gv_plc=0; gv_plc<POOL_CORE; gv_plc=gv_plc+1) begin: GEN_PLC

    //=====================================================================================================================
    // Variable Definition :
    //=====================================================================================================================
    wire [IDX_WIDTH         -1 : 0] CntCp;
    wire [MAPWORD_WIDTH     -1 : 0] CntMapWord;
    wire [CHNGRP_WIDTH      -1 : 0] CntChnGrp;
    wire [MAP_WIDTH         -1 : 0] CntNp;
    wire                            overflow_CntMapWord;
    reg                             overflow_CntMapWord_s1;
    reg                             overflow_CntMapWord_s2;
    reg                             overflow_CntMapWord_s3;
    reg                             overflow_CntMapWord_s4;
    wire                            overflow_CntCp;
    reg                             overflow_CntCp_s1;
    reg                             overflow_CntCp_s2;
    reg                             overflow_CntCp_s3;
    reg                             overflow_CntCp_s4;
    wire                            overflow_CntNp;
    wire                            overflow_CntNp_s1;
    reg                             overflow_CntNp_s2;
    reg                             overflow_CntNp_s3;
    reg                             overflow_CntNp_s4;
    reg                             overflow_CntChnGrp;
    reg                             overflow_CntChnGrp_s1;
    reg                             overflow_CntChnGrp_s2;
    reg                             overflow_CntChnGrp_s3;
    reg                             overflow_CntChnGrp_s4;

    reg                             LastCp_s1;
    wire                            LastCpNp_s2;
    reg                             LastCpNp_s3;
    reg                             LastCpNp_s4;

    wire                            rdy_s0;
    wire                            rdy_s1;
    wire                            rdy_s2;
    wire                            rdy_s3;
    wire                            rdy_s4;
    wire                            vld_s0;
    wire                            vld_s1;
    wire                            vld_s2;
    wire                            vld_s3;
    reg                             vld_s4;
    wire                            handshake_s0;
    wire                            handshake_s1;
    wire                            handshake_s2;
    wire                            handshake_s3;
    wire                            handshake_s4;
    wire                            ena_s0;
    wire                            ena_s1;
    wire                            ena_s2;
    wire                            ena_s3;
    wire                            ena_s4;

    wire                            SIPO_MapInRdy;
    wire [(2**MAP_WIDTH)-1 : 0][IDX_WIDTH -1 : 0] SIPO_MapOutDat; 
    wire                            SIPO_MapOutVld; 
    wire                            SIPO_MapOutLast;
    wire                            SIPO_MapOutRdy;

    wire                            PISO_MapInRdy; 
    wire [IDX_WIDTH         -1 : 0] PISO_MapOutDat;
    wire                            PISO_MapOutVld; 
    wire [IDX_WIDTH         -1 : 0] NpIdx_s2;
    reg  [IDX_WIDTH         -1 : 0] NpIdx_s3;
    reg  [IDX_WIDTH         -1 : 0] NpIdx_s4;
    //=====================================================================================================================
    // Logic Design: s0:  MapRdAddr
    //=====================================================================================================================
    localparam IDLE     = 3'b000;
    localparam MAPIN    = 3'b001;
    localparam WAITFNH  = 3'b011;
    reg [ 3     -1 : 0] state       ;
    reg [ 3     -1 : 0] next_state  ;

    // Combination Logic
    always @(*) begin
        case ( state )
            IDLE :  if ( CCUPOL_CfgVld[gv_plc] & POLCCU_CfgRdy[gv_plc] )
                        next_state <= MAPIN;
                    else
                        next_state <= IDLE;
            MAPIN:  if ( overflow_CntCp )
                        next_state <= WAITFNH;
                    else 
                        next_state <= MAPIN;
            WAITFNH:if ( (overflow_CntNp_s4 & overflow_CntChnGrp_s4 &overflow_CntCp_s4) & handshake_s4 )
                        next_state <= IDLE;
                    else
                        next_state <= WAITFNH;

            default:    next_state <= IDLE;
        endcase
    end
    assign POLCCU_CfgRdy[gv_plc] = state == IDLE;

    // Handshake
    assign rdy_s0 = GLBPOL_MapRdAddrRdy & ArbPLCIdx_MapRd == gv_plc;
    assign vld_s0 = state == MAPIN  & (rdy_s1 & !vld_s1);

    assign handshake_s0 = rdy_s0 & vld_s0;
    assign ena_s0 = handshake_s0 | ~vld_s0;

    // Reg Update
    always @ ( posedge clk or negedge rst_n ) begin
        if ( !rst_n ) begin
            state <= IDLE;
        end else if(CCUPOL_Rst[gv_plc]) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    wire [IDX_WIDTH     -1 : 0] MaxCntCp = CCUPOL_CfgNip[gv_plc] -1;
    counter#(
        .COUNT_WIDTH ( IDX_WIDTH )
    )u_CntCp(
        .CLK       ( clk                ),
        .RESET_N   ( rst_n              ),
        .CLEAR     ( state == IDLE      ),
        .DEFAULT   ( {IDX_WIDTH{1'd0}}  ),
        .INC       ( overflow_CntMapWord & handshake_s0 ),
        .DEC       ( 1'b0               ),
        .MIN_COUNT ( {IDX_WIDTH{1'd0}}  ),
        .MAX_COUNT ( MaxCntCp           ),
        .OVERFLOW  ( overflow_CntCp     ),
        .UNDERFLOW (                    ),
        .COUNT     ( CntCp              )
    );

    wire [MAPWORD_WIDTH     -1 : 0] MaxCntMapWord = 2**MAPWORD_WIDTH -1;
    counter#(
        .COUNT_WIDTH ( MAPWORD_WIDTH )
    )u_CntMapWord(
        .CLK       ( clk                    ),
        .RESET_N   ( rst_n                  ),
        .CLEAR     ( state == IDLE          ), // automatically loop by MAX_COUNT
        .DEFAULT   ( {MAPWORD_WIDTH{1'd0}}  ),
        .INC       ( handshake_s0           ),
        .DEC       ( 1'b0                   ),
        .MIN_COUNT ( {MAPWORD_WIDTH{1'd0}}  ),
        .MAX_COUNT ( MaxCntMapWord          ),
        .OVERFLOW  ( overflow_CntMapWord    ),
        .UNDERFLOW (                        ),
        .COUNT     ( CntMapWord             )
    );


    //=====================================================================================================================
    // Logic Design: s1: Get Map 
    //=====================================================================================================================

    // Combinational Logic
    assign PLC_MapRdAddr[gv_plc] = (CntCp<<MAPWORD_WIDTH) + CntMapWord;
    assign PLC_MapRdAddrVld[gv_plc] = vld_s0;//  & (rdy_s1 & !vld_s1); // ????????

    // Handshake
    assign rdy_s1 = SIPO_MapInRdy;
    assign vld_s1 = GLBPOL_MapRdDatVld & gv_plc ==ArbPLCIdx_MapRd_d;

    assign handshake_s1 = rdy_s1 & vld_s1;
    assign ena_s1 = handshake_s1 | ~vld_s1;

    // Reg Update
    always @ ( posedge clk or negedge rst_n ) begin
        if ( !rst_n ) begin
            LastCp_s1 <= 0;
        end else if(ena_s1) begin
            LastCp_s1 <= overflow_CntCp & overflow_CntMapWord;
        end
    end

    //=====================================================================================================================
    // Logic Design: s2: Write Shape
    //=====================================================================================================================

    // Combinational Logic
    assign PLC_MapRdDatRdy[gv_plc] = rdy_s1;

    // Handshake
    assign rdy_s2 = GLBPOL_OfmRdAddrRdy[gv_plc];
    assign vld_s2 = PISO_MapOutVld;

    assign handshake_s2 = rdy_s2 & vld_s2;
    assign ena_s2 = handshake_s2 | ~vld_s2;


    // Reg Update
    SIPO#(
        .DATA_IN_WIDTH   ( SRAM_WIDTH  ), 
        .DATA_OUT_WIDTH  ( IDX_WIDTH*(2**MAP_WIDTH)  )
    )u_SIPO_MAP(
        .CLK       ( clk                ),
        .RST_N     ( rst_n              ),
        .IN_VLD    ( vld_s1             ),
        .IN_LAST   ( LastCp_s1          ),
        .IN_DAT    ( GLBPOL_MapRdDat    ),
        .IN_RDY    ( SIPO_MapInRdy      ),
        .OUT_DAT   ( SIPO_MapOutDat     ),
        .OUT_VLD   ( SIPO_MapOutVld     ),
        .OUT_LAST  ( SIPO_MapOutLast    ),
        .OUT_RDY   ( SIPO_MapOutRdy     )
    );
    assign SIPO_MapOutRdy = PISO_MapInRdy & overflow_CntNp; // only when map is used up for CntNp(inner loop)

    PISO_NOCACHE#(
        .DATA_IN_WIDTH   ( IDX_WIDTH*(2**MAP_WIDTH)),
        .DATA_OUT_WIDTH  ( IDX_WIDTH )
    )u_PISO_MAP(
        .CLK       ( clk            ),
        .RST_N     ( rst_n          ),
        .IN_VLD    ( SIPO_MapOutVld ),
        .IN_LAST   ( SIPO_MapOutLast),
        .IN_DAT    ( SIPO_MapOutDat ),
        .IN_RDY    ( PISO_MapInRdy  ), 
        .OUT_DAT   ( PISO_MapOutDat ),
        .OUT_VLD   ( PISO_MapOutVld ),
        .OUT_LAST  ( LastCpNp_s2    ),
        .OUT_RDY   ( rdy_s2         ) // all the time is fetching
    );


    //=====================================================================================================================
    // Logic Design: s3: Get Ofm
    //=====================================================================================================================
    
    // Combination Logic
    assign POLGLB_OfmRdAddrVld[gv_plc] = vld_s2;
    `ifdef PSEUDO_DATA
        assign NpIdx_s2 = (CCUPOL_CfgChn[gv_plc]/POOL_COMP_CORE)*PISO_MapOutDat[0 +: 4] + CntChnGrp;
    `else
        assign NpIdx_s2 = (CCUPOL_CfgChn[gv_plc]/POOL_COMP_CORE)*PISO_MapOutDat + CntChnGrp;
    `endif

    assign POLGLB_OfmRdAddr[gv_plc] = NpIdx_s2;


    // Handshake
    assign rdy_s3 = ena_s4;
    assign vld_s3 = GLBPOL_OfmRdDatVld[gv_plc]; 

    assign handshake_s3 = rdy_s3 & vld_s3;
    assign ena_s3       = handshake_s3 | ~vld_s3;

    // Reg Update
    wire [MAP_WIDTH     -1 : 0] MaxCntNp = CCUPOL_CfgK[gv_plc] -1;
    counter#(
        .COUNT_WIDTH ( MAP_WIDTH )
    )u_CntNp(
        .CLK       ( clk                    ),
        .RESET_N   ( rst_n                  ),
        .CLEAR     ( CCUPOL_Rst[gv_plc]     ),
        .DEFAULT   ( {MAP_WIDTH{1'd0}}      ),
        .INC       ( handshake_s2           ),
        .DEC       ( 1'b0                   ),
        .MIN_COUNT ( {MAP_WIDTH{1'd0}}      ),
        .MAX_COUNT ( MaxCntNp               ),
        .OVERFLOW  ( overflow_CntNp         ), // inner loop
        .UNDERFLOW (                        ),
        .COUNT     ( CntNp                  )
    );
    wire [CHNGRP_WIDTH      -1 : 0] MaxCntChnGrp = CCUPOL_CfgChn[gv_plc]/POOL_COMP_CORE -1;
    counter#(
        .COUNT_WIDTH ( CHNGRP_WIDTH )
    )u_CntChnGrp(
        .CLK       ( clk                ),
        .RESET_N   ( rst_n              ),
        .CLEAR     ( CCUPOL_Rst[gv_plc] ),
        .DEFAULT   ( {CHNGRP_WIDTH{1'd0}}),
        .INC       ( overflow_CntNp & handshake_s2 ),
        .DEC       ( 1'b0               ),
        .MIN_COUNT ( {CHNGRP_WIDTH{1'd0}}  ),
        .MAX_COUNT ( MaxCntChnGrp       ),
        .OVERFLOW  ( overflow_CntChnGrp ), // outer loop
        .UNDERFLOW (                    ),
        .COUNT     ( CntChnGrp          )
    );
    assign POLGLB_OfmRdDatRdy[gv_plc] = rdy_s3;

    always @ ( posedge clk or negedge rst_n ) begin
        if ( !rst_n ) begin
            {NpIdx_s3, LastCpNp_s3} <= 0;
        end else if(ena_s3) begin
            {NpIdx_s3, LastCpNp_s3} <= {NpIdx_s2, LastCpNp_s2};
        end
    end

    //=====================================================================================================================
    // Logic Design: s4: Max
    //=====================================================================================================================
    // Combinational Logic 


    // Handshake
    assign rdy_s4 = GLBPOL_OfmWrDatRdy & ArbPLCIdxWrOfm == gv_plc;

    assign handshake_s4 = rdy_s4 & vld_s4;
    assign ena_s4 = handshake_s4 | ~vld_s4;

    // Reg Update
    // PCC 
    for(gv_cmp=0; gv_cmp<POOL_COMP_CORE; gv_cmp=gv_cmp+1) begin: GEN_CMP
        wire [ACT_WIDTH     -1 : 0] CMP_DatIn;
        reg  [ACT_WIDTH     -1 : 0] MaxArray[0 : POOL_COMP_CORE -1];

        assign CMP_DatIn = GLBPOL_OfmRdDat[gv_plc][ACT_WIDTH*gv_cmp +: ACT_WIDTH];
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                MaxArray[gv_cmp] <= 0;
            end else if(CCUPOL_Rst[gv_plc]) begin
                MaxArray[gv_cmp] <= 0;
            end else if ( CntNp ==0 & handshake_s3 ) begin // initialize
                MaxArray[gv_cmp] <= CMP_DatIn;                
            end else if ( handshake_s3 ) begin // Compare
                MaxArray[gv_cmp] <= (CMP_DatIn > MaxArray[gv_cmp] )? CMP_DatIn : MaxArray[gv_cmp];
            end
        end
        assign PLC_OfmWrDat[gv_plc][ACT_WIDTH*gv_cmp +: ACT_WIDTH] =  MaxArray[gv_cmp];
    end


    always @ ( posedge clk or negedge rst_n ) begin
        if ( !rst_n ) begin
            {NpIdx_s4, overflow_CntNp_s4, overflow_CntChnGrp_s4, overflow_CntCp_s4,vld_s4} <= 0;
        end else if(ena_s4) begin
            {NpIdx_s4, overflow_CntNp_s4, overflow_CntChnGrp_s4, overflow_CntCp_s4, vld_s4} <= {NpIdx_s3, overflow_CntNp_s3, overflow_CntChnGrp_s3, overflow_CntCp_s3, overflow_CntNp};
        end
    end

    //=====================================================================================================================
    // Logic Design: Out
    //=====================================================================================================================
    // Combination Logic
    assign PLC_OfmWrDatVld[gv_plc] = vld_s4;
    assign PLC_OfmWrAddr[gv_plc] = NpIdx_s4;

    end
endgenerate

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================


endmodule
