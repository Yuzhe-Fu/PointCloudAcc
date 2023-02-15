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

    parameter ITF_NUM_RDPORT    = 2,
    parameter ITF_NUM_WRPORT    = 4

    )(
    input                                               clk             ,
    input                                               rst_n           ,
    output                                              ITFPAD_DatOE    ,
    output reg                                          ITFPAD_CmdVld    ,
    output [PORT_WIDTH                          -1 : 0] ITFPAD_Dat      ,
    output                                              ITFPAD_DatVld   ,
    input                                               PADITF_DatRdy   ,

    input  [PORT_WIDTH                          -1 : 0] PADITF_Dat      ,
    input                                               PADITF_DatVld   ,
    output                                              ITFPAD_DatRdy   ,

    input  [(ITF_NUM_RDPORT+ITF_NUM_WRPORT)-1 : 0][DRAM_ADDR_WIDTH-1 : 0] CCUITF_DRAMBaseAddr,
    input                                               CCUITF_Rst,

    output [ITF_NUM_RDPORT  -1 : 0][ADDR_WIDTH      -1 : 0] ITFGLB_RdAddr    ,
    output [ITF_NUM_RDPORT                          -1 : 0] ITFGLB_RdAddrVld ,
    input  [ITF_NUM_RDPORT                          -1 : 0] GLBITF_RdAddrRdy ,
    input  [ITF_NUM_RDPORT  -1 : 0][SRAM_WIDTH      -1 : 0] GLBITF_RdDat     ,
    input  [ITF_NUM_RDPORT                          -1 : 0] GLBITF_RdDatVld  ,
    output [ITF_NUM_RDPORT                          -1 : 0] ITFGLB_RdDatRdy  ,
    input  [ITF_NUM_RDPORT                          -1 : 0] GLBITF_RdEmpty   ,

    output [ITF_NUM_WRPORT  -1 : 0][ADDR_WIDTH      -1 : 0] ITFGLB_WrAddr    ,
    output [ITF_NUM_WRPORT  -1 : 0][SRAM_WIDTH      -1 : 0] ITFGLB_WrDat     , 
    output [ITF_NUM_WRPORT                          -1 : 0] ITFGLB_WrDatVld  , 
    input  [ITF_NUM_WRPORT                          -1 : 0] GLBITF_WrDatRdy  ,
    input  [ITF_NUM_WRPORT                          -1 : 0] GLBITF_WrFull    

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE     = 3'b000;
localparam CMD      = 3'b001;
localparam IN2CHIP  = 3'b010;
localparam OUT2OFF  = 3'b011;

localparam NUMPORT_WIDTH = $clog2(ITF_NUM_WRPORT + ITF_NUM_RDPORT);
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg  [PORT_WIDTH    -1 : 0] Cmd;
wire                        CmdRdy;
wire                        CmdVld;
wire                        Out2Off;
reg [NUMPORT_WIDTH  -1 : 0] PortIdx_;
reg [NUMPORT_WIDTH  -1 : 0] PortIdx;
wire [SRAM_WIDTH    -1 : 0] DatIn;
wire                        DatInVld;
wire                        DatInRdy;
wire [PORT_WIDTH    -1 : 0] DatOut;
wire                        DatOutVld;
wire                        DatOutRdy;
wire [NUMPORT_WIDTH -1 : 0] WrPort;
wire                        PISO_OUTRdy;

wire [(ITF_NUM_WRPORT + ITF_NUM_RDPORT) -1 : 0] gnt;

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if( |gnt ) // Start
                    next_state <= CMD;
                else
                    next_state <= IDLE;
        CMD :   if( CmdRdy & CmdVld) begin
                    if ( PortIdx_ >= ITF_NUM_WRPORT)
                        next_state <= OUT2OFF;
                    else
                        next_state <= IN2CHIP;
                end else
                    next_state <= CMD;
        IN2CHIP:   if( GLBITF_WrFull[PortIdx] ) // End
                    next_state <= IDLE;
                else
                    next_state <= IN2CHIP;
        OUT2OFF:   if(GLBITF_RdEmpty[PortIdx - ITF_NUM_WRPORT] & !DatOutVld ) // End: Rdy->0 & Dat is fetched by Off-chip
                    next_state <= IDLE;
                else
                    next_state <= OUT2OFF;
        default:    next_state <= IDLE;
    endcase
end
always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else if( CCUITF_Rst ) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

//=====================================================================================================================
// Logic Design:
//=====================================================================================================================

// Combinational Logic
RR_arbiter #(
    .REQ_WIDTH ( ITF_NUM_RDPORT + ITF_NUM_WRPORT )
)u_RR_arbiter_Port(
    .clk        ( clk       ),
    .rst_n      ( rst_n     ),
    .req        ( {GLBITF_RdAddrRdy, GLBITF_WrDatRdy} ),
    .gnt        ( gnt       ),
    .arb_port   ( PortIdx_  )
);

// HandShake
assign CmdVld = state == CMD;

