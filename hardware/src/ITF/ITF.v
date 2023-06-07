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
// File   : .v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------
module ITF #(
    parameter PORT_WIDTH            = 128,
    parameter OPNUM                 = 5,
    parameter ASYNC_FIFO_ADDR_WIDTH = 4,
    parameter FBDIV_WIDTH           = 5
    )(
        
    // PAD
    input                           I_BypAsysnFIFO_PAD,// Hyper
    input                           I_BypOE_PAD       , 
    input                           I_BypPLL_PAD      , 
    input                           I_SysRst_n_PAD    , 
    input [FBDIV_WIDTH      -1 : 0] I_FBDIV_PAD       ,
    input                           I_SwClk_PAD       ,
    input                           I_SysClk_PAD      , 
    input                           I_OffClk_PAD      ,
    output                          O_SysClk_PAD      ,
    output                          O_OffClk_PAD      ,
    output                          O_PLLLock_PAD     ,

    output [OPNUM           -1 : 0] O_CfgRdy_PAD      , // Monitor
    output                          O_DatOE_PAD       ,

    input                           I_OffOE_PAD       , // Transfer-Control
    input                           I_DatVld_PAD      ,
    input                           I_DatLast_PAD     ,
    output                          O_DatRdy_PAD      ,
    output                          O_DatVld_PAD      , 
    output                          O_DatLast_PAD     , 
    input                           I_DatRdy_PAD      , 

    input                           I_ISAVld_PAD      , // Transfer-Data
    output                          O_CmdVld_PAD      ,
    inout   [PORT_WIDTH     -1 : 0] IO_Dat_PAD        , 

    // CCU
    input  [OPNUM           -1 : 0] CCUITF_CfgRdy     ,
    output   [PORT_WIDTH    -1 : 0] ITFCCU_ISARdDat   ,       
    output                          ITFCCU_ISARdDatVld,          
    output                          ITFCCU_ISARdDatLast,          
    input                           CCUITF_ISARdDatRdy,

    // GIC-Global Buffer Interface Controller
    input [PORT_WIDTH       -1 : 0] GICITF_Dat      ,
    input                           GICITF_DatVld   ,
    input                           GICITF_DatLast  ,
    input                           GICITF_CmdVld   ,
    output                          ITFGIC_DatRdy   ,

    output  [PORT_WIDTH     -1 : 0] ITFGIC_Dat      ,
    output                          ITFGIC_DatVld   ,
    output                          ITFGIC_DatLast  ,
    input                           GICITF_DatRdy   ,

    // Monitor
    input [PORT_WIDTH       -1 : 0] MONITF_Dat      ,
    input                           MONITF_DatVld   ,
    input                           MONITF_DatLast  ,
    output                          ITFMON_DatRdy   ,

    output                          clk             ,
    output                          rst_n            

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam INPUT_PAD = 1'b1, OUTPUT_PAD = 1'b0;

localparam IDLE     = 0;
localparam IN2CHIP  = 1;
localparam INWAIT   = 2;
localparam OUT2OFF  = 3;
localparam OUTWAIT  = 4;
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                          I_BypAsysnFIFO;
wire                          I_BypOE       ;
wire                          I_BypPLL      ;
wire [FBDIV_WIDTH     -1 : 0] I_FBDIV       ;
wire                          I_SwClk       ;
wire                          I_SysRst_n    ;
wire                          I_SysClk      ;
wire                          I_OffClk      ;
wire                          O_PLLLock     ;
wire [OPNUM           -1 : 0] O_CfgRdy      ;
wire                          O_DatOE       ;
wire                          I_OffOE       ;
wire                          I_DatVld      ;
wire                          I_DatLast     ;
wire                          O_DatRdy      ;
wire                          O_DatVld      ;
wire                          I_DatRdy      ;
wire                          I_ISAVld      ;
wire                          O_CmdVld      ;
wire  [PORT_WIDTH     -1 : 0] I_Dat         ;
wire  [PORT_WIDTH     -1 : 0] O_Dat         ;

wire                        I_OffOE_sync;
wire                        I_DatVld_sync;
wire                        fifo_async_IN2CHIP_push ;
wire                        fifo_async_IN2CHIP_pop  ;
wire [PORT_WIDTH + 2-1 : 0] fifo_async_IN2CHIP_din  ;
wire [PORT_WIDTH + 2-1 : 0] fifo_async_IN2CHIP_dout ;
wire                        fifo_async_IN2CHIP_empty;
wire                        fifo_async_IN2CHIP_empty_sync;
wire                        fifo_async_IN2CHIP_full ;

wire                        fifo_async_OUT2OFF_push ;
wire                        fifo_async_OUT2OFF_pop  ;
wire [PORT_WIDTH + 2-1 : 0] fifo_async_OUT2OFF_din  ;
wire [PORT_WIDTH + 2-1 : 0] fifo_async_OUT2OFF_dout ;
wire                        fifo_async_OUT2OFF_empty;
wire                        fifo_async_OUT2OFF_empty_sync;
wire                        fifo_async_OUT2OFF_full ;

wire                        OE;
wire [3             -1 : 0] state_sync;

genvar                      gv_i;
wire                        O_DatLastHS_sync;

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if ( I_DatVld_sync )
                    next_state <= IN2CHIP;
                else if ( GICITF_DatVld | MONITF_DatVld )
                    next_state <= OUT2OFF;
                else
                    next_state <= IDLE;

        IN2CHIP:if( (ITFGIC_DatLast & (ITFGIC_DatVld & GICITF_DatRdy)) | (ITFCCU_ISARdDatLast & ITFCCU_ISARdDatVld & CCUITF_ISARdDatRdy) )
                    next_state <= IDLE;
                else
                    next_state <= IN2CHIP;

        OUT2OFF:if( O_DatLastHS_sync )
                    next_state <= OUTWAIT;
                else
                    next_state <= OUT2OFF;

        default:    next_state <= IN2CHIP;
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
// Logic Design: PAD_Init
//=====================================================================================================================
PDUW08DGZ_V_G inst_I_BypAsysnFIFO_PAD(.I(1'b0   ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_BypAsysnFIFO_PAD  ), .C(I_BypAsysnFIFO));
PDUW08DGZ_V_G inst_I_BypOE_PAD      (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_BypOE_PAD         ), .C(I_BypOE       ));
PDUW08DGZ_V_G inst_I_BypPLL_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_BypPLL_PAD        ), .C(I_BypPLL      ));
PDUW08DGZ_V_G inst_I_SysRst_n_PAD   (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_SysRst_n_PAD      ), .C(I_SysRst_n    ));
PDUW08DGZ_V_G inst_I_SwClk_PAD      (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_SwClk_PAD         ), .C(I_SwClk       ));
PDUW08DGZ_V_G inst_I_SysClk_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_SysClk_PAD        ), .C(I_SysClk      ));
PDUW08DGZ_V_G inst_I_OffClk_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_OffClk_PAD        ), .C(I_OffClk      ));
PDUW08DGZ_V_G inst_I_OffOE_PAD      (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_OffOE_PAD         ), .C(I_OffOE       ));
PDUW08DGZ_V_G inst_I_DatLast_PAD    (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_DatLast_PAD       ), .C(I_DatLast     ));
PDUW08DGZ_V_G inst_I_DatVld_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_DatVld_PAD        ), .C(I_DatVld      ));
PDUW08DGZ_V_G inst_I_DatRdy_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_DatRdy_PAD        ), .C(I_DatRdy      ));
PDUW08DGZ_V_G inst_I_ISAVld_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_ISAVld_PAD        ), .C(I_ISAVld      ));

