`timescale  1 ns / 100 ps

`define CLOCK_PERIOD 20
`define OFFCLOCK_PERIOD 20
`define SIM
`define FUNC_SIM
// `define POST_SIM
`define PSEUDO_DATA
`define ASSERTION_ON
// `define WITHPAD

module TOP_tb();
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
parameter PORT_WIDTH        = 128   ;
parameter ADDR_WIDTH        = 16    ;
parameter DRAM_ADDR_WIDTH   = 32    ;
parameter OPNUM             = 6     ;

parameter FPSISA_WIDTH   = PORT_WIDTH*16;
parameter KNNISA_WIDTH   = PORT_WIDTH*2 ;
parameter SYAISA_WIDTH   = PORT_WIDTH*2 ;
parameter POLISA_WIDTH   = PORT_WIDTH*9 ;
parameter GICISA_WIDTH   = PORT_WIDTH*2 ;
parameter MONISA_WIDTH   = PORT_WIDTH*1 ;

localparam [OPNUM -1 : 0][DRAM_ADDR_WIDTH -1 : 0] MDUISABASEADDR = {
    32'd0 + FPSISA_WIDTH/PORT_WIDTH + KNNISA_WIDTH/PORT_WIDTH + SYAISA_WIDTH/PORT_WIDTH + POLISA_WIDTH/PORT_WIDTH + GICISA_WIDTH/PORT_WIDTH + MONISA_WIDTH/PORT_WIDTH,
    32'd0 + FPSISA_WIDTH/PORT_WIDTH + KNNISA_WIDTH/PORT_WIDTH + SYAISA_WIDTH/PORT_WIDTH + POLISA_WIDTH/PORT_WIDTH, //29
    32'd0 + FPSISA_WIDTH/PORT_WIDTH + KNNISA_WIDTH/PORT_WIDTH + SYAISA_WIDTH/PORT_WIDTH, 
    32'd0 + FPSISA_WIDTH/PORT_WIDTH + KNNISA_WIDTH/PORT_WIDTH, 
    32'd0 + FPSISA_WIDTH/PORT_WIDTH, 
    32'd0
};

localparam [OPNUM -1 : 0][ADDR_WIDTH -1 : 0] MDUISANUM = {
    MONISA_WIDTH[0 +: 16]/PORT_WIDTH,
    GICISA_WIDTH[0 +: 16]/PORT_WIDTH, 
    POLISA_WIDTH[0 +: 16]/PORT_WIDTH, 
    SYAISA_WIDTH[0 +: 16]/PORT_WIDTH, 
    KNNISA_WIDTH[0 +: 16]/PORT_WIDTH, 
    FPSISA_WIDTH[0 +: 16]/PORT_WIDTH
};

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
// TOP Inputs
reg                             I_BypAsysnFIFO;
reg                             I_BypOE;
reg                             I_OffOE;
reg                             I_SysClk;
reg                             I_OffClk;

// TOP Outputs
wire                            O_DatOE;
wire                            O_CmdVld;

// TOP Bidirs
wire  [PORT_WIDTH       -1 : 0] IO_Dat;
wire                            O_DatVld ;
wire                            I_DatVld ;
wire                            I_DatRdy ;
wire                            O_DatRdy ;
wire                            I_DatLast;

reg                             rst_n ;

reg [PORT_WIDTH         -1 : 0] Dram[0 : 2**18-1];
wire[DRAM_ADDR_WIDTH    -1 : 0] addr;

reg [$clog2(OPNUM)      -1 : 0] ArbCfgRdyIdx;
reg [$clog2(OPNUM)      -1 : 0] ArbCfgRdyIdx_d;
wire[OPNUM  -1 : 0][ADDR_WIDTH  -1 : 0] MduISARdAddr;
wire[OPNUM              -1 : 0] Overflow_ISA;
wire [OPNUM             -1 : 0] O_CfgRdy;
wire                            I_ISAVld;
wire                            Overflow_DatAddr;

localparam IDLE         = 3'b000;
localparam ISASND       = 3'b001;
// localparam ISAWAITCFG   = 3'b010;
localparam DATCMD       = 3'b011;
localparam DATIN2CHIP   = 3'b100;
localparam DATOUT2OFF   = 3'b101;


reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;

//=====================================================================================================================
// Logic Design: Debounce
//=====================================================================================================================
initial
begin
    I_OffClk = 1;
    forever #(`OFFCLOCK_PERIOD/2) I_OffClk=~I_OffClk;
end

