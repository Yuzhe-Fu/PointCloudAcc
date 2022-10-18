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

    // input [(NUM_RDPORT + NUM_WRPORT)* NUM_BANK  -1 : 0] CCUGLB_CfgBankPort,
    input [NUM_BANK * (NUM_RDPORT + NUM_WRPORT)  -1 : 0] CCUGLB_CfgPortBankFlag,

    input [ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)   -1 : 0] CCUGLB_CfgPort_AddrMax,
    input [($clog2(MAXPAR) + 1)*NUM_RDPORT      -1 : 0] CCUGLB_CfgRdPortParBank,
    input [($clog2(MAXPAR) + 1)*NUM_WRPORT      -1 : 0] CCUGLB_CfgWrPortParBank,


    // Data
    input  wire [SRAM_WIDTH*MAXPAR*NUM_WRPORT   -1: 0] WrPortDat,
    input  wire [NUM_WRPORT                     -1: 0] WrPortDatVld,
    input  wire [NUM_WRPORT                     -1: 0] WrPortDatLast,
    output reg  [NUM_WRPORT                     -1: 0] WrPortDatRdy,
    output reg  [NUM_WRPORT                     -1: 0] WrPortEmpty,
    output reg  [ADDR_WIDTH*NUM_WRPORT          -1: 0] WrPortReqNum,
    output wire [ADDR_WIDTH*NUM_WRPORT          -1: 0] WrPortAddr_Out, // Detect

    input  wire [NUM_WRPORT                     -1: 0] WrPortUseAddr, //  Mode1: Use Address
    input  wire [ADDR_WIDTH*NUM_WRPORT          -1: 0] WrPortAddr,

    output wire [SRAM_WIDTH*MAXPAR*NUM_RDPORT   -1: 0] RdPortDat,
    output reg  [NUM_RDPORT                     -1: 0] RdPortDatVld,
    // output reg  [NUM_RDPORT                     -1: 0] RdPortDatLast, // ????????????????????????????????
    input  wire [NUM_RDPORT                     -1: 0] RdPortDatRdy,
    output reg  [NUM_RDPORT                     -1: 0] RdPortFull,
    output reg  [ADDR_WIDTH*NUM_RDPORT          -1: 0] RdPortReqNum,
    output wire [ADDR_WIDTH*NUM_RDPORT          -1: 0] RdPortAddr_Out,

    input  wire [NUM_RDPORT                     -1: 0] RdPortUseAddr,
    input  wire [ADDR_WIDTH*NUM_RDPORT          -1: 0] RdPortAddr,
    input  wire [NUM_RDPORT                     -1: 0] RdPortAddrVld,
    output reg  [NUM_RDPORT                     -1: 0] RdPortAddrRdy    

);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam SRAM_DEPTH_WIDTH = $clog2(SRAM_WORD);

localparam IDLE = 3'b000;
localparam CFG  = 3'b001;
localparam WORK = 3'b010;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [ADDR_WIDTH        -1 : 0] WrPortAddr_Array[0: NUM_WRPORT -1];
wire [ADDR_WIDTH        -1 : 0] RdPortAddr_Array[0: NUM_RDPORT -1];
reg  [SRAM_WIDTH*MAXPAR -1 : 0] RdPortDat_Array[0 : NUM_RDPORT -1];
wire [SRAM_WIDTH*MAXPAR -1 : 0] WrPortDat_Array[0 : NUM_WRPORT -1];

// Map
reg [$clog2(NUM_RDPORT) -1 : 0] BankRdPort       [0: NUM_BANK -1];
reg [$clog2(NUM_WRPORT) -1 : 0] BankWrPort       [0: NUM_BANK -1];
reg [$clog2(NUM_BANK)   -1 : 0] BankWrPortRelIdx [0: NUM_BANK -1];
reg [$clog2(NUM_BANK)   -1 : 0] BankRdPortRelIdx [0: NUM_BANK -1];
reg [$clog2(NUM_BANK)   -1 : 0] BankWrPortParIdx [0: NUM_BANK -1];
reg [$clog2(NUM_BANK)   -1 : 0] BankRdPortParIdx [0: NUM_BANK -1];

