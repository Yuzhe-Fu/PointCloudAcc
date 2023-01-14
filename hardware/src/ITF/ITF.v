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
module ITF #(
    parameter PORT_WIDTH        = 128,
    parameter SRAM_WIDTH        = 256,
    parameter DRAM_ADDR_WIDTH   = 32,
    parameter ADDR_WIDTH        = 16,

    parameter ITF_NUM_RDPORT = 2,
    parameter ITF_NUM_WRPORT = 4

    )(
    input                                               clk  ,
    input                                               rst_n,
    output reg                                          ITFPAD_DatOE,
    output [PORT_WIDTH                          -1 : 0] ITFPAD_Dat     ,
    output                                              ITFPAD_DatVld  ,
    output                                              ITFPAD_DatLast ,
    input                                               PADITF_DatRdy  ,

    input  [PORT_WIDTH                          -1 : 0] PADITF_Dat     ,
    input                                               PADITF_DatVld  ,
    input                                               PADITF_DatLast ,
    output                                              ITFPAD_DatRdy  ,

    input  [1*(ITF_NUM_RDPORT+ITF_NUM_WRPORT)           -1 : 0] TOPITF_EmptyFull, 
    input  [ADDR_WIDTH*(ITF_NUM_RDPORT+ITF_NUM_WRPORT)  -1 : 0] TOPITF_ReqNum  ,
    input  [ADDR_WIDTH*(ITF_NUM_RDPORT+ITF_NUM_WRPORT)  -1 : 0] TOPITF_Addr    ,
    input  [DRAM_ADDR_WIDTH*(ITF_NUM_RDPORT+ITF_NUM_WRPORT)  -1 : 0] CCUITF_BaseAddr,

    input  [SRAM_WIDTH*ITF_NUM_RDPORT               -1 : 0] TOPITF_Dat     ,
    input  [ITF_NUM_RDPORT                          -1 : 0] TOPITF_DatVld  ,
    output [ITF_NUM_RDPORT                          -1 : 0] ITFTOP_DatRdy  ,

    output [SRAM_WIDTH*ITF_NUM_WRPORT               -1 : 0] ITFTOP_Dat    , 
    output [ITF_NUM_WRPORT                          -1 : 0] ITFTOP_DatVld , 
    output [ITF_NUM_WRPORT                          -1 : 0] ITFTOP_DatLast , 
    input  [ITF_NUM_WRPORT                          -1 : 0] TOPITF_DatRdy   

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE = 3'b000;
localparam CMD  = 3'b001;
localparam IN   = 3'b010;
localparam OUT  = 3'b011;
localparam FNH  = 3'b100;

localparam NUMPORT_WIDTH = $clog2(ITF_NUM_WRPORT + ITF_NUM_RDPORT);
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg  [PORT_WIDTH    -1 : 0] Cmd;
wire                        CmdRdy;
wire                        CmdVld;
wire                        RdTOP;
wire [$clog2(ITF_NUM_WRPORT + ITF_NUM_RDPORT)   -1 : 0] ArbEmptyFullIdx;
reg [NUMPORT_WIDTH      : 0] PortIdx_;
reg [NUMPORT_WIDTH      : 0] PortIdx;

wire [NUMPORT_WIDTH -1 : 0] MaxIdx;
wire [ADDR_WIDTH    -1 : 0] MaxNum;

wire [SRAM_WIDTH    -1 : 0] DatIn;
wire                        DatInVld;
wire                        DatInLast;
wire                        DatInRdy;
wire [PORT_WIDTH    -1 : 0] DatOut;
wire                        DatOutVld;
wire                        DatOutLast;
wire                        DatOutRdy;

wire [NUMPORT_WIDTH -1 : 0] WrPort;

wire                        PISO_OUTRdy;

wire                        IntraTOPITF_DatLast;
wire                        CntOverflow;
wire                        CntInc;
reg  [ADDR_WIDTH     -1 : 0] InOutNum_s1;

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if( PortIdx_ != -1 )
                    next_state <= CMD;
                else
                    next_state <= IDLE;
        CMD :   if( CmdRdy & CmdVld) begin
                    if ( RdTOP)
                        next_state <= OUT;
                    else
                        next_state <= IN;
                end else
                    next_state <= CMD;
        IN:   if( DatInVld & DatInLast & DatInRdy )
                    next_state <= FNH;
                else
                    next_state <= IN;
        OUT:   if(ITFPAD_DatVld & ITFPAD_DatLast & PADITF_DatRdy )
                    next_state <= FNH;
                else
                    next_state <= OUT;
        FNH:   if( 1'b1 )
                    next_state <= IDLE;
                else
                    next_state <= FNH;
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
// Logic Design: s1
//=====================================================================================================================

// Combinational Logic
MINMAX # (
    .DATA_WIDTH (ADDR_WIDTH),
    .PORT(ITF_NUM_RDPORT+ITF_NUM_WRPORT),
    .MINMAX(1)
)u_MAX_REQNUM(
    .IN (TOPITF_ReqNum),
    .IDX(MaxIdx),
    .VALUE(MaxNum)
);

always @(*) begin
    PortIdx_ = -1;
    if (TOPITF_ReqNum[0 +: ADDR_WIDTH] !=0) begin// CCU
        PortIdx_ = 0; // Update
    end else if( |TOPITF_EmptyFull ) begin
        PortIdx_ = ArbEmptyFullIdx;
    end else if( MaxNum != 0 ) begin
        PortIdx_ = MaxIdx;
    end
end

prior_arb#(
    .REQ_WIDTH ( ITF_NUM_WRPORT + ITF_NUM_RDPORT )
)u_prior_arb_BankWrPortIdx(
    .req ( TOPITF_EmptyFull ),
    .gnt (  ),
    .arb_port  ( ArbEmptyFullIdx  )
);

