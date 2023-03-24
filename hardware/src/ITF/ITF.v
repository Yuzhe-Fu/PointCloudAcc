// This is a simpleCCUITF_InOut example.
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
    parameter BYTE_WIDTH        = 8
    )(
    input                                               clk             ,
    input                                               rst_n           ,

    input                                               CCUITF_CfgVld      ,
    output                                              ITFCCU_CfgRdy      ,  
    input   [BYTE_WIDTH                         -1 : 0] CCUITF_CfgInOut       , // 0: IN2CHIP; 1: OUT2OFF
    input   [DRAM_ADDR_WIDTH                    -1 : 0] CCUITF_CfgDRAMBaseAddr,
    input   [ADDR_WIDTH                         -1 : 0] CCUITF_CfgGLBBaseAddr ,
    input   [ADDR_WIDTH                         -1 : 0] CCUITF_CfgNum         , 

    output                                              ITFPAD_DatOE    ,
    output reg                                          ITFPAD_CmdVld   ,
    output [PORT_WIDTH                          -1 : 0] ITFPAD_Dat      ,
    output                                              ITFPAD_DatVld   ,
    input                                               PADITF_DatRdy   ,

    input  [PORT_WIDTH                          -1 : 0] PADITF_Dat      ,
    input                                               PADITF_DatVld   ,
    output                                              ITFPAD_DatRdy   ,

    output [ADDR_WIDTH                          -1 : 0] ITFGLB_RdAddr    ,
    output                                              ITFGLB_RdAddrVld ,
    input                                               GLBITF_RdAddrRdy ,
    input  [SRAM_WIDTH                          -1 : 0] GLBITF_RdDat     ,
    input                                               GLBITF_RdDatVld  ,
    output                                              ITFGLB_RdDatRdy  ,
    input                                               GLBITF_RdEmpty   ,

    output [ADDR_WIDTH                          -1 : 0] ITFGLB_WrAddr    ,
    output [SRAM_WIDTH                          -1 : 0] ITFGLB_WrDat     , 
    output                                              ITFGLB_WrDatVld  , 
    input                                               GLBITF_WrDatRdy  ,
    input                                               GLBITF_WrFull    

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE     = 3'b000;
localparam CMD      = 3'b001;
localparam IN2CHIP  = 3'b010;
localparam OUT2OFF  = 3'b011;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg  [PORT_WIDTH    -1 : 0] Cmd;
wire                        CmdRdy;
wire                        CmdVld;
wire                        Out2Off;
wire [SRAM_WIDTH    -1 : 0] DatIn;
wire                        DatInVld;
wire                        DatInRdy;
wire [PORT_WIDTH    -1 : 0] DatOut;
wire                        DatOutVld;
wire                        DatOutRdy;
wire                        PISO_OUTRdy;
wire [ADDR_WIDTH    -1 : 0] CntGLBAddr;

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================
reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if( CCUITF_CfgVld ) // Start
                    next_state <= CMD;
                else
                    next_state <= IDLE;
        CMD :   if(CCUITF_CfgVld)
                    next_state <= IDLE;
                else if( CmdRdy & CmdVld) begin
                    if ( CCUITF_CfgInOut == 1)
                        next_state <= OUT2OFF;
                    else
                        next_state <= IN2CHIP;
                end else
                    next_state <= CMD;
        IN2CHIP:if(CCUITF_CfgVld)
                    next_state <= IDLE;
                else if( CntGLBAddr == CCUITF_CfgNum ) // End
                    next_state <= IDLE;
                else
                    next_state <= IN2CHIP;
        OUT2OFF:if(CCUITF_CfgVld)
                    next_state <= IDLE;
                else if( CntGLBAddr == CCUITF_CfgNum & !DatOutVld ) // fetched by Off-chip
                    next_state <= IDLE;
                else
                    next_state <= OUT2OFF;
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
// Logic Design:
//=====================================================================================================================
// HandShake
assign CmdVld = state == CMD;

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        Cmd <= {PORT_WIDTH{1'b0}};
    end else if ( state == IDLE )begin 
        Cmd <= {PORT_WIDTH{1'b0}};
    end else if(state == IDLE && next_state == CMD) begin
        Cmd <= {CCUITF_CfgDRAMBaseAddr, CCUITF_CfgInOut[0]};
    end
end

assign ITFPAD_DatOE  = state == CMD | state == OUT2OFF;
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
    .IN_VLD       ( PADITF_DatVld & state == IN2CHIP ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( PADITF_Dat     ),
    .IN_RDY       ( ITFPAD_DatRdy  ),
    .OUT_DAT      ( DatIn          ),
    .OUT_VLD      ( DatInVld       ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( DatInRdy       )
);
assign DatInRdy = state == IN2CHIP & GLBITF_WrDatRdy;

assign ITFGLB_WrDat     = state == IN2CHIP? DatIn   : 0;
assign ITFGLB_WrDatVld  = state == IN2CHIP? DatInVld: 0;
assign ITFGLB_WrAddr    = CntGLBAddr;

wire [ADDR_WIDTH     -1 : 0] MaxCnt= 2**ADDR_WIDTH - 1;
counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u_counter_CntGLBAddr(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state == IDLE  ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
    .INC       ( (ITFGLB_WrDatVld & GLBITF_WrDatRdy) | ITFGLB_RdAddrVld & GLBITF_RdAddrRdy),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
    .MAX_COUNT ( MaxCnt         ),
    .OVERFLOW  (                ),
    .UNDERFLOW (                ),
    .COUNT     ( CntGLBAddr     )
); 

//=====================================================================================================================
// Logic Design: Out to off-chip
//=====================================================================================================================
assign ITFGLB_RdAddr    = CntGLBAddr; 
assign ITFGLB_RdAddrVld = state == OUT2OFF & CntGLBAddr < CCUITF_CfgNum; 
assign ITFGLB_RdDatRdy  = PISO_OUTRdy & state == OUT2OFF;

PISO_NOCACHE #(
    .DATA_IN_WIDTH ( SRAM_WIDTH ),
    .DATA_OUT_WIDTH ( PORT_WIDTH )
)u_PISO_OUT2OFF(
    .CLK          ( clk         ),
    .RST_N        ( rst_n       ),
    .IN_VLD       ( state == OUT2OFF & GLBITF_RdDatVld),
    .IN_LAST      ( 1'b0        ),
    .IN_DAT       ( GLBITF_RdDat),
    .IN_RDY       ( PISO_OUTRdy ),
    .OUT_DAT      ( DatOut      ), // On-chip output to Off-chip 
    .OUT_VLD      ( DatOutVld   ),
    .OUT_LAST     (             ),
    .OUT_RDY      ( DatOutRdy   )
);
assign ITFPAD_Dat       = state==CMD? Cmd   : DatOut;
assign ITFPAD_DatVld    = state==CMD? CmdVld: DatOutVld;
assign DatOutRdy        = PADITF_DatRdy;
assign CmdRdy           = PADITF_DatRdy;

// Reg Update

//=====================================================================================================================
// Debug
//=====================================================================================================================
wire Debug_IO_Uti;
assign Debug_IO_Uti = (ITFPAD_DatVld & PADITF_DatRdy) | (PADITF_DatVld & ITFPAD_DatRdy);

endmodule
