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
    parameter SORT_LEN_WIDTH    = 5,
    parameter CRD_WIDTH         = 16,
    parameter CRD_DIM           = 3, 
    parameter DISTSQR_WIDTH     =  $clog2( CRD_WIDTH*2*$clog2(CRD_DIM) ),
    parameter NUM_SORT_CORE     = 8,
    parameter MASK_ADDR_WIDTH = $clog2(2**IDX_WIDTH*NUM_SORT_CORE/SRAM_WIDTH)
    )(
    input                               clk  ,
    input                               rst_n,

    // Configure
    input                               CCUCTR_Rst,
    input                               CCUCTR_CfgVld,
    output                              KNNCCU_CfgRdy,
    input [IDX_WIDTH            -1 : 0] CCUCTR_CfgNip,
    input [SORT_LEN_WIDTH       -1 : 0] CCUCTR_CfgK, 

    // Fetch Crd
    output [IDX_WIDTH           -1 : 0] KNNGLB_CrdAddr,   
    output                              KNNGLB_CrdAddrVld, 
    input                               GLBKNN_CrdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0 ]GLBKNN_Crd,        
    input                               GLBKNN_CrdVld,     
    output                              KNNGLB_CrdRdy,

    output  [MASK_ADDR_WIDTH        -1 : 0] PSSGLB_MaskRdAddr,
    output                                  PSSGLB_MaskRdAddrVld,
    input                                   GLBPSS_MaskRdAddrRdy,
    input   [SRAM_WIDTH             -1 : 0] GLBPSS_MaskDatOut,
    input                                   GLBPSS_MaskDatOutVld,
    output                                  PSSGLB_MaskDatRdy,

    // Output Map of KNN
    output [SRAM_WIDTH          -1 : 0 ]PSSCTR_Map,   
    output                              PSSCTR_MapVld,     
    input                               CTRPSS_MapRdy     

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
reg [CRD_WIDTH*CRD_DIM  -1 : 0] KNN_CpCrd_s2;

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
        IDLE :  if(KNNCCU_CfgRdy & CCUCTR_CfgVld)
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
// Logic Design: PIPE0
//=====================================================================================================================

 wire INC_CpIdx;
counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u0_counter_CpIdx(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( CCUCTR_Rst     ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}),
    .INC       ( INC_CpIdx      ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}),
    .MAX_COUNT ( CCUCTR_CfgNip  ),
    .OVERFLOW  ( CpLast               ),
    .UNDERFLOW (                ),
    .COUNT     ( CpIdx   )
);

assign INC_CpIdx    =  LopLast_s2 & (KNNPSS_LopVld & PSSKNN_LopRdy);


