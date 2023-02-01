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
module FPS #(
    parameter SRAM_WIDTH        = 256,
    parameter IDX_WIDTH         = 10,
    parameter CRD_WIDTH         = 16,
    parameter CRD_DIM           = 3,
    parameter NUM_FPC           = 4,
    parameter DISTSQR_WIDTH     = CRD_WIDTH*2 + $clog2(CRD_DIM),
    parameter CRDIDX_WIDTH      = CRD_WIDTH*CRD_DIM+IDX_WIDTH
    )(
    input                               clk  ,
    input                               rst_n,

    // Configure
    input  [NUM_FPC             -1 : 0] CCUFPS_Rst,
    input  [NUM_FPC             -1 : 0] CCUFPS_CfgVld,
    output [NUM_FPC             -1 : 0] FPSCCU_CfgRdy,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgNip,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgNop,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgCrdBaseRdAddr,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgCrdBaseWrAddr,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgIdxBaseWrAddr,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgMaskBaseAddr,
    input  [IDX_WIDTH*NUM_FPC   -1 : 0] CCUFPS_CfgDistBaseAddr,

    output [IDX_WIDTH           -1 : 0] FPSGLB_MaskRdAddr,
    output                              FPSGLB_MaskRdAddrVld,
    input                               GLBFPS_MaskRdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0] GLBFPS_MaskRdDat,    
    input                               GLBFPS_MaskRdDatVld,    
    output                              FPSGLB_MaskRdDatRdy,    

    output [IDX_WIDTH           -1 : 0] FPSGLB_MaskWrAddr,
    output [SRAM_WIDTH          -1 : 0] FPSGLB_MaskWrDat,   
    output                              FPSGLB_MaskWrDatVld,
    input                               GLBFPS_MaskWrDatRdy, 

    output [IDX_WIDTH           -1 : 0] FPSGLB_CrdRdAddr,
    output                              FPSGLB_CrdRdAddrVld,
    input                               GLBFPS_CrdRdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0] GLBFPS_CrdRdDat,    
    input                               GLBFPS_CrdRdDatVld,    
    output                              FPSGLB_CrdRdDatRdy,    

    output [IDX_WIDTH           -1 : 0] FPSGLB_CrdWrAddr,
    output [SRAM_WIDTH          -1 : 0] FPSGLB_CrdWrDat,   
    output                              FPSGLB_CrdWrDatVld,
    input                               GLBFPS_CrdWrDatRdy,  

    output [IDX_WIDTH           -1 : 0] FPSGLB_DistRdAddr,
    output                              FPSGLB_DistRdAddrVld,
    input                               GLBFPS_DistRdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0] GLBFPS_DistRdDat,    
    input                               GLBFPS_DistRdDatVld,    
    output                              FPSGLB_DistRdDatRdy,    

    output [IDX_WIDTH           -1 : 0] FPSGLB_DistWrAddr,
    output [SRAM_WIDTH          -1 : 0] FPSGLB_DistWrDat,   
    output                              FPSGLB_DistWrDatVld,
    input                               GLBFPS_DistWrDatRdy,

    output [IDX_WIDTH           -1 : 0] FPSGLB_IdxWrAddr,
    output [SRAM_WIDTH          -1 : 0] FPSGLB_IdxWrDat,   
    output                              FPSGLB_IdxWrDatVld,
    input                               GLBFPS_IdxWrDatRdy,

);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam NUM_CRD_SRAM = 2**$clog2( SRAM_WIDTH / (CRD_WIDTH*CRD_DIM) );
localparam NUM_DIST_SRAM = SRAM_WIDTH / DISTSQR_WIDTH;
localparam NUM_MASK_SRAM = SRAM_WIDTH;


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

