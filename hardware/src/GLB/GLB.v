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
module GLB #(
    parameter NUM_BANK     = 32,
    parameter SRAM_WIDTH   = 256,
    parameter SRAM_WORD    = 128, // MUST 2**
    parameter ADDR_WIDTH   = 16,

    parameter NUM_WRPORT   = 3,
    parameter NUM_RDPORT   = 4,
    parameter MAXPAR       = 32,
    
    parameter CLOCK_PERIOD = 10

    )(
    input                                               clk  ,
    input                                               rst_n,

    // Configure
    input  [NUM_RDPORT+NUM_WRPORT               -1 : 0] CCUGLB_CfgVld,
    output [NUM_RDPORT+NUM_WRPORT               -1 : 0] GLBCCU_CfgRdy,

    input [NUM_BANK * (NUM_RDPORT + NUM_WRPORT) -1 : 0] CCUGLB_CfgPortBankFlag,

    input [ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)   -1 : 0] CCUGLB_CfgPort_AddrMax,
    input [($clog2(MAXPAR) + 1)*(NUM_RDPORT + NUM_WRPORT)-1 : 0] CCUGLB_CfgPortParBank,

    // Data
    input  wire [SRAM_WIDTH*MAXPAR*NUM_WRPORT   -1 : 0] WrPortDat,
    input  wire [NUM_WRPORT                     -1 : 0] WrPortDatVld,
    input  wire [NUM_WRPORT                     -1 : 0] WrPortDatLast,
    output wire [NUM_WRPORT                     -1 : 0] WrPortDatRdy,
    output wire [NUM_WRPORT                     -1 : 0] WrPortEmpty,
    output wire [ADDR_WIDTH*NUM_WRPORT          -1 : 0] WrPortReqNum,
    output wire [ADDR_WIDTH*NUM_WRPORT          -1 : 0] WrPortAddr_Out, // Detect

    input  wire [NUM_WRPORT                     -1 : 0] WrPortUseAddr, //  Mode1: Use Address
    input  wire [ADDR_WIDTH*NUM_WRPORT          -1 : 0] WrPortAddr,

    output wire [SRAM_WIDTH*MAXPAR*NUM_RDPORT   -1 : 0] RdPortDat,
    output wire [NUM_RDPORT                     -1 : 0] RdPortDatVld,
    input  wire [NUM_RDPORT                     -1 : 0] RdPortDatRdy,
    output wire [NUM_RDPORT                     -1 : 0] RdPortFull,
    output wire [ADDR_WIDTH*NUM_RDPORT          -1 : 0] RdPortReqNum,
    output wire [ADDR_WIDTH*NUM_RDPORT          -1 : 0] RdPortAddr_Out,

    input  wire [NUM_RDPORT                     -1 : 0] RdPortUseAddr,
    input  wire [ADDR_WIDTH*NUM_RDPORT          -1 : 0] RdPortAddr,
    input  wire [NUM_RDPORT                     -1 : 0] RdPortAddrVld,
    output wire [NUM_RDPORT                     -1 : 0] RdPortAddrRdy    

);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam SRAM_DEPTH_WIDTH = $clog2(SRAM_WORD);

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [ADDR_WIDTH                -1 : 0] WrPortAddr_Array[0 : NUM_WRPORT -1];
wire [ADDR_WIDTH                -1 : 0] RdPortAddr_Array[0 : NUM_RDPORT -1];
reg  [SRAM_WIDTH*MAXPAR         -1 : 0] RdPortDat_Array [0 : NUM_RDPORT -1];
wire [SRAM_WIDTH*MAXPAR         -1 : 0] WrPortDat_Array [0 : NUM_WRPORT -1];

// reg [NUM_RDPORT+NUM_WRPORT      -1 : 0] CfgVld;
// wire [NUM_RDPORT+NUM_WRPORT     -1 : 0] CfgRdy;

wire [ADDR_WIDTH                -1 : 0] Cnt_RdPortAddr;
wire [ADDR_WIDTH                -1 : 0] Cnt_WrPortAddr;