reg [($clog2(NUM_BANK) + 1)-1 : 0] RdPortNumBank[0 : NUM_RDPORT -1];
reg [($clog2(NUM_BANK) + 1)-1 : 0] WrPortNumBank[0 : NUM_WRPORT -1];

reg [($clog2(MAXPAR) + 1)  -1 : 0] RdPortParBank[0 : NUM_RDPORT      -1];
reg [($clog2(MAXPAR) + 1)  -1 : 0] WrPortParBank[0 : NUM_WRPORT      -1];

reg [$clog2(NUM_RDPORT) -1 : 0] BankRdPort_wire       [0: NUM_BANK -1];
reg [$clog2(NUM_WRPORT) -1 : 0] BankWrPort_wire       [0: NUM_BANK -1];
reg [$clog2(NUM_BANK)   -1 : 0] BankWrPortRelIdx_wire [0: NUM_BANK -1];
reg [$clog2(NUM_BANK)   -1 : 0] BankRdPortRelIdx_wire [0: NUM_BANK -1];
reg [$clog2(NUM_BANK)   -1 : 0] BankWrPortParIdx_wire [0: NUM_BANK -1];
reg [$clog2(NUM_BANK)   -1 : 0] BankRdPortParIdx_wire [0: NUM_BANK -1];

reg [($clog2(NUM_BANK) + 1)-1 : 0] RdPortNumBank_wire[0 : NUM_RDPORT -1];
reg [($clog2(NUM_BANK) + 1)-1 : 0] WrPortNumBank_wire[0 : NUM_WRPORT -1];

reg [($clog2(MAXPAR) + 1)  -1 : 0] RdPortParBank_wire[0 : NUM_RDPORT      -1];
reg [($clog2(MAXPAR) + 1)  -1 : 0] WrPortParBank_wire[0 : NUM_WRPORT      -1];


reg [(NUM_RDPORT + NUM_WRPORT)* NUM_BANK     -1 : 0] BankPort_s0;

reg [NUM_RDPORT+NUM_WRPORT                  -1 : 0] CfgVld;
wire [NUM_RDPORT+NUM_WRPORT                 -1 : 0] CfgRdy;

wire [ADDR_WIDTH                            -1 : 0] Cnt_RdPortAddr;
wire [ADDR_WIDTH                            -1 : 0] Cnt_WrPortAddr;

wire                        rvalid_array  [0 : NUM_BANK-1];
wire [SRAM_WIDTH    -1 : 0] rdata_array   [0 : NUM_BANK-1];
wire                        arvalid_array [0 : NUM_BANK-1];
wire                        arready_array [0 : NUM_BANK-1];
wire                        Full_array    [0 : NUM_BANK-1];
wire [ADDR_WIDTH    -1 : 0] RdReqNum_array[0 : NUM_BANK-1];
wire                        wvalid_array  [0 : NUM_BANK-1];
wire                        Empty_array   [0 : NUM_BANK-1];
wire [ADDR_WIDTH    -1 : 0] WrReqNum_array[0 : NUM_BANK-1];

genvar i;
genvar j, k;
genvar m, n;
integer bk, pt;
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

//=====================================================================================================================
// Logic Design 2: PIPE Configure DECODE
//=====================================================================================================================


generate
    for(m=0; m<NUM_WRPORT+NUM_RDPORT; m=m+1) begin
        always @ ( posedge clk or negedge rst_n ) begin
            if ( !rst_n ) begin
                CfgVld[m] <= 0;
            end else if (CCUGLB_CfgVld[m] & GLBCCU_CfgRdy[m]) begin
                CfgVld[m] <= 1'b1;
            end else if (GLBCCU_CfgRdy[m]) begin
                CfgVld[m] <= 1'b0;
            end
        end
    end
endgenerate
assign GLBCCU_CfgRdy = CfgRdy | !CfgVld;

//=====================================================================================================================
// Logic Design 3: Bank read and write
//=====================================================================================================================


