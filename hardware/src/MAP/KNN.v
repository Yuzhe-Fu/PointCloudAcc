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
    parameter IDX_WIDTH         = 10,
    parameter MAP_WIDTH         = 5,
    parameter CRD_WIDTH         = 16,
    parameter CRD_DIM           = 3, 
    parameter DISTSQR_WIDTH     = CRD_WIDTH*2 + $clog2(CRD_DIM),
    parameter NUM_SORT_CORE     = 4,
    parameter MASK_ADDR_WIDTH = $clog2(2**IDX_WIDTH*NUM_SORT_CORE/SRAM_WIDTH)
    )(
    input                               clk  ,
    input                               rst_n,

    // Configure
    input                               CCUKNN_Rst,
    input                               CCUKNN_CfgVld,
    output                              KNNCCU_CfgRdy,
    input [IDX_WIDTH            -1 : 0] CCUKNN_CfgNip,
    input [MAP_WIDTH            -1 : 0] CCUKNN_CfgK, 

    // Fetch Crd
    output [IDX_WIDTH           -1 : 0] KNNGLB_CrdIdxAddr,   
    output                              KNNGLB_CrdIdxAddrVld, 
    input                               GLBKNN_CrdIdxAddrRdy,
    input  [SRAM_WIDTH          -1 : 0 ]GLBKNN_CrdIdx,        
    input                               GLBKNN_CrdIdxVld,     
    output                              KNNGLB_CrdIdxRdy,

    // Output Map of KNN
    output [SRAM_WIDTH          -1 : 0 ]KNNGLB_Map,   
    output                              KNNGLB_MapVld,     
    input                               GLBKNN_MapRdy     

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE   = 3'b000;
localparam CP     = 3'b001;
localparam LP     = 3'b010;
localparam WAITFNH= 3'b011;

localparam SORT_LEN=2**MAP_WIDTH;
localparam NUMMAPWORD = (IDX_WIDTH*SORT_LEN)%SRAM_WIDTH == 0? (IDX_WIDTH*SORT_LEN)/SRAM_WIDTH : (IDX_WIDTH*SORT_LEN)/SRAM_WIDTH + 1;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

wire[IDX_WIDTH          -1 : 0] CpIdx;  
wire                            CpLast;
reg                             CpLast_s1;
reg                             CpLast_s2;

wire                            LopLast;
reg                             LopLast_s1;
wire [IDX_WIDTH         -1 : 0] LopIdx;
wire                            PISO_OUT_LAST;
wire                            PISO_IN_RDY;

wire [SRAM_WIDTH*NUMMAPWORD*NUM_SORT_CORE   -1 : 0] INSMap;
wire                           INC_CpIdx;
wire                           INC_LopIdx;

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
wire  [IDX_WIDTH*SORT_LEN*NUM_SORT_CORE -1 : 0] INSKNN_Map;
wire  [NUM_SORT_CORE    -1 : 0] INSKNN_MapVld;
wire  [NUM_SORT_CORE    -1 : 0] KNNINS_MapRdy;
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
        LP:     if ( LopLast ) begin
                    if ( CpLast )
                        next_state <= WAITFNH;
                    else //
                        next_state <= CP;
                end else
                    next_state <= LP;
        WAITFNH:if(PISO_OUT_LAST & KNNGLB_MapVld & GLBKNN_MapRdy)
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


assign INC_CpIdx    = state == CP & ena_s0;
assign INC_LopIdx   = state == LP & ena_s0;

// HandShake
assign rdy_s0 = GLBKNN_CrdIdxAddrRdy;
assign vld_s0 = state == CP | state == LP;

assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0 = handshake_s0 | ~vld_s0;

counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u0_counter_CpIdx(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( CCUKNN_Rst     ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}),
    .INC       ( INC_CpIdx      ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}),
    .MAX_COUNT ( CCUKNN_CfgNip  ),
    .OVERFLOW  ( CpLast               ),
    .UNDERFLOW (                ),
    .COUNT     ( CpIdx   )
);

counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_LopIdx(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CpIdx | CCUKNN_Rst   ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
    .INC       ( INC_LopIdx         ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
    .MAX_COUNT ( CCUKNN_CfgNip    ),
    .OVERFLOW  ( LopLast     ),
    .UNDERFLOW (                    ),
    .COUNT     ( LopIdx             )
);

//=====================================================================================================================
// Logic Design: s1-Out CrdIdx
//=====================================================================================================================
// Combinational Logic
assign KNNGLB_CrdIdxAddr = state == CP ? CpIdx : LopIdx;
assign KNNGLB_CrdIdxAddrVld = vld_s0;

// HandShake
assign rdy_s1 = KNNGLB_CrdIdxRdy;
assign vld_s1 = GLBKNN_CrdIdxVld;

assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1 = handshake_s1 | ~vld_s1;

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {LopLast_s1, CpLast_s1, state_s1} <= 0;
    end else if(ena_s1) begin
        {LopLast_s1, CpLast_s1, state_s1} <= {CpIdx, LopLast, CpLast, state};
    end
end

//========================================================================================================== ===========
// Logic Design: s2
//=====================================================================================================================
// Combinational Logic
assign KNNGLB_CrdIdxRdy = &INSKNN_LopRdy;

// HandShake
assign rdy_s2 = PISO_IN_RDY;
assign vld_s2 = &INSKNN_MapVld;

assign handshake_s2 = rdy_s2 & vld_s2;
assign ena_s2 = handshake_s2 | ~vld_s2;

genvar i;
generate
    for(i=0; i<NUM_SORT_CORE; i=i+1) begin

        wire [CRD_WIDTH*CRD_DIM  -1 : 0] Crd_s1;
        wire [IDX_WIDTH          -1 : 0] PntIdx_s1;
        wire[DISTSQR_WIDTH       -1 : 0] LopDist_s1;
        reg  [CRD_WIDTH*CRD_DIM  -1 : 0] CpCrd_s2;

        assign {Crd_s1, PntIdx_s1} = GLBKNN_CrdIdx[(CRD_WIDTH*CRD_DIM + IDX_WIDTH)*i +: CRD_WIDTH*CRD_DIM + IDX_WIDTH];
        EDC#(
            .CRD_WIDTH ( CRD_WIDTH  ),
            .CRD_DIM   ( CRD_DIM    )
        )u_EDC(
            .Crd0      ( CpCrd_s2),
            .Crd1      ( Crd_s1     ),
            .DistSqr   ( LopDist_s1    )
        );
        assign KNNINS_LopVld[i] = state_s1 == LP & (GLBKNN_CrdIdxVld & KNNGLB_CrdIdxRdy);
        INS#(
            .SORT_LEN_WIDTH   ( MAP_WIDTH ),
            .IDX_WIDTH       ( IDX_WIDTH ),
            .DISTSQR_WIDTH      ( DISTSQR_WIDTH )
        )u_INS(
            .clk                 ( clk                 ),
            .rst_n               ( rst_n               ),
            .KNNINS_LopLast      ( LopLast_s1          ),
            .KNNINS_Lop          ( {LopDist_s1, PntIdx_s1}),
            .KNNINS_LopVld       ( KNNINS_LopVld[i]    ),
            .INSKNN_LopRdy       ( INSKNN_LopRdy[i]    ),
            .INSKNN_Map          ( INSKNN_Map[(IDX_WIDTH*SORT_LEN)*i +: (IDX_WIDTH*SORT_LEN)]),
            .INSKNN_MapVld       ( INSKNN_MapVld[i]       ),
            .KNNINS_MapRdy       ( KNNINS_MapRdy[i]       )
        );

        assign INSMap[SRAM_WIDTH*NUMMAPWORD*i +: SRAM_WIDTH*NUMMAPWORD] = INSKNN_Map[(IDX_WIDTH*SORT_LEN)*i +: (IDX_WIDTH*SORT_LEN)];
        assign KNNINS_MapRdy[i] = handshake_s2;


        // Reg Update
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                CpCrd_s2 <= 0;
            end else if(ena_s2) begin
                CpCrd_s2 <= state_s1 == CP? Crd_s1 : CpCrd_s2;
            end 
        end

    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        CpLast_s2 <= 0;
    end else if(ena_s2) begin
        CpLast_s2 <= CpLast_s1;
    end 
end
//=====================================================================================================================
// Logic Design: s3-out
//=====================================================================================================================

PISO_NOCACHE#(
    .DATA_IN_WIDTH   ( SRAM_WIDTH*NUMMAPWORD*NUM_SORT_CORE  ), // (32+1)*10 /96 = 330 /96 <= 4
    .DATA_OUT_WIDTH  ( SRAM_WIDTH  )
)u_PISO_MAP(
    .CLK       ( clk            ),
    .RST_N     ( rst_n          ),
    .IN_VLD    ( vld_s2         ),
    .IN_LAST   ( CpLast_s2      ),
    .IN_DAT    ( INSMap         ),
    .IN_RDY    ( PISO_IN_RDY    ),
    .OUT_DAT   ( KNNGLB_Map     ),
    .OUT_VLD   ( KNNGLB_MapVld  ),
    .OUT_LAST  ( PISO_OUT_LAST  ),
    .OUT_RDY   ( GLBKNN_MapRdy  )
);

endmodule
