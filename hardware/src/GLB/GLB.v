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
    input                                               clk                     ,
    input                                               rst_n                   ,

    // Configure
    input  [NUM_RDPORT+NUM_WRPORT               -1 : 0] CCUGLB_CfgVld,
    output [NUM_RDPORT+NUM_WRPORT               -1 : 0] GLBCCU_CfgRdy,

    input [(NUM_RDPORT + NUM_WRPORT)* NUM_BANK  -1 : 0] CCUGLB_CfgBankPort,

    input [ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)   -1 : 0] CCUGLB_CfgPort_AddrMax,
    input [($clog2(MAXPAR) + 1)*NUM_RDPORT      -1 : 0] CCUGLB_CfgRdPortParBank,
    input [($clog2(MAXPAR) + 1)*NUM_WRPORT      -1 : 0] CCUGLB_CfgWrPortParBank,


    // Data
    input  wire [SRAM_WIDTH*MAXPAR*NUM_WRPORT   -1: 0] WrPortDat,
    input  wire [NUM_WRPORT                     -1: 0] WrPortDatVld,
    output reg  [NUM_WRPORT                     -1: 0] WrPortDatRdy,
    output reg  [NUM_WRPORT                     -1: 0] WrPortFull,
    output reg  [ADDR_WIDTH*NUM_WRPORT          -1: 0] WrPortReqNum,
    output wire [ADDR_WIDTH*NUM_WRPORT          -1: 0] WrPortAddr_Out, // Detect

    input  wire [NUM_WRPORT                     -1: 0] WrPortUseAddr, //  Mode1: Use Address
    input  wire [ADDR_WIDTH*NUM_WRPORT          -1: 0] WrPortAddr,

    output wire [SRAM_WIDTH*MAXPAR*NUM_RDPORT   -1: 0] RdPortDat,
    output reg  [NUM_RDPORT                     -1: 0] RdPortDatVld,
    input  wire [NUM_RDPORT                     -1: 0] RdPortDatRdy,
    output reg  [NUM_RDPORT                     -1: 0] RdPortEmpty,
    output reg  [ADDR_WIDTH*NUM_RDPORT          -1: 0] RdPortReqNum,
    output wire [ADDR_WIDTH*NUM_RDPORT          -1: 0] RdPortAddr_Out,

    input  wire [NUM_WRPORT                     -1: 0] RdPortUseAddr,
    input  wire [ADDR_WIDTH*NUM_RDPORT          -1: 0] RdPortAddr,
    input  wire [NUM_WRPORT                     -1: 0] RdPortAddrVld,
    output reg  [NUM_WRPORT                     -1: 0] RdPortAddrRdy    

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

genvar i;
genvar j, k;
genvar m, n;
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

//=====================================================================================================================
// Logic Design 2: PIPE Configure DECODE
//=====================================================================================================================