generate
    for(i=0; i<NUM_BANK; i=i+1) begin: GEN_BANK

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
        assign wvalid = WrPortBankEn[BankWrPort[i]][i];
        assign waddr   = WrPortAddr_Array[BankWrPort[i]]; // Cut LSB

        always @(*) begin
            BankWrPortParIdx = 0;
            for(int_i=0; int_i<NUM_BANK; int_i=int_i+1) begin
                if(int_i < i)
                    BankWrPortParIdx = BankWrPortParIdx + WrPortBankEn[BankWrPort[i]][int_i];
            end
        end
        assign wdata = WrPortDat_Array[BankWrPort[i]][SRAM_WIDTH*BankWrPortParIdx +: SRAM_WIDTH];

        //=====================================================================================================================
        // Logic Design 4: Read Port
        //=====================================================================================================================
        assign arvalid  = RdPortBankEn[BankRdPortIdx[i]];    
        assign araddr   = RdPortAddr_Array[BankRdPortIdx[i]]; 
        
        assign rready = BankRdPortDatRdy;
        assign rvalid_array[i]  = rvalid;
        assign rdata_array[i]   = rdata;

        prior_arb#(
            .REQ_WIDTH ( NUM_WRPORT )
        )u_prior_arb_BankWrPortIdx(
            .req ( BankPortFlag[i][0 +: NUM_WRPORT] ),
            .gnt (  ),
            .arb_port  ( BankWrPortIdx[i]  )
        );

        prior_arb#(
            .REQ_WIDTH ( NUM_RDPORT )
        )u_prior_arb_BankRdPortIdx(
            .req ( BankPortFlag[i][NUM_WRPORT +: NUM_RDPORT] ),
            .gnt (  ),
            .arb_port  ( BankRdPortIdx[i]  )
        );


    end
endgenerate

