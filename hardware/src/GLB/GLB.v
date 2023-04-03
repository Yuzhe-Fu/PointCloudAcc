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

    parameter NUM_WRPORT   = 8,
    parameter NUM_RDPORT   = 16
    )(
    input                                               clk                 ,
    input                                               rst_n               ,

    // Configure
    input [(NUM_RDPORT + NUM_WRPORT)-1 : 0][NUM_BANK            -1 : 0] TOPGLB_CfgPortBankFlag,
    input [(NUM_RDPORT + NUM_WRPORT)                            -1 : 0] TOPGLB_CfgPortOffEmptyFull,

    // Data
    input  [NUM_WRPORT              -1 : 0][SRAM_WIDTH          -1 : 0] TOPGLB_WrPortDat    ,
    input  [NUM_WRPORT                                          -1 : 0] TOPGLB_WrPortDatVld ,
    output [NUM_WRPORT                                          -1 : 0] GLBTOP_WrPortDatRdy ,
    input  [NUM_WRPORT              -1 : 0][ADDR_WIDTH          -1 : 0] TOPGLB_WrPortAddr   , 
    output [NUM_WRPORT                                          -1 : 0] GLBTOP_WrFull       ,   


    input  [NUM_RDPORT              -1 : 0][ADDR_WIDTH          -1 : 0] TOPGLB_RdPortAddr   ,
    input  [NUM_RDPORT                                          -1 : 0] TOPGLB_RdPortAddrVld,
    output [NUM_RDPORT                                          -1 : 0] GLBTOP_RdPortAddrRdy,
    output [NUM_RDPORT              -1 : 0][SRAM_WIDTH          -1 : 0] GLBTOP_RdPortDat    ,
    output [NUM_RDPORT                                          -1 : 0] GLBTOP_RdPortDatVld ,
    input  [NUM_RDPORT                                          -1 : 0] TOPGLB_RdPortDatRdy ,
    output [NUM_RDPORT                                          -1 : 0] GLBTOP_RdEmpty       
);

//=====================================================================================================================
// Constant Definition :
//integer=====================================================================================================================
localparam SRAM_DEPTH_WIDTH = $clog2(SRAM_WORD);

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [NUM_WRPORT    -1 : 0][NUM_BANK                -1 : 0] PortWrBankVld  ;
wire [NUM_WRPORT                                    -1 : 0] WrPortEn;

wire [NUM_RDPORT    -1 : 0][NUM_BANK                -1 : 0] PortRdBankAddrVld  ;
wire [NUM_RDPORT                                    -1 : 0] RdPortEn;

wire [NUM_BANK                                      -1 : 0] Bank_rvalid;
wire [NUM_BANK                                      -1 : 0] Bank_arready;
wire [NUM_BANK                                      -1 : 0] Bank_wready;
wire [NUM_BANK      -1 : 0][SRAM_WIDTH              -1 : 0] Bank_rdata_array;
wire [NUM_BANK      -1 : 0][$clog2(NUM_WRPORT)      -1 : 0] BankWrPortIdx;
wire [NUM_BANK      -1 : 0][$clog2(NUM_WRPORT)      -1 : 0] BankWrPortIdx_d;
wire [NUM_BANK      -1 : 0][$clog2(NUM_RDPORT)      -1 : 0] BankRdPortIdx;
wire [NUM_BANK      -1 : 0][$clog2(NUM_RDPORT)      -1 : 0] BankRdPortIdx_d;
wire [NUM_BANK      -1 : 0][(NUM_WRPORT+NUM_RDPORT) -1 : 0] BankPortFlag;
reg  [NUM_BANK      -1 : 0][ADDR_WIDTH              -1 : 0] BankWrAddr_d;
reg  [NUM_BANK                                      -1 : 0] BankWrtn; // clarify whether data is written >= one time
reg  [NUM_BANK      -1 : 0][ADDR_WIDTH              -1 : 0] BankRdAddr_d;
reg  [NUM_BANK                                      -1 : 0] BankRden; // clarify whether data is read >= one time 

genvar      gv_i;
genvar      gv_j;
integer     int_i;

//=====================================================================================================================
// Logic Design
//=====================================================================================================================


