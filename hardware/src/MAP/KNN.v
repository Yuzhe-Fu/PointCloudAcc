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
`define CEIL(a, b) ( \
 (a % b)? (a / b + 1) : (a / b) \
)
module KNN #(
    parameter KNNISA_WIDTH      = 128*2,
    parameter SRAM_WIDTH        = 256,
    parameter IDX_WIDTH         = 16,
    parameter MAP_WIDTH         = 5,
    parameter CRD_WIDTH         = 16,
    parameter CRD_DIM           = 3, 
    parameter DISTSQR_WIDTH     = CRD_WIDTH*2 + $clog2(CRD_DIM),
    parameter NUM_SORT_CORE     = 8,
    parameter KNNMON_WIDTH      = 128
    )(
    input                               clk                 ,
    input                               rst_n               ,

    // Configure
    input                               CCUKNN_CfgVld       ,
    output                              KNNCCU_CfgRdy       ,
    input  [KNNISA_WIDTH        -1 : 0] CCUKNN_CfgInfo      ,

    // Fetch Crd
    output [IDX_WIDTH           -1 : 0] KNNGLB_CrdRdAddr    ,   
    output                              KNNGLB_CrdRdAddrVld , 
    input                               GLBKNN_CrdRdAddrRdy ,
    input  [SRAM_WIDTH          -1 : 0 ]GLBKNN_CrdRdDat     ,        
    input                               GLBKNN_CrdRdDatVld  ,     
    output                              KNNGLB_CrdRdDatRdy  ,

    // Fetch Mask of Output Points
    output [IDX_WIDTH           -1 : 0] KNNGLB_MaskRdAddr   ,
    output                              KNNGLB_MaskRdAddrVld,
    input                               GLBKNN_MaskRdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0] GLBKNN_MaskRdDat    ,    
    input                               GLBKNN_MaskRdDatVld ,    
    output                              KNNGLB_MaskRdDatRdy ,   

    // Output Map of KNN
    output [IDX_WIDTH           -1 : 0] KNNGLB_MapWrAddr    ,
    output [SRAM_WIDTH          -1 : 0] KNNGLB_MapWrDat     ,   
    output                              KNNGLB_MapWrDatVld  ,     
    input                               GLBKNN_MapWrDatRdy  ,

    output [IDX_WIDTH           -1 : 0] KNNGLB_IdxMaskRdAddr   ,
    output                              KNNGLB_IdxMaskRdAddrVld,
    input                               GLBKNN_IdxMaskRdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0] GLBKNN_IdxMaskRdDat    ,    
    input                               GLBKNN_IdxMaskRdDatVld ,    
    output                              KNNGLB_IdxMaskRdDatRdy ,  

    output [KNNMON_WIDTH        -1 : 0] KNNMON_Dat                
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE   = 3'b000;
localparam CP     = 3'b001;
localparam LP     = 3'b010;
localparam WAITFNH= 3'b011;

localparam SORT_LEN         = 2**MAP_WIDTH;
localparam NUM_SRAMWORD_MAP = (IDX_WIDTH*SORT_LEN)%SRAM_WIDTH == 0? (IDX_WIDTH*SORT_LEN)/SRAM_WIDTH : (IDX_WIDTH*SORT_LEN)/SRAM_WIDTH + 1;
localparam MASK_ADDR_WIDTH  = IDX_WIDTH - $clog2(SRAM_WIDTH);

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

wire [NUM_SORT_CORE     -1 : 0][NUM_SRAMWORD_MAP   -1 : 0][(SRAM_WIDTH + IDX_WIDTH) + 1 -1 : 0] PISO_InDat;
reg                             Pseudo_CrdRdVld;
wire [SRAM_WIDTH        -1 : 0] CrdRdDat_s1;
wire [SRAM_WIDTH        -1 : 0] MaskRdDat_s1;
wire                            PISO_InRdy_CrdRd  ;
wire [CRD_WIDTH*CRD_DIM -1 : 0] PISO_OutDat_CrdRd ;
wire                            PISO_OutVld_CrdRd ;
wire                            PISO_OutLast_CrdRd;
wire                            PISO_OutRdy_CrdRd ;
parameter CRDBYTE_WIDTH = $clog2(NUM_SORT_CORE);
wire [CRDBYTE_WIDTH     -1 : 0] MaxCntCrdByte;
wire [CRDBYTE_WIDTH     -1 : 0] CntCrdByte;
wire                            req_Mask;
wire                            INC_CntMaskAddr;
wire                            INC_CntIdxMaskAddr;
wire [MASK_ADDR_WIDTH   -1 : 0] CntMaskAddr;
wire [IDX_WIDTH         -1 : 0] CntIdxMaskAddr;
wire [NUM_SORT_CORE     -1 : 0] MapFnh;

wire [IDX_WIDTH            -1 : 0] CCUKNN_CfgNip       ;
wire [(MAP_WIDTH + 1)      -1 : 0] CCUKNN_CfgK         ; 
wire [IDX_WIDTH            -1 : 0] CCUKNN_CfgCrdRdAddr ;
wire [IDX_WIDTH            -1 : 0] CCUKNN_CfgMaskRdAddr;
wire [IDX_WIDTH            -1 : 0] CCUKNN_CfgMapWrAddr ;
wire [IDX_WIDTH            -1 : 0] CCUKNN_CfgIdxMaskRdAddr ;

//=====================================================================================================================
// Logic Design: ISA Decode
//=====================================================================================================================
assign {
CCUKNN_CfgIdxMaskRdAddr,
CCUKNN_CfgMapWrAddr ,   // 16
CCUKNN_CfgMaskRdAddr,
CCUKNN_CfgCrdRdAddr ,   // 16
CCUKNN_CfgK         ,   // 8
CCUKNN_CfgNip       // 16
} = CCUKNN_CfgInfo;

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
        CP:     if(CCUKNN_CfgVld)
                    next_state <= IDLE;
                else if( handshake_s0 )
                    next_state <= LP;
                else
                    next_state <= CP;
        LP:     if(CCUKNN_CfgVld)
                    next_state <= IDLE;
                else if ( CntCrdRdAddrLast & KNNGLB_CrdRdAddrVld & GLBKNN_CrdRdAddrRdy ) begin
                    if ( CntCpCrdRdAddr == 0 )
                        next_state <= WAITFNH;
                    else //
                        next_state <= CP;
                end else
                    next_state <= LP;
        WAITFNH:if(CCUKNN_CfgVld)
                    next_state <= IDLE;
                else if(PISO_OUT_LAST & KNNGLB_MapWrDatVld & GLBKNN_MapWrDatRdy)
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


assign INC_CntCpCrdRdAddr   = state == CP & ena_s0;
assign INC_CntCrdRdAddr     = state == LP & ena_s0;
assign INC_CntIdxMaskAddr   = state == LP & ena_s0;
assign INC_CntMaskAddr      = handshake_s0 & req_Mask;

assign req_Mask = SRAM_WIDTH*CntMaskAddr                    <= NUM_SORT_CORE*CntCpCrdRdAddr;
assign req_Idx  = (SRAM_WIDTH/(IDX_WIDTH+1))*CntIdxMaskAddr <= NUM_SORT_CORE*CntCpCrdRdAddr;

// HandShake
// `ifdef PSEUDO_DATA
//     assign rdy_s0 = 1'b1;?????????????????
// `else
    assign rdy_s0 = GLBKNN_CrdRdAddrRdy & GLBKNN_MaskRdAddrRdy; // Two loads
