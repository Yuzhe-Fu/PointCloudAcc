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
// `include "../source/include/dw_params_presim.vh"
module MIC #(
    parameter POOL_CORE   = 6,
    parameter POOL_COMP_CORE = 64,
    parameter IDX_WIDTH = 10,
    parameter ACT_WIDTH = 8
    )(
    input                                                           clk                     ,
    input                                                           rst_n                   ,
    input                                                           MIFMIC_Rst,

    input       [IDX_WIDTH                                  -1 : 0] CCUMIC_AddrMin,
    input       [IDX_WIDTH                                  -1 : 0] CCUMIC_AddrMax,// Not Included


    // Configure
    input       [POOL_CORE                                  -1 : 0] POLMIC_AddrVld,
    input       [IDX_WIDTH*POOL_CORE                        -1 : 0] POLMIC_Addr   ,
    output      [POOL_CORE                                  -1 : 0] MICMIF_Rdy    ,

    output                                                          MIFGLB_AddrVld,
    output      [IDX_WIDTH                                  -1 : 0] MIFGLB_Addr   ,
    input                                                           GLBMIF_AddrRdy,

    input       [ACT_WIDTH*POOL_COMP_CORE                   -1 : 0] GLBMIF_Ofm     ,
    input                                                           GLBMIF_OfmVld  ,
    output                                                          MIFGLB_OfmRdy  ,
    output      [$clog2(POOL_CORE) + ACT_WIDTH*POOL_COMP_CORE-1 : 0]MICMIF_Ofm     ,
    output                                                          MICMIF_OfmVld  ,
    input                                                           MIFMIC_OfmRdy  

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [$clog2(POOL_CORE)      -1 : 0] arb_port;
wire[$clog2(POOL_CORE)      -1 : 0] rd_port;
reg [$clog2(POOL_CORE)      -1 : 0] rd_port_d;
wire[POOL_CORE              -1 : 0] gnt;
wire                                cmd_empty;  
wire                                cmd_full;  
wire                                out_empty;  
wire                                out_full;  

wire [POOL_CORE             -1 : 0] AddrMatch;
genvar gv_i;
//=====================================================================================================================
// Logic Design : 
//=====================================================================================================================




//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

FIFO_FWFT#(
    .INIT       ( "init.mif"                    ),
    .DATA_WIDTH ( $clog2(POOL_CORE) + ACT_WIDTH*POOL_COMP_CORE ),
    .ADDR_WIDTH ( 2                             ),
    .INITIALIZE_FIFO ( "no"                     )
)U0_FIFO_FWFT_OUT(
    .clk        ( clk                               ),
    .Reset      ( MIFMIC_Rst                              ),
    .rst_n      ( rst_n                             ),
    .push       ( GLBMIF_OfmVld &  MIFGLB_OfmRdy    ),
    .pop        ( MICMIF_OfmVld & MIFMIC_OfmRdy   ),
    .data_in    ( {rd_port_d, GLBMIF_Ofm}            ),
    .data_out   ( MICMIF_Ofm                         ),
    .empty      ( out_empty                         ),
    .full       ( out_full                          ),
    .fifo_count (                                   )
);

assign MICMIF_OfmVld = !out_empty;
assign MIFGLB_OfmRdy = !out_full;

FIFO_FWFT#(
    .INIT       ( "init.mif"                    ),
    .DATA_WIDTH ( $clog2(POOL_CORE) + IDX_WIDTH ),
    .ADDR_WIDTH ( 2                             ),
    .INITIALIZE_FIFO ( "no"                     )
)U0_FIFO_FWFT_CMD(
    .clk        ( clk                                                       ),
    .Reset      ( MIFMIC_Rst                                                      ),
    .rst_n      ( rst_n                                                     ),
    .push       ( POLMIC_AddrVld[arb_port] & MICMIF_Rdy[arb_port]           ), 
    .pop        ( MIFGLB_AddrVld & GLBMIF_AddrRdy                           ),
    .data_in    ( {arb_port, POLMIC_Addr[IDX_WIDTH*arb_port +: IDX_WIDTH]}  ),
    .data_out   ( {rd_port, MIFGLB_Addr}                                    ),
    .empty      ( cmd_empty                                                 ),
    .full       ( cmd_full                                                  ),
    .fifo_count (                                                           )
);

assign MIFGLB_AddrVld   = !cmd_empty;
assign MICMIF_Rdy       =  gnt & {POOL_CORE{!cmd_full}};

generate
    for(gv_i=0; gv_i<POOL_CORE; gv_i=gv_i+1) begin
        assign AddrMatch[gv_i] = POLMIC_Addr[IDX_WIDTH*gv_i +: IDX_WIDTH]>= CCUMIC_AddrMin & POLMIC_Addr[IDX_WIDTH*gv_i +: IDX_WIDTH] < CCUMIC_AddrMax;
    end
endgenerate

prior_arb#(
    .REQ_WIDTH ( POOL_CORE )
)u_prior_arb(
    .req ( POLMIC_AddrVld & AddrMatch   ),
    .gnt ( gnt              ), // 010000
    .arb_port( arb_port             )
);

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        rd_port_d <= 0;
    end else if(MIFMIC_Rst) begin
        rd_port_d <= 0;
    end else if (MIFGLB_AddrVld & GLBMIF_AddrRdy) begin
        rd_port_d <= rd_port;
    end
end

endmodule