// Reg Update
wire [(ITF_NUM_RDPORT + ITF_NUM_WRPORT)  -1 : 0][ADDR_WIDTH  -1 : 0] GLBPort_Addr_Array;
assign GLBPort_Addr_Array = {ITFGLB_RdAddr, ITFGLB_WrAddr};
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {Cmd, PortIdx} <= { {PORT_WIDTH{1'b0}}, { {NUMPORT_WIDTH{1'b1}}} };
    end else if ( CCUITF_Rst )begin 
        {Cmd, PortIdx} <= { {PORT_WIDTH{1'b0}}, { {NUMPORT_WIDTH{1'b1}}} };
    end else if(state == IDLE && next_state == CMD) begin
        {Cmd, PortIdx} <= { {CCUITF_DRAMBaseAddr[PortIdx_] + GLBPort_Addr_Array[PortIdx_], PortIdx_ >= ITF_NUM_WRPORT}, 
        PortIdx_};
    end
end

assign ITFPAD_DatOE = state == CMD | state == OUT2OFF;
assign ITFPAD_CmdVld = state == CMD;

//=====================================================================================================================
// Logic Design: // Input to on-chip
//=====================================================================================================================
// Combinational Logic
SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH     ),
    .DATA_OUT_WIDTH ( SRAM_WIDTH    )
)u_SIPO_IN2CHIP(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .IN_VLD       ( PADITF_DatVld & state == IN2CHIP  ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( PADITF_Dat     ),
    .IN_RDY       ( ITFPAD_DatRdy  ),
    .OUT_DAT      ( DatIn          ),
    .OUT_VLD      ( DatInVld       ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( DatInRdy       )
);
assign DatInRdy = state == IN2CHIP & GLBITF_WrDatRdy[PortIdx];

genvar i;
generate
    for(i=0; i<ITF_NUM_WRPORT; i=i+1) begin: GEN_WRGLB // state ==IN2CHIP and portidx match
        wire [ADDR_WIDTH        -1 : 0] CntWrAddr;
        assign ITFGLB_WrDat[i] = (state == IN2CHIP  && i==PortIdx ? DatIn : 0);
        assign ITFGLB_WrDatVld[i] = (state == IN2CHIP  && i==PortIdx ? DatInVld : 0);

        assign ITFGLB_WrAddr[i] = CntWrAddr;

        wire [ADDR_WIDTH     -1 : 0] MaxCnt= 2**ADDR_WIDTH - 1;
        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_CntWrAddr(
            .CLK       ( clk            ),
            .RESET_N   ( rst_n          ),
            .CLEAR     ( CCUITF_Rst     ),
            .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
            .INC       ( ITFGLB_WrDatVld[i] & GLBITF_WrDatRdy[i] ),
            .DEC       ( 1'b0           ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
            .MAX_COUNT ( MaxCnt         ),
            .OVERFLOW  (                ),
            .UNDERFLOW (                ),
            .COUNT     ( CntWrAddr      )
        ); 
    end
endgenerate

//=====================================================================================================================
// Logic Design: Out to off-chip
//=====================================================================================================================

genvar gv_i;
generate
    for(gv_i=0; gv_i<ITF_NUM_RDPORT; gv_i=gv_i+1) begin: GEN_RDGLB
        wire [ADDR_WIDTH            -1 : 0] CntRdAddr;
        assign ITFGLB_RdAddr[gv_i] = CntRdAddr; 
        assign ITFGLB_RdAddrVld[gv_i] = state == OUT2OFF & ( (PortIdx-ITF_NUM_WRPORT) == gv_i ); 

        assign ITFGLB_RdDatRdy[gv_i]    = (PISO_OUTRdy & state == OUT2OFF) & ( (PortIdx-ITF_NUM_WRPORT) == gv_i );

        wire [ADDR_WIDTH     -1 : 0] MaxCnt= 2**ADDR_WIDTH - 1;
        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_CntRdAddr(
            .CLK       ( clk            ),
            .RESET_N   ( rst_n          ),
            .CLEAR     ( CCUITF_Rst     ),
            .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
            .INC       ( ITFGLB_RdAddrVld[gv_i] & GLBITF_RdAddrRdy[gv_i] ),
            .DEC       ( 1'b0           ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
            .MAX_COUNT ( MaxCnt         ),
            .OVERFLOW  (                ),
            .UNDERFLOW (                ),
            .COUNT     ( CntRdAddr      )
        ); 
    end
endgenerate

PISO_NOCACHE #(
    .DATA_IN_WIDTH ( SRAM_WIDTH ),
    .DATA_OUT_WIDTH ( PORT_WIDTH )
)u_PISO_OUT2OFF(
    .CLK          ( clk         ),
    .RST_N        ( rst_n       ),
    .IN_VLD       ( state == OUT2OFF & GLBITF_RdDatVld[PortIdx-ITF_NUM_WRPORT]),
    .IN_LAST      ( 1'b0        ),
    .IN_DAT       ( GLBITF_RdDat[PortIdx-ITF_NUM_WRPORT]),
    .IN_RDY       ( PISO_OUTRdy ),
    .OUT_DAT      ( DatOut      ), // On-chip output to Off-chip 
    .OUT_VLD      ( DatOutVld   ),
    .OUT_LAST     (             ),
    .OUT_RDY      ( DatOutRdy   )
);
assign ITFPAD_Dat       = state==CMD? Cmd : DatOut;
assign ITFPAD_DatVld    = state==CMD? CmdVld : DatOutVld;
assign DatOutRdy        = PADITF_DatRdy;
assign CmdRdy           = PADITF_DatRdy;

// Reg Update

//=====================================================================================================================
// Debug
//=====================================================================================================================
wire Debug_IO_Uti;
assign Debug_IO_Uti = (ITFPAD_DatVld & PADITF_DatRdy) | (PADITF_DatVld & ITFPAD_DatRdy);

endmodule
