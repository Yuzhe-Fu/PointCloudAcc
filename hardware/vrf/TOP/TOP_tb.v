`timescale  1 ns / 100 ps
`define SIM
`define FUNC_SIM
module TOP_tb();
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
parameter CLOCK_PERIOD   = 10;
parameter PORT_WIDTH      = 128;
parameter ADDR_WIDTH      = 16;
parameter DRAM_ADDR_WIDTH = 32;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
// TOP Inputs
reg                             I_StartPulse  ;
reg                             I_BypAsysnFIFO;

// TOP Outputs
wire                            O_DatOE;
wire                            O_NetFnh;

// TOP Bidirs
wire  [PORT_WIDTH       -1 : 0] IO_Dat;
wire                            IO_DatVld ;
wire                            IO_DatLast;
wire                            OI_DatRdy ;

reg                             rst_n ;
reg                             clk   ;
reg [PORT_WIDTH         -1 : 0] Dram[0 : 2**18-1];
reg [DRAM_ADDR_WIDTH    -1 : 0] addr;
reg [DRAM_ADDR_WIDTH    -1 : 0] BaseAddr;
reg [ADDR_WIDTH         -1 : 0] ReqNum;

//=====================================================================================================================
// Logic Design: Debounce
//=====================================================================================================================
initial
begin
    clk= 1;
    forever #(CLOCK_PERIOD/2)  clk=~clk;
end

initial
begin
    rst_n  =  1;
    I_StartPulse = 0;
    I_BypAsysnFIFO = 1;
    #(CLOCK_PERIOD*2)  rst_n  =  0;
    #(CLOCK_PERIOD*10) rst_n  =  1;
    #(CLOCK_PERIOD*2)  I_StartPulse = 1;
    #(CLOCK_PERIOD*10) I_StartPulse = 0;


end

initial begin
    $readmemh("Dram.txt", Dram);
end
//=====================================================================================================================
// Logic Design 1: FSM=ITF
//=====================================================================================================================
localparam IDLE = 3'b000;
localparam CMD  = 3'b001;
localparam IN   = 3'b010;
localparam OUT  = 3'b011;
localparam FNH  = 3'b100;

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if( 1'b1 )
                    next_state <= CMD;
                else
                    next_state <= IDLE;
        CMD :   if( IO_DatVld & OI_DatRdy) begin
                    if ( IO_Dat[0] )
                        next_state <= OUT;
                    else
                        next_state <= IN;
                end else
                    next_state <= CMD;
        IN:   if( IO_DatVld & IO_DatLast & OI_DatRdy )
                    next_state <= FNH;
                else
                    next_state <= IN;
        OUT:   if(IO_DatVld & IO_DatLast & OI_DatRdy )
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
// Logic Design 
//=====================================================================================================================

always @(posedge clk or rst_n) begin
    if (!rst_n) begin
        addr <= 0;
    end else if(state == FNH) begin
        addr <= 0;
    end else if(state==CMD && IO_DatVld & OI_DatRdy) begin
        addr <= IO_Dat[1 +: DRAM_ADDR_WIDTH];
        BaseAddr <= IO_Dat[1 +: DRAM_ADDR_WIDTH];
        ReqNum <= IO_Dat[1+DRAM_ADDR_WIDTH +: ADDR_WIDTH];
    end else if(state== IN | state == OUT) begin
        if(IO_DatVld & OI_DatRdy)
            addr <= addr + 1;
    end
end

// DRAM READ
assign IO_DatLast = O_DatOE? 1'bz : (addr == BaseAddr + ReqNum -1) && IO_DatVld;
assign IO_DatVld  = O_DatOE? 1'bz : state== IN;
assign IO_Dat = O_DatOE? {PORT_WIDTH{1'bz}} : Dram[addr];

// DRAM WRITE
assign OI_DatRdy = O_DatOE? state==CMD | state==OUT: 1'bz;

always @(posedge clk or rst_n) begin
    if(state == OUT) begin
        if(IO_DatVld & OI_DatRdy)
            Dram[addr] <= IO_Dat;
    end
end

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

TOP #(
    .CLOCK_PERIOD(CLOCK_PERIOD),
    .PORT_WIDTH  (PORT_WIDTH)
)
    u_TOP (
    .I_SysRst_n              ( rst_n     ),
    .I_SysClk                ( clk       ),
    .I_StartPulse            ( I_StartPulse   ),
    .I_BypAsysnFIFO          ( I_BypAsysnFIFO ),
    .O_DatOE                 ( O_DatOE        ),
    .IO_Dat                  ( IO_Dat         ),
    .IO_DatVld               ( IO_DatVld      ),
    .IO_DatLast              ( IO_DatLast     ),
    .OI_DatRdy               ( OI_DatRdy      ),
    .O_NetFnh                ( O_NetFnh       )
);


endmodule