generate
    for(gv_i=0; gv_i<NUM_BANK; gv_i=gv_i+1) begin: GEN_BANK

        wire                            wvalid;
        wire                            wready;
        wire                            arvalid;
        wire                            arready;
        wire                            rvalid;
        wire                            rready;
        wire [SRAM_DEPTH_WIDTH  -1 : 0] waddr;
        wire [SRAM_DEPTH_WIDTH  -1 : 0] araddr;
        wire [SRAM_WIDTH        -1 : 0] wdata;
        wire [SRAM_WIDTH        -1 : 0] rdata;
        reg  [$clog2(NUM_BANK)  -1 : 0] CurBankIdxInWrPortPar;

        RAM_HS#(
            .SRAM_BIT     ( SRAM_WIDTH  ),
            .SRAM_BYTE    ( 1           ),
            .SRAM_WORD    ( SRAM_WORD   ),
            .DUAL_PORT    ( 0           )
        )u_SPRAM_HS(
            .clk          ( clk          ),
            .rst_n        ( rst_n        ),
            .wvalid       ( wvalid       ),
            .wready       ( wready       ),
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
        // Logic Design: Write
        //=====================================================================================================================
        assign wvalid           = PortWrBankVld[BankWrPortIdx[gv_i]][gv_i];
        assign waddr            = TOPGLB_WrPortAddr[BankWrPortIdx[gv_i]]; // Cut MSB
        assign Bank_wready[gv_i]= wready;

        always @(*) begin
            CurBankIdxInWrPortPar = 0;
            for(int_i=0; int_i<NUM_BANK; int_i=int_i+1) begin
                if(int_i < gv_i)
                    CurBankIdxInWrPortPar = CurBankIdxInWrPortPar + PortWrBankVld[BankWrPortIdx[gv_i]][int_i];
            end
        end
        assign wdata = TOPGLB_WrPortDat[BankWrPortIdx[gv_i]][SRAM_WIDTH*CurBankIdxInWrPortPar +: SRAM_WIDTH];

        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                BankWrAddr_d[gv_i]  <= 0;
                BankWrtn[gv_i]      <= 0;
            end else if (BankWrPortIdx_d[gv_i] != BankWrPortIdx[gv_i] ) begin // Change Port -> Reset
                BankWrAddr_d[gv_i]  <= 0;
                BankWrtn[gv_i]      <= 0;            
            end else if (wvalid & wready ) begin// Handshake
                BankWrAddr_d[gv_i]  <= TOPGLB_WrPortAddr[BankWrPortIdx[gv_i]];
                BankWrtn[gv_i]      <= 1'b1;
            end
        end

        //=====================================================================================================================
        // Logic Design: Read
        //=====================================================================================================================
        // Bank
        assign arvalid              = PortRdBankAddrVld[BankRdPortIdx[gv_i]][gv_i];    
        assign araddr               = TOPGLB_RdPortAddr[BankRdPortIdx[gv_i]]; 
        assign Bank_arready[gv_i]   = arready;

        assign rready                = TOPGLB_RdPortDatRdy[BankRdPortIdx[gv_i]];
        assign Bank_rvalid[gv_i]     = rvalid;
        assign Bank_rdata_array[gv_i]= rdata;

        // Output
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                BankRdAddr_d[gv_i]  <= 0;
                BankRden[gv_i]      <= 0;
            end else if(BankRdPortIdx_d[gv_i] != BankRdPortIdx[gv_i]) begin // Change Port -> Reset
                BankRdAddr_d[gv_i]  <= 0;
                BankRden[gv_i]      <= 0;
            end else if (arvalid & arready ) begin// Handshake
                BankRdAddr_d[gv_i]  <= TOPGLB_RdPortAddr[BankRdPortIdx[gv_i]];
                BankRden[gv_i]      <= 1'b1;
            end
        end

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
            assign BankPortFlag[gv_i][gv_j] = TOPGLB_CfgPortBankFlag[gv_j][gv_i];
        end

    end
endgenerate

DELAY#(
    .NUM_STAGES ( 1 ),
    .DATA_WIDTH ( ( $clog2(NUM_RDPORT) + $clog2(NUM_WRPORT) )*NUM_BANK )
)u_DELAY_BankWrPortIdx(
    .CLK        ( clk        ),
    .RST_N      ( rst_n      ),
    .DIN        ( {BankRdPortIdx  , BankWrPortIdx   }  ),
    .DOUT       ( {BankRdPortIdx_d, BankWrPortIdx_d })
);

