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
    parameter IDX_WIDTH             = 10,
    parameter ACT_WIDTH             = 8,
    parameter POOL_COMP_CORE        = 64,
    parameter POOL_MAP_DEPTH_WIDTH  = 5,
    parameter POOL_CORE             = 6,
    parameter CHN_WIDTH             = 12,
    parameter SRAM_WIDTH            = 256
    )(
    input                               clk                     ,
    input                               rst_n                   ,

    // Configure
    input                                                   CCUPOL_Rst,
    input                                                   CCUPOL_CfgVld,
    output                                                  POLCCU_CfgRdy,
    input  [POOL_MAP_DEPTH_WIDTH                    -1 : 0] CCUPOL_CfgK  , // 24
    input  [IDX_WIDTH                               -1 : 0] CCUPOL_CfgNip, // 1024
    input  [CHN_WIDTH                               -1 : 0] CCUPOL_CfgChi, // 64
    input  [IDX_WIDTH*POOL_CORE                     -1 : 0] CCUPOL_AddrMin,
    input  [IDX_WIDTH*POOL_CORE                     -1 : 0] CCUPOL_AddrMax,// Not Included

    output [IDX_WIDTH                               -1 : 0] POLGLB_MapRdAddr,   
    output                                                  POLGLB_MapRdAddrVld, 
    input                                                   GLBPOL_MapRdAddrRdy,

    input                                                   GLBPOL_MapRdVld ,
    input  [SRAM_WIDTH                              -1 : 0] GLBPOL_MapRdDat    ,
    output                                                  POLGLB_MapRdRdy ,

    output [POOL_CORE                               -1 : 0] POLGLB_OfmRdAddrVld,
    output [IDX_WIDTH*POOL_CORE                     -1 : 0] POLGLB_OfmRdAddr  ,
    input  [POOL_CORE                               -1 : 0] GLBPOL_OfmRdAddrRdy,
    input  [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE    -1 : 0] GLBPOL_OfmRdDat    ,
    input  [POOL_CORE                               -1 : 0] GLBPOL_OfmRdVld ,
    output [POOL_CORE                               -1 : 0] POLGLB_OfmRdRdy ,

    output [IDX_WIDTH                               -1 : 0] POLGLB_OfmWrAddr    ,
    output [(ACT_WIDTH*POOL_COMP_CORE)              -1 : 0] POLGLB_OfmWrDat    ,
    output                                                  POLGLB_OfmWrVld ,
    input                                                   GLBPOL_OfmWrRdy   
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE     = 3'b000;
localparam MAPIN    = 3'b001;
localparam WAITFNH  = 3'b011;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [POOL_CORE                             -1 : 0] PLCPOL_IdxRdy;
wire [POOL_CORE                             -1 : 0] PLCPOL_AddrVld;
wire [IDX_WIDTH*POOL_CORE                   -1 : 0] PLCPOL_Addr;
wire [POOL_CORE                             -1 : 0] POLPLC_AddrRdy;
wire [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE  -1 : 0] POLPLC_Ofm;
wire [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE  -1 : 0] PLCPOL_Ofm;

wire [POOL_CORE                             -1 : 0] POLPLC_OfmVld;
wire [POOL_CORE                             -1 : 0] PLCPOL_OfmRdy;

wire [POOL_CORE                             -1 : 0] PLCPOL_OfmVld;
wire [POOL_CORE                             -1 : 0] POLPLC_OfmRdy;
wire [$clog2(POOL_CORE)                     -1 : 0] ARBIdx_PLCPOL_OfmVld;

wire                                                MapInLast;
wire                                                OfmOutLast;

reg  [IDX_WIDTH                             -1 : 0] CntMapIn;
reg  [IDX_WIDTH                             -1 : 0] CntOfmOut;

wire [POOL_CORE                             -1 : 0] PLCPOL_Empty;

//=====================================================================================================================
// Logic Design: s0:  MapRdAddr
//=====================================================================================================================

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;

// Combination Logic
always @(*) begin
    case ( state )
        IDLE :  if ( CCUPOL_CfgVld & POLCCU_CfgRdy )
                    next_state <= MAPIN;
                else
                    next_state <= IDLE;
        MAPIN:  if ( overflow_CntCp )
                    next_state <= WAITFNH;
                else 
                    next_state <= MAPIN;
        WAITFNH:if (  )
                    next_state <= IDLE;
                else
                    next_state <= WAITFNH;

        default: next_state <= IDLE;
    endcase
end
assign POLCCU_CfgRdy = state == IDLE;

// Handshake
assign rdy_s0 = GLBPOL_MapRdAddrRdy;
assign vld_s0 = state == MAPIN;

assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0 = handshake_s0 | ~vld_s0;


// Reg Update

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else if(CCUPOL_Rst) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

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
    .MAX_COUNT ( CCUPOL_CfgNip-1    ),
    .OVERFLOW  ( overflow_CntCp     ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntCp              )
);

