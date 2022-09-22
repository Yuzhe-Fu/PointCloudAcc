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
module MIF #(
    POOL_CORE   = 6,
    POOL_COMP_CORE = 64,
    IDX_WIDTH = 10,
    ACT_WIDTH = 8
    )(
    input                                                           clk                     ,
    input                                                           rst_n                   ,

    // Configure
    input       [POOL_CORE                                  -1 : 0] POLMIF_AddrVld,
    input       [IDX_WIDTH*POOL_CORE                        -1 : 0] POLMIF_Addr   ,
    output      [POOL_CORE                                  -1 : 0] MIFPOL_Rdy    ,

    output                                                          MIFGLB_AddrVld,
    output      [IDX_WIDTH                                  -1 : 0] MIFGLB_Addr   ,
    input                                                           GLBMIF_AddrRdy,

    input       [ACT_WIDTH*POOL_COMP_CORE                   -1 : 0] GLBMIF_Fm     ,
    input                                                           GLBMIF_FmVld  ,
    output                                                          MIFGLB_FmRdy  ,
    output      [$clog2(POOL_CORE) + ACT_WIDTH*POOL_COMP_CORE -1 : 0]MIFPOL_Fm     ,
    output                                                          MIFPOL_FmVld  ,
    input                                                           MIFPOL_FmRdy  

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg [$clog2(POOL_CORE)      -1 : 0] arb_port;
wire[$clog2(POOL_CORE)      -1 : 0] rd_port;
reg [$clog2(POOL_CORE)      -1 : 0] rd_port_d;
wire[POOL_CORE              -1 : 0] gnt;
wire                                cmd_empty;  
wire                                cmd_full;  
wire                                out_empty;  
wire                                out_full;  

//=====================================================================================================================
// Logic Design 2: Addr Gen.
//=====================================================================================================================




//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

fifo_fwft#(
    .INIT       ( "init.mif"                    ),
    .DATA_WIDTH ( $clog2(POOL_CORE) + ACT_WIDTH ),
    .ADDR_WIDTH ( 2                             ),
    .INITIALIZE_FIFO ( "no"                     )
)U0_fifo_fwft_OUT(
    .clk        ( clk                               ),
    .Reset      ( 1'b0                              ),
    .rst_n      ( rst_n                             ),
    .push       ( POLPLC_IdxVld &  PLCPOL_IdxRdy    ),
    .pop        ( PLCPOL_AddrVld & POLPLC_AddrRdy   ),
    .data_in    ( {rd_port_d, GLBMIF_Fm}            ),
    .data_out   ( MIFPOL_Fm                         ),
    .empty      ( out_empty                         ),
    .full       ( out_full                          ),
    .fifo_count (                                   )
);

assign MIFPOL_FmVld = !out_empty;
assign MIFGLB_FmRdy = !out_full;

fifo_fwft#(
    .INIT       ( "init.mif"                    ),
    .DATA_WIDTH ( $clog2(POOL_CORE) + IDX_WIDTH ),
    .ADDR_WIDTH ( 2                             ),
    .INITIALIZE_FIFO ( "no"                     )
)U0_fifo_fwft_CMD(
    .clk        ( clk                                                       ),
    .Reset      ( 1'b0                                                      ),
    .rst_n      ( rst_n                                                     ),
    .push       ( MIFGLB_AddrVld[arb_port]                                  ),
    .pop        ( MIFGLB_AddrVld & MIFGLB_AddrRdy                           ),
    .data_in    ( {arb_port, POLMIF_Addr[IDX_WIDTH*arb_port +: IDX_WIDTH]}  ),
    .data_out   ( {rd_port, MIFGLB_Addr}                                    ),
    .empty      ( cmd_empty                                                 ),
    .full       ( cmd_full                                                  ),
    .fifo_count (                                                           )
);

assign MIFGLB_AddrVld   = !cmd_empty;
assign MIFPOL_Rdy       =  gnt & {POOL_CORE{!cmd_full}};


prior_arb#(
    .REQ_WIDTH ( POOL_CORE )
)u_prior_arb(
    .req ( POLMIF_AddrVld   ),
    .gnt ( gnt              ) // 010000
);

int i;
always @() begin
    arb_port = 0;
    for(i=0; i<NUM_PORT; i=i+1) begin
        if(gnt[i]) begin
            arb_port |= i;
        end
    end
end 

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        rd_port_d <= 0;
    end else if (MIFGLB_AddrVld & MIFGLB_AddrRdy) begin
        rd_port_d <= rd_port;
    end
end

endmodule