PDUW08DGZ_V_G inst_O_SysClk_PAD     (.I(clk     ), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_SysClk_PAD        ), .C(              ));
PDUW08DGZ_V_G inst_O_OffClk_PAD     (.I(OffClk  ), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_OffClk_PAD        ), .C(              ));
PDUW08DGZ_V_G inst_O_PLLLock_PAD    (.I(O_PLLLock), .OEN(OUTPUT_PAD ), .REN(1'b0), .PAD(O_PLLLock_PAD       ), .C(              ));
PDUW08DGZ_V_G inst_O_DatOE_PAD      (.I(OE      ), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_DatOE_PAD         ), .C(              ));
PDUW08DGZ_V_G inst_O_DatVld_PAD     (.I(O_DatVld), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_DatVld_PAD        ), .C(              ));
PDUW08DGZ_V_G inst_O_DatLast_PAD    (.I(O_DatLast),.OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_DatLast_PAD       ), .C(              ));
PDUW08DGZ_V_G inst_O_DatRdy_PAD     (.I(O_DatRdy), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_DatRdy_PAD        ), .C(              ));
PDUW08DGZ_V_G inst_O_CmdVld_PAD     (.I(O_CmdVld), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_CmdVld_PAD        ), .C(              ));

generate
    for (gv_i = 0; gv_i < FBDIV_WIDTH; gv_i = gv_i + 1) begin: GEN_I_FBDIV_PAD
        PDUW08DGZ_V_G inst_I_FBDIV_PAD      (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_FBDIV_PAD[gv_i]         ), .C(I_FBDIV[gv_i] ));
    end 
