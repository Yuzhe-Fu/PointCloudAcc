//======================================================
// Copyright (C) 2020 By 
// All Rights Reserved
//======================================================
// Module : 
// Author : 
// Contact : 
// Date : 
//=======================================================
// Description :
//========================================================
module SHIFT #(
    parameter DATA_WIDTH= 8,
    parameter WIDTH     = 32,// Number of Input data
    parameter ADDR_WIDTH= 8, // Depth of shift buffer >= Chn*Point/WIDTH
    parameter DEPTH     = 2**ADDR_WIDTH
  )(
    input                                       clk             ,
    input                                       rst_n           ,
    input                                       Rst             , 

    // 0: MSB is written to Lowest Address; 1: MSB is written to Significant Address;
    input                                       ByteWrIncr      , // = WrRecTangle
    // Enable Addr write back when last triangle, when transform to SYA input

    input [ADDR_WIDTH                   -1 : 0] ByteWrStep      , // Address step between Bytes
    input [ADDR_WIDTH                   -1 : 0] WrBackStep      , 

    input  [WIDTH    -1 : 0][DATA_WIDTH -1 : 0] shift_din       , 
    input                                       shift_din_vld   ,
    input                                       shift_din_last  ,
    output                                      shift_din_rdy   ,
    
    output [WIDTH   -1 : 0][DATA_WIDTH  -1 : 0] shift_dout      ,
    output                                      shift_dout_vld  ,
    input                                       shift_dout_rdy  ,

    output reg [ADDR_WIDTH + 1              -1 : 0] fifo_count      
  );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
genvar gv_i;
localparam IDLE = 3'b000;
localparam IN   = 3'b010;
localparam OUT  = 3'b100;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg     [ADDR_WIDTH     -1 : 0] wr_pointer;
reg     [ADDR_WIDTH     -1 : 0] rd_pointer;
wire                            empty;
wire                            full;
wire                            push;
wire                            pop;

wire    [WIDTH          -1 : 0][ADDR_WIDTH  -1 : 0] waddr;
wire    [WIDTH          -1 : 0][ADDR_WIDTH  -1 : 0] araddr;
wire                            arvalid;
wire                            wvalid;
wire                            rvalid;
wire                            rready;

wire                            incCntWrChnGrp;
wire [ADDR_WIDTH        -1 : 0] cntWrChnGrp;

//=====================================================================================================================
// Logic Design : 
//=====================================================================================================================

reg [ 3 -1:0 ]state;
reg [ 3 -1:0 ]next_state;
always @(*) begin
    case ( state )
        IN:   if(shift_din_last & (shift_din_vld & shift_din_rdy))
                    next_state <= OUT;
                else
                    next_state <= IN;

        OUT: if(Rst)
                    next_state <= IN;
                else
                    next_state <= OUT;
                
        default: next_state <= IN;
    endcase
end

always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IN;
    end else begin
        state <= next_state;
    end
end

//=====================================================================================================================
// Logic Design : 
//=====================================================================================================================
counter#(
    .COUNT_WIDTH ( ADDR_WIDTH )
)u1_counter_WrChnGrp( 
    .CLK       ( clk                ),
    .RESET_N   ( rst_n              ),
    .CLEAR     (                    ),
    .DEFAULT   ( {ADDR_WIDTH{1'b0}} ),
    .INC       ( incCntWrChnGrp     ),
    .DEC       ( 1'b0               ),
    .MIN_COUNT ( {ADDR_WIDTH{1'b0}} ),
    .MAX_COUNT ( {ADDR_WIDTH{1'b1}} ),
    .OVERFLOW  (                    ),
    .UNDERFLOW (                    ),
    .COUNT     ( cntWrChnGrp        )
);
assign incCntWrChnGrp = (wr_pointer%(WrBackStep*ByteWrStep) == WrBackStep -ByteWrStep) & (push && !full);

//=====================================================================================================================
// Logic Design : FIFO Control
//=====================================================================================================================
always @ (posedge clk or negedge rst_n)begin : FIFO_COUNTER
    if (!rst_n) begin
        fifo_count <= WIDTH;
    end else if( Rst) begin
        fifo_count <= WIDTH;
    end else if (push && (!pop||pop&&empty) && !full)
        fifo_count <= fifo_count + 1;
    else if (pop && (!push||push&&full) && !empty)
        fifo_count <= fifo_count - 1;
end

always @ (posedge clk or negedge rst_n) begin : WRITE_PTR
    if (!rst_n) begin
        wr_pointer <= 0;
    end else if( Rst )begin
        wr_pointer <= 0;
    end else if (push && !full) begin
        wr_pointer <= wr_pointer + 1;
    end

end

always @ (posedge clk or negedge rst_n) begin : READ_PTR
    if (!rst_n) begin
        rd_pointer <= 0;
    end else if( Rst )begin
        rd_pointer <= 0;
    end else if (pop && !empty) begin
        rd_pointer <= rd_pointer + 1;
    end
end

// Write finished
assign empty = state == IN; // write assign TotalWord = WrBackStep*ByteWrStep;
assign full  = state == OUT;// !FULL:
assign push  = wvalid;
assign pop   = arvalid;

//=====================================================================================================================
// Logic Design : DPRAM
//=====================================================================================================================
assign wvalid               = shift_din_vld & shift_din_rdy;
assign shift_din_rdy        = !full | shift_dout_rdy; // write and read simultaneously

assign arvalid              = !empty & ( (&rvalid) & rready | ~(&rvalid) );
assign shift_dout_vld       = rvalid;
assign rready               = shift_dout_rdy;
assign wvalid_array = shift_din_vld & wvalid; // Write a part

generate
    for( gv_i=0 ; gv_i < WIDTH; gv_i = gv_i+1 ) begin : ROW_BLOCK
        assign waddr[gv_i]  = ByteWrIncr? 
                                (((wr_pointer + ByteWrStep*gv_i) >= ByteWrStep*WrBackStep) ?
                                    (wr_pointer + ByteWrStep*gv_i) - ByteWrStep*WrBackStep
                                    : wr_pointer + ByteWrStep*gv_i
                                ) // Write back to ByteWrIncr=Rectangle when WrRecTangle and >= ByteWrStep*WrBackStep
                                : (wr_pointer - ByteWrStep*gv_i) + cntWrChnGrp;
        assign araddr[gv_i] = rd_pointer;

        RAM_HS#(
            .SRAM_BIT     ( DATA_WIDTH  ),
            .SRAM_BYTE    ( 1           ),
            .SRAM_WORD    ( DEPTH       ),
            .DUAL_PORT    ( 1           )
        )u_DPRAM_HS (
            .clk          ( clk         ),
            .rst_n        ( rst_n       ),
            .wvalid       ( wvalid_array),
            .wready       (             ),
            .waddr        ( waddr[gv_i] ),
            .wdata        ( shift_din[gv_i] ),
            .arvalid      ( arvalid     ),
            .arready      (             ),
            .araddr       ( araddr[gv_i]),
            .rvalid       ( rvalid      ),
            .rready       ( rready      ),
            .rdata        ( shift_dout[gv_i] )
        );
    end
endgenerate

endmodule
