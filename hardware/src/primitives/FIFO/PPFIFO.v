module PPFIFO(
    parameter DEPTH = 64;
    parameter DATAWIDTH = 128;


)(
    //----------INPUT/OUTPUT--------------
    input                           clk;
    input                           rst_n;
    input                           rd_en;
    input                           wr_en;
    input [DATAWIDTH/8-1:0] wr_be;

    output reg rd_rdy;
    output reg wr_rdy;
    output reg rd_vld;

    output reg [DATAWIDTH-1:0] rdata;
    input [ADDRWIDTH-1:0] raddr;
    input [DATAWIDTH-1:0] wdata;
    input [ADDRWIDTH-1:0] waddr;
);

localparam ADDRWIDTH = clogb2(DEPTH-1);
localparam IDLE = 4'b0001;
localparam WRAM1 = 4'b0010;
localparam WRAM2_RRAM1 = 4'b0100;
localparam WRAM1_RRAM2 = 4'b1000;

//---------------reg definitions----------------//
wire [DATAWIDTH-1:0] rdata1;
reg cen1;
reg [DATAWIDTH/8-1:0] wen1;
reg [ADDRWIDTH-1:0] addr1;
reg [DATAWIDTH-1:0] wdata1;

wire [DATAWIDTH-1:0] rdata2;
reg cen2;
reg [DATAWIDTH/8-1:0] wen2;
reg [ADDRWIDTH-1:0] addr2;
reg [DATAWIDTH-1:0] wdata2;

reg [3:0] state,next_state;
reg rd_vld_r;
reg [3:0] state_r;
reg wr_en_r;
//---------------FSM-----------------------//
always@(*)begin
    case(state)
        IDLE:begin
            if(wr_en == 1'b1)
                next_state = WRAM1;
            else
                next_state = IDLE;
        end
        WRAM1:begin
            if(addr1 == {(ADDRWIDTH){1'b1}})
                next_state = WRAM2_RRAM1;
            else
                next_state = WRAM1;
        end
        WRAM2_RRAM1:begin
            if((addr1 == {(ADDRWIDTH){1'b1}}) && (addr2 == {(ADDRWIDTH){1'b1}}) && wr_en_r)
                next_state = WRAM1_RRAM2;
            else
                next_state = WRAM2_RRAM1;                
        end
        WRAM1_RRAM2:begin
            if((addr1 == {(ADDRWIDTH){1'b1}}) && (addr2 == {(ADDRWIDTH){1'b1}}) && wr_en_r)
                next_state = WRAM2_RRAM1;
            else
                next_state = WRAM1_RRAM2;            
        end
        default:next_state = IDLE;
    endcase
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        state <= IDLE;
    else begin
        state <= next_state; 
end

//rdata
always@(*)begin
    if(state_r == WRAM2_RRAM1) begin
        rdata = rdata1;
    end
    else if(state_r == WRAM1_RRAM2) begin
        rdata = rdata2;
    end
end
//RAM1 wr_be 

//RAM2 wr_be 

//RAM1 cen waddr wdata

//RAM1 cen waddr wdata

//---------------sub module----------------//
sp_mem#(.DEPTH(DEPTH), .DATAWIDTH(DATAWIDTH))
u_sram0(
.Q(rdata1),
.CLK(clk),
.CEN(cen1),
.WEN(wen1),
.A(addr1),
.D(wdata1)
);

RAM#(
    .SRAM_BIT     ( DATAWIDTH ),
    .SRAM_BYTE    ( 1 ),
    .SRAM_WORD    ( DEPTH )
)u_RAM(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .addr_r       ( addr1       ),
    .addr_w       ( addr1       ),
    .read_en      ( read_en      ),
    .write_en     ( wen1     ),
    .data_in      ( wdata1      ),
    .data_out     ( rdata1     )
);


sp_mem#(.DEPTH(DEPTH), .DATAWIDTH(DATAWIDTH))
u_sram1(
.Q(rdata2),
.CLK(clk),
.CEN(cen2),
.WEN(wen2),
.A(addr2),
.D(wdata2)
);

function integer clogb2 (input integer depth);
    integer depth_t;
    begin
        depth_t = depth;
            for(clogb2 = 0; depth_t>0; clogb2 = clogb2+1)
                depth_t = depth_t >>1;
    end
endfunction

endmodule