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
// File   : ADD.v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------
module ADD #( // Channel-wise Add
    parameter DATA_WIDTH        = 16,
    parameter SRAM_WIDTH        = 6,
    parameter ADDR_WIDTH        = 16,
    parameter ADDISA_WIDTH      = 128  
    )(
    input                                       clk                     ,
    input                                       rst_n                   ,

    // Configure
    input                                       CCUADD_CfgVld           ,
    output                                      ADDCCU_CfgRdy           ,
    input  [ADDISA_WIDTH                -1 : 0] CCUADD_CfgInfo          ,

    output [ADDR_WIDTH                  -1 : 0] ADDGLB_Add0RdAddr       ,
    output                                      ADDGLB_Add0RdAddrVld    ,
    input                                       GLBADD_Add0RdAddrRdy    ,
    input  [SRAM_WIDTH                  -1 : 0] GLBADD_Add0RdDat        ,    
    input                                       GLBADD_Add0RdDatVld     ,    
    output                                      ADDGLB_Add0RdDatRdy     ,    
    output [ADDR_WIDTH                  -1 : 0] ADDGLB_Add1RdAddr       ,
    output                                      ADDGLB_Add1RdAddrVld    ,
    input                                       GLBADD_Add1RdAddrRdy    ,
    input  [SRAM_WIDTH                  -1 : 0] GLBADD_Add1RdDat        ,    
    input                                       GLBADD_Add1RdDatVld     ,    
    output                                      ADDGLB_Add1RdDatRdy     ,     
    output [ADDR_WIDTH                  -1 : 0] ADDGLB_SumWrAddr        ,
    output [SRAM_WIDTH                  -1 : 0] ADDGLB_SumWrDat         ,   
    output                                      ADDGLB_SumWrDatVld      ,
    input                                       GLBADD_SumWrDatRdy       

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE    = 3'b000;
localparam COMP    = 3'b010;
localparam WAITFNH = 3'b100;

localparam NUM = SRAM_WIDTH / DATA_IN_WIDTH;
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [NUM   -1 : 0][DATA_WIDTH  -1 : 0] Add0;
wire [NUM   -1 : 0][DATA_WIDTH  -1 : 0] Add1;
reg  [NUM   -1 : 0][DATA_WIDTH  -1 : 0] Sum;

genvar                                  gv_i;
wire                                    overflow_CntAddr;
reg                                     overflow_CntAddr_s1;
reg                                     overflow_CntAddr_s2;
wire                                    rdy_s0;
wire                                    rdy_s1;
wire                                    rdy_s2;
wire                                    vld_s0;
wire                                    vld_s1;
reg                                     vld_s2;
wire                                    handshake_s0;
wire                                    handshake_s1;
wire                                    handshake_s2;
wire                                    ena_s0;
wire                                    ena_s1;
wire                                    ena_s2;
wire [IDX_WIDTH                 -1 : 0] CntAddr;

wire [ADDR_WIDTH                -1 : 0] CCUADD_CfgAdd0Addr;
wire [ADDR_WIDTH                -1 : 0] CCUADD_CfgAdd1Addr;
wire [ADDR_WIDTH                -1 : 0] CCUADD_CfgSumAddr;

//=====================================================================================================================
// Logic Design: FSM
//=====================================================================================================================
reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]state_s1;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE :  if(ADDCCU_CfgRdy & CCUADD_CfgVld)// 
                    next_state <= COMP; //
                else
                    next_state <= IDLE;

        COMP:   if(CCUADD_CfgVld)
                    next_state <= IDLE;
                else if( overflow_CntAddr & handshake_s0 ) // wait pipeline finishing
                    next_state <= WAITFNH;
                else
                    next_state <= COMP;

        WAITFNH:if(CCUADD_CfgVld)
                    next_state <= IDLE;
                else if (overflow_CntAddr_s2)
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

assign ADDCCU_CfgRdy = state==IDLE;

//=====================================================================================================================
// Logic Design: s0
//=====================================================================================================================
assign rdy_s0       = GLBADD_Add0RdAddrRdy & GLBADD_Add1RdAddrRdy;
assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0       = handshake_s0 | ~vld_s0;

assign vld_s0 = state == COMP;

wire [IDX_WIDTH     -1 : 0] MaxCntAddr = CCUADD_CfgNum -1;
counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u0_counter_CntAddr(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state == IDLE  ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}),
    .INC       ( handshake_s0   ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}),
    .MAX_COUNT (  MaxCntAddr    ),
    .OVERFLOW  ( overflow_CntAddr),
    .UNDERFLOW (                ),
    .COUNT     ( CntAddr        )
);

assign ADDGLB_Add0RdAddr = CCUADD_CfgAdd0Addr + CntAddr;
assign ADDGLB_Add1RdAddr = CCUADD_CfgAdd1Addr + CntAddr;

assign ADDGLB_Add0RdAddrVld = vld_s0 & GLBADD_Add1RdAddrRdy;
assign ADDGLB_Add1RdAddrVld = vld_s0 & GLBADD_Add0RdAddrRdy;

//=====================================================================================================================
// Logic Design: s1
//=====================================================================================================================
assign rdy_s1       = ena_s1;
assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1       = handshake_s1 | ~vld_s1;
assign vld_s1       = GLBADD_Add0RdDatVld & GLBADD_Add1RdDatVld;

assign Add0             = GLBADD_Add0RdDat;
assign Add1             = GLBADD_Add1RdDat;

assign ADDGLB_Add0RdDatRdy = rdy_s1 & GLBADD_Add1RdDatVld;
assign ADDGLB_Add1RdDatRdy = rdy_s1 & GLBADD_Add0RdDatVld;

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        overflow_CntAddr_s1 <= 0;
    end else if( state == IDLE) begin
        overflow_CntAddr_s1 <= 0;
    end else if(ena_s1) begin
        overflow_CntAddr_s1 <= overflow_CntAddr;
    end
end

//=====================================================================================================================
// Logic Design: s2
//=====================================================================================================================
assign rdy_s2       = GLBADD_SumWrDatRdy;
assign handshake_s2 = rdy_s2 & vld_s2;
assign ena_s2       = handshake_s2 | ~vld_s2;

generate
    for(gv_i=0; gv_i< ; gv_i=gv_i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                Sum[gv_i] <= 0;
            end else if( state == IDLE ) begin
                Sum[gv_i] <= 0;
            end else if(handshake_s1) begin
                Sum[gv_i] <= Add0[gv_i] + Add1[gv_i];
            end
            
        end
    end
    always @ ( posedge clk or negedge rst_n ) begin
        if ( !rst_n ) begin
            vld_s2 <= 0;
            overflow_CntAddr_s2 <= 0;
        end else if( state == IDLE) begin
            vld_s2 <= 0;
            overflow_CntAddr_s2 <= 0;
        end else if(ena_s2) begin
            vld_s2 <= handshake_s1;
            overflow_CntAddr_s2 <= overflow_CntAddr_s1;
        end
    end
    
endgenerate

assign ADDGLB_SumWrDat      = Sum;
assign ADDGLB_SumWrAddr     = CCUADD_CfgSumAddr + CntAddr;
assign ADDGLB_SumWrDatVld   = vld_s2;

endmodule
