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
module ITF #(
    parameter PORT_WIDTH = 128,
    parameter SRAM_WIDTH = 256,
    parameter ADDR_WIDTH = 16,

    parameter NUM_RDPORT = 2,
    parameter NUM_WRPORT = 3

    )(
    input                                               clk  ,
    input                                               rst_n,
    output                                              CCUITF_Empty, 
    output [ADDR_WIDTH                          -1 : 0] CCUITF_ReqNum,
    output [ADDR_WIDTH                          -1 : 0] CCUITF_Addr,  
    output [PORT_WIDTH                          -1 : 0] ITFPAD_Dat     ,
    output [1                                   -1 : 0] ITFPAD_DatVld  ,
    output [1                                   -1 : 0] ITFPAD_DatLast ,
    input  [1                                   -1 : 0] PADITF_DatRdy  ,

    input  [PORT_WIDTH                          -1 : 0] PADITF_Dat     ,
    input  [1                                   -1 : 0] PADITF_DatVld  ,
    input  [1                                   -1 : 0] PADITF_DatLast ,
    output [1                                   -1 : 0] ITFPAD_DatRdy  ,

    input  [1*(NUM_RDPORT+NUM_WRPORT)           -1 : 0] TOPITF_EmptyFull, 
    input  [ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)  -1 : 0] TOPITF_ReqNum  ,
    input  [ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)  -1 : 0] TOPITF_Addr    ,
    input  [DRAM_ADDR_WIDTH*(NUM_RDPORT+NUM_WRPORT)  -1 : 0] CCUITF_BaseAddr,

    input  [SRAM_WIDTH*NUM_RDPORT               -1 : 0] TOPITF_Dat     ,
    input  [NUM_RDPORT                          -1 : 0] TOPITF_DatVld  ,
    input  [NUM_RDPORT                          -1 : 0] TOPITF_DatLast  ,
    output [NUM_RDPORT                          -1 : 0] ITFTOP_DatRdy  ,

    output [SRAM_WIDTH*NUM_WRPORT               -1 : 0] ITFTOP_Dat    , 
    output [NUM_WRPORT                          -1 : 0] ITFTOP_DatVld , 
    output [NUM_WRPORT                          -1 : 0] ITFTOP_DatLast , 
    input  [NUM_WRPORT                          -1 : 0] TOPITF_DatRdy   

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE = 3'b000;
localparam CMD  = 3'b001;
localparam IN   = 3'b010;
localparam OUT  = 3'b011;
localparam FNH  = 3'b100;

localparam NUMPORT_WIDTH = $clog2(NUM_WRPORT + NUM_RDPORT);
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg                         Trans;
wire [PORT_WIDTH    -1 : 0] Cmd;
wire                        CmdRdy;
wire                        CmdVld;
reg                         RdTOP;
reg [NUMPORT_WIDTH  -1 : 0] Port_wire;
reg [NUMPORT_WIDTH  -1 : 0] Port;

wire [NUMPORT_WIDTH -1 : 0] MaxIdx;
wire [ADDR_WIDTH    -1 : 0] MaxNum;

wire [SRAM_WIDTH    -1 : 0] DatIn;
wire                        DatInVld;
wire                        DatInRdy;
wire [PORT_WIDTH    -1 : 0] DatOut;
wire                        DatOutVld;
wire                        DatOutLast;
wire                        DatOutRdy;

wire [NUMPORT_WIDTH -1 : 0] WrPort;