//=====================================================================================================================
// Logic Design 4: Read Port
//=====================================================================================================================


generate
    for(gv_j=0; gv_j<NUM_RDPORT; gv_j=gv_j+1) begin: GEN_RDPORT
        wire [$clog2(NUM_BANK)      -1 : 0] PortCur1stBankIdx;
        wire [$clog2(NUM_BANK)      -1 : 0] PortCur1stBankIdx_d;
        wire [$clog2(NUM_BANK)      -1 : 0] RdPort1stBankIdx;
        wire                                Empty;
        wire [NUM_BANK              -1 : 0] RdPortHitBank;
        wire                                RdPortAlloc;
        wire [$clog2(NUM_BANK)          : 0] RdPortNumBank;
        wire [ADDR_WIDTH            -1 : 0] RdPortAddrVldRange;
        reg  [ADDR_WIDTH            -1 : 0] RdPortMthWrAddr;
        reg                                 RdPortMthWrtn;

        // Map RdPort to Bank
        assign RdPortAddrVldRange =  RdPortAlloc? SRAM_WORD*RdPortNumBank : SRAM_WORD; // Cut address to a relative(valid) range in NumBank/ParBank; Default: SRAM_WORD
        assign RdPortAlloc = |TOPGLB_CfgPortBankFlag[NUM_WRPORT + gv_j];
        assign PortCur1stBankIdx = RdPort1stBankIdx + (TOPGLB_RdPortAddr[gv_j] % RdPortAddrVldRange >> SRAM_DEPTH_WIDTH);

        // To Bank
        for(gv_i=0; gv_i<NUM_BANK; gv_i=gv_i+1) begin
                assign RdPortHitBank[gv_i] = PortCur1stBankIdx <= gv_i & gv_i < PortCur1stBankIdx + 1;
        end
        assign PortRdBankAddrVld[gv_j] = {NUM_BANK{TOPGLB_RdPortAddrVld[gv_j] & !Empty}} & RdPortHitBank; // 32bits, // addr handshake : enable of (add+1)

        always@(*) begin // Max WrAddr of allocated banks
            RdPortMthWrAddr = 0;
            RdPortMthWrtn   = 0;
            for(int_i = 0; int_i < RdPortNumBank; int_i = int_i + 1) begin
                RdPortMthWrAddr = RdPortMthWrAddr < BankWrAddr_d[RdPort1stBankIdx + int_i]? BankWrAddr_d[RdPort1stBankIdx + int_i] : RdPortMthWrAddr;
                RdPortMthWrtn = RdPortMthWrtn | BankWrtn[RdPort1stBankIdx + int_i];
            end
        end
        // To Output (Addr)
        assign Empty = !TOPGLB_CfgPortOffEmptyFull[NUM_WRPORT + gv_j] & ( !RdPortMthWrtn | (TOPGLB_RdPortAddr[gv_j] > RdPortMthWrAddr) );//
        assign  GLBTOP_RdPortAddrRdy[gv_j] = RdPortAlloc & !Empty & Bank_arready[PortCur1stBankIdx];
        assign  GLBTOP_RdEmpty[gv_j] = Empty;

        // To Output (Data)
        assign  GLBTOP_RdPortDatVld[gv_j] = RdPortAlloc & Bank_rvalid[PortCur1stBankIdx_d];
        assign  GLBTOP_RdPortDat[gv_j] =  Bank_rdata_array[PortCur1stBankIdx_d];

        prior_arb#(
            .REQ_WIDTH ( NUM_BANK )
        )u_prior_arb_RdPort1stBankIdx(
            .req ( TOPGLB_CfgPortBankFlag[NUM_WRPORT + gv_j] ),
            .gnt (  ),
            .arb_port  ( RdPort1stBankIdx  )
        );
        CNT1 #(
            .DATA_WIDTH(NUM_BANK)
        ) u_CNT1_RdPortNumBank(
            .din(TOPGLB_CfgPortBankFlag[NUM_WRPORT + gv_j]),
            .dout(RdPortNumBank)
        );

        LATCH_DELAY#(
            .DATA_WIDTH ( $clog2(NUM_BANK) )
        )u_LATCH_DELAY_PortCur1stBankIdx(
            .CLK   ( clk   ),
            .RST_N ( rst_n ),
            .LATCH ( GLBTOP_RdPortAddrRdy[gv_j] & TOPGLB_RdPortAddrVld[gv_j] ),
            .DIN   ( PortCur1stBankIdx ),
            .DOUT  ( PortCur1stBankIdx_d  )
        );

    end