initial
begin
    I_SysClk = 1;
    forever #(`CLOCK_PERIOD/2)  I_SysClk=~I_SysClk;
end

initial
begin
    rst_n           = 1;
    I_BypAsysnFIFO  = 1;
    I_BypOE         = 0;
    I_OffOE         = 0;
    #(`CLOCK_PERIOD*2)  rst_n  =  0;
    #(`CLOCK_PERIOD*10) rst_n  =  1;
end

initial begin
    $readmemh("Dram.txt", Dram);
end

initial begin
    $shm_open("TEMPLATE.shm");
    $shm_probe(TOP_tb, "AS");
end

initial
begin
    ArbCfgRdyIdx = 7; // Invalid
    @(posedge rst_n);
    repeat(10) @(posedge I_OffClk);
    forever begin
        wait (state == IDLE & |O_CfgRdy & !O_CmdVld);
        @ (negedge I_OffClk );
        $stop;
        wait (ArbCfgRdyIdx <= OPNUM -1);
        repeat(2) @(posedge I_OffClk); // 
    end
end

`ifdef POST_SIM
    initial begin 
        $sdf_annotate ("/workspace/home/zhoucc/Proj_HW/PointCloudAcc/hardware/work/synth/TOP/Date230417_Period10_group_Track3vt_NoteWoPAD&RTSEL10/gate/TOP.sdf", u_TOP, , "TOP_sdf.log", "MAXIMUM", "1.0:1.0:1.0", "FROM_MAXIMUM");
    end 

    reg EnTcf;
    initial begin
        EnTcf = 1'b0;
    end
`endif


//=====================================================================================================================
// Logic Design 1: FSM=ITF
//=====================================================================================================================
always @(*) begin
    case ( state )
        IDLE:   if( O_CmdVld )
                    next_state <= DATCMD;
                else if ( ArbCfgRdyIdx <= 5 )
                    next_state <= ISASND;
                else
                    next_state <= IDLE;

        // ISA
        ISASND: if( I_DatLast & I_DatVld & I_DatRdy )
                    next_state <= IDLE;
                else
                    next_state <= ISASND;

        // Data
        DATCMD :if( O_DatOE & O_DatVld & I_DatRdy) begin
                    if ( IO_Dat[0] ) // 
                        next_state <= DATOUT2OFF;
                    else
                        next_state <= DATIN2CHIP;
                end else
                    next_state <= DATCMD;

        DATIN2CHIP:   if( Overflow_DatAddr )
                    next_state <= IDLE;
                else
                    next_state <= DATIN2CHIP;

        DATOUT2OFF:   if( Overflow_DatAddr )
                    next_state <= IDLE;
                else
                    next_state <= DATOUT2OFF;

        default:    next_state <= IDLE;
    endcase