// Combined Logic
always @(*) begin
    if (!rst_n) begin
        for(bk=0; bk<NUM_BANK; bk=bk+1) begin
            for(pt=0; pt<NUM_WRPORT; pt=pt+1) begin
                    BankWrPort_wire[bk]     = 0;
                    WrPortNumBank_wire[pt]  = 0;
                    WrPortParBank_wire[pt]  = 0;
                    BankWrPortRelIdx_wire[bk]= 0;
                    
            end
            for(pt=NUM_WRPORT; pt<NUM_RDPORT+NUM_WRPORT; pt=pt+1) begin
                    BankRdPort_wire[bk]            = 0;
                    RdPortNumBank_wire[pt-NUM_WRPORT]= 0;
                    RdPortParBank_wire[pt-NUM_WRPORT]= 0;
                    BankRdPortRelIdx_wire[bk]       = 0;
            end
        end
    end else if(CCUGLB_CfgVld & GLBCCU_CfgRdy) begin // PIPE STAGE0
        for(pt=0; pt<NUM_WRPORT; pt=pt+1)
            WrPortNumBank_wire[pt] = 0;
            WrPortParBank_wire[pt] = CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*pt +: ($clog2(MAXPAR) + 1)];
        for(pt=NUM_WRPORT; pt<NUM_RDPORT+NUM_WRPORT; pt=pt+1)
            RdPortNumBank_wire[pt-NUM_WRPORT] = 0;
            RdPortParBank_wire[pt-NUM_WRPORT] = CCUGLB_CfgRdPortParBank_wire[($clog2(MAXPAR) + 1)*(pt-NUM_RDPORT +: ($clog2(MAXPAR) + 1)];

        for(pt=0; pt<NUM_WRPORT; pt=pt+1) begin
            for(bk=0; bk<NUM_BANK; bk=bk+1) begin
                if (CCUGLB_CfgBankPort[(NUM_RDPORT + NUM_WRPORT)*bk + pt])begin
                    BankWrPort_wire[bk] = pt;
                    WrPortNumBank_wire[pt] = WrPortNumBank_wire[pt] + 1;
                    BankWrPortParIdx_wire[bk] = (BankWrPortParIdx_wire[bk] + 1 == WrPortParBank_wire[pt] ) ? 0 : BankWrPortParIdx_wire[bk] + 1;
                    BankWrPortRelIdx_wire[bk] = (BankWrPortParIdx_wire[bk] + 1 == WrPortParBank_wire[pt] ) ? BankWrPortRelIdx_wire[bk] + 1 : BankWrPortRelIdx_wire[bk]; 

        for(pt=NUM_WRPORT; pt<NUM_RDPORT+NUM_WRPORT; pt=pt+1) begin
            for(bk=0; bk<NUM_BANK; bk=bk+1) begin
                if (CCUGLB_CfgBankPort[(NUM_RDPORT + NUM_WRPORT)*bk + pt])begin
                    BankRdPort_wire[bk]            = pt-NUM_WRPORT;
                    RdPortNumBank_wire[pt-NUM_WRPORT]= RdPortNumBank_wire[pt-NUM_WRPORT] + 1;
                    BankRdPortParIdx_wire[bk] = (BankRdPortParIdx_wire[bk] + 1 == RdPortParBank_wire[pt-NUM_WRPORT] ) ? 0 : BankRdPortParIdx_wire[bk] + 1;
                    BankRdPortRelIdx_wire[bk] = (BankRdPortParIdx_wire[bk] + 1 == RdPortParBank_wire[pt-NUM_WRPORT] ) ? BankRdPortRelIdx_wire[bk] + 1 : 
                end
            end
        end

    end
end

always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        BankWrPort      <= 0;
        WrPortNumBank   <= 0;
        WrPortParBank   <= 0;
        BankWrPortRelIdx<= 0;
        BankWrPortParIdx<= 0;
        
        BankRdPort      <= 0;
        RdPortNumBank   <= 0;
        RdPortParBank   <= 0;
        BankRdPortRelIdx<= 0;
        BankRdPortParIdx<= 0;
        BankPort_s0     <= 0;
    else begin
        BankWrPort      <= BankWrPort_wire      ;
        WrPortNumBank   <= WrPortNumBank_wire   ;
        WrPortParBank   <= WrPortParBank_wire   ;
        BankWrPortRelIdx<= BankWrPortRelIdx_wire;
        BankWrPortParIdx<= BankWrPortParIdx_wire;
        BankRdPort      <= BankRdPort_wire      ;
        RdPortNumBank   <= RdPortNumBank_wire   ;
        RdPortParBank   <= RdPortParBank_wire   ;
        BankRdPortRelIdx<= BankRdPortRelIdx_wire;
        BankRdPortParIdx<= BankRdPortParIdx_wire;

        BankPort_s0     <= CCUGLB_CfgBankPort;
    end  
end


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

        reg  [SRAM_DEPTH_WIDTH  -1 : 0] RdPortAddr_Mnt;
        reg  [SRAM_DEPTH_WIDTH  -1 : 0] WrPortAddr_Mnt;

        wire [ADDR_WIDTH        -1 : 0] WrPortAddr;
        wire [ADDR_WIDTH        -1 : 0] RdPortAddr;

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
        // Logic Design 4: Read Port
        //=====================================================================================================================
        assign WithWrPort = |BankPort_s0[NUM_BANK*i +: NUM_WRPORT];
        assign WithRdPort = |BankPort_s0[NUM_BANK*i + NUM_WRPORT +: NUM_RDPORT];
        always @(posedge clk or rst_n) begin
            if (!rst_n) begin
                WrPortAddr_Mnt <= 0;
            end else if ( WithWrPort) begin
                WrPortAddr_Mnt <= WrPortAddr_Array[BankWrPort[i];
            end
        end
        always @(posedge clk or rst_n) begin
            if (!rst_n) begin
                RdPortAddr_Mnt <= 0;
            end else if ( WithRdPort) begin
                RdPortAddr_Mnt <= RdPortAddr_Array[BankRdPort[i];
            end
        end

        assign WrPortAddr = WithWrPort ? WrPortAddr_Array[BankWrPort[i]] : WrPortAddr_Mnt;
        assign RdPortAddr = WithRdPort ? RdPortAddr_Array[BankRdPort[i]] : RdPortAddr_Mnt;

        assign BankWrPortDatRdy = WithWrPort ? WrPortDatRdy[BankWrPort[i]] : 0;
        assign BankRdPortDatRdy = WithRdPort ? RdPortDatRdy[BankRdPort[i]] : 0;

        //=====================================================================================================================
        // Logic Design 4: Write Port
        //=====================================================================================================================
        wire    WrAloc;
        wire    Full;
        wire    WrReqNum;
        assign WrReqNum = CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*BankWrPort[i] +: ADDR_WIDTH] - (WrPortAddr - RdPortaddr)
        assign Full = ( (WrPortAddr - RdPortaddr)== CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*BankWrPort[i] +: ADDR_WIDTH] );
        assign PortWrEn = !(arvalid & arready) & WrPortDatVld[BankWrPort[i]]  & !Full;
        assign WrAloc = ( (WrPortAddr >> SRAM_DEPTH_WIDTH )*BankWrPortParBank == BankWrPortRelIdx[i]);
        assign wvalid = PortWrEn & WrAloc;
        assign waddr   = WrPortAddr - SRAM_WORD * BankWrPortRelIdx[i]        ;

        assign wdata = WrPortDat_Array[BankRdPort[i]][SRAM_WIDTH*BankWrPortParIdx[i] +: SRAM_WIDTH];

        //=====================================================================================================================
        // Logic Design 4: Read Port
        //=====================================================================================================================
        wire RdAloc;
        wire Empty;
        wire [ADDR_WIDTH    -1 : 0] RdReqNum;
        assign RdReqNum = WrPortAddr - RdPortAddr;
        assign Empty = (WrPortAddr==RdPortAddr);
        assign PortRdEn = ( RdPortUseAddr[BankRdPort[i]]? RdPortAddrVld[BankRdPort[i]]: BankRdPortDatRdy ) & ! Empty;     
        assign RdAloc = ( (RdPortAddr >> SRAM_DEPTH_WIDTH )*BankRdPortParBank == BankRdPortRelIdx[i]);
        assign arvalid  = PortRdEn & RdAloc;    
        assign araddr   = RdPortAddr - SRAM_WORD * BankRdPortRelIdx[i]; 
        assign rready = BankRdPortDatRdy;

    end
endgenerate

//=====================================================================================================================
// Logic Design 4: Read Port
//=====================================================================================================================

generate
    for(j=0; j<NUM_RDPORT; j=j+1) begin
        reg [$clog2(MAXPAR) + 1 -1 : 0] ByteIdx;
        reg                             INC;

        always @(*) begin
            ByteIdx = 0;
            RdPortDat_Array[j] = 0;
            RdPortDatVld[j]     = 0;
            INC = 0;
            RdPortEmpty[j] = 1'b0;
            RdPortReqNum[j] = 1'b0;
            RdPortAddrRdy[j] = 1'b0;
            for (bk=0; bk<NUM_BANK; bk=bk+1) begin
                if (BankRdPort[bk]==j) begin
                    if (GEN_BANK[bk].rvalid) begin
                        RdPortDat_Array[j][SRAM_WIDTH*ByteIdx +: SRAM_WIDTH] = GEN_BANK[bk].rdata;
                        ByteIdx = ByteIdx + 1;
                        RdPortDatVld[j] = 1;
                    end
                    if (GEN_BANK[bk].arvalid & GEN_BANK[bk].arready) begin
                        INC = 1'b1;
                        RdPortAddrRdy[j] = 1'b1;
                    end
                    RdPortEmpty[j] = GEN_BANK[bk].Empty;
                    RdPortReqNum[j] = GEN_BANK[bk].RdReqNum;
                end
            end
        end
        assign RdPortDat[SRAM_WIDTH*MAXPAR*j +: SRAM_WIDTH*MAXPAR] =  RdPortDat_Array[j];
        assign RdPortAddr_Out[ADDR_WIDTH*j +: ADDR_WIDTH] = RdPortAddr_Array[j];

        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_RdPortAddr(
            .CLK       ( clk                                                            ),
            .RESET_N   ( rst_n                                                          ),
            .CLEAR     ( CfgVld[NUM_WRPORT+j]                                           ),
            .DEFAULT   ( 0                                                              ),
            .INC       ( INC                                                            ),
            .DEC       ( 1'b0                                                           ),
            .MIN_COUNT ( 0                                                              ),
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
        reg INC ;
        always @(*) begin
            WrPortDatRdy[m] = 0;
            INC             = 0;
            WrPortFull[m]   = 0;
            WrPortReqNum[m] = 0;
            // for(n=0; n<WrPortNumBank[m]; n=n+1) begin
            for (bk=0; bk<NUM_BANK; bk=bk+1) begin
                if (BankWrPort[bk]==m) begin
                    if (GEN_BANK[bk].wvalid) begin
                        WrPortDatRdy[m] = 1'b1;
                        INC = 1'b1;
                    end
                    WrPortFull[m] = GEN_BANK[bk].full;
                    WrPortReqNum[m] = GEN_BANK[bk].WrReqNum;
                end
            end
        end
        assign WrPortDat_Array[m] = WrPortDat[SRAM_WIDTH*MAXPAR*m +: SRAM_WIDTH*MAXPAR];
        assign WrPortAddr_Out[ADDR_WIDTH*m +: ADDR_WIDTH] = WrPortAddr_Array[m];
        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter(
            .CLK       ( clk                                            ),
            .RESET_N   ( rst_n                                          ),
            .CLEAR     ( CfgVld[m] ),
            .DEFAULT   ( 0                                              ),
            .INC       ( INC                                            ),
            .DEC       ( 1'b0                                           ),
            .MIN_COUNT ( 0                                              ),
            .MAX_COUNT ( CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*m +: ADDR_WIDTH]),
            .OVERFLOW  ( CfgRdy[m]                             ),
            .UNDERFLOW (                                                ),
            .COUNT     ( Cnt_WrPortAddr                            )
        );
        assign WrPortAddr_Array[m] = WrPortUseAddr[m? WrPortAddr[ADDR_WIDTH*m +: ADDR_WIDTH] : Cnt_WrPortAddr;

endgenerate


//=====================================================================================================================
// Logic Design 5: ITF
//=====================================================================================================================








//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================


endmodule