endgenerate

//=====================================================================================================================
// Logic Design 5: Write Port
//=====================================================================================================================

generate
    for(gv_j=0; gv_j<NUM_WRPORT; gv_j=gv_j+1) begin: GEN_WRPORT
        wire [$clog2(NUM_BANK)  -1 : 0] PortCur1stBankIdx;
        wire [$clog2(NUM_BANK)  -1 : 0] WrPort1stBankIdx;
        wire [$clog2(NUM_RDPORT)-1 : 0] WrPortMthRdBankIdx;
        wire                            Full;
        wire [NUM_BANK          -1 : 0] WrPortHitBank;
        wire                            WrPortAlloc;
        wire [$clog2(NUM_BANK)     : 0] WrPortNumBank;
        wire [ADDR_WIDTH        -1 : 0] WrPortAddrVldSpace;
        reg  [ADDR_WIDTH        -1 : 0] WrPortMthRdAddr;
        reg                             WrPortMthRden;

        // Map WrPort to Bank
        assign WrPortAddrVldSpace = WrPortAlloc? SRAM_WORD*WrPortNumBank : SRAM_WORD;// Cut address to a relative(valid) range in NumBank/ParBank
        assign WrPortAlloc = |TOPGLB_CfgPortBankFlag[gv_j];
        assign PortCur1stBankIdx = WrPort1stBankIdx + (TOPGLB_WrPortAddr[gv_j] % WrPortAddrVldSpace  >> SRAM_DEPTH_WIDTH);

        // To Bank
        for(gv_i=0; gv_i<NUM_BANK; gv_i=gv_i+1) begin
                assign WrPortHitBank[gv_i] = PortCur1stBankIdx <= gv_i & gv_i < PortCur1stBankIdx + 1;
        end
        assign PortWrBankVld[gv_j] = {NUM_BANK{TOPGLB_WrPortDatVld[gv_j] & !Full}} & WrPortHitBank; // 32bits

        always@(*) begin // Max RdAddr of allocated banks
            WrPortMthRdAddr = 0;
            WrPortMthRden   = 0;
            for(int_i = 0; int_i < WrPortNumBank; int_i = int_i + 1) begin
                WrPortMthRdAddr = WrPortMthRdAddr < BankRdAddr_d[WrPort1stBankIdx + int_i]? BankRdAddr_d[WrPort1stBankIdx + int_i] : WrPortMthRdAddr;
                WrPortMthRden   = WrPortMthRden | BankRden[WrPort1stBankIdx + int_i];
            end
        end

        // To Output
        assign Full = !TOPGLB_CfgPortOffEmptyFull[gv_j] & (TOPGLB_WrPortAddr[gv_j] - WrPortMthRdAddr) >= (WrPortMthRden? WrPortAddrVldSpace + 1 : WrPortAddrVldSpace);
        assign GLBTOP_WrPortDatRdy[gv_j] = WrPortAlloc & !Full & Bank_wready[PortCur1stBankIdx];
        assign GLBTOP_WrFull[gv_j] = Full;

        prior_arb#(
            .REQ_WIDTH ( NUM_BANK )
        )u_prior_arb_WrPort1stBankIdx(
            .req ( TOPGLB_CfgPortBankFlag[gv_j]),
            .gnt (  ),
            .arb_port  ( WrPort1stBankIdx  )
        );
        CNT1 #(
            .DATA_WIDTH(NUM_BANK)
        ) u_CNT1_WrPortNumBank(
            .din(TOPGLB_CfgPortBankFlag[gv_j]),
            .dout(WrPortNumBank)
        );

    end
endgenerate

endmodule