// HandShake
assign CmdVld = state == CMD;

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {InOutNum_s1, Cmd, PortIdx} <= { {ADDR_WIDTH{1'b0}} , {PORT_WIDTH{1'b0}}, { {NUMPORT_WIDTH{1'b1}}, {1'b1} } };
    end else if(state == IDLE && next_state == CMD) begin
        {InOutNum_s1, Cmd, PortIdx} <= {TOPITF_ReqNum[ADDR_WIDTH*PortIdx +: ADDR_WIDTH], {TOPITF_ReqNum[ADDR_WIDTH*PortIdx_ +: ADDR_WIDTH], CCUITF_BaseAddr[DRAM_ADDR_WIDTH*PortIdx_ +: DRAM_ADDR_WIDTH] + TOPITF_Addr[ADDR_WIDTH*PortIdx_ +: ADDR_WIDTH], RdTOP}, PortIdx_};
    end
end

//=====================================================================================================================
// Logic Design: s2
//=====================================================================================================================
// Combinational Logic
assign RdTOP = PortIdx >= ITF_NUM_WRPORT;
assign ITFPAD_DatOE = state == CMD | state == OUT;

// Input to on-chip
SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH ),
    .DATA_OUT_WIDTH ( SRAM_WIDTH )
)u_SIPO_IN(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .IN_VLD       ( PADITF_DatVld & state == IN  ),
    .IN_LAST      ( PADITF_DatLast ),
    .IN_DAT       ( PADITF_Dat     ),
    .IN_RDY       ( ITFPAD_DatRdy  ),
    .OUT_DAT      ( DatIn          ), // Off-chip input to on-chip
    .OUT_VLD      ( DatInVld       ),
    .OUT_LAST     ( DatInLast      ),
    .OUT_RDY      ( DatInRdy       )
);

genvar i;
generate
    for(i=0; i<ITF_NUM_WRPORT; i=i+1) begin // state ==IN and portidx match
        assign ITFTOP_Dat[SRAM_WIDTH*i +: SRAM_WIDTH] = (state == IN  && i==PortIdx ? DatIn : 0);
        assign ITFTOP_DatVld[i] = (state == IN  && i==PortIdx ? DatInVld : 0);
        assign ITFTOP_DatLast[i]= (state == IN  && i==PortIdx ? DatInLast : 0);
    end
endgenerate

assign DatInRdy = state == IN & TOPITF_DatRdy[PortIdx];

// Out to off-chip
    // IntraTOPITF_DatLast
    wire [ADDR_WIDTH     -1 : 0] MAX_COUNT= InOutNum_s1 -1;
    assign CntInc = state == OUT & TOPITF_DatVld[PortIdx-ITF_NUM_WRPORT] & ITFTOP_DatRdy[PortIdx-ITF_NUM_WRPORT];
    counter#(
        .COUNT_WIDTH ( ADDR_WIDTH )
    )u_counter_RdPortCnt(
        .CLK       ( clk            ),
        .RESET_N   ( rst_n          ),
        .CLEAR     ( state == CMD   ),
        .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
        .INC       ( CntInc         ),
        .DEC       ( 1'b0           ),
        .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
        .MAX_COUNT ( MAX_COUNT    ),
        .OVERFLOW  ( CntOverflow    ),
        .UNDERFLOW (                ),
        .COUNT     (                )
    );

    assign IntraTOPITF_DatLast = state == OUT & CntOverflow & TOPITF_DatVld[PortIdx-ITF_NUM_WRPORT];


genvar gv_i;
generate
    for(gv_i=0; gv_i<ITF_NUM_RDPORT; gv_i=gv_i+1) begin
        assign ITFTOP_DatRdy[gv_i]    = (PISO_OUTRdy & state == OUT) & PortIdx == gv_i + ITF_NUM_WRPORT;
    end
endgenerate

PISO#(
    .DATA_IN_WIDTH ( SRAM_WIDTH ),
    .DATA_OUT_WIDTH ( PORT_WIDTH )
)u_PISO_OUT(
    .CLK          ( clk                        ),
    .RST_N        ( rst_n                      ),
    .IN_VLD       ( state == OUT & TOPITF_DatVld[PortIdx-ITF_NUM_WRPORT]),
    .IN_LAST      ( IntraTOPITF_DatLast),
    .IN_DAT       ( TOPITF_Dat[SRAM_WIDTH*(PortIdx-ITF_NUM_WRPORT) +: SRAM_WIDTH]),
    .IN_RDY       ( PISO_OUTRdy                ),
    .OUT_DAT      ( DatOut                     ), // On-chip output to Off-chip 
    .OUT_VLD      ( DatOutVld                  ),
    .OUT_LAST     ( DatOutLast                   ),
    .OUT_RDY      ( DatOutRdy                  )
);

assign ITFPAD_Dat       = state==CMD? Cmd : DatOut;
assign ITFPAD_DatVld    = state==CMD? CmdVld : DatOutVld;
assign ITFPAD_DatLast   = state==CMD? CmdVld : DatOutLast;
assign DatOutRdy        = PADITF_DatRdy;
assign CmdRdy           = PADITF_DatRdy;

// Reg Update


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================




//=====================================================================================================================
// Debug
//=====================================================================================================================
wire Debug_IO_Uti;
DEC2D #(
    .WIDTH(ADDR_WIDTH),
    .DEPTH(ITF_NUM_WRPORT+ITF_NUM_RDPORT)
) u_DEC2D_TOPITF_ReqNum(
    .IN(TOPITF_ReqNum)
);

assign Debug_IO_Uti = (ITFPAD_DatVld & PADITF_DatRdy) | (PADITF_DatVld & ITFPAD_DatRdy);

endmodule