// `endif

assign vld_s0       = state == CP | state == LP;
assign handshake_s0 = rdy_s0 & vld_s0;
assign ena_s0       = handshake_s0 | ~vld_s0;

wire [IDX_WIDTH     -1 : 0] MaxCntCrdRdAddr = `CEIL(CCUKNN_CfgNip, NUM_SORT_CORE) -1;
counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u0_counter_CntCp(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state == IDLE  ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}),
    .INC       ( INC_CntCpCrdRdAddr),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}),
    .MAX_COUNT (  MaxCntCrdRdAddr),
    .OVERFLOW  ( CntCpCrdRdAddrLast),
    .UNDERFLOW (                ),
    .COUNT     ( CntCpCrdRdAddr )
);

wire [MASK_ADDR_WIDTH   -1 : 0 ] MaxCntMaskAddr = `CEIL(CCUKNN_CfgNip, SRAM_WIDTH) -1;

counter#(
    .COUNT_WIDTH ( MASK_ADDR_WIDTH )
)u0_counter_CntMaskAddr(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state == IDLE  ),
    .DEFAULT   ( {MASK_ADDR_WIDTH{1'b0}}),
    .INC       ( INC_CntMaskAddr),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {MASK_ADDR_WIDTH{1'b0}}),
    .MAX_COUNT (  MaxCntMaskAddr),
    .OVERFLOW  (                ),
    .UNDERFLOW (                ),
    .COUNT     ( CntMaskAddr    )
);

counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_CntCrdRdAddr(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CntCpCrdRdAddr | state == IDLE   ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
    .INC       ( INC_CntCrdRdAddr   ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
    .MAX_COUNT ( MaxCntCrdRdAddr    ),
    .OVERFLOW  ( CntCrdRdAddrLast   ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntLopCrdRdAddr    )
);

counter#(
    .COUNT_WIDTH ( IDX_WIDTH )
)u1_counter_CntIdxMaskAddr(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CntCpCrdRdAddr | state == IDLE ),
    .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
    .INC       ( INC_CntIdxMaskAddr ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
    .MAX_COUNT ( {IDX_WIDTH{1'b1}}  ),
    .OVERFLOW  (                    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntIdxMaskAddr     ) // Similar to Mask
);

//=====================================================================================================================
// Logic Design: s1-Out Crd
//=====================================================================================================================
// Combinational Logic
assign KNNGLB_CrdRdAddr     = CCUKNN_CfgCrdRdAddr + (state == CP ? CntCpCrdRdAddr : CntLopCrdRdAddr);
assign KNNGLB_CrdRdAddrVld  = vld_s0 & (req_Mask? GLBKNN_MaskRdAddrRdy : 1'b1);
assign KNNGLB_MaskRdAddr    = CCUKNN_CfgMaskRdAddr + CntMaskAddr;
assign KNNGLB_MaskRdAddrVld = vld_s0 & (GLBKNN_CrdRdAddrRdy & req_Mask);

assign KNNGLB_IdxMaskRdAddr     = CCUKNN_CfgIdxMaskRdAddr + CntIdxMaskAddr;
assign KNNGLB_IdxMaskRdAddrVld  = vld_s0 & (req_Idx & GLBKNN_MaskRdAddrRdy & GLBKNN_CrdRdAddrRdy);

// HandShake
assign rdy_s1 = state_s1 == CP | PISO_InRdy_CrdRd;
// `ifdef PSEUDO_DATA
//     assign vld_s1 = Pseudo_CrdRdVld;
// `else
    assign vld_s1 = GLBKNN_CrdRdDatVld;
// `endif

assign handshake_s1 = rdy_s1 & vld_s1;
assign ena_s1 = handshake_s1 | ~vld_s1;

// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {CntLopCrdRdAddr_s1, CntLopCrdRdAddrLast_s1, CntCpCrdRdAddr_s1, CntCpCrdRdAddrLast_s1, state_s1} <= 0;
    end else if ( state == IDLE ) begin
        {CntLopCrdRdAddr_s1, CntLopCrdRdAddrLast_s1, CntCpCrdRdAddr_s1, CntCpCrdRdAddrLast_s1, state_s1} <= 0;
    end else if(ena_s1) begin
        CntLopCrdRdAddr_s1      <= CntLopCrdRdAddr;
        CntLopCrdRdAddrLast_s1  <= CntCrdRdAddrLast;
        CntCpCrdRdAddr_s1       <= state == CP | state == WAITFNH? CntCpCrdRdAddr : CntCpCrdRdAddr_s1;
        CntCpCrdRdAddrLast_s1   <= state == CP | state == WAITFNH? CntCpCrdRdAddrLast : CntCpCrdRdAddrLast_s1;
        state_s1                <= state;

    end
end

//========================================================================================================== ===========
// Logic Design: S2 (No cache)
//=====================================================================================================================
// Combinational Logic
// `ifdef PSEUDO_DATA
//     assign CrdRdDat_s1 = state_s1 == IDLE? GLBKNN_CrdRdDat : {NUM_SORT_CORE{ {(CRD_WIDTH*CRD_DIM - IDX_WIDTH){1'b0}}, KNNGLB_CrdRdAddr}};
// `else
    assign CrdRdDat_s1  = GLBKNN_CrdRdDat;
    assign MaskRdDat_s1 = GLBKNN_MaskRdDat;
    wire [SRAM_WIDTH/(IDX_WIDTH + 1)    -1 : 0][(IDX_WIDTH + 1) -1 : 0] IdxMaskRdDat_s1;
    assign IdxMaskRdDat_s1 = GLBKNN_IdxMaskRdDat;
// `endif

assign KNNGLB_CrdRdDatRdy   = rdy_s1; //state_s1 == LP & PISO_InRdy_CrdRd | state_s1 == CP & 1'b1;
assign KNNGLB_MaskRdDatRdy  = rdy_s1;
assign KNNGLB_IdxMaskRdDatRdy = rdy_s1;

PISO_NOCACHE#(
    .DATA_IN_WIDTH   ( SRAM_WIDTH       ), 
    .DATA_OUT_WIDTH  ( CRD_WIDTH*CRD_DIM)
)u_PISO_CrdRd(
    .CLK       ( clk                ),
    .RST_N     ( rst_n              ),
    .RESET     ( state == IDLE      ),
    .IN_VLD    ( state_s1 == LP & vld_s1),
    .IN_LAST   ( CntLopCrdRdAddrLast_s1 ),
    .IN_DAT    ( CrdRdDat_s1        ),
    .IN_RDY    ( PISO_InRdy_CrdRd   ),
    .OUT_DAT   ( PISO_OutDat_CrdRd  ),
    .OUT_VLD   ( PISO_OutVld_CrdRd  ),
    .OUT_LAST  ( PISO_OutLast_CrdRd ),
    .OUT_RDY   ( PISO_OutRdy_CrdRd  )
);
assign PISO_OutRdy_CrdRd = &INSKNN_LopRdy;

assign MaxCntCrdByte = NUM_SORT_CORE - 1;
counter#(
    .COUNT_WIDTH ( CRDBYTE_WIDTH )
)u1_counter_CrdByte(
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     ( INC_CntCrdRdAddr | state == IDLE  ),
    .DEFAULT   ( {CRDBYTE_WIDTH{1'b0}}  ),
    .INC       ( PISO_OutVld_CrdRd & PISO_OutRdy_CrdRd   ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {CRDBYTE_WIDTH{1'b0}}  ),
    .MAX_COUNT ( MaxCntCrdByte      ),
    .OVERFLOW  (                    ),
    .UNDERFLOW (                    ),
    .COUNT     ( CntCrdByte         )
);

//=====================================================================================================================
// Logic Design: s2-Out
//=====================================================================================================================
// HandShake
assign rdy_s2 = PISO_IN_RDY;
assign vld_s2 = &MapFnh;

assign handshake_s2 = rdy_s2 & vld_s2;
assign ena_s2       = handshake_s2 | ~vld_s2;

genvar gv_core;
genvar gv_wd;
generate
    for(gv_core=0; gv_core<NUM_SORT_CORE; gv_core=gv_core+1) begin: GEN_INS

        wire [CRD_WIDTH*CRD_DIM  -1 : 0] Crd_s1;
        reg                              CpVld_s2;
        wire [IDX_WIDTH          -1 : 0] PntIdx_s1;
        wire [IDX_WIDTH          -1 : 0] PntIdx_s1_upd;
        wire [IDX_WIDTH          -1 : 0] CpIdx_s1;
        reg  [IDX_WIDTH          -1 : 0] CpIdx_s2;
        wire [DISTSQR_WIDTH      -1 : 0] LopDist_s1;
        reg  [CRD_WIDTH*CRD_DIM  -1 : 0] CpCrd_s2;
        wire [NUM_SRAMWORD_MAP   -1 : 0][SRAM_WIDTH -1 : 0] INSKNN_Map;
        wire [$clog2(SRAM_WIDTH/(IDX_WIDTH + 1))    -1 : 0] PntIdx_s1_offset;
        
        assign CpIdx_s1         = NUM_SORT_CORE*CntCpCrdRdAddr_s1  + gv_core;
        assign PntIdx_s1        = NUM_SORT_CORE*CntLopCrdRdAddr_s1 + CntCrdByte;
        assign PntIdx_s1_offset = PntIdx_s1 % (SRAM_WIDTH/(IDX_WIDTH + 1));

        assign PntIdx_s1_upd    = IdxMaskRdDat_s1[PntIdx_s1_offset][0]? IdxMaskRdDat_s1[PntIdx_s1_offset][1 +: IDX_WIDTH] : CpIdx_s1; // Enable Point Pruning
        // `ifdef PSEUDO_DATA
        //     assign Crd_s1 = state_s1 == IDLE? GLBKNN_CrdRdDat[CRD_WIDTH*CRD_DIM*gv_core +: CRD_WIDTH*CRD_DIM] : KNNGLB_CrdRdAddr;
        // `else
            assign Crd_s1 = PISO_OutDat_CrdRd;
        // `endif
        
        EDC#(
            .CRD_WIDTH ( CRD_WIDTH  ),
            .CRD_DIM   ( CRD_DIM    )
        )u_EDC(
            .Crd0      ( CpVld_s2? CpCrd_s2 : {CRD_WIDTH{1'b0}} ), // Cp
            .Crd1      ( Crd_s1     ), // Np
            .DistSqr   ( LopDist_s1 )
        );
        // `ifdef PSEUDO_DATA
        //     assign KNNINS_LopVld[gv_core] = state_s1 == LP & (Pseudo_CrdRdVld & KNNGLB_CrdRdDatRdy);
        // `else
            assign KNNINS_LopVld[gv_core] = state_s1 == LP & (PISO_OutVld_CrdRd & PISO_OutRdy_CrdRd);
        // `endif
        
        INS#(
            .SORT_LEN_WIDTH     ( MAP_WIDTH     ),
            .IDX_WIDTH          ( IDX_WIDTH     ),
            .DATA_WIDTH         ( DISTSQR_WIDTH )
        )u_INS(
            .clk                 ( clk                 ),
            .rst_n               ( rst_n               ),
            .reset               ( state == IDLE       ),
            .KNNINS_CfgK         ( CCUKNN_CfgK         ),
            .KNNINS_LopLast      ( PISO_OutLast_CrdRd & CpVld_s2  ),
            .KNNINS_Lop          ( {LopDist_s1, PntIdx_s1}),
            .KNNINS_LopVld       ( KNNINS_LopVld[gv_core] & CpVld_s2),
            .INSKNN_LopRdy       ( INSKNN_LopRdy[gv_core]),
            .INSKNN_Map          ( INSKNN_Map           ),
            .INSKNN_MapVld       ( INSKNN_MapVld[gv_core]),
            .KNNINS_MapRdy       ( KNNINS_MapRdy[gv_core])
        );
        
        for (gv_wd=0; gv_wd < NUM_SRAMWORD_MAP; gv_wd=gv_wd+1) begin
            wire [IDX_WIDTH     -1 : 0] MapWrAddr;
            
            // `ifdef PSEUDO_DATA
            //     assign MapWrAddr = (NUM_SRAMWORD_MAP*(MaxCntCrdRdAddr + 1))*CntCpCrdRdAddr_s1 + NUM_SRAMWORD_MAP*CntLopCrdRdAddr_s1 + gv_wd;
            // `else
                assign MapWrAddr = CCUKNN_CfgMapWrAddr + NUM_SRAMWORD_MAP*CpIdx_s2 + gv_wd;
                assign MapFnh[gv_core] = CpVld_s2? INSKNN_MapVld[gv_core] : 1'b1;
            // `endif

            assign PISO_InDat[gv_core][gv_wd] = {INSKNN_Map[gv_wd], MapWrAddr, CpVld_s2};
        end

        assign KNNINS_MapRdy[gv_core] = handshake_s2;

        // Reg Update
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                CpIdx_s2 <= 0;
            end else if ( state == IDLE ) begin
                CpIdx_s2 <= 0;
            end else if(KNNINS_LopVld[gv_core] & INSKNN_LopRdy[gv_core]) begin
                CpIdx_s2 <= CpIdx_s1;
            end 
        end

        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                CpCrd_s2 <= 0;
                CpVld_s2 <= 0;
            end else if ( state == IDLE ) begin
                CpCrd_s2 <= 0;
                CpVld_s2 <= 0;
            end else if(state_s1 == CP) begin
                CpCrd_s2 <= CrdRdDat_s1[CRD_WIDTH*CRD_DIM*gv_core +: CRD_WIDTH*CRD_DIM];
                CpVld_s2 <= MaskRdDat_s1[CpIdx_s1 % SRAM_WIDTH];
            end 
        end 

    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {CntLopCrdRdAddrLast_s2, CntCpCrdRdAddrLast_s2} <= 0;
    end else if ( state == IDLE ) begin
        {CntLopCrdRdAddrLast_s2, CntCpCrdRdAddrLast_s2} <= 0;
    end else if(ena_s2) begin
        {CntLopCrdRdAddrLast_s2, CntCpCrdRdAddrLast_s2}  <= {CntLopCrdRdAddrLast_s1, CntCpCrdRdAddrLast_s1};
    end 
end
//=====================================================================================================================
// Logic Design: s3-out
//=====================================================================================================================
wire    PISO_OUT_VLD;
wire [SRAM_WIDTH + IDX_WIDTH + 1   -1 : 0] PISO_OUT_DAT;

PISO_NOCACHE#(
    .DATA_IN_WIDTH   ( (SRAM_WIDTH + IDX_WIDTH + 1)*NUM_SRAMWORD_MAP*NUM_SORT_CORE ), 
    .DATA_OUT_WIDTH  ( SRAM_WIDTH + IDX_WIDTH + 1)
)u_PISO_MAP(
    .CLK       ( clk            ),
    .RST_N     ( rst_n          ),
    .RESET     ( state == IDLE  ),
    .IN_VLD    ( vld_s2         ),
    .IN_LAST   ( CntCpCrdRdAddrLast_s2 &  CntLopCrdRdAddrLast_s2 ),
    .IN_DAT    ( PISO_InDat     ),
    .IN_RDY    ( PISO_IN_RDY    ),
    .OUT_DAT   ( PISO_OUT_DAT   ),
    .OUT_VLD   ( PISO_OUT_VLD   ),
    .OUT_LAST  ( PISO_OUT_LAST  ),
    .OUT_RDY   ( GLBKNN_MapWrDatRdy)
);
assign KNNGLB_MapWrDatVld= PISO_OUT_VLD & PISO_OUT_DAT[0];
assign KNNGLB_MapWrAddr = KNNGLB_MapWrDatVld? PISO_OUT_DAT[1 +: IDX_WIDTH] : 0;
assign KNNGLB_MapWrDat  = KNNGLB_MapWrDatVld? PISO_OUT_DAT[1 + IDX_WIDTH +: SRAM_WIDTH] : 0;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        Pseudo_CrdRdVld <= 0;
    end else if(state == IDLE) begin
        Pseudo_CrdRdVld <= 0;
    end else if(KNNGLB_CrdRdAddrVld & rdy_s0) begin
        Pseudo_CrdRdVld <= 1'b1;
    end else if(GLBKNN_CrdRdDatVld & KNNGLB_CrdRdDatRdy) begin
        Pseudo_CrdRdVld <= 1'b0;
    end
end

//=====================================================================================================================
// Logic Design: Monitor
//=====================================================================================================================
assign KNNMON_Dat = {CntCrdByte, CntLopCrdRdAddr, CntMaskAddr, CntCpCrdRdAddr, CCUKNN_CfgInfo, state};

endmodule
