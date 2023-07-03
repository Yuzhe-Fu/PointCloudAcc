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
// File   : CLK.v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------

module CLK #(
    parameter FBDIV_WIDTH   = 5
    )(
    input                       I_BypAsysnFIFO,
    input                       I_BypPLL    , 
    input                       I_SwClk     ,
    input                       I_SysRst_n  , 
    input                       I_SysClk    , 
    input                       I_OffClk    ,
    input [FBDIV_WIDTH  -1 : 0] I_FBDIV     ,
    output                      SysRst_n    ,
    output                      SysClk      ,
    output                      OffClk      ,
    output                      O_PLLLock    
);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                PLLclk;
wire [12    -1 : 0] FBDIV;
wire                SysClk_tmp;

//=====================================================================================================================
// Logic Design:
//=====================================================================================================================
assign SysRst_n = I_SysRst_n;

assign SysClk_tmp = I_BypAsysnFIFO? I_OffClk : I_BypPLL? I_SysClk : PLLclk;

assign FBDIV = {I_FBDIV, 4'd0};
//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================
`define PLL
`ifdef PLL
    PLLTS28HPMFRAC u_PLLTS28HPMFRAC (
        .BYPASS         ( I_BypPLL  ),
        .DACPD          ( 1'b0      ),
        .DSMPD          ( 1'b1      ), // integer
        .FBDIV          ( FBDIV     ), // 12 bit: 1-300MHz, 10MHz step: range = 30: 5bit; 
        .FRAC           ( 24'd0     ),
        .FREF           ( I_SysClk  ),
        .PD             ( 1'b0      ),
        .REFDIV         ( 6'd1      ),
        .POSTDIV1       ( 3'd1      ),
        .POSTDIV2       ( 3'd1      ),

        .LOCK           ( O_PLLLock ),
        .FOUTPOSTDIV    ( PLLclk    ), // output clk = FREF*FBDIV

        .FOUTPOSTDIVPD  ( 1'b0      ),
        .FOUTVCOPD      ( 1'b0      ),
        .FOUT4PHASEPD   ( 1'b1      ),
        .FOUT1PH0       (           ),
        .FOUT1PH90      (           ),
        .FOUT1PH180     (           ),    
        .FOUT1PH270     (           ),
        .FOUT2          (           ),
        .FOUT3          (           ),
        .FOUT4          (           ),
        .FOUTVCO        (           ),
        .CLKSSCG        (           ) 
        );
`else
    assign PLLclk = I_SysClk;
    assign O_PLLLock = I_BypPLL & (&FBDIV); // use all bits
`endif

CLKREL u_CLKREL_SysClk(
    .sw     ( I_SwClk   ),
    .rst_n  ( I_SysRst_n),
    .clk_in ( SysClk_tmp),
    .clk_out( SysClk    )
);

CLKREL u_CLKREL_OffClk(
    .sw     ( I_SwClk   ),
    .rst_n  ( I_SysRst_n),
    .clk_in ( I_OffClk  ),
    .clk_out( OffClk    )
);

endmodule
