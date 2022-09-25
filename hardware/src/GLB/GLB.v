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
    parameter LOOP_WIDTH   = 10,
    
    parameter CLOCK_PERIOD = 10

    )(
    input                                               clk                     ,
    input                                               rst_n                   ,

    // Configure
    input                                               CCUGLB_CfgVld,
    output                                              GLBCCU_CfgRdy,

    input [($clog2(NUM_RDPORT) + $clog2(NUM_WRPORT))* NUM_BANK     -1 : 0] CCUGLB_CfgBankPort,

    input [1*(NUM_RDPORT+NUM_WRPORT)            -1 : 0] CCUGLB_CfgPortMod,
    input [LOOP_WIDTH*NUM_RDPORT                -1 : 0] CCUGLB_CfgRdPortLoop,
    input [LOOP_WIDTH*NUM_WRPORT                -1 : 0] CCUGLB_CfgWrPortLoop,
    input [ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)   -1 : 0] CCUGLB_CfgPort_AddrMax,
    input [($clog2(MAXPAR) + 1)*NUM_RDPORT      -1 : 0] CCUGLB_CfgRdPortParBank,
    input [($clog2(MAXPAR) + 1)*NUM_WRPORT      -1 : 0] CCUGLB_CfgWrPortParBank,


    // Control
    output [NUM_RDPORT+NUM_WRPORT               -1 : 0] GLBCCU_Port_fnh ,
    input  [NUM_RDPORT+NUM_WRPORT               -1 : 0] CCUGLB_Port_rst ,

    // Data
    input  wire [SRAM_WIDTH*MAXPAR*NUM_WRPORT   -1: 0] WrPortDat,
    input  wire [NUM_WRPORT                     -1: 0] WrPortDatVld,
    output wire [NUM_WRPORT                     -1: 0] WrPortDatRdy,
    output wire [SRAM_WIDTH*MAXPAR*NUM_RDPORT   -1: 0] RdPortDat,
    output reg  [NUM_RDPORT                     -1: 0] RdPortDatVld,
    input  wire [NUM_RDPORT                     -1: 0] RdPortDatRdy

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
reg [$clog2(NUM_RDPORT) -1 : 0] BankRdPort[0      : NUM_BANK -1];
reg [$clog2(NUM_WRPORT) -1 : 0] BankWrPort[0      : NUM_BANK -1];
reg [$clog2(NUM_BANK)   -1 : 0] BankWrPortRelIdx [0: NUM_BANK -1];
reg [$clog2(NUM_BANK)   -1 : 0] BankRdPortRelIdx [0: NUM_BANK -1];

reg [($clog2(NUM_BANK) + 1)-1 : 0] RdPortNumBank[0 : NUM_RDPORT -1];
reg [($clog2(NUM_BANK) + 1)-1 : 0] WrPortNumBank[0 : NUM_WRPORT -1];

reg [($clog2(MAXPAR) + 1)  -1 : 0] RdPortParBank[0 : NUM_RDPORT      -1];
reg [($clog2(MAXPAR) + 1)  -1 : 0] WrPortParBank[0 : NUM_WRPORT      -1];

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================
reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE : if( CCUGLB_CfgVld)
                    next_state <= CFG; //A network config a time
                else
                    next_state <= IDLE;
        CFG: if( CCUGLB_CfgVld &  GLBCCU_CfgRdy)
                    next_state <= WORK;
                else
                    next_state <= CFG;
        WORK: if( CCUGLB_CfgVld ) /// COMP_FRM COMP_PAT COMP_...
                    next_state <= CFG;
                else
                    next_state <= WORK;
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


//=====================================================================================================================
// Logic Design 2: Configure
//=====================================================================================================================

