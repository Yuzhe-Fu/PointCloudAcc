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
module SYNC_SHAPE #(
    parameter ACT_WIDTH  = 8,
    parameter NUM_BANK   = 4,
    parameter NUM_ROW    = 16,
    parameter ADDR_WIDTH = 4 // 2**ADDR_WIDTH MUST >= NUM_ROW
  )(
    input                                                       clk     ,
    input                                                       rst_n   ,
    input                                                       Rst     , 

    input  [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][ACT_WIDTH -1 : 0]  din_data, 
    input  [NUM_BANK                                    -1 : 0]  din_data_vld,
    output [NUM_BANK                                    -1 : 0]  din_data_rdy,
    
    output [NUM_BANK  -1 : 0][NUM_ROW -1 : 0][ACT_WIDTH -1 : 0]  out_data,
    output [NUM_BANK                                     -1 : 0] out_data_vld,
    input  [NUM_BANK                                     -1 : 0] out_data_rdy
  );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam RAM_DEPTH = 2**ADDR_WIDTH;

genvar gen_i, gen_j;
generate
  for( gen_i=0 ; gen_i < NUM_BANK; gen_i = gen_i+1 ) begin : BANK_BLOCK
        //=====================================================================================================================
        // Variable Definition :
        //=====================================================================================================================
        reg     [ADDR_WIDTH     -1 : 0] wr_pointer;
        reg     [ADDR_WIDTH     -1 : 0] rd_pointer;
        wire                            empty;
        wire                            full;
        wire                            push;
        wire                            pop;
        reg     [ADDR_WIDTH + 1 -1 : 0] fifo_count;

        wire    [NUM_ROW        -1 : 0][ADDR_WIDTH  -1 : 0] waddr;
        wire    [NUM_ROW        -1 : 0][ADDR_WIDTH  -1 : 0] araddr;
        wire                            arvalid;
        wire                            wvalid;
        wire                            rvalid;
        wire                            rready;
        //=====================================================================================================================
        // Logic Design : FIFO Control
        //=====================================================================================================================
        always @ (posedge clk or negedge rst_n)begin : FIFO_COUNTER
            if (!rst_n) begin
                fifo_count <= 0;
            end else if( Rst) begin
                fifo_count <= 0;
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

        assign empty = fifo_count < NUM_ROW; // !empty
        assign full  = fifo_count >= 2**ADDR_WIDTH; // !FULL
        assign push  = wvalid;
        assign pop   = arvalid;

        //=====================================================================================================================
        // Logic Design : DPRAM
        //=====================================================================================================================
        assign wvalid               = din_data_vld[gen_i] & !full;
        assign din_data_rdy[gen_i]  = !full;

        assign arvalid              = !empty & ( (&rvalid) & rready | ~(&rvalid) );
        assign out_data_vld[gen_i]  = &rvalid;
        assign rready               = out_data_rdy[gen_i];

        for( gen_j=0 ; gen_j < NUM_ROW; gen_j = gen_j+1 ) begin : ROW_BLOCK
            assign waddr[gen_j]  = wr_pointer -gen_j;
            assign araddr[gen_j] = rd_pointer;
        end

        RAM_HS#(
            .SRAM_BIT     ( ACT_WIDTH  ),
            .SRAM_BYTE    ( 1           ),
            .SRAM_WORD    ( 2**ADDR_WIDTH   ),
            .DUAL_PORT    ( 1           )
        )u_DPRAM_HS [NUM_ROW     -1 : 0](
            .clk          ( clk          ),
            .rst_n        ( rst_n        ),
            .wvalid       ( {NUM_ROW{wvalid}}),
            .wready       (              ),
            .waddr        ( waddr        ),
            .wdata        ( din_data[gen_i]),
            .arvalid      ( {NUM_ROW{arvalid}}),
            .arready      (              ),
            .araddr       ( araddr       ),
            .rvalid       ( rvalid       ),
            .rready       ( {NUM_ROW{rready}}),
            .rdata        ( out_data[gen_i])
        );
    end
    
endgenerate

endmodule