//=====================================================================================================================
// Logic Design 4: Read Port
//=====================================================================================================================
generate
    for(j=0; j<NUM_RDPORT; j=j+1) begin
        reg [$clog2(MAXPAR) + 1 -1 : 0] ByteIdx;
        reg                             INC;

        assign INC = RdPortAddrRdy[j] & RdPortAddrVld[j];
        assign PortCur1stBankIdx[j] = RdPort1stBankIdx + (RdPortAddr_Array[m] >> SRAM_DEPTH_WIDTH)*CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*j +: ($clog2(MAXPAR) + 1)];
        assign RdPortMthWrPortIdx[j] = BankWrPortIdx[PortCur1stBankIdx[j]];
        assign Empty = RdPortAddr_Array[j] == WrPortAddr_Array[RdPortMthWrPortIdx];

        // To Bank
        assign RdPortEn[m] = RdPortUseAddr[j]? RdPortAddrVld[j] : RdPortDatRdy[j]  & !Empty;
        assign RdPortAddr_Array[j] = RdPortUseAddr[j] ? RdPortAddr[ADDR_WIDTH*j +: ADDR_WIDTH] : Cnt_RdPortAddr;
        generate 
            for(i=0; i<NUM_BANK; i=i+1) begin
                    RdPortHitBank [j][i] = PortCur1stBankIdx[j] <= i & i < PortCur1stBankIdx[j] + CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*j +: ($clog2(MAXPAR) + 1)];
            end
        endgenerate
        assign RdPortBankEn[j] = RdPortEn[j] & RdPortHitBank[j]; // 32bits

        assign RdPortDatVld[j] = &rvalid_array[PortCur1stBankIdx[j]];
        assign RdPortDat[SRAM_WIDTH*MAXPAR*j +: SRAM_WIDTH*MAXPAR] =  rdata_array[SRAM_WIDTH*PortCur1stBankIdx[j] +: SRAM_WIDTH*MAXPAR];
        assign RdPortAddrRdy[j] = INC;
        assign RdPortFull[j] = RdPortReqNum[j] == CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(NUM_WRPORT+j) +: ADDR_WIDTH] ;
        assign RdPortReqNum[j] = WrPortAddr_Array[RdPortMthWrPortIdx[j]] - RdPortAddr_Array[j];
        assign RdPortAddr_Out[ADDR_WIDTH*j +: ADDR_WIDTH] = RdPortAddr_Array[j];

        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_RdPortAddr(
            .CLK       ( clk                                                            ),
            .RESET_N   ( rst_n                                                          ),
            .CLEAR     ( CfgVld[NUM_WRPORT+j]                                           ),
            .DEFAULT   ( {ADDR_WIDTH{1'b0}}                                                              ),
            .INC       ( INC                                                            ),
            .DEC       ( 1'b0                                                           ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}                                                              ),
            .MAX_COUNT ( CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(NUM_WRPORT+j) +: ADDR_WIDTH]   ),
            .OVERFLOW  ( CfgRdy[NUM_WRPORT+j]                                  ),
            .UNDERFLOW (                                                                ),
            .COUNT     ( Cnt_RdPortAddr                                            )
        );
        assign RdPortAddr_Array[j] = RdPortUseAddr[j]? RdPortAddr[ADDR_WIDTH*j +: ADDR_WIDTH] : Cnt_RdPortAddr;

    end

endgenerate

//=====================================================================================================================
// Logic Design 5: Write Port
//=====================================================================================================================

generate
    for(m=0; m<NUM_WRPORT; m=m+1) begin
        wire    INC;

        // Intra signals
        assign INC = WrPortDatRdy[m] & WrPortDatVld[m];
        assign PortCur1stBankIdx[m] = WrPort1stBankIdx + (WrPortAddr_Array[m] >> SRAM_DEPTH_WIDTH)*CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*m +: ($clog2(MAXPAR) + 1)];
        assign WrPortMthRdPortIdx[m] = BankRdPortIdx[PortCur1stBankIdx[m]];
        assign Full = ( (WrPortAddr_Array[m] - RdPortAddr_Array[WrPortMthRdPortIdx])== CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*m +: ADDR_WIDTH] );

        // To Bank
        assign WrPortEn[m] = !(RdPortEn[WrPortMthRdPortIdx]) & WrPortDatVld[m]  & !Full;
        assign WrPortDat_Array[m] = WrPortDat[SRAM_WIDTH*MAXPAR*m +: SRAM_WIDTH*MAXPAR];
        assign WrPortAddr_Array[m] = WrPortUseAddr[m] ? WrPortAddr[ADDR_WIDTH*m +: ADDR_WIDTH] : Cnt_WrPortAddr;
        generate 
            for(i=0; i<NUM_BANK; i=i+1) begin
                    WrPortHitBank [m][i] = PortCur1stBankIdx[m] <= i & i < PortCur1stBankIdx[m] + CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*m +: ($clog2(MAXPAR) + 1)];
            end
        endgenerate
        assign WrPortBankEn[m] = WrPortEn[m] & WrPortHitBank[m]; // 32bits

        // To Output
        assign WrPortDatRdy[m] = !Full;
        assign WrPortEmpty[m] = WrPortReqNum[ADDR_WIDTH*m +: ADDR_WIDTH] == CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*m +: ADDR_WIDTH];
        assign WrPortReqNum[ADDR_WIDTH*m +: ADDR_WIDTH] = CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*m +: ADDR_WIDTH] - (WrPortAddr_Array[m] - RdPortAddr_Array[WrPortMthRdPortIdx]);
        assign WrPortAddr_Out[ADDR_WIDTH*m +: ADDR_WIDTH] = WrPortAddr_Array[m];

        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter(
            .CLK       ( clk        ),
            .RESET_N   ( rst_n      ),
            .CLEAR     ( CfgVld[m]  ),
            .DEFAULT   ( {ADDR_WIDTH{1'b0}}          ),
            .INC       ( INC        ),
            .DEC       ( 1'b0       ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}          ),
            .MAX_COUNT ( CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*m +: ADDR_WIDTH]),
            .OVERFLOW  ( CfgRdy[m]  ),
            .UNDERFLOW (            ),
            .COUNT     ( Cnt_WrPortAddr)
        );

        prior_arb#(
            .REQ_WIDTH ( NUM_BANK )
        )u_prior_arb(
            .req ( CCUGLB_CfgPortBankFlag[NUM_BANK*m +: NUM_BANK]),
            .gnt (  ),
            .arb_port  ( WrPort1stBankIdx[m]  )
        );


    end
endgenerate


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================


endmodule
