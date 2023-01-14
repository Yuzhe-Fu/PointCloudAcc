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
    parameter MAP_WIDTH    = 5,
    parameter CRD_WIDTH         = 16,
    parameter CRD_DIM           = 3, 
    parameter DISTSQR_WIDTH     =  CRD_WIDTH*2 + $clog2(CRD_DIM),
    parameter NUM_SORT_CORE     = 8,
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
    output [IDX_WIDTH           -1 : 0] KNNGLB_CrdAddr,   
    output                              KNNGLB_CrdAddrVld, 
    input                               GLBKNN_CrdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0 ]GLBKNN_Crd,        
    input                               GLBKNN_CrdVld,     
    output                              KNNGLB_CrdRdy,

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
localparam FNH    = 3'b011;


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================


reg [CRD_WIDTH*CRD_DIM  -1 : 0] LopCrd_s2;

wire                            KNNPSS_LopLast_s2;

wire[IDX_WIDTH          -1 : 0] CpIdx;  

wire[DISTSQR_WIDTH      -1 : 0] LopDist_s2;

reg                             LopLast_s2;
reg                             LopLast_s1;
reg                             KNNGLB_CrdAddr_s1;
reg [IDX_WIDTH          -1 : 0] LopIdx_s2;
reg [IDX_WIDTH          -1 : 0] LopIdx_s1;

wire                            CpLast;
reg [CRD_WIDTH*CRD_DIM  -1 : 0] CpCrd_s2;

wire                            LopLast;

reg                             KNNPSS_LopVld;
wire                            PSSKNN_LopRdy;
wire [IDX_WIDTH         -1 : 0] LopIdx;
reg  [$clog2(SRAM_WIDTH/NUM_SORT_CORE) -1 : 0] MaskRAMByteIdx;
reg  [$clog2(SRAM_WIDTH/NUM_SORT_CORE) -1 : 0] MaskRAMByteIdx_s1;
reg  [$clog2(SRAM_WIDTH/NUM_SORT_CORE) -1 : 0] MaskRAMByteIdx_s2;
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IDLE :  if(KNNCCU_CfgRdy & CCUKNN_CfgVld)
                    next_state <= CP; //
                else
                    next_state <= IDLE;
        CP:     if( KNNGLB_CrdAddrVld & GLBKNN_CrdAddrRdy)
                    next_state <= LP;
                else
                    next_state <= CP;
        LP:     if ( LopLast ) begin
                    if ( CpLast )
                        next_state <= FNH;
                    else //
                        next_state <= CP;
                end
                else
                    next_state <= LP;
        FNH:    next_state <= IDLE;
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
// Logic Design: s0
//=====================================================================================================================

 wire INC_CpIdx;
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


counter#( // Pipe S0
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
// Logic Design: s1
//=====================================================================================================================

// Combinational Logic
assign INC_CpIdx    =  LopLast_s2 & (KNNPSS_LopVld & PSSKNN_LopRdy);
assign INC_LopIdx = KNNGLB_CrdAddrVld & GLBKNN_CrdAddrRdy ;

assign KNNGLB_CrdAddr = state == CP ? CpIdx : LopIdx;

assign KNNGLB_CrdAddrVld = state == CP | state == LP;

// HandShake
assign KNNGLB_CrdRdy = rdy_s0; // pipe1 of HS: last_ready or current invalid
assign vld_s0 = KNNGLB_CrdVld;

assign rdy_s0 = PSSKNN_LopRdy | !KNNPSS_LopVld;
assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0 = handshake_s1 | ~vld_s0;

// Reg Update


//=====================================================================================================================
// Logic Design: s2
//=====================================================================================================================

genvar i;
generate
    for(i=0; i<NUM_SORT_CORE; i=i+1) begin

        assign LopCrd_s2 = ;
        assign LopPntIdx_s2 = ;
        EDC#(
            .CRD_WIDTH ( CRD_WIDTH  ),
            .CRD_DIM   ( CRD_DIM    )
        )u_EDC(
            .Crd0      ( CpCrd_s2),
            .Crd1      ( LopCrd_s2     ),
            .DistSqr   ( LopDist_s2    )
        );
        assign PSSINS_LopVld[i] = state_s2 == LP & KNNGLB_CrdVld & (&INSPSS_LopRdy);
        INS#(
            .SORT_LEN_WIDTH   ( SORT_LEN_WIDTH ),
            .IDX_WIDTH       ( IDX_WIDTH ),
            .DIST_WIDTH      ( DIST_WIDTH )
        )u_INS(
            .clk                 ( clk                 ),
            .rst_n               ( rst_n               ),
            .PSSINS_LopLast      ( KNNPSS_LopLast      ),
            .PSSINS_Lop          ( {LopDist_s2, LopPntIdx_s2}),
            .PSSINS_LopVld       ( PSSINS_LopVld[i]    ),
            .INSPSS_LopRdy       ( INSPSS_LopRdy[i]    ),
            .INSPSS_Idx          ( INSPSS_Idx[(IDX_WIDTH*SORT_LEN)*i +: (IDX_WIDTH*SORT_LEN)]),
            .INSPSS_IdxVld       ( INSPSS_IdxVld[i]       ),
            .PSSINS_IdxRdy       ( PSSINS_IdxRdy[i]       )
        );

        assign PSSMap[SRAM_WIDTH*i +: SRAM_WIDTH] = {54'd0, {KNNPSS_CpIdx, INSPSS_Idx[(IDX_WIDTH*SORT_LEN)*i +: (IDX_WIDTH*SORT_LEN)]}};
        
    end
endgenerate


assign KNNPSS_LopLast_s2 = LopLast_s2 & KNNPSS_LopVld;

//=====================================================================================================================
// Logic Design: s3-out
//=====================================================================================================================



endmodule