wire                                    rvalid_array  [0 : NUM_BANK     -1];
wire [SRAM_WIDTH                -1 : 0] rdata_array   [0 : NUM_BANK     -1];
wire [NUM_BANK                  -1 : 0] WrPortBankEn  [0 : NUM_WRPORT   -1];
wire [NUM_BANK                  -1 : 0] RdPortBankEn  [0 : NUM_RDPORT   -1];
wire [$clog2(NUM_WRPORT)        -1 : 0] BankWrPortIdx [0 : NUM_BANK     -1];
wire [$clog2(NUM_RDPORT)        -1 : 0] BankRdPortIdx [0 : NUM_BANK     -1];
wire [(NUM_WRPORT+NUM_RDPORT)   -1 : 0] BankPortFlag  [0 : NUM_BANK     -1];

wire [NUM_RDPORT                -1 : 0] RdPortEn;
wire [NUM_RDPORT                -1 : 0] WrPortEn;

genvar      gv_i;
genvar      gv_j;
integer     int_i;
//=====================================================================================================================
// Logic Design
//=====================================================================================================================

// generate
//     for(gv_j=0; gv_j<NUM_WRPORT+NUM_RDPORT; gv_j=gv_j+1) begin
//         always @ ( posedge clk or negedge rst_n ) begin
//             if ( !rst_n ) begin
//                 CfgVld[gv_j] <= 0;
//             end else if (CCUGLB_CfgVld[gv_j] & GLBCCU_CfgRdy[gv_j]) begin
//                 CfgVld[gv_j] <= 1'b1;
//             end else if (GLBCCU_CfgRdy[gv_j]) begin
//                 CfgVld[gv_j] <= 1'b0;
//             end
//         end
//     end
// endgenerate
// assign GLBCCU_CfgRdy = CfgRdy | !CfgVld;


//=====================================================================================================================
// Logic Design
//=====================================================================================================================


generate
    for(gv_i=0; gv_i<NUM_BANK; gv_i=gv_i+1) begin: GEN_BANK

        wire                            wvalid;
        wire                            arvalid;
        wire                            arready;
        wire                            rvalid;
        wire                            rready;
        wire [SRAM_DEPTH_WIDTH  -1 : 0] waddr;
        wire [SRAM_DEPTH_WIDTH  -1 : 0] araddr;
        wire [SRAM_WIDTH        -1 : 0] wdata;
        wire [SRAM_WIDTH        -1 : 0] rdata;
        reg  [$clog2(NUM_BANK)  -1 : 0] BankWrPortParIdx;

        RAM_HS#(
            .SRAM_BIT     ( SRAM_WIDTH ),
            .SRAM_BYTE    ( 1 ),
            .SRAM_WORD    ( SRAM_WORD ),
            .CLOCK_PERIOD ( CLOCK_PERIOD )
        )u_RAM_HS(
            .clk          ( clk          ),
            .rst_n        ( rst_n        ),
            .wvalid       ( wvalid       ),
            .wready       (              ),
            .waddr        ( waddr        ),
            .wdata        ( wdata        ),
            .arvalid      ( arvalid      ),
            .arready      ( arready      ),
            .araddr       ( araddr       ),
            .rvalid       ( rvalid       ),
            .rready       ( rready       ),
            .rdata        ( rdata        )
        );
        //=====================================================================================================================
        // Logic Designss
        //=====================================================================================================================
        assign wvalid = WrPortBankEn[BankWrPortIdx[gv_i]][gv_i];
        assign waddr   = WrPortAddr_Array[BankWrPortIdx[gv_i]]; // Cut LSB

        always @(*) begin
            BankWrPortParIdx = 0;
            for(int_i=0; int_i<NUM_BANK; int_i=int_i+1) begin
                if(int_i < gv_i)
                    BankWrPortParIdx = BankWrPortParIdx + WrPortBankEn[BankWrPortIdx[gv_i]][int_i];
            end
        end
        assign wdata = WrPortDat_Array[BankWrPortIdx[gv_i]][SRAM_WIDTH*BankWrPortParIdx +: SRAM_WIDTH];

        //=====================================================================================================================
        // Logic Design 4: Read Port
        //=====================================================================================================================
        assign arvalid  = RdPortBankEn[BankRdPortIdx[gv_i]];    
        assign araddr   = RdPortAddr_Array[BankRdPortIdx[gv_i]]; 

        assign rready = RdPortDatRdy[BankRdPortIdx[gv_i]];
        assign rvalid_array[gv_i]  = rvalid;
        assign rdata_array[gv_i]   = rdata;

        prior_arb#(
            .REQ_WIDTH ( NUM_WRPORT )
        )u_prior_arb_BankWrPortIdx(
            .req ( BankPortFlag[gv_i][0 +: NUM_WRPORT] ),
            .gnt (  ),
            .arb_port  ( BankWrPortIdx[gv_i]  )
        );

        prior_arb#(
            .REQ_WIDTH ( NUM_RDPORT )
        )u_prior_arb_BankRdPortIdx(
            .req ( BankPortFlag[gv_i][NUM_WRPORT +: NUM_RDPORT] ),
            .gnt (  ),
            .arb_port  ( BankRdPortIdx[gv_i]  )
        );

        for(gv_j=0; gv_j<NUM_WRPORT+NUM_RDPORT; gv_j=gv_j+1) begin
            assign BankPortFlag[gv_i][gv_j] = CCUGLB_CfgPortBankFlag[NUM_BANK*gv_j + gv_i];
        end

    end