endgenerate

generate
    for (gv_i = 0; gv_i < OPNUM; gv_i = gv_i + 1) begin: GEN_O_CfgRdy_PAD
        PDUW08DGZ_V_G inst_O_CfgRdy_PAD    (.I(O_CfgRdy[gv_i]    ), .OEN(OUTPUT_PAD), .REN(1'b0),  .PAD(O_CfgRdy_PAD[gv_i]    ), .C( ));
    end 
endgenerate

generate
    for (gv_i = 0; gv_i < 20; gv_i = gv_i + 1) begin: IO_Dat_PAD_0_19
        PDUW08DGZ_V_G inst_IO_Dat_PAD_0_19 (.I(O_Dat[gv_i]), .OEN(!OE), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate

generate
    for (gv_i = 20; gv_i < 60; gv_i = gv_i + 1) begin: IO_Dat_PAD_20_59
        PDUW08DGZ_H_G inst_IO_Dat_PAD_20_59 (.I(O_Dat[gv_i]), .OEN(!OE), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate

generate
    for (gv_i = 60; gv_i < 90; gv_i = gv_i + 1) begin: IO_Dat_PAD_60_89
        PDUW08DGZ_V_G inst_IO_Dat_PAD_60_89 (.I(O_Dat[gv_i]), .OEN(!OE), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate

generate
    for (gv_i = 90; gv_i < 128; gv_i = gv_i + 1) begin: IO_Dat_PAD_90_127
        PDUW08DGZ_H_G inst_IO_Dat_PAD_90_127 (.I(O_Dat[gv_i]), .OEN(!OE), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate
 // module PDUW08DGZ_H_G (
//     input  I, 
//     input  OEN, 
//     input  REN, 
//     inout  PAD, 
//     output C
    
// );

//     // reg PAD;
//     // reg C;

//     assign PAD = OEN == 0 ? I : 1'bz;
//     assign C   = OEN == 0 ? I : PAD;

// endmodule : PDUW08DGZ_H_G   

assign OE       = I_BypOE? I_OffOE_sync : state == OUT2OFF | state == OUTWAIT;

//=====================================================================================================================
// Sub-Module : TOP
//=====================================================================================================================

//=====================================================================================================================
// Sub-Module : Monitor
//=====================================================================================================================
DELAY#(
    .NUM_STAGES ( 1     ),
    .DATA_WIDTH ( OPNUM )
)u_DELAY_O_CfgRdy(
    .CLK        ( clk           ),
    .RST_N      ( rst_n         ),
    .DIN        ( CCUITF_CfgRdy ),
    .DOUT       ( O_CfgRdy      )
);

//=====================================================================================================================
// Sub-Module : Sync
//=====================================================================================================================
// OFF2CHIP
DELAY#(
    .NUM_STAGES ( 2    ),
    .DATA_WIDTH ( 4     )
)u_DELAY_Sync_OFF2CHIP(
    .CLK        ( clk           ),
    .RST_N      ( rst_n         ),
    .DIN        ( {fifo_async_IN2CHIP_empty, fifo_async_OUT2OFF_empty, I_DatVld, I_OffOE}       ),
    .DOUT       ( {fifo_async_IN2CHIP_empty_sync, fifo_async_OUT2OFF_empty_sync, I_DatVld_sync, I_OffOE_sync} )
);

SYNC_PULSE u_SYNC_PULSE(
    .in_rst_n  ( rst_n      ),
    .in_clk    ( OffClk   ),
    .in_pulse  ( O_DatLast & O_DatVld & I_DatRdy  ),
    .out_rst_n ( rst_n      ),
    .out_clk   ( I_SysClk   ),
    .out_pulse ( O_DatLastHS_sync )
);


// CHIP2OFF
DELAY#(
    .NUM_STAGES ( 2     ),
    .DATA_WIDTH ( 3     )
)u_DELAY_Sync_CHIP2OFF(
    .CLK        ( OffClk        ),
    .RST_N      ( rst_n         ),
    .DIN        ( {state}       ),
    .DOUT       ( {state_sync}  )
);

//=====================================================================================================================
// Sub-Module : IN2CHIP
//=====================================================================================================================
// PAD
assign O_DatRdy                 = (state_sync == IN2CHIP | state_sync == INWAIT)? ( I_BypAsysnFIFO ? (I_ISAVld? CCUITF_ISARdDatRdy :  GICITF_DatRdy) 
                                                                    : !fifo_async_IN2CHIP_full )
                                                                        : 1'b0;
assign fifo_async_IN2CHIP_push  = (state_sync == IN2CHIP | state_sync == INWAIT) & !I_BypAsysnFIFO & I_DatVld & !fifo_async_IN2CHIP_full;
assign fifo_async_IN2CHIP_din   = {I_Dat, I_DatLast, I_ISAVld};

// GIC
assign fifo_async_IN2CHIP_pop   = (state == IN2CHIP | state == INWAIT) & !I_BypAsysnFIFO & !fifo_async_IN2CHIP_empty  
                                        & (ITFCCU_ISARdDatVld & CCUITF_ISARdDatRdy | ITFGIC_DatVld & GICITF_DatRdy );
assign {ITFGIC_Dat, ITFGIC_DatLast, ITFGIC_DatVld} = {fifo_async_IN2CHIP_dout[1 +: PORT_WIDTH + 1], !fifo_async_IN2CHIP_dout[0] & !fifo_async_IN2CHIP_empty};

// CCU
assign {ITFCCU_ISARdDat, ITFCCU_ISARdDatLast, ITFCCU_ISARdDatVld} = (state == IN2CHIP | state == INWAIT)? (I_BypAsysnFIFO? {I_Dat, I_ISAVld}  
            : {fifo_async_IN2CHIP_dout[1 +: PORT_WIDTH + 1], fifo_async_IN2CHIP_dout[0] & !fifo_async_IN2CHIP_empty}) : 0;


fifo_async_fwft#(
    .DATA_WIDTH ( PORT_WIDTH + 2           ),
    .ADDR_WIDTH ( ASYNC_FIFO_ADDR_WIDTH )
)u_fifo_async_fwft_IN2CHIP(
    .rst_n      ( I_SysRst_n                ),
    .wr_clk     ( OffClk                    ),
    .rd_clk     ( clk                       ),
    .push       ( fifo_async_IN2CHIP_push   ),
    .pop        ( fifo_async_IN2CHIP_pop    ),
    .data_in    ( fifo_async_IN2CHIP_din    ),
    .data_out   ( fifo_async_IN2CHIP_dout   ),
    .empty      ( fifo_async_IN2CHIP_empty  ),
    .full       ( fifo_async_IN2CHIP_full   ) 
);

//=====================================================================================================================
// Sub-Module : OUT2OFF
//=====================================================================================================================
// PAD
assign {O_Dat, O_CmdVld, O_DatLast, O_DatVld}= (state_sync == OUT2OFF | state_sync == OUTWAIT)? ( I_BypAsysnFIFO? (MONITF_DatVld? {MONITF_Dat, 1'b0, MONITF_DatLast} : {GICITF_Dat, GICITF_CmdVld, GICITF_DatLast})
                                                                : {fifo_async_OUT2OFF_dout, !fifo_async_OUT2OFF_empty} ) 
                                            : { {PORT_WIDTH{1'b0}}, 1'b0, 1'b0, 1'b0};
assign fifo_async_OUT2OFF_pop   = (state_sync == OUT2OFF | state_sync == OUTWAIT) & !I_BypAsysnFIFO & I_DatRdy & !fifo_async_OUT2OFF_empty;

// GIC & MON
assign fifo_async_OUT2OFF_push = (state == OUT2OFF | state == OUTWAIT) & !I_BypAsysnFIFO & !fifo_async_OUT2OFF_full
                                    & (GICITF_DatVld & ITFGIC_DatRdy | MONITF_DatVld & ITFMON_DatRdy);
assign fifo_async_OUT2OFF_din  = (state == OUT2OFF | state == OUTWAIT)? MONITF_DatVld? {MONITF_Dat, 1'b0, MONITF_DatLast} : {GICITF_Dat, GICITF_CmdVld, GICITF_DatLast} : 0;

assign ITFGIC_DatRdy           = ((state == OUT2OFF | state == OUTWAIT) | MONITF_DatVld)? (I_BypAsysnFIFO? I_DatRdy : !fifo_async_OUT2OFF_full) : 1'b0;
assign ITFMON_DatRdy           = (state == OUT2OFF | state == OUTWAIT)? (I_BypAsysnFIFO? I_DatRdy : !fifo_async_OUT2OFF_full) : 1'b0;

fifo_async_fwft#(
    .DATA_WIDTH ( PORT_WIDTH + 2        ),
    .ADDR_WIDTH ( ASYNC_FIFO_ADDR_WIDTH )
)u_fifo_async_fwft_OUT2OFF(
    .rst_n      ( I_SysRst_n                ),
    .wr_clk     ( clk                       ),
    .rd_clk     ( OffClk                    ),
    .push       ( fifo_async_OUT2OFF_push   ),
    .pop        ( fifo_async_OUT2OFF_pop    ),
    .data_in    ( fifo_async_OUT2OFF_din    ),
    .data_out   ( fifo_async_OUT2OFF_dout   ),
    .empty      ( fifo_async_OUT2OFF_empty  ),
    .full       ( fifo_async_OUT2OFF_full   ) 
);
//=====================================================================================================================
// Logic Design: Monitor
//=====================================================================================================================

CLK#(
    .FBDIV_WIDTH ( FBDIV_WIDTH )
)u_CLK(
    .I_BypAsysnFIFO(I_BypAsysnFIFO),
    .I_BypPLL    ( I_BypPLL     ),
    .I_SwClk     ( I_SwClk      ),
    .I_SysRst_n  ( I_SysRst_n   ),
    .I_SysClk    ( I_SysClk     ),
    .I_OffClk    ( I_OffClk     ),
    .I_FBDIV     ( I_FBDIV      ),
    .SysRst_n    ( rst_n        ),
    .SysClk      ( clk          ),
    .OffClk      ( OffClk       ),
    .O_PLLLock   ( O_PLLLock    ) 
);

endmodule
