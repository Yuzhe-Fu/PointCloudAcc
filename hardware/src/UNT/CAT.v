// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : zhouchch@pku.edu.cn
// File   : CAT.v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------
module CAT #(
    parameter SRAM_WIDTH    = 256,
    parameter ADDR_WIDTH    = 16,  
    parameter CATISA_WIDTH  = 128  
    )(
    input                               clk                     ,
    input                               rst_n                   ,

    // Configure
    input                                       CCUCAT_CfgVld           ,
    output                                      CATCCU_CfgRdy           ,
    input  [CATISA_WIDTH                -1 : 0] CCUCAT_CfgInfo          ,

    output [ADDR_WIDTH                  -1 : 0] CATGLB_Ele0RdAddr       ,
    output                                      CATGLB_Ele0RdAddrVld    ,
    input                                       GLBCAT_Ele0RdAddrRdy    ,
    input  [SRAM_WIDTH                  -1 : 0] GLBCAT_Ele0RdDat        ,    
    input                                       GLBCAT_Ele0RdDatVld     ,    
    output                                      CATGLB_Ele0RdDatRdy     ,    
    output [ADDR_WIDTH                  -1 : 0] CATGLB_Ele1RdAddr       ,
    output                                      CATGLB_Ele1RdAddrVld    ,
    input                                       GLBCAT_Ele1RdAddrRdy    ,
    input  [SRAM_WIDTH                  -1 : 0] GLBCAT_Ele1RdDat        ,    
    input                                       GLBCAT_Ele1RdDatVld     ,    
    output                                      CATGLB_Ele1RdDatRdy     ,     
    output [ADDR_WIDTH                  -1 : 0] CATGLB_CatWrAddr        ,
    output [SRAM_WIDTH                  -1 : 0] CATGLB_CatWrDat         ,   
    output                                      CATGLB_CatWrDatVld      ,
    input                                       GLBCAT_CatWrDatRdy       

);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE    = 3'b000;
localparam COMP    = 3'b010;
localparam WAITFNH = 3'b100;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [SRAM_WIDTH  -1 : 0] Ele;
reg  [SRAM_WIDTH  -1 : 0] Cat;

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
wire [ADDR_WIDTH                -1 : 0] CntAddr;
reg  [ADDR_WIDTH                -1 : 0] CntAddr_s1;
reg  [ADDR_WIDTH                -1 : 0] CntAddr_s2;
wire                                    sel;
reg                                     sel_s1;

wire [ADDR_WIDTH                -1 : 0] CCUCAT_CfgEle0Addr;
wire [ADDR_WIDTH                -1 : 0] CCUCAT_CfgEle1Addr;
wire [ADDR_WIDTH                -1 : 0] CCUCAT_CfgCatAddr;
wire [ADDR_WIDTH                -1 : 0] CCUCAT_CfgWord0;
wire [ADDR_WIDTH                -1 : 0] CCUCAT_CfgNumPnt;

//=====================================================================================================================
// Logic Design: Cfg
//=====================================================================================================================
assign {
    CCUCAT_CfgEle0Addr  ,
    CCUCAT_CfgEle1Addr  ,
    CCUCAT_CfgCatAddr   ,
    CCUCAT_CfgWord1     , // How many words occupied by all channels
    CCUCAT_CfgWord0     , // 
    CCUCAT_CfgNumPnt         // How many points
} = CCUCAT_CfgInfo[12 +: ADDR_WIDTH*4];

//=====================================================================================================================
// Logic Design: FSM
//=====================================================================================================================
reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]state_s1;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE :  if(CATCCU_CfgRdy & CCUCAT_CfgVld)// 
                    next_state <= COMP; //
                else
                    next_state <= IDLE;

        COMP:   if(CCUCAT_CfgVld)
                    next_state <= IDLE;
                else if( overflow_CntAddr & handshake_s0 ) // wait pipeline finishing
                    next_state <= WAITFNH;
                else
                    next_state <= COMP;

        WAITFNH:if(CCUCAT_CfgVld)
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