parameter MAPWORD_WIDTH = $clog2(IDX_WIDTH*(2**MAP_WIDTH)/SRAM_WIDTH);

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
    .MAX_COUNT ( 2**MAPWORD_WIDTH -1    ),
    .OVERFLOW  ( overflow_CntMapWord    ),
    .UNDERFLOW (                        ),
    .COUNT     ( CntMapWord             )
);


//=====================================================================================================================
// Logic Design: s1: Get Map 
//=====================================================================================================================

// Combinational Logic

assign POLGLB_MapRdAddr = CntCp<<MAPWORD_WIDTH + CntMapWord;
assign POLGLB_MapRdAddrVld = vld_s0;

// Handshake
assign rdy_s1 = PISO_IN_RDY;
assign vld_s1 = GLBPOL_MapRdVld;

assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1 = handshake_s1 | ~vld_s1;

// Reg Update


//=====================================================================================================================
// Logic Design: s2: Write Shape
//=====================================================================================================================

// Combinational Logic
assign POLGLB_MapRdRdy = rdy_s1;

PISO_NOCACHE#(
    .DATA_IN_WIDTH   ( SRAM_WIDTH*NUMMAPWORD*NUM_SORT_CORE  ), // (32+1)*10 /96 = 330 /96 <= 4
    .DATA_OUT_WIDTH  ( SRAM_WIDTH  )
)u_PISO_MAP(
    .CLK       ( clk            ),
    .RST_N     ( rst_n          ),
    .IN_VLD    ( GLBPOL_MapRdVld),
    .IN_LAST   ( 1'b0           ),
    .IN_DAT    ( GLBPOL_MapRdDat),
    .IN_RDY    ( PISO_IN_RDY    ),
    .OUT_DAT   ( PISO_MapOutDat ),
    .OUT_VLD   ( PISO_MapOutVld ),
    .OUT_LAST  (                ),
    .OUT_RDY   ( PISO_MapOutRdy )
);



// Handshake
assign rdy_s2 = &GLBPOL_OfmRdAddrRdy;
assign vld_s2 = &SYNC_SHAPE_MapOutVld;

assign handshake_s2 = rdy_s2 & vld_s2;
assign ena_s2 = handshake_s2 | ~vld_s2;

// Reg Update
SYNC_SHAPE #(
    .ACT_WIDTH           ( IDX_WIDTH            ),
    .SRAM_WIDTH          ( 2*POOL_CORE*IDX_WIDTH),
    .NUM_BANK            ( 1                    ),
    .NUM_ROW             ( POOL_CORE            )
) SYNC_SHAPE_U (               

    .clk                 ( clk                  ),
    .rst_n               ( rst_n                ),
                        
    .din_data            ( PISO_MapOutDat       ),
    .din_data_vld        ( PISO_MapOutVld       ),
    .din_data_rdy        ( PISO_MapOutRdy       ),
                        
    .out_data            ( SYNC_SHAPE_MapOutDat ),
    .out_data_vld        ( SYNC_SHAPE_MapOutVld ),
    .out_data_rdy        ( rdy_s2               )
);

//=====================================================================================================================
// Logic Design: s3: Get Ofm
//=====================================================================================================================

genvar i;
parameter CHNGRP_WIDTH = CHN_WIDTH - $clog2(POOL_COMP_CORE);
assign POLGLB_OfmRdAddrVld = {POOL_CORE{handshake_s1}};

