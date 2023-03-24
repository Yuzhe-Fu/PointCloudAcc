`timescale  1 ns / 100 ps

`define CLOCK_PERIOD 10
`define SIM
`define FUNC_SIM
`define PSEUDO_DATA
`define ASSERTION_ON

module TOP_tb();
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
parameter PORT_WIDTH        = 128;
parameter ADDR_WIDTH        = 16;
parameter DRAM_ADDR_WIDTH   = 32;
parameter OPNUM = 27;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
// TOP Inputs
reg                             I_StartPulse  ;
reg                             I_BypAsysnFIFO;

// TOP Outputs
wire                            O_DatOE;
wire                            O_CmdVld;
wire                            O_NetFnh;

// TOP Bidirs
wire  [PORT_WIDTH       -1 : 0] IO_Dat;
wire                            IO_DatVld ;
wire                            OI_DatRdy ;

reg                             rst_n ;
reg                             clk   ;
reg [PORT_WIDTH         -1 : 0] Dram[0 : 2**18-1];
reg [DRAM_ADDR_WIDTH    -1 : 0] addr;
reg [DRAM_ADDR_WIDTH    -1 : 0] BaseAddr;
reg [ADDR_WIDTH         -1 : 0] ReqNum;

wire [$clog2(OPNUM)     -1 : 0] ArbCfgRdyIdx;
reg  [$clog2(OPNUM)     -1 : 0] ArbCfgRdyIdx_d;
wire [OPNUM -1 : 0][ADDR_WIDTH      -1 : 0] CntMduISARdAddr;
reg  [OPNUM -1 : 0][DRAM_ADDR_WIDTH -1 : 0] MDUISABASEADDR;
wire [OPNUM             -1 : 0] O_CfgRdy;
wire                            I_ISAVld;
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
    rst_n           =  1;
    I_StartPulse    = 0;
    I_BypAsysnFIFO  = 1;
    #(`CLOCK_PERIOD*2)  rst_n  =  0;
    #(`CLOCK_PERIOD*10) rst_n  =  1;
    #(`CLOCK_PERIOD*2)  I_StartPulse = 1;
    #(`CLOCK_PERIOD*10) I_StartPulse = 0;
end

initial begin
    $readmemh("Dram.txt", Dram);
end

initial begin
    $shm_open("TEMPLATE.shm");
    $shm_probe(TOP_tb, "AS");
end


//=====================================================================================================================
// Logic Design 1: FSM=ITF
//=====================================================================================================================
localparam IDLE     = 3'b000;
localparam FET      = 3'b001;
localparam CMD      = 3'b010;
localparam IN2CHIP  = 3'b011;
localparam OUT2OFF  = 3'b100;


reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if ( |O_CfgRdy )
                    next_state <= FET;
                else if( O_CmdVld )
                    next_state <= CMD;
                else
                    next_state <= IDLE;
        // ISA
        FET:    if( !O_CfgRdy[ArbCfgRdyIdx_d] )
                    next_state <= IDLE;
                else
                    next_state <= FET;
        // Data
        CMD :   if( O_DatOE & IO_DatVld & OI_DatRdy) begin
                    if ( IO_Dat[0] ) // 
                        next_state <= OUT2OFF;
                    else
                        next_state <= IN2CHIP;
                end else
                    next_state <= CMD;
        IN2CHIP:   if( O_CmdVld )
                    next_state <= IDLE;
                else
                    next_state <= IN2CHIP;
        OUT2OFF:   if( O_CmdVld )
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
MDUISABASEADDR[4] <= 21;
MDUISABASEADDR[5] <= 26;
MDUISABASEADDR[6] <= 27;

end

prior_arb#(
    .REQ_WIDTH ( OPNUM )
)u_prior_arb_ArbCfgRdyIdx(
    .req ( O_CfgRdy             ),
    .gnt (                      ),
    .arb_port  ( ArbCfgRdyIdx   )
);

genvar gv_i;
generate
    for(gv_i = 0; gv_i < OPNUM; gv_i = gv_i + 1) begin: GEN_CntMduISARdAddr
        wire [ADDR_WIDTH     -1 : 0] MaxCnt = 2**ADDR_WIDTH -1;
        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_CntMduISARdAddr(
            .CLK       ( clk            ),
            .RESET_N   ( rst_n          ),
            .CLEAR     ( 1'b0           ),
            .DEFAULT   ( {ADDR_WIDTH{1'b0}}),
            .INC       ( I_ISAVld & (IO_DatVld & OI_DatRdy) & (ArbCfgRdyIdx_d == gv_i) ),
            .DEC       ( 1'b0           ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
            .MAX_COUNT ( MaxCnt         ),
            .OVERFLOW  (                ),
            .UNDERFLOW (                ),
            .COUNT     ( CntMduISARdAddr[gv_i])
        );
    end
endgenerate

assign I_ISAVld = state == FET;
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
always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        addr <= 0;
    end else if(state == IDLE) begin
        addr <= 0;
    end else if(state==CMD & (next_state == IN2CHIP | next_state == OUT2OFF)) begin
        addr <= IO_Dat[1 +: DRAM_ADDR_WIDTH];
    end else if ( (state == IN2CHIP | state == OUT2OFF) & IO_DatVld & OI_DatRdy) begin
        addr <= addr + 1;
    end
end
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
assign IO_DatVld  = I_ISAVld? 1'b1 : (O_DatOE? 1'bz : state== IN2CHIP);
assign IO_Dat     = I_ISAVld? Dram[MDUISABASEADDR[ArbCfgRdyIdx_d] + CntMduISARdAddr[ArbCfgRdyIdx_d]] : (O_DatOE? {PORT_WIDTH{1'bz}} : Dram[addr]);

// DRAM WRITE
assign OI_DatRdy = I_ISAVld? 1'bz : (O_DatOE? O_CmdVld & state==CMD | !O_CmdVld & state==OUT2OFF: 1'bz);

TOP #(
    .PORT_WIDTH  (PORT_WIDTH)
)
    u_TOP (
    .I_SysRst_n              ( rst_n          ),
    .I_SysClk                ( clk            ),
    .I_BypAsysnFIFO          ( I_BypAsysnFIFO ),
    .O_CfgRdy                ( O_CfgRdy       ),
    .I_ISAVld                ( I_ISAVld       ),
    .O_DatOE                 ( O_DatOE        ),
    .O_CmdVld                ( O_CmdVld       ),
    .IO_Dat                  ( IO_Dat         ),
    .IO_DatVld               ( IO_DatVld      ),
    .OI_DatRdy               ( OI_DatRdy      )
);

endmodule