//=====================================================================================================================
// Logic Design
//=====================================================================================================================
generate
    for(gv_fpc=0; gv_fpc<NUM_FPC; gv_fpc=gv_fpc+1) begin
        //=====================================================================================================================
        // Constant Definition :
        //=====================================================================================================================
        localparam IDLE   = 3'b000;
        localparam CP     = 3'b001;
        localparam LP     = 3'b010;
        localparam WAITFNH= 3'b011;


        //=====================================================================================================================
        // Variable Definition :
        //=====================================================================================================================
        reg [IDX_WIDTH          -1 : 0] FPS_MaxIdx;
        wire[IDX_WIDTH          -1 : 0] FPS_MaxIdx_;
        reg [CRD_WIDTH*CRD_DIM  -1 : 0] FPS_MaxCrd;
        wire[CRD_WIDTH*CRD_DIM  -1 : 0] FPS_MaxCrd_;
        reg [CRD_WIDTH*CRD_DIM  -1 : 0] FPS_CpCrd;
        wire                            FPS_UpdMax;
        wire[IDX_WIDTH          -1 : 0] FPS_PsIdx;
        reg [DISTSQR_WIDTH      -1 : 0] FPS_MaxDist;
        wire[DISTSQR_WIDTH      -1 : 0] FPS_MaxDist_;
        wire[DISTSQR_WIDTH      -1 : 0] FPS_PsDist;
        reg [DISTSQR_WIDTH      -1 : 0] FPS_PsDist_s2;
        reg [DISTSQR_WIDTH      -1 : 0] FPS_PsDist_s3;
        wire[DISTSQR_WIDTH      -1 : 0] LopDist;
        reg [DISTSQR_WIDTH      -1 : 0] FPS_LastPsDist_s2; 
        reg [IDX_WIDTH          -1 : 0] FPS_LastPsIdx_s2;
        reg                             LopCntLast_s2;
        reg                             LopCntLast_s1;
        reg                             LopCntLast_s3;
        wire                            LopCntLast;
        reg [IDX_WIDTH          -1 : 0] LopPntIdx_s2;
        reg [IDX_WIDTH          -1 : 0] LopPntIdx_s1;
        reg [IDX_WIDTH          -1 : 0] LopPntIdx_s3;
        wire[IDX_WIDTH          -1 : 0] LopPntIdx;
        wire[CRD_WIDTH*CRD_DIM  -1 : 0] LopPntCrd;
        reg [CRD_WIDTH*CRD_DIM  -1 : 0] LopPntCrd_s2;
        reg [CRD_WIDTH*CRD_DIM  -1 : 0] LopPntCrd_s3;
        wire                            CpLast;
        wire [IDX_WIDTH         -1 : 0] CpCnt;
        reg  [IDX_WIDTH         -1 : 0] CpCnt_s1;
        wire [IDX_WIDTH         -1 : 0] LopLLA;
        wire [IDX_WIDTH         -1 : 0] LopCnt;
        reg  [$clog2(NUM_LAYER) -1 : 0] FPSLyIdx;
        reg  [$clog2(NUM_LAYER) -1 : 0] FPSLyIdx_s1;
        reg  [$clog2(NUM_LAYER) -1 : 0] FPSLyIdx_s2;
        wire [$clog2(SRAM_WIDTH/NUM_LAYER) -1 : 0] MaskRAMByteIdx;
        wire [$clog2(NUM_LAYER) -1 : 0] MaskRAMBitIdx;
        reg  [SRAM_WIDTH        -1 : 0] GLBFPS_MaskRdDat_s2;
        wire                            rdy_s0;
        wire                            rdy_s1;
        wire                            rdy_s2;
        wire                            rdy_s3;
        reg                             vld_s0;
        wire                            vld_s1;
        reg                             vld_s2;
        reg                             vld_s3;
        wire                            handshake_s0;
        wire                            handshake_s1;
        wire                            handshake_s2;
        wire                            handshake_s3;
        wire                            ena_s0;
        wire                            ena_s1;
        wire                            ena_s2;
        wire                            ena_s3;

        //=====================================================================================================================
        // Logic Design: Stage0
        //=====================================================================================================================

        reg [ 3 -1:0 ]state;
        reg [ 3 -1:0 ]next_state;
        always @(*) begin
            case ( state )
                IDLE :  if(FPSCCU_CfgRdy[gv_fpc] & CCUFPS_CfgVld[gv_fpc])
                            next_state <= CP; //
                        else
                            next_state <= IDLE;
                CP:     if( 1'b1)
                            next_state <= LP;
                        else
                            next_state <= CP;
                LP:     if ( LopCntLast ) begin
                            if ( CpLast )
                                next_state <= WAITFNH;
                            else //
                                next_state <= CP;
                        end
                        else
                            next_state <= LP;
                WAITFNH:if(LopCntLast_s2 & FPSGLB_MaskWrDatVld[gv_fpc] & FPSGLB_DistWrDatVld[gv_fpc] & FPSGLB_CrdWrDatVld[gv_fpc] & FPSGLB_IdxWrDatVld[gv_fpc]) // Last Loop point & no to Write
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

        assign FPSCCU_CfgRdy[gv_fpc] = state==IDLE;

        // Combinational Logic
        assign LopCntLast = (FPC_CrdRdAddr+1)*NUM_CRD_SRAM >= CCUFPS_CfgNip;
        // HandShake

        // Reg Update

        wire INC_CntCp;
        wire [IDX_WIDTH     -1 : 0] MaxCntCp = CCUFPS_CfgNop[IDX_WIDTH*gv_fpc +: IDX_WIDTH] -1;
        counter#(
            .COUNT_WIDTH ( IDX_WIDTH )
        )u0_counter_CntCp(
            .CLK       ( clk            ),
            .RESET_N   ( rst_n          ),
            .CLEAR     ( CCUFPS_Rst     ),
            .DEFAULT   ( {IDX_WIDTH{1'b0}}),
            .INC       ( state == LP && next_state == CP),
            .DEC       ( 1'b0           ),
            .MIN_COUNT ( {IDX_WIDTH{1'b0}}),
            .MAX_COUNT ( MaxCntCp       ),
            .OVERFLOW  ( CpLast         ),
            .UNDERFLOW (                ),
            .COUNT     ( CpCnt          )
        );

        wire [IDX_WIDTH     -1 : 0] Max_FPC_MaskRdAddr = CCUFPS_CfgNip % SRAM_WIDTH?  CCUFPS_CfgNip / SRAM_WIDTH -1 : CCUFPS_CfgNip / SRAM_WIDTH;
        wire INC_FPC_MaskRdAddr = FPSGLB_MaskRdAddrVld & GLBFPS_MaskRdAddrRdy;
        counter#( // Pipe S0
            .COUNT_WIDTH ( IDX_WIDTH )
        )u1_counter_FPC_MaskRdAddr(
            .CLK       ( clk                ),
            .RESET_N   ( rst_n              ),
            .CLEAR     ( state == LP && next_state == CP | CCUFPS_Rst),
            .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
            .INC       ( INC_FPC_MaskRdAddr         ),
            .DEC       ( 1'b0               ),
            .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
            .MAX_COUNT ( Max_FPC_MaskRdAddr  ),
            .OVERFLOW  (                    ),
            .UNDERFLOW (                    ),
            .COUNT     ( CntMaskRd             )
        );

        wire [IDX_WIDTH     -1 : 0] Max_FPC_CrdRdAddr = CCUFPS_CfgNip % NUM_CRD_SRAM?  CCUFPS_CfgNip / NUM_CRD_SRAM -1 : CCUFPS_CfgNip / NUM_CRD_SRAM;;
         wire HandShake_CrdRdAddr = FPSGLB_CrdRdAddrVld & GLBFPS_CrdRdAddrRdy;
        counter#( // Pipe S0
            .COUNT_WIDTH ( IDX_WIDTH )
        )u1_counter_LopIdx(
            .CLK       ( clk                ),
            .RESET_N   ( rst_n              ),
            .CLEAR     ( state == LP && next_state == CP | CCUFPS_Rst ),
            .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
            .INC       ( HandShake_CrdRdAddr         ),
            .DEC       ( 1'b0               ),
            .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
            .MAX_COUNT ( Max_FPC_CrdRdAddr          ),
            .OVERFLOW  (          ),
            .UNDERFLOW (                    ),
            .COUNT     ( FPC_CrdRdAddr             )
        );

        wire [IDX_WIDTH     -1 : 0] Max_FPC_DistRdAddr = CCUFPS_CfgNip % NUM_DIST_SRAM?  CCUFPS_CfgNip / NUM_DIST_SRAM -1 : CCUFPS_CfgNip / NUM_DIST_SRAM;;
         wire INC_FPC_DistRdAddr = FPSGLB_DistRdAddrVld & GLBFPS_DistRdAddrRdy;
        counter#( // Pipe S0
            .COUNT_WIDTH ( IDX_WIDTH )
        )u1_counter_LopIdx(
            .CLK       ( clk                ),
            .RESET_N   ( rst_n              ),
            .CLEAR     ( state == LP && next_state == CP | CCUFPS_Rst),
            .DEFAULT   ( {IDX_WIDTH{1'b0}}  ),
            .INC       ( INC_FPC_DistRdAddr         ),
            .DEC       ( 1'b0               ),
            .MIN_COUNT ( {IDX_WIDTH{1'b0}}  ),
            .MAX_COUNT ( Max_FPC_DistRdAddr          ),
            .OVERFLOW  (          ),
            .UNDERFLOW (                    ),
            .COUNT     ( FPC_DistRdAddr             )
        );
s
        //=====================================================================================================================
        // Logic Design: Stage1: Crd Gen
        //=====================================================================================================================
        // Combinational Logic
        assign FPC_MaskRdAddr = CCUFPS_CfgMaskBaseRdAddr[IDX_WIDTH*gv_fpc +: IDX_WIDTH] + CntMaskRd;
        assign FPSGLB_MaskRdAddrVld = CntMaskRd*SRAM_WIDTH < RealIdx_s1+1;

        assign FPSGLB_CrdRdAddr[IDX_WIDTH*gv_fpc +: IDX_WIDTH] = CCUFPS_CfgCrdBaseRdAddr[IDX_WIDTH*gv_fpc +: IDX_WIDTH] +FPC_CrdRdAddr;
        assign FPSGLB_CrdRdAddrVld = FPSGLB_CrdRdAddr*NUM_CRD_NUM <= RealIdx_s1+1;

        assign FPSGLB_DistRdAddr[IDX_WIDTH*gv_fpc +: IDX_WIDTH] = CCUFPS_CfgDistBaseRdAddr[IDX_WIDTH*gv_fpc +: IDX_WIDTH] + FPC_DistRdAddr;
        assign FPSGLB_DistRdAddrVld = FPC_DistRdAddr*NUM_DIST_SRAM <= RealIdx_s1+1; // ahead 1 clk
        
        // HandShake

        // Reg Update
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                FPC_MaskRdAddr_s1 <= 0;
            end else if ( HandShake_CrdRdAddr  ) begin
                FPC_MaskRdAddr_s1 <= FPC_MaskRdAddr;
            end
        end

        //=====================================================================================================================
        // Logic Design: Stage2: Max Gen
        //=====================================================================================================================
        // Combinational Logic
        // Mask
        assign FPSGLB_MaskRdDatRdy[gv_fpc] = ena_s2 & (FPC_MaskWrDatVld? GLBFPS_MaskWrDatRdy : 1'b1);
        assign FPSGLB_CrdRdDatRdy[gv_fpc] = ena_s2;
        assign FPSGLB_DistRdDatRdy[gv_fpc] = ena_s2;
        prior_arb#(
            .REQ_WIDTH ( SRAM_WIDTH )
        )u_prior_arb_MaskCheck(
            .req ( !MaskCheck_s1[AddrCnt*4 +: 4] ),
            .gnt (  ),
            .arb_port  ( VldIdx  )
        );
        assign VldArb = !(&MaskCheck_s1[AddrCnt*4 +: 4]); // exist 0
        assign RealIdx_s1 = VldArb? (AddrCnt*4 + VldIdx) : AddrCnt*(4 + 1);// exist 0(valid? arbed Idx : first idx of next word 

        // Mask write back
        assign FPC_MaskWrAddr = FPC_MaskRdAddr_s1;
        generate // set "1"
            for(gv_mask; ) begin
                assign FPC_MaskWrDat[gv_mask] = gv_mask==FPS_MaxIdx_% SRAM_WIDTH? 1'b1 : GLBFPS_MaskRdDat[gv_mask];
            end
        endgenerate
        assign FPC_MaskWrDatVld = LopCntLast_s1 & FPC_MaskRdDatVld;

        // PISO
        assign MaskCheck_s1 =  FPC_MaskRdDatVld & FPSGLB_MaskRdDatRdy[gv_fpc]? GLBFPS_MaskRdDat : MaskCheck_s2;
        assign Crd_s1 = FPSGLB_CrdRdDatVld? GLBFPS_CrdRdDat : Crd_s2;
        assign Dist_s1 = FPSGLB_DistRdDatVld? GLBFPS_DistRdDat : Dist_s2;

        // FPS   
        assign LopPntCrd = VldArb? Crd_s1[CRD_WIDTH*CRD_DIM*(VldIdx % NUM_CRD_SRAM) +: CRD_WIDTH*CRD_DIM]: 0;   

        EDC#(
            .CRD_WIDTH ( CRD_WIDTH  ),
            .CRD_DIM   ( CRD_DIM    )
        )u_EDC(
            .Crd0      ( FPS_CpCrd  ),
            .Crd1      ( LopPntCrd  ),
            .DistSqr   ( LopDist    )
        );
        assign FPS_LastPsDist = VldArb? Dist_s1[DISTSQR_WIDTH*(RealIdx_s1 % NUM_DIST_SRAM) +: DISTSQR_WIDTH]: 0; 
        assign FPS_PsDist = FPS_LastPsDist > LopDist ? LopDist : FPS_LastPsDist;
        assign FPS_UpdMax = FPS_MaxDist < FPS_PsDist;
        assign {FPS_MaxDist_, FPS_MaxCrd_, FPS_MaxIdx_} = FPS_UpdMax ? {FPS_PsDist, LopPntCrd, LopPntIdx_s1} : {FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx};

        // HandShake
        assign rdy_s2 = ena_s3;
        assign handshake_s2 = rdy_s2 & vld_s2;
        assign ena_s2 = handshake_s2 | ~vld_s2;

        // Reg Update
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                {FPS_CpCrd, FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx, FPS_PsDist_s2, LopPntIdx_s2, LopCntLast_s2, vld_s2} <= 0;
            end else if (ena_s2) begin
                {FPS_CpCrd, FPS_MaxDist, FPS_MaxCrd, FPS_MaxIdx, FPS_PsDist_s2, LopPntIdx_s2, LopCntLast_s2, vld_s2} <= 
                {(LopCntLast_s1 | CpCnt_s1==0)? FPS_MaxCrd_ : FPS_CpCrd, FPS_MaxCrd_, FPS_MaxIdx_, FPS_PsDist, LopPntIdx_s1, LopCntLast_s1, handshake_s1};
            end
        end

        generate // set "1"
            for(gv_mask; ) begin
                always @(posedge clk or negedge rst_n) begin
                    if(!rst_n) begin
                        {} <= 0;
                    end else if (ena_s2) begin
                        if (VldArb & gv_mask == AddrCnt*4 + VldIdx)
                            MaskCheck_s2[gv_mask] <= 1'b1;
                        else
                            MaskCheck_s2[gv_mask] <= MaskCheck_s1[gv_mask];
                    end
                end
            end
        endgenerate

        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                Crd_s2 <= 0;
            end else if (ena_s2) begin
                Crd_s2 <= Crd_s1;
            end
        end
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                Dist_s2 <= 0;
            end else if (ena_s2) begin
                Dist_s2 <= Dist_s1;
            end
        end


        //=====================================================================================================================
        // Logic Design: S3
        //=====================================================================================================================

        // Combinational Logic
        assign FPC_CrdWrDatVld = vld_s2 &  LopCntLast_s2;
        assign {FPC_CrdWrDat, FPC_CrdWrAddr}= {FPS_MaxCrd, CpCnt_s2 / NUM_CRD_SRAM};
    
        assign FPC_IdxWrDatVld =  vld_s2 &  LopCntLast_s2;
        assign {FPC_IdxWrDat, FPC_IdxWrAddr}= {FPS_MaxIdx, CpCnt_s2 / NUM_IDX_SRAM};

        // HandShake
        assign rdy_s3 = SIPO_DistInRdy;
        assign handshake_s3 = rdy_s3 & vld_s3;
        assign ena_s3 = handshake_s3 | ~vld_s3;

        // Reg Update
        SIPO#(
            .DATA_IN_WIDTH   ( DISTSQR_WIDTH  ), 
            .DATA_OUT_WIDTH  ( DISTSQR_WIDTH*(SRAM_WIDTH/DISTSQR_WIDTH)  )
        )u_SIPO_DISTWR(
            .CLK       ( clk                ),
            .RST_N     ( rst_n              ),
            .IN_VLD    ( vld_s2 & LopCntLast_s2 ),
            .IN_LAST   (           ),
            .IN_DAT    ( FPS_PsDist_s2    ),
            .IN_RDY    ( SIPO_DistInRdy      ),
            .OUT_DAT   ( FPC_DistWrDat      ),
            .OUT_VLD   ( FPC_DistWrDatVld     ),
            .OUT_LAST  (                    ),
            .OUT_RDY   ( GLBFPS_DistWrDatRdy & FPC_DistWrDatVld )
        );
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                CpCnt_s3 <= 0;
            end else if (ena_s3) begin
                CpCnt_s3 <= CpCnt_s2;
            end
        end
        assign FPC_IdxWrAddr= CpCnt_s3 / NUM_IDX_SRAM;

    end 

endgenerate


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================




endmodule