generate
    for(i=0; i<POOL_CORE; i=i+1) begin: GEN_PCC
    
    assign POLGLB_OfmRdAddr[IDX_WIDTH*i +: IDX_WIDTH] = (CCUPOL_CfgChi/POOL_COMP_CORE)*SYNC_SHAPE_MapOutDat[IDX_WIDTH*i +: IDX_WIDTH] + CntChnGrp;

    end
endgenerate

// Handshake
assign rdy_s3 = PCC_DatInRdy;
assign vld_s3 = GLBPOL_OfmRdVld;

assign handshake_s3 = rdy_s3 & vld_s3;
assign ena_s3 = handshake_s3 | ~vld_s3;

// Reg Update
counter#(
    .COUNT_WIDTH ( MAP_WIDTH )
)u_CntChnGrp(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     (                    ),
    .DEFAULT   ( {IDX_WIDTH{1'd0}}  ),
    .INC       (                    ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'd0}}  ),
    .MAX_COUNT (                    ),
    .OVERFLOW  (                    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntChnGrp          )
);

counter#(
    .COUNT_WIDTH ( CHNGRP_WIDTH )
)u_CntNp(
    .CLK       ( clk                    ),
    .RESET_N   ( rst_n                  ),
    .CLEAR     (                        ),
    .DEFAULT   ( {CHNGRP_WIDTH{1'd0}}   ),
    .INC       (                        ),
    .DEC       ( 1'b0                   ),
    .MIN_COUNT ( {CHNGRP_WIDTH{1'd0}}   ),
    .MAX_COUNT (                        ),
    .OVERFLOW  (                        ),
    .UNDERFLOW (                        ),
    .COUNT     ( CntNp                  )
);

assign POLGLB_OfmRdRdy = {POOL_CORE{rdy_s3}};

//=====================================================================================================================
// Logic Design: s4: Max
//=====================================================================================================================
// Combinational Logic  

// Handshake
assign rdy_s4 = PISO_OFMWR_IN_RDY;
assign vld_s4 = &PCC_DatOutVld;

assign handshake_s4 = rdy_s4 & vld_s4;
assign ena_s4 = handshake_s4 | ~vld_s4;

// Reg Update
 generate
    for(i=0; i<POOL_CORE; i=i+1) begin: GEN_PCC
  
    PCC#(
        .NUM_MAX    ( POOL_COMP_CORE),
        .DATA_WIDTH ( ACT_WIDTH     )
    )U1_PLCC(
        .clk       ( clk            ),
        .rst_n     ( rst_n          ),
        .Rst       ( POLPLC_Rst     ),
        .DatInVld  ( vld_s3         ),
        .DatInLast (                ),
        .DatIn     ( GLBPOL_OfmRdDat[ACT_WIDTH*POOL_COMP_CORE*i +: ACT_WIDTH*POOL_COMP_CORE]),
        .DatInRdy  ( PCC_DatInRdy   ),
        .DatOutVld ( PCC_DatOutVld  ),
        .DatOut    ( PCC_DatOut[ACT_WIDTH*POOL_COMP_CORE*i +: ACT_WIDTH*POOL_COMP_CORE]   ),
        .DatOutRdy ( rdy_s4         )
    );

    end
endgenerate 


//=====================================================================================================================
// Logic Design: Out
//=====================================================================================================================

PISO_NOCACHE#(
    .DATA_IN_WIDTH   ( ACT_WIDTH*POOL_COMP_CORE*POOL_CORE  ),
    .DATA_OUT_WIDTH  ( ACT_WIDTH*POOL_COMP_CORE  )
)u_PISO_OFMWR(
    .CLK       ( clk            ),
    .RST_N     ( rst_n          ),
    .IN_VLD    ( vld_s4         ),
    .IN_LAST   ( 1'b0           ),
    .IN_DAT    ( PCC_DatOut     ),
    .IN_RDY    ( PISO_OFMWR_IN_RDY),
    .OUT_DAT   ( POLGLB_OfmWrDat),
    .OUT_VLD   ( POLGLB_OfmWrVld),
    .OUT_LAST  (                ),
    .OUT_RDY   ( GLBPOL_OfmWrRdy)
);

assign POLGLB_OfmWrAddr = (CCUPOL_CfgChi/POOL_COMP_CORE)*(CntPCCCp_s4*POOL_CORE + u_PISO_OFMWR.count) + CntChnGrp_s4;

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================


endmodule