assign CATCCU_CfgRdy = state==IDLE;

//=====================================================================================================================
// Logic Design: s0
//=====================================================================================================================
assign rdy_s0       = sel? GLBCAT_Ele0RdAddrRdy : GLBCAT_Ele1RdAddrRdy;
assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0       = handshake_s0 | ~vld_s0;

assign vld_s0 = state == COMP;

wire [ADDR_WIDTH    -1 : 0] TotalWord = CCUCAT_CfgWord0 + CCUCAT_CfgWord1;
wire [ADDR_WIDTH     -1 : 0] MaxCntAddr = TotalWord*CCUCAT_CfgNumPnt -1;
counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u0_counter_CntAddr(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state == IDLE  ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
    .INC       ( handshake_s0   ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
    .MAX_COUNT (  MaxCntAddr    ),
    .OVERFLOW  ( overflow_CntAddr),
    .UNDERFLOW (                ),
    .COUNT     ( CntAddr        )
);
assign sel = CntAddr % TotalWord < CCUCAT_CfgWord0;
assign CATGLB_Ele0RdAddr = CCUCAT_CfgEle0Addr + CCUCAT_CfgWord0*(CntAddr/TotalWord) + CntAddr % TotalWord;
assign CATGLB_Ele1RdAddr = CCUCAT_CfgEle1Addr + CCUCAT_CfgWord1*(CntAddr/TotalWord) + (CntAddr % TotalWord - CCUCAT_CfgWord0);

assign CATGLB_Ele0RdAddrVld = vld_s0 &  sel;
assign CATGLB_Ele1RdAddrVld = vld_s0 & !sel;

//=====================================================================================================================
// Logic Design: s1
//=====================================================================================================================
assign rdy_s1       = ena_s2;
assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1       = handshake_s1 | ~vld_s1;
assign vld_s1       = sel_s1? GLBCAT_Ele0RdDatVld : GLBCAT_Ele1RdDatVld;

assign Ele             = sel_s1? GLBCAT_Ele0RdDat : GLBCAT_Ele1RdDat;

assign CATGLB_Ele0RdDatRdy = rdy_s1 & sel_s1;
assign CATGLB_Ele1RdDatRdy = rdy_s1 & !sel_s1;

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        overflow_CntAddr_s1 <= 0;
        sel_s1              <= 0;
        CntAddr_s1          <= 0;
    end else if( state == IDLE) begin
        overflow_CntAddr_s1 <= 0;
        sel_s1              <= 0;
        CntAddr_s1          <= 0;
    end else if(ena_s1) begin
        overflow_CntAddr_s1 <= overflow_CntAddr;
        sel_s1              <= sel;
        CntAddr_s1          <= CntAddr;
    end
end

//=====================================================================================================================
// Logic Design: s2
//=====================================================================================================================
assign rdy_s2       = GLBCAT_CatWrDatRdy;
assign handshake_s2 = rdy_s2 & vld_s2;
assign ena_s2       = handshake_s2 | ~vld_s2;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        Cat <= 0;
    end else if( state == IDLE ) begin
        Cat <= 0;
    end else if(handshake_s1) begin
        Cat <= Ele;
    end
    
end

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        vld_s2              <= 0;
        overflow_CntAddr_s2 <= 0;
        CntAddr_s2          <= 0;
    end else if( state == IDLE) begin
        vld_s2              <= 0;
        overflow_CntAddr_s2 <= 0;
        CntAddr_s2          <= 0;
    end else if(ena_s2) begin
        vld_s2              <= handshake_s1;
        overflow_CntAddr_s2 <= overflow_CntAddr_s1;
        CntAddr_s2          <= CntAddr_s1;
    end
end

assign CATGLB_CatWrDat      = Cat;
assign CATGLB_CatWrAddr     = CCUCAT_CfgCatAddr + CntAddr_s2;
assign CATGLB_CatWrDatVld   = vld_s2;

endmodule