counter#( // Pipe S0
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_LopIdx(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CpIdx | CCUCTR_Rst   ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
    .INC       ( INC_LopIdx         ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
    .MAX_COUNT ( CCUCTR_CfgNip    ),
    .OVERFLOW  ( LopLast     ),
    .UNDERFLOW (                    ),
    .COUNT     ( LopIdx             )
);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        MaskRAMByteIdx <= 0;
    end else if( CCUCTR_Rst ) begin
        MaskRAMByteIdx <= 0;
    end else if( INC_LopIdx) begin
        MaskRAMByteIdx <= MaskRAMByteIdx + 1; // Loop
    end
end

assign INC_LopIdx = KNNGLB_CrdAddrVld & GLBKNN_CrdAddrRdy ;

assign KNNGLB_CrdAddr = state == CP ? CpIdx : LopIdx;
assign KNNGLB_CrdAddrVld = state == CP | state == LP;
//=====================================================================================================================
// Logic Design: PIPE1
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin: Pipe1
    if(!rst_n) begin
        {MaskRAMByteIdx_s1, KNNGLB_CrdAddr_s1, LopLast_s1} <= 0;
    end else if (KNNGLB_CrdAddrVld & GLBKNN_CrdAddrRdy) begin
        {MaskRAMByteIdx_s1, KNNGLB_CrdAddr_s1, LopLast_s1} <= {MaskRAMByteIdx, KNNGLB_CrdAddr, LopLast};
    end
end

assign KNNGLB_CrdRdy = PSSKNN_LopRdy | !KNNPSS_LopVld; // pipe1 of HS: last_ready or current invalid
//=====================================================================================================================
// Logic Design: PIPE2
//=====================================================================================================================

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        KNN_CpCrd_s2 <= 0;
    end else if (GLBKNN_CrdVld & KNNGLB_CrdRdy) begin
        KNN_CpCrd_s2 <= GLBKNN_Crd;
    end
end

always @(posedge clk or negedge rst_n) begin: Pipe2_LopCrd_s2
    if(!rst_n) begin
        {MaskRAMByteIdx_s2, LopCrd_s2, LopIdx_s2, LopLast_s2} <= 0;
    end else if (GLBKNN_CrdVld & KNNGLB_CrdRdy) begin
        {MaskRAMByteIdx_s2, LopCrd_s2, LopIdx_s2, LopLast_s2} <= {MaskRAMByteIdx_s1, GLBKNN_Crd, KNNGLB_CrdAddr_s1, LopLast_s1};
    end
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        KNNPSS_LopVld <= 1'b0;
    end else if (GLBKNN_CrdVld & KNNGLB_CrdRdy) begin
        KNNPSS_LopVld <= 1'b1;
    end else if (KNNPSS_LopVld & PSSKNN_LopRdy) begin
        KNNPSS_LopVld <= 1'b0;
    end
end

assign KNNPSS_LopLast_s2 = LopLast_s2 & KNNPSS_LopVld;

EDC#(
    .CRD_WIDTH ( CRD_WIDTH  ),
    .CRD_DIM   ( CRD_DIM    )
)u_EDC(
    .Crd0      ( KNN_CpCrd_s2),
    .Crd1      ( LopCrd_s2     ),
    .DistSqr   ( LopDist_s2    )
);

PSS#(
    .SORT_LEN_WIDTH  ( SORT_LEN_WIDTH   ),
    .IDX_WIDTH       ( IDX_WIDTH        ),
    .DIST_WIDTH      ( DISTSQR_WIDTH    ),
    .NUM_SORT_CORE   ( NUM_SORT_CORE    ),
    .SRAM_WIDTH      ( SRAM_WIDTH       )
)u_PSS(
    .clk             ( clk              ),
    .rst_n           ( rst_n            ),
    .KNNPSS_LopLast  ( KNNPSS_LopLast_s2),
    .KNNPSS_Rst      ( CCUCTR_Rst      ),
    .KNNPSS_CpIdx    ( CpIdx           ),
    .KNNPSS_Lop      ( {MaskRAMByteIdx_s2, LopDist_s2,  LopIdx_s2 }),// {idx, dist} 
    .KNNPSS_LopVld   ( KNNPSS_LopVld   ),
    .PSSKNN_LopRdy   ( PSSKNN_LopRdy   ),
    .PSSGLB_MaskRdAddr      ( PSSGLB_MaskRdAddr    ),
    .PSSGLB_MaskRdAddrVld   ( PSSGLB_MaskRdAddrVld ),
    .GLBPSS_MaskRdAddrRdy   ( GLBPSS_MaskRdAddrRdy ),
    .GLBPSS_MaskDatOut      ( GLBPSS_MaskDatOut    ),
    .GLBPSS_MaskDatOutVld   ( GLBPSS_MaskDatOutVld ),
    .PSSGLB_MaskDatRdy      ( PSSGLB_MaskDatRdy    ),
    .PSSCTR_Map      ( PSSCTR_Map      ),
    .PSSCTR_MapVld   ( PSSCTR_MapVld   ),
    .CTRPSS_MapRdy   ( CTRPSS_MapRdy   )
);


endmodule
