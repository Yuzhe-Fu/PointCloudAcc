`timescale  1 ns / 100 ps

`define CLOCK_PERIOD 10
`define SIM
// `define FUNC_SIM
`define POST_SIM
`define PSEUDO_DATA
`define ASSERTION_ON
// `define WITHPAD

module TOP_tb();
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
parameter PORT_WIDTH        = 128;
parameter ADDR_WIDTH        = 16;
parameter DRAM_ADDR_WIDTH   = 32;
parameter OPNUM             = 6;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
// TOP Inputs
reg                             I_BypAsysnFIFO;

// TOP Outputs
wire                            O_DatOE;
wire                            O_CmdVld;

// TOP Bidirs
wire  [PORT_WIDTH       -1 : 0] IO_Dat;
wire                            IO_DatVld ;
wire                            OI_DatRdy ;

reg                             rst_n ;
reg                             clk   ;
reg [PORT_WIDTH         -1 : 0] Dram[0 : 2**18-1];
wire[DRAM_ADDR_WIDTH    -1 : 0] addr;

reg [$clog2(OPNUM)      -1 : 0] ArbCfgRdyIdx;
reg  [$clog2(OPNUM)     -1 : 0] ArbCfgRdyIdx_d;
wire [OPNUM -1 : 0][ADDR_WIDTH      -1 : 0] MduISARdAddr;
wire [OPNUM -1 : 0] Overflow_ISA;
reg  [OPNUM -1 : 0][DRAM_ADDR_WIDTH -1 : 0] MDUISABASEADDR;
reg  [OPNUM -1 : 0][DRAM_ADDR_WIDTH -1 : 0] MDUISANUM;
wire [OPNUM             -1 : 0] O_CfgRdy;
wire                            I_ISAVld;

localparam IDLE     = 3'b000;
localparam FET      = 3'b001;
localparam WAITCFG  = 3'b010;
localparam CMD      = 3'b011;
localparam IN2CHIP  = 3'b100;
localparam OUT2OFF  = 3'b101;


reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;

//=====================================================================================================================
// Logic Design: Debounce
//=====================================================================================================================
initial
begin
    clk= 1;
    forever #(`CLOCK_PERIOD/2)  clk=~clk;
end

initial
begin
    rst_n           = 1;
    I_BypAsysnFIFO  = 1;
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
    repeat(10) @(posedge clk);
    forever begin
        wait (state == IDLE & |O_CfgRdy & !O_CmdVld);
        @ (negedge clk );
        $stop;
        wait (ArbCfgRdyIdx <= 5);
        repeat(2) @(posedge clk); // 
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
                    next_state <= CMD;
                else if ( ArbCfgRdyIdx <= 5 )
                    next_state <= FET;
                else
                    next_state <= IDLE;
        // ISA
        FET:    if( Overflow_ISA )
                    next_state <= WAITCFG;
                else
                    next_state <= FET;
        WAITCFG:    if ( !O_CfgRdy[ArbCfgRdyIdx_d] )
                    next_state <= IDLE;
                else
                    next_state <= WAITCFG;        
        // Data
        CMD :   if( O_DatOE & IO_DatVld & OI_DatRdy) begin
                    if ( IO_Dat[0] ) // 
                        next_state <= OUT2OFF;
                    else
                        next_state <= IN2CHIP;
                end else
                    next_state <= CMD;
        IN2CHIP:   if( O_CfgRdy[5] )
                    next_state <= IDLE;
                else
                    next_state <= IN2CHIP;
        OUT2OFF:   if( O_CfgRdy[5] )
                    next_state <= IDLE;
                else
                    next_state <= OUT2OFF;
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
// Logic Design: ISA 
//=====================================================================================================================
always @ ( posedge clk or negedge rst_n ) begin
MDUISABASEADDR[0] <= 0;
MDUISABASEADDR[1] <= 1;
MDUISABASEADDR[2] <= 17;
MDUISABASEADDR[3] <= 19;
MDUISABASEADDR[4] <= 22;
MDUISABASEADDR[5] <= 28;

MDUISANUM[0] <= 1;
MDUISANUM[1] <= 16;
MDUISANUM[2] <= 2;
MDUISANUM[3] <= 3;
MDUISANUM[4] <= 6;
MDUISANUM[5] <= 2;

end