// Must posedge clk 
always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        for(bk=0; bk<NUM_BANK; bk=bk+1) begin
            for(pt=0; pt<NUM_WRPORT; pt=pt+1) begin
                    BankWrPort[bk] < = 0;
                    WrPortNumBank[pt] <= 0;
                    WrPortParBank[pt] <= 0;
                    BankWrPortRelIdx[bk] <= 0;
                    
            end
            for(pt=NUM_WRPORT; pt<NUM_RDPORT+NUM_WRPORT; pt=pt+1) begin
                    BankRdPort[bk]            <= 0;
                    RdPortNumBank[pt-NUM_WRPORT]<= 0;
                    RdPortParBank[pt-NUM_WRPORT] <= 0;
                    BankRdPortRelIdx[bk]      <= 0;
            end
        end
        
    end else if(CCUGLB_CfgVld & GLBCCU_CfgRdy) begin
        for(pt=0; pt<NUM_WRPORT; pt=pt+1)
            WrPortNumBank[pt] <= 0;
        for(pt=NUM_WRPORT; pt<NUM_RDPORT+NUM_WRPORT; pt=pt+1)
            RdPortNumBank[pt-NUM_WRPORT]<= 0;
        for(bk=0; bk<NUM_BANK; bk=bk+1) begin
            BankWrPortRelIdx[bk] = 0;
            for(pt=0; pt<NUM_WRPORT; pt=pt+1) begin
                if (CCUGLB_CfgBankPort[($clog2(NUM_RDPORT) + $clog2(NUM_WRPORT))*bk +: $clog2(NUM_WRPORT)] == pt)begin
                    BankWrPort[bk] <= pt;
                    WrPortNumBank[pt] <= WrPortNumBank[pt] + 1;
                    WrPortParBank[pt] <= CCUGLB_CfgWrPortParBank[($clog2(MAXPAR) + 1)*pt +: ($clog2(MAXPAR) + 1)];
                    BankWrPortRelIdx[bk] <= BankWrPortRelIdx + 1;
                end
            end
            BankRdPortRelIdx[bk] = 0;
            for(pt=NUM_WRPORT; pt<NUM_RDPORT+NUM_WRPORT; pt=pt+1) begin
                if (CCUGLB_CfgBankPort[($clog2(NUM_RDPORT) + $clog2(NUM_WRPORT))*bk + $clog2(NUM_WRPORT) +: $clog2(NUM_RDPORT)])begin
                    BankRdPort[bk]            <= pt-NUM_WRPORT;
                    RdPortNumBank[pt-NUM_WRPORT]<= RdPortNumBank[pt-NUM_WRPORT] + 1;
                    RdPortParBank[pt-NUM_WRPORT] <= CCUGLB_CfgRdPortParBank[($clog2(MAXPAR) + 1)*(pt-NUM_RDPORT +: ($clog2(MAXPAR) + 1)];
                    BankRdPortRelIdx[bk]      <= BankRdPortRelIdx + 1;
                end
            end
        end
    end
end

assign GLBCCU_CfgRdy = 1'b1;

//=====================================================================================================================
// Logic Design 3: Bank read and write
//=====================================================================================================================

genvar i;
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
        wire RdAloc;
        assign RdAloc = ( (RdPortAddr_Array[BankRdPort[i]] >> SRAM_DEPTH_WIDTH )*RdPortParBank[BankRdPort[i]] == BankRdPortRelIdx[i]);
        assign arvalid  = RdPortDatRdy[BankRdPort[i]] & RdAloc & !(araddr == waddr & RdPortLoop[BankRdPort[i]] == WrPortLoop[BankWrPort[i]]) & (state == WORK);     
        assign araddr   = RdPortAddr_Array[BankRdPort[i]] - SRAM_WORD * BankRdPortRelIdx[i] ; 
        assign rready = RdPortDatRdy[BankRdPort[i]];

        wire WrAloc;
        assign WrAloc = ( (WrPortAddr_Array[BankRdPort[i]] >> SRAM_DEPTH_WIDTH )*WrPortParBank[BankRdPort[i]] == BankWrPortRelIdx[i]);
        assign wvalid = !(arvalid & arready) & WrPortDatVld[BankWrPort[i]] & WrAloc & (state == WORK) & !( araddr == waddr & RdPortLoop[BankRdPort[i]] < WrPortLoop[BankWrPort[i]]);
        assign waddr   = WrPortAddr_Array[BankWrPort[i]] - SRAM_WORD * BankWrPortRelIdx[i]        ;

        assign ParIdx  = WrPortNumBank[BankRdPort[i]] % WrPortParBank[BankRdPort[i]];
        assign wdata = WrPortDat_Array[BankRdPort[i]][SRAM_WIDTH*ParIdx +: SRAM_WIDTH];

    end
endgenerate

//=====================================================================================================================
// Logic Design 4: Read Port
//=====================================================================================================================
genvar j, k;
generate
    for(j=0; j<NUM_RDPORT; j=j+1) begin
        reg [$clog2(MAXPAR) + 1 -1 : 0] ByteIdx;
        reg                             INC;

        always @(*) begin
            ByteIdx = 0;
            RdPortDat_Array[j] = 0;
            RdPortDatVld[j]     = 0;
            INC = 0;
            for (bk=0; bk<NUM_BANK; bk=bk+1) begin
                if (BankRdPort[bk]==j) begin
                    if (GEN_BANK[bk].rvalid) begin
                        RdPortDat_Array[j][SRAM_WIDTH*ByteIdx +: SRAM_WIDTH] = GEN_BANK[bk].rdata;
                        ByteIdx = ByteIdx + 1;
                        RdPortDatVld[j] = 1;
                    end
                    if (GEN_BANK[bk].arvalid & GEN_BANK[bk].arready) begin
                        INC = 1'b1;
                    end
                end
            end
        end
        assign RdPortDat[SRAM_WIDTH*MAXPAR*j +: SRAM_WIDTH*MAXPAR] =  RdPortDat_Array[j];

        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_RdPortAddr(
            .CLK       ( clk                                                            ),
            .RESET_N   ( rst_n                                                          ),
            .CLEAR     ( CCUGLB_Port_rst[NUM_WRPORT+j] | ( overflow_RdPortAddr &!overflow_RdPortLoop)                                  ),
            .DEFAULT   ( 0                                                              ),
            .INC       ( INC                                                            ),
            .DEC       ( 1'b0                                                           ),
            .MIN_COUNT ( 0                                                              ),
            .MAX_COUNT ( CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*(NUM_WRPORT+j) +: ADDR_WIDTH]   ),
            .OVERFLOW  ( overflow_RdPortAddr                                  ),
            .UNDERFLOW (                                                                ),
            .COUNT     ( RdPortAddr_Array[j]                                            )
        );
        counter#(
            .COUNT_WIDTH ( 10 ) // ??
        )u_counter_RdLoop(
            .CLK       ( clk                                                            ),
            .RESET_N   ( rst_n                                                          ),
            .CLEAR     ( CCUGLB_Port_rst[NUM_WRPORT+j]                                 ),
            .DEFAULT   ( 0                                                              ),
            .INC       ( overflow_RdPortAddr                                                            ),
            .DEC       ( 1'b0                                                           ),
            .MIN_COUNT ( 0                                                              ),
            .MAX_COUNT ( CCUGLB_CfgRdPortLoop[LOOP_WIDTH*(NUM_WRPORT+j) +: LOOP_WIDTH]   ),
            .OVERFLOW  ( overflow_RdPortLoop                                  ),
            .UNDERFLOW (                                                                ),
            .COUNT     ( RdPortLoop[j]                                            )
        );
        assign GLBCCU_Port_fnh[NUM_WRPORT+j] = overflow_RdPortLoop;
    end

endgenerate

//=====================================================================================================================
// Logic Design 5: Write Port
//=====================================================================================================================
genvar m, n;
generate
    for(m=0; m<NUM_WRPORT; m=m+1) begin
        reg INC ;
        always @(*) begin
            WrPortDatRdy[m] = 0;
            INC             = 0;
            // for(n=0; n<WrPortNumBank[m]; n=n+1) begin
            for (bk=0; bk<NUM_BANK; bk=bk+1) begin
                if (BankWrPort[bk]==m) begin
                    if (GEN_BANK[bk].wvalid) begin
                        WrPortDatRdy[m] = 1'b1;
                        INC = 1'b1;
                    end
                end
            end
        end
        assign WrPortDat_Array[m] = WrPortDat[SRAM_WIDTH*MAXPAR*m +: SRAM_WIDTH*MAXPAR];

        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter(
            .CLK       ( clk                                            ),
            .RESET_N   ( rst_n                                          ),
            .CLEAR     ( CCUGLB_Port_rst[m] | (CCUGLB_CfgPortMod[m]==1 & overflow_WrPortAddr & !overflow_WrPortLoop) ),
            .DEFAULT   ( 0                                              ),
            .INC       ( INC                                            ),
            .DEC       ( 1'b0                                           ),
            .MIN_COUNT ( 0                                              ),
            .MAX_COUNT ( CCUGLB_CfgPort_AddrMax[ADDR_WIDTH*m +: ADDR_WIDTH]),
            .OVERFLOW  ( overflow_WrPortAddr                             ),
            .UNDERFLOW (                                                ),
            .COUNT     ( WrPortAddr_Array[m]                            )
        );
        counter#(
            .COUNT_WIDTH ( 10 ) // ??
        )u_counter_WrLoop(
            .CLK       ( clk                                                            ),
            .RESET_N   ( rst_n                                                          ),
            .CLEAR     ( CCUGLB_Port_rst[m]                                 ),
            .DEFAULT   ( 0                                                              ),
            .INC       ( overflow_WrPortAddr                                                            ),
            .DEC       ( 1'b0                                                           ),
            .MIN_COUNT ( 0                                                              ),
            .MAX_COUNT ( CCUGLB_CfgWrPortLoop[LOOP_WIDTH*m +: LOOP_WIDTH]   ),
            .OVERFLOW  ( overflow_WrPortLoop                                  ),
            .UNDERFLOW (                                                                ),
            .COUNT     ( WrPortLoop[m]                                            )
        );
        assign GLBCCU_Port_fnh[m] = overflow_WrPortLoop;
endgenerate

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================


endmodule
