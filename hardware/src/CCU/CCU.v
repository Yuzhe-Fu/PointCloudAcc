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
module CCU #(
    parameter SRAM_WIDTH            = 256,
    parameter PORT_WIDTH            = 128,
    parameter POOL_CORE             = 6,
    parameter BYTE_WIDTH            = 8,

    parameter ADDR_WIDTH            = 16,
    parameter DRAM_ADDR_WIDTH       = 32,
    parameter GLB_NUM_RDPORT        = 12,
    parameter GLB_NUM_WRPORT        = 13,
    parameter IDX_WIDTH             = 16,
    parameter CHN_WIDTH             = 16,
    parameter QNTSL_WIDTH           = 16,
    parameter ACT_WIDTH             = 8,
    parameter MAP_WIDTH             = 5,
    parameter NUM_LAYER_WIDTH       = 20,
    parameter NUM_MODULE            = 6,
    parameter NUM_BANK              = 32,
    parameter NUM_FPC               = 8,
    parameter OPNUM                 = NUM_MODULE,

    parameter CCUISA_WIDTH           = PORT_WIDTH*1,
    parameter FPSISA_WIDTH           = PORT_WIDTH*16,
    parameter KNNISA_WIDTH           = PORT_WIDTH*2,
    parameter SYAISA_WIDTH           = PORT_WIDTH*3,
    parameter POLISA_WIDTH           = PORT_WIDTH*9,
    parameter GICISA_WIDTH           = PORT_WIDTH*2

    )(
    input                                   clk                 ,
    input                                   rst_n               ,

    output [OPNUM                   -1 : 0] CCUITF_CfgRdy       ,
    input   [PORT_WIDTH             -1 : 0] ITFCCU_ISARdDat     ,       
    input                                   ITFCCU_ISARdDatVld  ,          
    output                                  CCUITF_ISARdDatRdy  ,

    output                                  CCUGIC_CfgVld       ,
    input                                   GICCCU_CfgRdy       ,  
    output [GICISA_WIDTH            -1 : 0] CCUGIC_CfgInfo      ,
                
    output  [NUM_FPC                -1 : 0] CCUFPS_CfgVld       ,
    input   [NUM_FPC                -1 : 0] FPSCCU_CfgRdy       ,   
    output [FPSISA_WIDTH            -1 : 0] CCUFPS_CfgInfo      ,     

    output                                  CCUKNN_CfgVld       ,
    input                                   KNNCCU_CfgRdy       ,  
    output [KNNISA_WIDTH            -1 : 0] CCUKNN_CfgInfo      ,        

    output                                  CCUSYA_CfgVld       ,
    input                                   SYACCU_CfgRdy       ,
    output [SYAISA_WIDTH            -1 : 0] CCUSYA_CfgInfo      , 

    output  [POOL_CORE              -1 : 0] CCUPOL_CfgVld       ,
    input   [POOL_CORE              -1 : 0] POLCCU_CfgRdy       ,
    output  [POLISA_WIDTH           -1 : 0] CCUPOL_CfgInfo          

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam OPCODE_WIDTH = 8;
localparam NUMWORD_WIDTH= 8;

localparam IDLE         = 4'b0000;cfgVld
localparam DEC          = 4'b0001;
localparam CFG          = 4'b0010;

localparam OPCODE_CCU   = 0;
localparam OPCODE_FPS   = 1;
localparam OPCODE_KNN   = 2;
localparam OPCODE_SYA   = 3;
localparam OPCODE_POL   = 4;
localparam OPCODE_ITF   = 5;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg [OPCODE_WIDTH                   -1 : 0] opCode;
integer                                     int_i;
wire  [OPNUM                        -1 : 0] cfgVld; 
wire  [OPNUM                        -1 : 0] SIPO_InRdy; 
wire                                        CCUTOP_CfgVld;  

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================
reg [4      -1 : 0] state       ;
reg [4      -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE    :   if(ITFCCU_ISARdDatVld)
                        next_state <= DEC; //
                    else
                        next_state <= IDLE;
        DEC:   if (SIPO_FPSISA_OUT_VLD[opCode] & SIPO_FPSISA_OUT_RDY[opCode])
                        next_state <= IDLE;
                    else
                        next_state <= DEC;

        default :       next_state <= IDLE;
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
// Logic Design
//=====================================================================================================================
// CCUITF_CfgRdy -> Req
// `ifdef PSEUDO_DATA
//     assign CCUITF_CfgRdy = {GICCCU_CfgRdy, 1'b0, 1'b0, 1'b0, &FPSCCU_CfgRdy, 1'b0};
// `else
    assign CCUITF_CfgRdy = cfgRdy;
    assign cfgRdy = {GICCCU_CfgRdy, &POLCCU_CfgRdy, SYACCU_CfgRdy, KNNCCU_CfgRdy, &FPSCCU_CfgRdy, 1'b0};
// `endif

wire        FPS_CfgVld;
wire        POL_CfgVld;

assign {CCUGIC_CfgVld, POL_CfgVld, CCUSYA_CfgVld, CCUKNN_CfgVld, FPS_CfgVld, CCUTOP_CfgVld} = cfgVld;
assign CCUFPS_CfgVld = {NUM_FPC{FPS_CfgVld}};
assign CCUPOL_CfgVld = {POOL_CORE{POL_CfgVld}};

//=====================================================================================================================
// Logic Design: s2
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        opCode <= {OPCODE_WIDTH{1'b1}};
    end else if(next_state == IDLE) begin // HS
        opCode <= {OPCODE_WIDTH{1'b1}};
    end else if(state == IDLE & next_state == DEC) begin
        opCode <= ITFCCU_ISARdDat[0 +: OPCODE_WIDTH];
    end
end

wire                                    SIPO_CCU_InRdy;
wire                                    SIPO_FPS_InRdy;
wire                                    SIPO_KNN_InRdy;
wire                                    SIPO_SYA_InRdy;
wire                                    SIPO_POL_InRdy;
wire                                    SIPO_ITF_InRdy;

SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH               ),
    .DATA_OUT_WIDTH ( FPSISA_WIDTH  )
)u_SIPO_ISA_FPS(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .RESET        ( state == IDLE  ),
    .IN_VLD       ( state == DEC & ITFCCU_ISARdDatVld & opCode == OPCODE_FPS ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( ITFCCU_ISARdDat),
    .IN_RDY       ( SIPO_FPS_InRdy ),
    .OUT_DAT      ( SIPO_FPSISA_OUT_DAT                ),
    .OUT_VLD      ( SIPO_FPSISA_OUT_VLD                ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( SIPO_FPSISA_OUT_RDY)
);
assign SIPO_FPSISA_OUT_RDY = !FIFO_FPSISA_Reset & !FIFO_FPSISA_full;

assign FIFO_FPSISA_Reset = SIPO_FPSISA_OUT_DAT[OPCODE_WIDTH] & SIPO_FPSISA_OUT_VLD & !FIFO_FPSISA_empty;
FIFO_FWFT#(
    .DATA_WIDTH ( FPSISA_WIDTH ),
    .ADDR_WIDTH ( FPSISA_FIFO_ADDR_WIDTH )
)u_FIFO_FWFT(
    .clk        ( clk                   ),
    .Reset      (  ),
    .rst_n      ( rst_n                 ),
    .push       ( FIFO_FPSISA_push      ),
    .pop        ( FIFO_FPSISA_pop       ),
    .data_in    ( SIPO_FPSISA_OUT_DAT   ),
    .data_out   ( FIFO_FPSISA_data_out  ),
    .empty      ( FIFO_FPSISA_empty     ),
    .full       ( FIFO_FPSISA_full      ),
    .fifo_count (                       )
);

assign FIFO_FPSISA_push= !FIFO_FPSISA_Reset & SIPO_FPSISA_OUT_VLD & !FIFO_FPSISA_full;
assign FIFO_FPSISA_pop = cfgRdy[OPCODE_FPS];

assign  cfgEnable = FIFO_FPSISA_data_out[OPCODE_WIDTH] | (cfgRdy[OPCODE_FPS] & !FIFO_FPSISA_empty);
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        CCUFPS_CfgInfo <= 0;
    end else if( cfgEnable) begin
        CCUFPS_CfgInfo <= FIFO_FPSISA_data_out;
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cfgVld[OPCODE_FPS] <= 0;
    end else if( cfgVld[OPCODE_FPS] & cfgRdy[OPCODE_FPS] ) begin
        cfgVld[OPCODE_FPS] <= 1'b0;
    end else if( cfgEnable ) begin
        cfgVld[OPCODE_FPS] <= 1'b1;
    end
end





SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH     ),
    .DATA_OUT_WIDTH ( KNNISA_WIDTH  )
)u_SIPO_ISA_KNN(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .RESET        ( state == IDLE  ),
    .IN_VLD       ( state == DEC & ITFCCU_ISARdDatVld & opCode == OPCODE_KNN ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( ITFCCU_ISARdDat),
    .IN_RDY       ( SIPO_KNN_InRdy ),
    .OUT_DAT      ( CCUKNN_CfgInfo        ),
    .OUT_VLD      ( cfgVld[OPCODE_KNN] ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( CCUITF_CfgRdy[OPCODE_KNN])
);

SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH               ),
    .DATA_OUT_WIDTH ( SYAISA_WIDTH  )
)u_SIPO_ISA_SYA(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .RESET        ( state == IDLE  ),
    .IN_VLD       ( state == DEC & ITFCCU_ISARdDatVld & opCode == OPCODE_SYA ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( ITFCCU_ISARdDat),
    .IN_RDY       ( SIPO_SYA_InRdy ),
    .OUT_DAT      ( CCUSYA_CfgInfo        ),
    .OUT_VLD      ( cfgVld[OPCODE_SYA] ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( CCUITF_CfgRdy[OPCODE_SYA])
);

SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH               ),
    .DATA_OUT_WIDTH ( POLISA_WIDTH  )
)u_SIPO_ISA_POL(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .RESET        ( state == IDLE  ),
    .IN_VLD       ( state == DEC & ITFCCU_ISARdDatVld & opCode == OPCODE_POL ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( ITFCCU_ISARdDat),
    .IN_RDY       ( SIPO_POL_InRdy ),
    .OUT_DAT      ( CCUPOL_CfgInfo        ),
    .OUT_VLD      ( cfgVld[OPCODE_POL] ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( CCUITF_CfgRdy[OPCODE_POL])
);
SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH               ),
    .DATA_OUT_WIDTH ( GICISA_WIDTH  )
)u_SIPO_ISA_ITF(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .RESET        ( state == IDLE  ),
    .IN_VLD       ( state == DEC & ITFCCU_ISARdDatVld & opCode == OPCODE_ITF ),
    .IN_LAST      ( 1'b0           ),
    .IN_DAT       ( ITFCCU_ISARdDat),
    .IN_RDY       ( SIPO_ITF_InRdy ),
    .OUT_DAT      ( CCUGIC_CfgInfo        ),
    .OUT_VLD      ( cfgVld[OPCODE_ITF] ),
    .OUT_LAST     (                ),
    .OUT_RDY      ( CCUITF_CfgRdy[OPCODE_ITF])
);

assign SIPO_InRdy           = {SIPO_ITF_InRdy, SIPO_POL_InRdy, SIPO_SYA_InRdy, SIPO_KNN_InRdy, SIPO_FPS_InRdy, 1'b1};
assign CCUITF_ISARdDatRdy   = state == DEC & SIPO_InRdy[opCode];


endmodule