endgenerate

//=====================================================================================================================
// Logic Design 4: Read Port
//=====================================================================================================================


generate
    for(gv_j=0; gv_j<NUM_RDPORT; gv_j=gv_j+1) begin
        wire                                INC;
        wire [$clog2(NUM_BANK)      -1 : 0] PortCur1stBankIdx;
        wire [$clog2(NUM_BANK)      -1 : 0] RdPort1stBankIdx;
        wire [$clog2(NUM_WRPORT)    -1 : 0] RdPortMthWrPortIdx;
        wire                                Empty;
        wire [NUM_BANK              -1 : 0] RdPortHitBank;

        assign INC = RdPortAddrRdy[gv_j] & RdPortAddrVld[gv_j];
        assign PortCur1stBankIdx = RdPort1stBankIdx + (RdPortAddr_Array[gv_j] >> SRAM_DEPTH_WIDTH)*CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*(NUM_WRPORT+gv_j) +: ($clog2(MAXPAR) + 1)];
        assign RdPortMthWrPortIdx = BankWrPortIdx[PortCur1stBankIdx];
        assign Empty = RdPortAddr_Array[gv_j] == WrPortAddr_Array[RdPortMthWrPortIdx];

        // To Bank
        assign RdPortEn[gv_j] = RdPortUseAddr[gv_j]? RdPortAddrVld[gv_j] : RdPortDatRdy[gv_j]  & !Empty;
        assign RdPortAddr_Array[gv_j] = RdPortUseAddr[gv_j] ? RdPortAddr[ADDR_WIDTH*gv_j +: ADDR_WIDTH] : Cnt_RdPortAddr;
        for(gv_i=0; gv_i<NUM_BANK; gv_i=gv_i+1) begin
                assign RdPortHitBank[gv_i] = PortCur1stBankIdx <= gv_i & gv_i < PortCur1stBankIdx + CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*(NUM_WRPORT+gv_j) +: ($clog2(MAXPAR) + 1)];
        end

        assign RdPortBankEn[gv_j] = RdPortEn[gv_j] & RdPortHitBank; // 32bits

        assign RdPortDatVld[gv_j] = rvalid_array[PortCur1stBankIdx];

        for(gv_i=0; gv_i<MAXPAR; gv_i=gv_i+1) begin
            assign RdPortDat[SRAM_WIDTH*(MAXPAR*gv_j + gv_i) +: SRAM_WIDTH] =  rdata_array[PortCur1stBankIdx+gv_i];
        end
        assign RdPortAddrRdy[gv_j] = INC;
        assign RdPortFull[gv_j] = RdPortReqNum[gv_j] == CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(NUM_WRPORT+gv_j) +: ADDR_WIDTH] ;
        assign RdPortReqNum[gv_j] = WrPortAddr_Array[RdPortMthWrPortIdx] - RdPortAddr_Array[gv_j];
        assign RdPortAddr_Out[ADDR_WIDTH*gv_j +: ADDR_WIDTH] = RdPortAddr_Array[gv_j];

        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_RdPortAddr(
            .CLK       ( clk                    ),
            .RESET_N   ( rst_n                  ),
            .CLEAR     ( CCUGLB_CfgVld[NUM_WRPORT+gv_j]),
            .DEFAULT   ( {ADDR_WIDTH{1'b0}}                                                              ),
            .INC       ( INC                                                            ),
            .DEC       ( 1'b0                                                           ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}                                                              ),
            .MAX_COUNT ( CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(NUM_WRPORT+gv_j) +: ADDR_WIDTH]   ),
            .OVERFLOW  ( GLBCCU_CfgRdy[NUM_WRPORT+gv_j]                                  ),
            .UNDERFLOW (                                                                ),
            .COUNT     ( Cnt_RdPortAddr                                            )
        );

    end

endgenerate

//=====================================================================================================================
// Logic Design 5: Write Port
//=====================================================================================================================

generate
    for(gv_j=0; gv_j<NUM_WRPORT; gv_j=gv_j+1) begin
        wire                            INC;
        wire [$clog2(NUM_BANK)  -1 : 0] PortCur1stBankIdx;
        wire [$clog2(NUM_BANK)  -1 : 0] WrPort1stBankIdx;
        wire [$clog2(NUM_RDPORT)-1 : 0] WrPortMthRdPortIdx;
        wire                            Full;
        wire [NUM_BANK          -1 : 0] WrPortHitBank;


        // Intra signals
        assign INC = WrPortDatRdy[gv_j] & WrPortDatVld[gv_j];
        assign PortCur1stBankIdx = WrPort1stBankIdx + (WrPortAddr_Array[gv_j] >> SRAM_DEPTH_WIDTH)*CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*gv_j +: ($clog2(MAXPAR) + 1)];
        assign WrPortMthRdPortIdx = BankRdPortIdx[PortCur1stBankIdx];
        assign Full = ( (WrPortAddr_Array[gv_j] - RdPortAddr_Array[WrPortMthRdPortIdx])== CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*gv_j +: ADDR_WIDTH] );

        // To Bank
        assign WrPortEn[gv_j] = !(RdPortEn[WrPortMthRdPortIdx]) & WrPortDatVld[gv_j]  & !Full;
        assign WrPortDat_Array[gv_j] = WrPortDat[SRAM_WIDTH*MAXPAR*gv_j +: SRAM_WIDTH*MAXPAR];
        assign WrPortAddr_Array[gv_j] = WrPortUseAddr[gv_j] ? WrPortAddr[ADDR_WIDTH*gv_j +: ADDR_WIDTH] : Cnt_WrPortAddr;
        for(gv_i=0; gv_i<NUM_BANK; gv_i=gv_i+1) begin
                assign WrPortHitBank[gv_i] = PortCur1stBankIdx <= gv_i & gv_i < PortCur1stBankIdx + CCUGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*gv_j +: ($clog2(MAXPAR) + 1)];
        end
        assign WrPortBankEn[gv_j] = WrPortEn[gv_j] & WrPortHitBank; // 32bits

        // To Output
        assign WrPortDatRdy[gv_j] = !Full;
        assign WrPortEmpty[gv_j] = WrPortReqNum[ADDR_WIDTH*gv_j +: ADDR_WIDTH] == CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*gv_j +: ADDR_WIDTH];
        assign WrPortReqNum[ADDR_WIDTH*gv_j +: ADDR_WIDTH] = CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*gv_j +: ADDR_WIDTH] - (WrPortAddr_Array[gv_j] - RdPortAddr_Array[WrPortMthRdPortIdx]);
        assign WrPortAddr_Out[ADDR_WIDTH*gv_j +: ADDR_WIDTH] = WrPortAddr_Array[gv_j];

        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter(
            .CLK       ( clk        ),
            .RESET_N   ( rst_n      ),
            .CLEAR     ( CCUGLB_CfgVld[gv_j]  ),
            .DEFAULT   ( {ADDR_WIDTH{1'b0}}          ),
            .INC       ( INC        ),
            .DEC       ( 1'b0       ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}          ),
            .MAX_COUNT ( CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*gv_j +: ADDR_WIDTH]),
            .OVERFLOW  ( GLBCCU_CfgRdy[gv_j]  ),
            .UNDERFLOW (            ),
            .COUNT     ( Cnt_WrPortAddr)
        );

        prior_arb#(
            .REQ_WIDTH ( NUM_BANK )
        )u_prior_arb(
            .req ( CCUGLB_CfgPortBankFlag[NUM_BANK*gv_j +: NUM_BANK]),
            .gnt (  ),
            .arb_port  ( WrPort1stBankIdx  )
        );


    end
endgenerate


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================


endmodule
