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
    input   CCUGLB_CfgPort_BankIdx,
    input  CCUGLB_CfgSA_Mod,
    output GLBCCU_Bank_fnh ,
    output CCUGLB_Bank_rst ,

    
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
wire [1                         -1: 0] WrPortEn_Array[0  : NUM_WRPORT -1];
wire [1                         -1: 0] RdPortEn_Array[0  : NUM_RDPORT -1];
wire [$clog2(NUM_RDPORT)      -1: 0] BankRdPort[0      : NUM_BANK -1];
wire [$clog2(NUM_WRPORT)      -1: 0] BankWrPort[0      : NUM_BANK -1];
reg  [SRAM_WIDTH*MAXPAR      -1: 0] RdPortDat_Array[0      : NUM_RDPORT -1];
wire [SRAM_WIDTH*MAXPAR      -1: 0] WrPortDat_Array[0      : NUM_WRPORT -1];


//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================


//=====================================================================================================================
// Logic Design 2: Addr Gen.
//=====================================================================================================================


// 

for(j=0; j)
wire [$clog2(NUM_BANK)    -1 : 0] Rel_BankIdx [0: NUM_BANK -1];
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

        assign RdAloc = ( (RdPortAddr_Array[BankRdPort[i]] >> SRAM_DEPTH_WIDTH )*RdPortParBank[BankRdPort[i]] == Rel_BankIdx[i]);
        assign arvalid  = RdPortEn_Array[BankRdPort[i]] & RdAloc ;     
        assign araddr   = RdPortAddr_Array[BankRdPort[i]]          ;
        assign rready = RdPortDatRdy[BankRdPort[i]];

        assign WrAloc = ( (WrPortAddr_Array[BankRdPort[i]] >> SRAM_DEPTH_WIDTH )*WrPortParBank[BankRdPort[i]] == Rel_BankIdx[i]);
        assign wvalid = !arvalid & WrPortEn_Array[BankWrPort[i]] & WrAloc ;
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
            for(k=0; k<RdPortNumBank[j]; k=k+1) begin
                if (GEN_BANK[RdPortBank[k]].rvalid) begin
                    RdPortDat_Array[j][SRAM_WIDTH*ByteIdx +: SRAM_WIDTH] = GEN_BANK[RdPortBank[k]].rdata;
                    ByteIdx = ByteIdx + 1;
                    RdPortDatVld[j] = 1;
                end
            end
        end
        assign RdPortDat[SRAM_WIDTH*MAXPAR*j +: SRAM_WIDTH*MAXPAR] =  RdPortDat_Array[j];

endgenerate

genvar m, n;
generate
    for(m=0; m<NUM_WRPORT; m=m+1) begin
        always @(*) begin
            WrPortDatRdy[m] = 0;
            for(n=0; n<WdPortNumBank[m]; n=n+1) begin
                if (GEN_BANK[WrPortBank[k]].wvalid) begin
                    WrPortDatRdy[m] = 1'b1;
                end
            end
        end
        assign WrPortDat_Array[m] = WrPortDat[SRAM_WIDTH*MAXPAR*m +: SRAM_WIDTH*MAXPAR];
        assign WrPortEn_Array[m] = WrPortDatVld[m];

endgenerate



endmodule