end
always @ ( posedge I_OffClk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

//=====================================================================================================================
// Logic Design: ISA 
//=====================================================================================================================
genvar gv_i;
generate
    for(gv_i = 0; gv_i < OPNUM; gv_i = gv_i + 1) begin: GEN_MduISARdAddr
        reg  [ADDR_WIDTH     -1 : 0] MduISARdAddr_r; // Last
        wire [ADDR_WIDTH     -1 : 0] MaxCnt; 
        wire [ADDR_WIDTH     -1 : 0] Default;

        assign MaxCnt   = 2**ADDR_WIDTH -1;
        assign Default  = MDUISABASEADDR[gv_i];

        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_MduISARdAddr(
            .CLK       ( I_OffClk       ),
            .RESET_N   ( rst_n          ),
            .CLEAR     ( 1'b0           ),
            .DEFAULT   ( Default        ),
            .INC       ( I_ISAVld & (I_DatVld & O_DatRdy) & (ArbCfgRdyIdx_d == gv_i) ),
            .DEC       ( 1'b0           ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
            .MAX_COUNT ( MaxCnt         ),
            .OVERFLOW  (                ),
            .UNDERFLOW (                ),
            .COUNT     ( MduISARdAddr[gv_i])
        );
        always @(posedge I_OffClk or rst_n) begin
            if (!rst_n) begin
                MduISARdAddr_r <= 0;
            end else if(state == IDLE) begin
                MduISARdAddr_r <= MduISARdAddr[gv_i];
            end
        end
        assign Overflow_ISA[gv_i] = MduISARdAddr[gv_i] - MduISARdAddr_r == MDUISANUM[ArbCfgRdyIdx_d] - 1;

    end
endgenerate

assign #2 I_ISAVld = state == ISASND;
always @(posedge I_OffClk or rst_n) begin
    if (!rst_n) begin
        ArbCfgRdyIdx_d <= 0;
    end else if(state == IDLE && next_state == ISASND) begin
        ArbCfgRdyIdx_d <= ArbCfgRdyIdx;
    end
end

//=====================================================================================================================
// Logic Design: DATA 
//=====================================================================================================================
reg [DRAM_ADDR_WIDTH        -1 : 0] MaxAddr;
wire[DRAM_ADDR_WIDTH        -1 : 0] default_addr;
always @(posedge I_OffClk or rst_n) begin
    if (!rst_n) begin
        MaxAddr <= 0;
    end else if(state==DATCMD & (next_state == DATIN2CHIP | next_state == DATOUT2OFF)) begin
        MaxAddr <= IO_Dat[1 +: DRAM_ADDR_WIDTH] + IO_Dat[1 + DRAM_ADDR_WIDTH +: ADDR_WIDTH];
    end
end
assign default_addr = state==DATCMD & (next_state == DATIN2CHIP | next_state == DATOUT2OFF) ? IO_Dat[1 +: DRAM_ADDR_WIDTH] : 0;
counter#(
    .COUNT_WIDTH ( DRAM_ADDR_WIDTH )
)u_counter_addr(
    .CLK       ( I_OffClk       ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state==DATCMD & (next_state == DATIN2CHIP | next_state == DATOUT2OFF) ),
    .DEFAULT   ( default_addr   ),
    .INC       ( (state == DATIN2CHIP | state == DATOUT2OFF) & (I_DatVld & O_DatRdy | O_DatVld & I_DatRdy) ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {DRAM_ADDR_WIDTH{1'b0}}),
    .MAX_COUNT ( MaxAddr        ),
    .OVERFLOW  ( Overflow_DatAddr),
    .UNDERFLOW (                ),
    .COUNT     ( addr           )
);

`ifndef PSEUDO_DATA
    always @(posedge I_OffClk or rst_n) begin
        if(state == DATOUT2OFF) begin
            if(O_DatVld & I_DatRdy)
                Dram[addr] <= IO_Dat;
        end
    end
`endif

//=====================================================================================================================
// Logic Design : Interface
//=====================================================================================================================
// DRAM READ
assign #2 I_DatVld  = state == ISASND | state== DATIN2CHIP;
assign    I_DatLast = (I_ISAVld? Overflow_ISA[ArbCfgRdyIdx_d] : Overflow_DatAddr) & I_DatVld;
assign #2 IO_Dat    = I_ISAVld? Dram[MduISARdAddr[ArbCfgRdyIdx_d]] : Dram[addr[0 +: 13]]; // 8196

wire [PORT_WIDTH    -1 : 0] TEST28 = Dram[28];

// DRAM WRITE
assign #2 I_DatRdy = I_ISAVld? 1'bz : (O_DatOE? O_CmdVld & state==DATCMD | !O_CmdVld & state==DATOUT2OFF: 1'bz);

TOP u_TOP (
    .I_BypAsysnFIFO_PAD ( I_BypAsysnFIFO),
    .I_BypOE_PAD        ( I_BypOE       ),
    .I_BypPLL_PAD       ( 1'b0          ),
    .I_FBDIV_PAD        ( 5'd1          ),
    .I_SwClk_PAD        ( 1'b1          ),
    .I_SysRst_n_PAD     ( rst_n         ),
    .I_SysClk_PAD       ( I_SysClk      ),
    .I_OffClk_PAD       ( I_OffClk      ),
    .O_SysClk_PAD       (               ),
    .O_OffClk_PAD       (               ),
    .O_PLLLock_PAD      (               ),
    .O_CfgRdy_PAD       ( O_CfgRdy      ),
    .O_DatOE_PAD        ( O_DatOE       ),
    .I_OffOE_PAD        ( I_OffOE       ),
    .I_DatVld_PAD       ( I_DatVld      ),
    .I_DatLast_PAD      ( I_DatLast     ),
    .O_DatRdy_PAD       ( O_DatRdy      ),
    .O_DatVld_PAD       ( O_DatVld      ), 
    .O_DatLast_PAD      ( O_DatLast     ), 
    .I_DatRdy_PAD       ( I_DatRdy      ),
    .I_ISAVld_PAD       ( I_ISAVld      ),
    .O_CmdVld_PAD       ( O_CmdVld      ),
    .IO_Dat_PAD         ( IO_Dat        ) 
);

endmodule