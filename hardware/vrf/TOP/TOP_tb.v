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
parameter PORT_WIDTH        = 128;
parameter ADDR_WIDTH        = 16;
parameter DRAM_ADDR_WIDTH   = 32;
parameter OPNUM             = 6;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
// TOP Inputs
reg                             I_BypAsysnFIFO;
reg                             I_BypOE;
reg                             I_OffOE;

reg     I_SysClk;
reg     I_OffClk;

// TOP Outputs
wire                            O_DatOE;
wire                            O_CmdVld;

// TOP Bidirs
wire  [PORT_WIDTH       -1 : 0] IO_Dat;
wire                            O_DatVld ;
wire                            I_DatVld ;
wire                            I_DatRdy ;
wire                            O_DatRdy ;

reg                             rst_n ;

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
wire                            Overflow_DatAddr;

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
        wait (ArbCfgRdyIdx <= 5);
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
        CMD :   if( O_DatOE & O_DatVld & I_DatRdy) begin
                    if ( IO_Dat[0] ) // 
                        next_state <= OUT2OFF;
                    else
                        next_state <= IN2CHIP;
                end else
                    next_state <= CMD;
        IN2CHIP:   if( Overflow_DatAddr )
                    next_state <= IDLE;
                else
                    next_state <= IN2CHIP;
        OUT2OFF:   if( Overflow_DatAddr )
                    next_state <= IDLE;
                else
                    next_state <= OUT2OFF;
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
always @ ( posedge I_OffClk or negedge rst_n ) begin
MDUISABASEADDR[0] <= 1;
MDUISABASEADDR[1] <= 17;
MDUISABASEADDR[2] <= 19;
MDUISABASEADDR[3] <= 22;
MDUISABASEADDR[4] <= 28;

MDUISANUM[0]      <= 16;
MDUISANUM[1]      <= 2;
MDUISANUM[2]      <= 3;
MDUISANUM[3]      <= 9;
MDUISANUM[4]      <= 2;

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
            .CLK       ( I_OffClk            ),
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
        assign Overflow_ISA[gv_i] = MduISARdAddr[gv_i] - MduISARdAddr_r == MDUISANUM[ArbCfgRdyIdx_d];

    end
endgenerate

// wire [ADDR_WIDTH     -1 : 0] MaxCnt = MDUISANUM[ArbCfgRdyIdx_d];
// counter#(
//     .COUNT_WIDTH ( ADDR_WIDTH )
// )u_counter_CntISA(
//     .CLK       ( I_OffClk            ),
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
always @(posedge I_OffClk or rst_n) begin
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
// always @(posedge I_OffClk or rst_n) begin
//     if (!rst_n) begin
//         addr_r <= 0;
//     end else if(state==CMD & (next_state == IN2CHIP | next_state == OUT2OFF)) begin
//         addr_r <= IO_Dat[1 +: DRAM_ADDR_WIDTH];
//     end
// end

wire [DRAM_ADDR_WIDTH     -1 : 0] MaxAddr = IO_Dat[1 +: DRAM_ADDR_WIDTH] + IO_Dat[1 + DRAM_ADDR_WIDTH +: ADDR_WIDTH]; // ReqNum
counter#(
    .COUNT_WIDTH ( DRAM_ADDR_WIDTH )
)u_counter_addr(
    .CLK       ( I_OffClk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state==CMD & (next_state == IN2CHIP | next_state == OUT2OFF) ),
    .DEFAULT   ( IO_Dat[1 +: DRAM_ADDR_WIDTH]),
    .INC       ( (state == IN2CHIP | state == OUT2OFF) & (I_DatVld & O_DatRdy | O_DatVld & I_DatRdy) ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {DRAM_ADDR_WIDTH{1'b0}}),
    .MAX_COUNT ( MaxAddr        ),
    .OVERFLOW  ( Overflow_DatAddr  ),
    .UNDERFLOW (                ),
    .COUNT     ( addr           )
);

// assign Overflow_Data = addr - addr_r = 

`ifndef PSEUDO_DATA
    always @(posedge I_OffClk or rst_n) begin
        if(state == OUT2OFF) begin
            if(O_DatVld & I_DatRdy)
                Dram[addr] <= IO_Dat;
        end
    end
`endif

//=====================================================================================================================
// Logic Design : Interface
//=====================================================================================================================
// DRAM READ
assign #2 I_DatVld  = I_ISAVld? state == FET & next_state != WAITCFG : (O_DatOE? 1'bz : state== IN2CHIP);
assign    I_DatLast = I_DatVld & Overflow_DatAddr ;
assign #2 IO_Dat     = I_ISAVld? Dram[MduISARdAddr[ArbCfgRdyIdx_d]] : (O_DatOE? {PORT_WIDTH{1'bz}} : Dram[addr[0 +: 13]]); // 8196

wire [PORT_WIDTH    -1 : 0] TEST28 = Dram[28];


// DRAM WRITE
assign #2 I_DatRdy = I_ISAVld? 1'bz : (O_DatOE? O_CmdVld & state==CMD | !O_CmdVld & state==OUT2OFF: 1'bz);

TOP u_TOP (
    .I_BypAsysnFIFO_PAD ( I_BypAsysnFIFO     ),
    .I_BypOE_PAD        ( I_BypOE            ),
    .I_SysRst_n_PAD     ( rst_n              ),
    .I_SysClk_PAD       ( I_SysClk           ),
    .I_OffClk_PAD       ( I_OffClk           ),
    .O_CfgRdy_PAD       ( O_CfgRdy           ),
    .O_DatOE_PAD        ( O_DatOE            ),
    .I_OffOE_PAD        ( I_OffOE            ),
    .I_DatVld_PAD       ( I_DatVld           ),
    .I_DatLast_PAD      ( I_DatLast          ),
    .O_DatRdy_PAD       ( O_DatRdy           ),
    .O_DatVld_PAD       ( O_DatVld           ),
    .I_DatRdy_PAD       ( I_DatRdy           ),
    .I_ISAVld_PAD       ( I_ISAVld           ),
    .O_CmdVld_PAD       ( O_CmdVld           ),
    .IO_Dat_PAD         ( IO_Dat             ) 
);

endmodule