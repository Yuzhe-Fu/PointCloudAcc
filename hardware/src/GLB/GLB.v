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
`include "../source/include/dw_params_presim.vh"
module GLB #(
    parameter NUM_BANK = 32,
    parameter NUM_WRPORT = 3,
    parameter NUM_RDPORT = 4,
    parameter SRAM_WIDTH = 256,
    parameter MAXPAR     = 32,

    parameter ADDR_WIDTH = 16


    )(
    input                               clk                     ,
    input                               rst_n                   ,

    // Configure
    input [NUM_BANK*(NUM_RDPORT+NUM_WRPORT)     -1 : 0]  CCUGLB_CfgPort_BankFlg,
    input  CCUGLB_CfgSA_Mod,
    output [NUM_RDPORT+NUM_WRPORT   -1 : 0] GLBCCU_Port_fnh ,
    output [NUM_RDPORT+NUM_WRPORT   -1 : 0] CCUGLB_Port_rst ,
    input [ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)   -1 : 0] CCUGLB_Port_AddrMax,
    input [($clog2(MAXPAR) + 1)*NUM_RDPORT       -1 : 0] RdPortParBank,
    input [($clog2(NUM_BANK) + 1)*NUM_RDPORT       -1 : 0] RdPortNumBank,
    input [($clog2(MAXPAR) + 1)*NUM_WRPORT       -1 : 0] WrPortParBank,
    input [($clog2(NUM_BANK) + 1)*NUM_WRPORT       -1 : 0] WrPortNumBank,

    
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
localparam IDLE    = 3'b000;
localparam CFG     = 3'b001;
localparam CMP     = 3'b010;
localparam STOP    = 3'b011;
localparam WAITGBF = 3'b100;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [ADDR_WIDTH                -1: 0] WrPortAddr_Array[0: NUM_WRPORT -1];
wire [ADDR_WIDTH                -1: 0] RdPortAddr_Array[0: NUM_RDPORT -1];
wire [$clog2(NUM_RDPORT)        -1: 0] BankRdPort[0      : NUM_BANK -1];
wire [$clog2(NUM_WRPORT)        -1: 0] BankWrPort[0      : NUM_BANK -1];
reg  [SRAM_WIDTH*MAXPAR         -1: 0] RdPortDat_Array[0 : NUM_RDPORT -1];
wire [SRAM_WIDTH*MAXPAR         -1: 0] WrPortDat_Array[0 : NUM_WRPORT -1];


//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================


//=====================================================================================================================
// Logic Design 2: Configure
//=====================================================================================================================



// Must posedge clk 
for(bk=0; bk<NUM_BANK; bk=bk+1) begin
    for(pt=0; pt<NUM_WRPORT; pt=pt+1) begin
        if (CCUGLB_CfgPort_BankFlg[NUM_BANK*pt+bk])begin
            BankWrPort[bk] = pt;
            WrPortBank[pt] = bk;
        end
    end
    for(pt=NUM_WRPORT; pt<NUM_RDPORT+NUM_WRPORT; pt=pt+1) begin
        if (CCUGLB_CfgPort_BankFlg[NUM_BANK*pt+bk])begin
            BankRdPort[bk] = pt-NUM_WRPORT;
            RdPortBank[pt-NUM_WRPORT] = bk;
        end
    end
end

wire [$clog2(NUM_BANK)    -1 : 0] BankRelIdx [0: NUM_BANK -1];??????????????????????????????????????

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

genvar i;
generate
    for(i=0; i<NUM_BANK; i=i+1) begin: GEN_BANK
        RAM_HS#(
            .SRAM_BIT     ( 128 ),
            .SRAM_BYTE    ( 1 ),
            .SRAM_WORD    ( 64 ),
            .CLOCK_PERIOD ( 10 )
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

        assign RdAloc = ( (RdPortAddr_Array[BankRdPort[i]] >> SRAM_DEPTH_WIDTH )*RdPortParBank[BankRdPort[i]] == BankRelIdx[i]);
        assign arvalid  = RdPortDatRdy[BankRdPort[i]] & RdAloc & (araddr < waddr);     
        assign araddr   = RdPortAddr_Array[BankRdPort[i]]          ;
        assign rready = RdPortDatRdy[BankRdPort[i]];

        assign WrAloc = ( (WrPortAddr_Array[BankRdPort[i]] >> SRAM_DEPTH_WIDTH )*WrPortParBank[BankRdPort[i]] == BankRelIdx[i]);
        assign wvalid = !(arvalid & arready) & WrPortDatVld[BankWrPort[i]] & WrAloc ;
        assign waddr   = WrPortAddr_Array[BankWrPort[i]]          ;

        assign ParIdx  = WrPortNumBank[BankRdPort[i]] % WrPortParBank[BankRdPort[i]];
        assign wdata = WrPortDat_Array[BankRdPort[i]][SRAM_WIDTH*ParIdx +: SRAM_WIDTH];

    end
endgenerate

genvar j, k;
generate
    for(j=0; j<NUM_RDPORT; j=j+1) begin
        always @(*) begin
            ByteIdx = 0;
            RdPortDat_Array[j] = 0;
            RdPortDatVld[j]     = 0;
            INC = 0;
            for(k=0; k<RdPortNumBank[j]; k=k+1) begin
                if (GEN_BANK[RdPortBank[k]].rvalid) begin
                    RdPortDat_Array[j][SRAM_WIDTH*ByteIdx +: SRAM_WIDTH] = GEN_BANK[RdPortBank[k]].rdata;
                    ByteIdx = ByteIdx + 1;
                    RdPortDatVld[j] = 1;
                end
                if (GEN_BANK[RdPortBank[k]].arvalid & GEN_BANK[RdPortBank[k]].arready) begin
                    INC = 1'b1;
                end
            end
        end
        assign RdPortDat[SRAM_WIDTH*MAXPAR*j +: SRAM_WIDTH*MAXPAR] =  RdPortDat_Array[j];

        counter#(
            .COUNT_WIDTH ( 3 )
        )u_counter(
            .CLK       ( clk       ),
            .RESET_N   ( rst_n   ),
            .CLEAR     ( CCUGLB_Port_rst[NUM_WRPORT+j]     ),
            .DEFAULT   ( 0   ),
            .INC       ( INC       ),
            .DEC       ( 1'b0       ),
            .MIN_COUNT ( 0 ),
            .MAX_COUNT ( CCUGLB_Port_AddrMax[ADDR_WIDTH*(NUM_WRPORT+j) +: ADDR_WIDTH] ),
            .OVERFLOW  ( GLBCCU_Port_fnh[NUM_WRPORT+j]  ),
            .UNDERFLOW (  ),
            .COUNT     ( RdPortAddr_Array[j]     )
        );
        
    end
endgenerate

genvar m, n;
generate
    for(m=0; m<NUM_WRPORT; m=m+1) begin
        always @(*) begin
            WrPortDatRdy[m] = 0;
            INC             = 0;
            for(n=0; n<WrPortNumBank[m]; n=n+1) begin
                if (GEN_BANK[WrPortBank[k]].wvalid) begin
                    WrPortDatRdy[m] = 1'b1;
                    INC = 1'b1;
                end
            end
        end
        assign WrPortDat_Array[m] = WrPortDat[SRAM_WIDTH*MAXPAR*m +: SRAM_WIDTH*MAXPAR];


        counter#(
            .COUNT_WIDTH ( 3 )
        )u_counter(
            .CLK       ( clk       ),
            .RESET_N   ( rst_n   ),
            .CLEAR     ( CCUGLB_Port_rst[m]     ),
            .DEFAULT   ( 0   ),
            .INC       ( INC       ),
            .DEC       ( 1'b0       ),
            .MIN_COUNT ( 0 ),
            .MAX_COUNT ( CCUGLB_Port_AddrMax[ADDR_WIDTH*m +: ADDR_WIDTH] ),
            .OVERFLOW  ( GLBCCU_Port_fnh[m]  ),
            .UNDERFLOW (  ),
            .COUNT     ( WrPortAddr_Array[m]     )
        );


endgenerate


endmodule
