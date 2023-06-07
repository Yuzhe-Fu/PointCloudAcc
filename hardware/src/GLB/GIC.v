// This is a simpleCCUGIC_InOut example.
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
module GIC #(
    parameter GICISA_WIDTH      = 128*2,
    parameter PORT_WIDTH        = 128,
    parameter SRAM_WIDTH        = 256,
    parameter DRAM_ADDR_WIDTH   = 32,
    parameter ADDR_WIDTH        = 16,
    parameter BYTE_WIDTH        = 8,
    parameter GICMON_WIDTH      = GICISA_WIDTH + 3
    )(
    input                                               clk             ,
    input                                               rst_n           ,

    input                                               CCUGIC_CfgVld      ,
    output                                              GICCCU_CfgRdy      ,  
    input   [GICISA_WIDTH                       -1 : 0] CCUGIC_CfgInfo      ,

    output reg                                          GICITF_CmdVld   ,
    output [PORT_WIDTH                          -1 : 0] GICITF_Dat      ,
    output                                              GICITF_DatVld   ,
    output                                              GICITF_DatLast  ,
    input                                               ITFGIC_DatRdy   ,

    input  [PORT_WIDTH                          -1 : 0] ITFGIC_Dat      ,
    input                                               ITFGIC_DatVld   ,
    input                                               ITFGIC_DatLast   ,
    output                                              GICITF_DatRdy   ,

    output [ADDR_WIDTH                          -1 : 0] GICGLB_RdAddr    ,
    output                                              GICGLB_RdAddrVld ,
    input                                               GLBGIC_RdAddrRdy ,
    input  [SRAM_WIDTH                          -1 : 0] GLBGIC_RdDat     ,
    input                                               GLBGIC_RdDatVld  ,
    output                                              GICGLB_RdDatRdy  ,
    input                                               GLBGIC_RdEmpty   ,

    output [ADDR_WIDTH                          -1 : 0] GICGLB_WrAddr    ,
    output [SRAM_WIDTH                          -1 : 0] GICGLB_WrDat     , 
    output                                              GICGLB_WrDatVld  , 
    input                                               GLBGIC_WrDatRdy  ,
    input                                               GLBGIC_WrFull    ,

    output [GICMON_WIDTH                        -1 : 0] GICMON_Dat        

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
wire [ADDR_WIDTH    -1 : 0] CntGLBAddr;
wire [BYTE_WIDTH                         -1 : 0] CCUGIC_CfgInOut       ; // 0: IN2CHIP; 1: OUT2OFF
wire [DRAM_ADDR_WIDTH                    -1 : 0] CCUGIC_CfgDRAMBaseAddr;
wire [ADDR_WIDTH                         -1 : 0] CCUGIC_CfgGLBBaseAddr ;
wire [ADDR_WIDTH                         -1 : 0] CCUGIC_CfgNum         ; 

//=====================================================================================================================
// Logic Design: ISA Decode
//=====================================================================================================================
assign {
CCUGIC_CfgGLBBaseAddr   , // 16
CCUGIC_CfgDRAMBaseAddr  , // 32
CCUGIC_CfgNum           , // 16
CCUGIC_CfgInOut           // 8 0: IN2CHIP; 1: OUT2OFF
} = CCUGIC_CfgInfo[GICISA_WIDTH -1 : 8];

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================
reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if( CCUGIC_CfgVld ) // Start
                    next_state <= CMD;
                else
                    next_state <= IDLE;
        CMD :   if(CCUGIC_CfgVld)
                    next_state <= IDLE;
                else if( CmdRdy & CmdVld) begin
                    if ( CCUGIC_CfgInOut == 1)
                        next_state <= OUT2OFF;
                    else
                        next_state <= IN2CHIP;
                end else
                    next_state <= CMD;
        IN2CHIP:if(CCUGIC_CfgVld)
                    next_state <= IDLE;
                else if( (CntGLBAddr == CCUGIC_CfgNum -1 | ITFGIC_DatLast) & (GICGLB_WrDatVld & GLBGIC_WrDatRdy) ) // End
                    next_state <= IDLE;
                else
                    next_state <= IN2CHIP;
        OUT2OFF:if(CCUGIC_CfgVld)
                    next_state <= IDLE;
                else if( CntGLBAddr == CCUGIC_CfgNum -1  & (GLBGIC_RdDatVld & GICGLB_RdDatRdy) ) // fetched by Off-chip
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
assign GICCCU_CfgRdy = state == IDLE;

// HandShake
assign CmdVld = state == CMD;

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        Cmd <= {PORT_WIDTH{1'b0}};
    end else if ( state == IDLE )begin 
        Cmd <= {PORT_WIDTH{1'b0}};
    end else if(state == IDLE && next_state == CMD) begin
        Cmd <= {CCUGIC_CfgNum, CCUGIC_CfgDRAMBaseAddr, CCUGIC_CfgInOut[0]};
    end
end

assign GICITF_CmdVld = state == CMD;

//=====================================================================================================================
// Logic Design: // Input to on-chip
//=====================================================================================================================
// Combinational Logic
assign GICITF_DatRdy = state == IN2CHIP & GLBGIC_WrDatRdy;

assign GICGLB_WrDat     = state == IN2CHIP? ITFGIC_Dat   : 0;
assign GICGLB_WrDatVld  = state == IN2CHIP? ITFGIC_DatVld: 0;
assign GICGLB_WrAddr    = CntGLBAddr;

wire [ADDR_WIDTH     -1 : 0] MaxCnt= 2**ADDR_WIDTH - 1;
counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u_counter_CntGLBAddr(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state == IDLE  ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
    .INC       ( (GICGLB_WrDatVld & GLBGIC_WrDatRdy) | GICGLB_RdAddrVld & GLBGIC_RdAddrRdy),
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
assign GICGLB_RdAddr    = CntGLBAddr; 
assign GICGLB_RdAddrVld = state == OUT2OFF & CntGLBAddr < CCUGIC_CfgNum; 
assign GICGLB_RdDatRdy  = ITFGIC_DatRdy & state == OUT2OFF;

assign GICITF_Dat       = state==CMD? Cmd   : GLBGIC_RdDat;
assign GICITF_DatVld    = state==CMD? CmdVld: GLBGIC_RdDatVld;
assign GICITF_DatLast   = GICITF_DatVld & CntGLBAddr == CCUGIC_CfgNum -1;

assign CmdRdy           = ITFGIC_DatRdy;

//=====================================================================================================================
// Debug
//=====================================================================================================================
wire Debug_IO_Uti;
assign Debug_IO_Uti = (GICITF_DatVld & ITFGIC_DatRdy) | (ITFGIC_DatVld & GICITF_DatRdy);

//=====================================================================================================================
// Logic Design : Monitor
//=====================================================================================================================
assign GICMON_Dat = {
CCUGIC_CfgVld   ,
GICCCU_CfgRdy   , 
GICITF_CmdVld   ,
GICITF_DatVld   ,
GICITF_DatLast  ,
ITFGIC_DatRdy   ,
ITFGIC_DatVld   ,
ITFGIC_DatLast  ,
GICITF_DatRdy   ,
GICGLB_RdAddrVld,
GLBGIC_RdAddrRdy,
GLBGIC_RdDatVld ,
GICGLB_RdDatRdy ,
GLBGIC_RdEmpty  ,
GICGLB_WrDatVld , 
GLBGIC_WrDatRdy ,
GLBGIC_WrFull   ,
CntGLBAddr      ,
CCUGIC_CfgInfo  ,
state           
};

endmodule
