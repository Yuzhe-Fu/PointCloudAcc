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
module KNN #(
    parameter SRAM_WIDTH        = 256,
    parameter IDX_WIDTH         = 16,
    parameter MAP_WIDTH         = 5,
    parameter CRD_WIDTH         = 16,
    parameter CRD_DIM           = 3, 
    parameter DISTSQR_WIDTH     = CRD_WIDTH*2 + $clog2(CRD_DIM),
    parameter NUM_SORT_CORE     = 5,
    parameter MASK_ADDR_WIDTH   = $clog2(2**IDX_WIDTH*NUM_SORT_CORE/SRAM_WIDTH)
    )(
    input                               clk                 ,
    input                               rst_n               ,

    // Configure
    input                               CCUKNN_Rst          ,
    input                               CCUKNN_CfgVld       ,
    output                              KNNCCU_CfgRdy       ,
    input [IDX_WIDTH            -1 : 0] CCUKNN_CfgNip       ,
    input [(MAP_WIDTH + 1)      -1 : 0] CCUKNN_CfgK         , 
    input [IDX_WIDTH            -1 : 0] CCUKNN_CfgCrdRdAddr ,
    input [IDX_WIDTH            -1 : 0] CCUKNN_CfgMapWrAddr ,

    // Fetch Crd
    output [IDX_WIDTH           -1 : 0] KNNGLB_CrdRdAddr    ,   
    output                              KNNGLB_CrdRdAddrVld , 
    input                               GLBKNN_CrdRdAddrRdy ,
    input  [SRAM_WIDTH          -1 : 0 ]GLBKNN_CrdRdDat     ,        
    input                               GLBKNN_CrdRdDatVld  ,     
    output                              KNNGLB_CrdRdDatRdy  ,

    // Output Map of KNN
    output [IDX_WIDTH           -1 : 0] KNNGLB_MapWrAddr    ,
    output [SRAM_WIDTH          -1 : 0] KNNGLB_MapWrDat     ,   
    output                              KNNGLB_MapWrDatVld  ,     
    input                               GLBKNN_MapWrDatRdy        
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE   = 3'b000;
localparam CP     = 3'b001;
localparam LP     = 3'b010;
localparam WAITFNH= 3'b011;

localparam SORT_LEN=2**MAP_WIDTH;
localparam NUM_SRAMWORD_MAP = (IDX_WIDTH*SORT_LEN)%SRAM_WIDTH == 0? (IDX_WIDTH*SORT_LEN)/SRAM_WIDTH : (IDX_WIDTH*SORT_LEN)/SRAM_WIDTH + 1;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

wire[IDX_WIDTH          -1 : 0] CntCpCrdRdAddr;  
reg [IDX_WIDTH          -1 : 0] CntCpCrdRdAddr_s1;  
wire                            CntCpCrdRdAddrLast;
reg                             CpLast_s1;
reg                             CpLast_s2;

wire                            CntCrdRdAddrLast;
reg                             CntCpCrdRdAddrLast_s1;
reg                             CntCpCrdRdAddrLast_s2;
reg                             CntLopCrdRdAddrLast_s1;
reg                             CntLopCrdRdAddrLast_s2;
wire [IDX_WIDTH         -1 : 0] CntLopCrdRdAddr;
reg  [IDX_WIDTH         -1 : 0] CntLopCrdRdAddr_s1;
wire                            PISO_OUT_LAST;
wire                            PISO_IN_RDY;

wire                           INC_CntCpCrdRdAddr;
wire                           INC_CntCrdRdAddr;

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

wire [NUM_SORT_CORE     -1 : 0][NUM_SRAMWORD_MAP   -1 : 0][(SRAM_WIDTH + IDX_WIDTH) -1 : 0] PISO_InDat;
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]state_s1;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE :  if(KNNCCU_CfgRdy & CCUKNN_CfgVld)// 
                    next_state <= CP; //
                else
                    next_state <= IDLE;
        CP:     if( handshake_s0 )
                    next_state <= LP;
                else
                    next_state <= CP;
        LP:     if ( CntCrdRdAddrLast ) begin
                    if ( CntCpCrdRdAddrLast )
                        next_state <= WAITFNH;
                    else //
                        next_state <= CP;
                end else
                    next_state <= LP;
        WAITFNH:if(PISO_OUT_LAST & KNNGLB_MapWrDatVld & GLBKNN_MapWrDatRdy)
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


