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
`define PLL
module CLK #(
    parameter FBDIV_WIDTH   = 5
    )(
    input                       I_BypAsysnFIFO,
    input                       I_SwClk     ,
    input                       I_SysRst_n  , 
    input                       I_SysClk    , 
    input                       I_OffClk    ,

    `ifdef PLL 
        input                       I_BypPLL    ,
        input [FBDIV_WIDTH  -1 : 0] I_FBDIV     , 
        output                      O_PLLLock   ,
    `endif 

    output                      SysRst_n    ,
    output                      SysClk      ,
    output                      OffClk      
);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================


//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                SysClk_tmp;

//=====================================================================================================================
// Logic Design:
//=====================================================================================================================
assign SysRst_n = I_SysRst_n;

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================
`ifdef PLL
    wire                    PLLclk;
    wire [12        -1 : 0] FBDIV;
    assign SysClk_tmp   = I_BypAsysnFIFO? I_OffClk : I_BypPLL? I_SysClk : PLLclk;
    assign FBDIV        = {I_FBDIV, 5'd0}; // Constraint: FBDIV: 16-3200
    PLLTS28HPMFRAC u_PLLTS28HPMFRAC (// Constraint: Input 1MHz-1200MHz, Ouput: 16 MHz->3200 MHz; 
        .BYPASS         ( I_BypPLL  ),
        .DACPD          ( 1'b0      ),
        .DSMPD          ( 1'b1      ), // integer
        .FBDIV          ( FBDIV     ), // 12 bit: 1-300MHz, 10MHz step: range = 30: 5bit; 1M Div to 300 M -> 300 -> shift; 4'd0; 
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
    assign SysClk_tmp = I_BypAsysnFIFO? I_OffClk : I_SysClk;
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