genvar gv_i;
generate
    for(gv_i = 0; gv_i < OPNUM; gv_i = gv_i + 1) begin: GEN_MduISARdAddr
        reg [ADDR_WIDTH     -1 : 0] MduISARdAddr_r; // Last
        wire [ADDR_WIDTH     -1 : 0] MaxCnt = 2**ADDR_WIDTH -1;
        wire [ADDR_WIDTH     -1 : 0] Default= MDUISABASEADDR[gv_i];
        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_MduISARdAddr(
            .CLK       ( clk            ),
            .RESET_N   ( rst_n          ),
            .CLEAR     ( 1'b0           ),
            .DEFAULT   ( Default        ),
            .INC       ( I_ISAVld & (IO_DatVld & OI_DatRdy) & (ArbCfgRdyIdx_d == gv_i) ),
            .DEC       ( 1'b0           ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
            .MAX_COUNT ( MaxCnt         ),
            .OVERFLOW  (                ),
            .UNDERFLOW (                ),
            .COUNT     ( MduISARdAddr[gv_i])
        );
        always @(posedge clk or rst_n) begin
            if (!rst_n) begin
                MduISARdAddr_r <= 0;
            end else if(state == IDLE) begin
                MduISARdAddr_r <= MduISARdAddr[gv_i];
            end
        end
        assign Overflow_ISA[gv_i] = MduISARdAddr[gv_i] - MduISARdAddr_r == MDUISANUM[ArbCfgRdyIdx_d];

    end
endgenerate

// wire [ADDR_WIDTH     -1 : 0] MaxCnt = MDUISANUM[ArbCfgRdyIdx_d];
// counter#(
//     .COUNT_WIDTH ( ADDR_WIDTH )
// )u_counter_CntISA(
//     .CLK       ( clk            ),
//     .RESET_N   ( rst_n          ),
//     .CLEAR     ( 1'b0           ),
//     .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
//     .INC       ( I_ISAVld & (IO_DatVld & OI_DatRdy) ),
//     .DEC       ( 1'b0           ),
//     .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
//     .MAX_COUNT ( MaxCnt         ),
//     .OVERFLOW  (                ),
//     .UNDERFLOW (                ),
//     .COUNT     ( CntISA         )
// );

assign #2 I_ISAVld = state == FET | state == WAITCFG;
always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        ArbCfgRdyIdx_d <= 0;
    end else if(state == IDLE && next_state == FET) begin
        ArbCfgRdyIdx_d <= ArbCfgRdyIdx;
    end
end


//=====================================================================================================================
// Logic Design: DATA 
//=====================================================================================================================
// Indexed addressing
// always @(posedge clk or rst_n) begin
//     if (!rst_n) begin
//         addr_r <= 0;
//     end else if(state==CMD & (next_state == IN2CHIP | next_state == OUT2OFF)) begin
//         addr_r <= IO_Dat[1 +: DRAM_ADDR_WIDTH];
//     end
// end

wire [DRAM_ADDR_WIDTH     -1 : 0] MaxAddr = 2**DRAM_ADDR_WIDTH - 1;
counter#(
    .COUNT_WIDTH ( DRAM_ADDR_WIDTH )
)u_counter_addr(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state==CMD & (next_state == IN2CHIP | next_state == OUT2OFF) ),
    .DEFAULT   ( IO_Dat[1 +: DRAM_ADDR_WIDTH]),
    .INC       ( (state == IN2CHIP | state == OUT2OFF) & IO_DatVld & OI_DatRdy ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {DRAM_ADDR_WIDTH{1'b0}}),
    .MAX_COUNT ( MaxAddr         ),
    .OVERFLOW  (                ),
    .UNDERFLOW (                ),
    .COUNT     ( addr           )
);

// assign Overflow_Data = addr - addr_r = 

`ifndef PSEUDO_DATA
    always @(posedge clk or rst_n) begin
        if(state == OUT2OFF) begin
            if(IO_DatVld & OI_DatRdy)
                Dram[addr] <= IO_Dat;
        end
    end
`endif

//=====================================================================================================================
// Logic Design : Interface
//=====================================================================================================================
// DRAM READ
assign #2 IO_DatVld  = I_ISAVld? state == FET & next_state != WAITCFG : (O_DatOE? 1'bz : state== IN2CHIP);
assign #2 IO_Dat     = I_ISAVld? Dram[MduISARdAddr[ArbCfgRdyIdx_d]] : (O_DatOE? {PORT_WIDTH{1'bz}} : Dram[addr]);

wire [PORT_WIDTH    -1 : 0] TEST28 = Dram[28];


// DRAM WRITE
assign #2 OI_DatRdy = I_ISAVld? 1'bz : (O_DatOE? O_CmdVld & state==CMD | !O_CmdVld & state==OUT2OFF: 1'bz);

TOP u_TOP (
    .I_SysRst_n_PAD              ( rst_n          ),
    .I_SysClk_PAD                ( clk            ),
    .I_BypAsysnFIFO_PAD          ( I_BypAsysnFIFO ),
    .O_CfgRdy_PAD                ( O_CfgRdy       ),
    .I_ISAVld_PAD                ( I_ISAVld       ),
    .O_DatOE_PAD                 ( O_DatOE        ),
    .O_CmdVld_PAD                ( O_CmdVld       ),
    .IO_Dat_PAD                  ( IO_Dat         ),
    .IO_DatVld_PAD               ( IO_DatVld      ),
    .OI_DatRdy_PAD               ( OI_DatRdy      )
);

endmodule