assign INC_CntCpCrdRdAddr    = state == CP & ena_s0;
assign INC_CntCrdRdAddr   = state == LP & ena_s0;

// HandShake
assign rdy_s0 = GLBKNN_CrdRdAddrRdy;
assign vld_s0 = state == CP | state == LP;

assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0 = handshake_s0 | ~vld_s0;

wire [IDX_WIDTH     -1 : 0] MaxCntCrdRdAddr = CCUKNN_CfgNip % NUM_SORT_CORE==0?  CCUKNN_CfgNip / NUM_SORT_CORE : CCUKNN_CfgNip / NUM_SORT_CORE + 1;
counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u0_counter_CntCp(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( CCUKNN_Rst     ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}),
    .INC       ( INC_CntCpCrdRdAddr),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}),
    .MAX_COUNT (  MaxCntCrdRdAddr),
    .OVERFLOW  ( CntCpCrdRdAddrLast),
    .UNDERFLOW (                ),
    .COUNT     ( CntCpCrdRdAddr )
);

counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_CntCrdRdAddr(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CntCpCrdRdAddr | CCUKNN_Rst   ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
    .INC       ( INC_CntCrdRdAddr   ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
    .MAX_COUNT ( MaxCntCrdRdAddr    ),
    .OVERFLOW  ( CntCrdRdAddrLast   ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntLopCrdRdAddr    )
);

//=====================================================================================================================
// Logic Design: s1-Out Crd
//=====================================================================================================================
// Combinational Logic
assign KNNGLB_CrdRdAddr = CCUKNN_CfgCrdRdAddr + (state == CP ? CntCpCrdRdAddr : CntLopCrdRdAddr);
assign KNNGLB_CrdRdAddrVld = vld_s0;

// HandShake
assign rdy_s1 = KNNGLB_CrdRdDatRdy;
assign vld_s1 = GLBKNN_CrdRdDatVld;

assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1 = handshake_s1 | ~vld_s1;

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {CntLopCrdRdAddr_s1, CntLopCrdRdAddrLast_s1, CntCpCrdRdAddr_s1, CntCpCrdRdAddrLast_s1, state_s1} <= 0;
    end else if(ena_s1) begin
        {CntLopCrdRdAddr_s1, CntLopCrdRdAddrLast_s1, CntCpCrdRdAddr_s1, CntCpCrdRdAddrLast_s1, state_s1} <= {CntCpCrdRdAddr, CntCrdRdAddrLast, CntCpCrdRdAddrLast, state};
    end
end

//========================================================================================================== ===========
// Logic Design: s2
//=====================================================================================================================
// Combinational Logic
assign KNNGLB_CrdRdDatRdy = &INSKNN_LopRdy;

// HandShake
assign rdy_s2 = PISO_IN_RDY;
assign vld_s2 = &INSKNN_MapVld;

assign handshake_s2 = rdy_s2 & vld_s2;
assign ena_s2 = handshake_s2 | ~vld_s2;

genvar gv_core;
genvar gv_wd;
generate
    for(gv_core=0; gv_core<NUM_SORT_CORE; gv_core=gv_core+1) begin

        wire [CRD_WIDTH*CRD_DIM  -1 : 0] Crd_s1;
        wire [IDX_WIDTH          -1 : 0] PntIdx_s1;
        reg  [IDX_WIDTH          -1 : 0] CpIdx_s2;
        wire[DISTSQR_WIDTH       -1 : 0] LopDist_s1;
        reg  [CRD_WIDTH*CRD_DIM  -1 : 0] CpCrd_s2;
        wire [NUM_SRAMWORD_MAP -1 : 0][SRAM_WIDTH -1 : 0] INSKNN_Map;
        
        assign CpIdx_s1 = NUM_SORT_CORE*CntCpCrdRdAddr_s1 + gv_core;
        assign PntIdx_s1 = NUM_SORT_CORE*CntLopCrdRdAddr_s1 + gv_core;
        assign Crd_s1 = GLBKNN_CrdRdDat[CRD_WIDTH*CRD_DIM*gv_core +: CRD_WIDTH*CRD_DIM];
        EDC#(
            .CRD_WIDTH ( CRD_WIDTH  ),
            .CRD_DIM   ( CRD_DIM    )
        )u_EDC(
            .Crd0      ( CpCrd_s2),
            .Crd1      ( Crd_s1     ),
            .DistSqr   ( LopDist_s1    )
        );
        assign KNNINS_LopVld[gv_core] = state_s1 == LP & (GLBKNN_CrdRdDatVld & KNNGLB_CrdRdDatRdy);
        INS#(
            .SORT_LEN_WIDTH     ( MAP_WIDTH     ),
            .IDX_WIDTH          ( IDX_WIDTH     ),
            .DATA_WIDTH         ( DISTSQR_WIDTH )
        )u_INS(
            .clk                 ( clk                 ),
            .rst_n               ( rst_n               ),
            .KNNINS_CfgK         ( CCUKNN_CfgK         ),
            .KNNINS_LopLast      ( CntCpCrdRdAddrLast_s1 ),
            .KNNINS_Lop          ( {LopDist_s1, PntIdx_s1}),
            .KNNINS_LopVld       ( KNNINS_LopVld[gv_core]),
            .INSKNN_LopRdy       ( INSKNN_LopRdy[gv_core]),
            .INSKNN_Map          ( INSKNN_Map           ),
            .INSKNN_MapVld       ( INSKNN_MapVld[gv_core]),
            .KNNINS_MapRdy       ( KNNINS_MapRdy[gv_core])
        );

        for (gv_wd=0; gv_wd < NUM_SRAMWORD_MAP; gv_wd=gv_wd+1) begin
            assign PISO_InDat[gv_core][gv_wd] = {INSKNN_Map[gv_wd], CCUKNN_CfgMapWrAddr + (CpIdx_s2 / NUM_SRAMWORD_MAP == 0? CpIdx_s2 / NUM_SRAMWORD_MAP : CpIdx_s2 / NUM_SRAMWORD_MAP + 1) };
        end

        assign KNNINS_MapRdy[gv_core] = handshake_s2;

        // Reg Update
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                {CpCrd_s2, CpIdx_s2} <= 0;
            end else if(ena_s2) begin
                {CpCrd_s2, CpIdx_s2} <= state_s1 == CP? {Crd_s1, CpIdx_s1} : {CpCrd_s2, CpIdx_s2};
            end 
        end

    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {CntLopCrdRdAddrLast_s2, CntCpCrdRdAddrLast_s2} <= 0;
    end else if(ena_s2) begin
        {CntLopCrdRdAddrLast_s2, CntCpCrdRdAddrLast_s2}  <= {CntLopCrdRdAddrLast_s1, CntCpCrdRdAddrLast_s1};
    end 
end
//=====================================================================================================================
// Logic Design: s3-out
//=====================================================================================================================

PISO_NOCACHE#(
    .DATA_IN_WIDTH   ( (SRAM_WIDTH + IDX_WIDTH)*NUM_SRAMWORD_MAP*NUM_SORT_CORE  ), 
    .DATA_OUT_WIDTH  ( SRAM_WIDTH + IDX_WIDTH  )
)u_PISO_MAP(
    .CLK       ( clk            ),
    .RST_N     ( rst_n          ),
    .IN_VLD    ( vld_s2         ),
    .IN_LAST   ( CntCpCrdRdAddrLast_s2 &  CntLopCrdRdAddrLast_s2 ),
    .IN_DAT    ( PISO_InDat     ),
    .IN_RDY    ( PISO_IN_RDY    ),
    .OUT_DAT   ( {KNNGLB_MapWrDat,  KNNGLB_MapWrAddr}),
    .OUT_VLD   ( KNNGLB_MapWrDatVld),
    .OUT_LAST  ( PISO_OUT_LAST  ),
    .OUT_RDY   ( GLBKNN_MapWrDatRdy)
);

endmodule