wire                        PISO_OUTRdy;
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if( Trans )
                    next_state <= CMD;
                else
                    next_state <= IDLE;
        CMD :   if( CmdRdy & CmdVld) begin
                    if ( RdTOP)
                        next_state <= OUT;
                    else
                        next_state <= IN;
                end else
                    next_state <= CMD;
        IN:   if( DatInVld & DatInLast & DatInRdy )
                    next_state <= FNH;
                else
                    next_state <= IN;
        OUT:   if(ITFPAD_DatVld & ITFPAD_DatLast & PADITF_DatRdy )
                    next_state <= FNH;
                else
                    next_state <= OUT;
        FNH:   if( 1'b1 )
                    next_state <= IDLE;
                else
                    next_state <= FNH;
        default:    next_state <= IDLE;
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
// Logic Design 2: ARB Request
//=====================================================================================================================
always @(*) begin
    Port_wire = 0;
    Trans = 1'b0;
    RdTOP = 0; // 0: Write; 1: Read
    for(j=0; j<(NUM_WRPORT+NUM_RDPORT); j=j+1 ) begin
        if (state == IDLE & (TOPITF_EmptyFull[j])) begin
            Port_wire = j;
            Trans = 1'b1;
            RdTOP = j >=  NUM_WRPORT -1; // 0: Write TOP; 1: Read TOP
        end else if( state == IDLE & MaxNum != 0) begin
            Port_wire = MaxIdx;
            Trans = 1'b1;
            RdTOP = MaxIdx >=  NUM_WRPORT -1; // 0: Write TOP; 1: Read TOP
        end
    end
end
always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        Port <= 0;
    else if(state==IDLE && next_state == CMD) begin
        Port <= Port_wire; // Update
    end
end

//=====================================================================================================================
// Logic Design 2: Input to TOP
//=====================================================================================================================
genvar i;
generate
    for(i=0; i<NUM_WRPORT; i=i+1) begin
        assign ITFTOP_Dat[SRAM_WIDTH*i +: SRAM_WIDTH] = DatIn;
        assign ITFTOP_DatVld[i] = DatInVld;
        assign ITFTOP_DatLast[i] = DatInLast;
    end
endgenerate

assign DatInRdy = TOPITF_DatRdy[WrPort];
assign WrPort   = state == OUT? 0 : Port;

//=====================================================================================================================
// Logic Design 2: Out to off-chip
//=====================================================================================================================
assign ITFPAD_Dat       = state==CMD? Cmd : DatOut;
assign ITFPAD_DatVld    = state==CMD? CmdVld : DatOutVld;
assign ITFPAD_DatLast   = state==CMD? CmdVld : DatOutLast;
assign DatOutRdy        = PADITF_DatRdy;
assign CmdRdy           = PADITF_DatRdy;
assign ITFTOP_DatRdy    = PISO_OUTRdy & state == OUT;

assign Cmd = {TOPITF_ReqNum[ADDR_WIDTH*Port +: ADDR_WIDTH], CCUITF_BaseAddr[DRAM_ADDR_WIDTH*Port +: DRAM_ADDR_WIDTH] + TOPITF_Addr[ADDR_WIDTH*Port +: ADDR_WIDTH], RdTOP};
assign CmdVld = state == CMD;


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH ),
    .DATA_OUT_WIDTH ( SRAM_WIDTH )
)u_SIPO_IN(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .IN_VLD       ( PADITF_DatVld  ),
    .IN_LAST      ( PADITF_DatLast ),
    .IN_DAT       ( PADITF_Dat     ),
    .IN_RDY       ( ITFPAD_DatRdy  ),
    .OUT_DAT      ( DatIn          ), // Off-chip input to on-chip
    .OUT_VLD      ( DatInVld       ),
    .OUT_LAST     ( DatInLast      ),
    .OUT_RDY      ( DatInRdy       )
);


MAX # (
    .DATA_WIDTH (ADDR_WIDTH),
    .PORT(NUM_RDPORT+NUM_WRPORT)
)U_MAX_REQNUM(
    .IN (TOPITF_ReqNum),
    .MAXIDX(MaxIdx),
    .MAXVALUE(MaxNum)
)


PISO#(
    .DATA_IN_WIDTH ( SRAM_WIDTH ),
    .DATA_OUT_WIDTH ( PORT_WIDTH )
)u_PISO_OUT(
    .CLK          ( clk                        ),
    .RST_N        ( rst_n                      ),
    .IN_VLD       ( TOPITF_DatVld & state == OUT),
    .IN_LAST      ( TOPITF_DatLast& state == OUT),
    .IN_DAT       ( TOPITF_Dat                 ),
    .IN_RDY       ( PISO_OUTRdy                ),
    .OUT_DAT      ( DatOut                     ), // On-chip output to Off-chip 
    .OUT_VLD      ( DatOutVld                  ),
    .OUT_LAST     ( DatOutLast                   ),
    .OUT_RDY      ( DatOutRdy                  )
);


endmodule
