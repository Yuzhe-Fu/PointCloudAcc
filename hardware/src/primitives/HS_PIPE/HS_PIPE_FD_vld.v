// 复旦打拍系列，
// 对valid进行打拍，但ready不打拍，有许多人质疑，建议用深度2的FIFO都打拍
// 参考https://zhuanlan.zhihu.com/p/212338948 ((AXI)握手协议（pvld/prdy或者valid-ready）中Valid及data打拍技巧)

module valid_flop
        (
        CLK                                                                     ,
        RESET                                                                   ,
        VALID_UP                                                                ,
        READY_UP                                                                ,
        DATA_UP                                                                 ,
        VALID_DOWN                                                              ,
        READY_DOWN                                                              ,
        DATA_DOWN
        );

//-----------------------------------------------------------------------------
parameter WIDTH            = 32                                                 ;

//-----------------------------------------------------------------------------
input                      CLK                                                  ;
input                      RESET                                                ;
input                      VALID_UP                                             ;
output                     READY_UP                                             ;
input  [WIDTH-1:0]         DATA_UP                                              ;
output                     VALID_DOWN                                           ;
input                      READY_DOWN                                           ;
output [WIDTH-1:0]         DATA_DOWN                                            ;

//-----------------------------------------------------------------------------
wire                       CLK                                                  ;
wire                       RESET                                                ;
wire                       VALID_UP                                             ;
wire                       READY_UP                                             ;
wire   [WIDTH-1:0]         DATA_UP                                              ;
//Down Stream
reg                        VALID_DOWN                                           ;
wire                       READY_DOWN                                           ;
reg    [WIDTH-1:0]         DATA_DOWN                                            ;

//-----------------------------------------------------------------------------
//Valid
always @(posedge CLK)
if (RESET)  VALID_DOWN <= 1'b0                                                  ;
else        VALID_DOWN <= READY_UP ? VALID_UP : VALID_DOWN                      ;
//Data
always @(posedge CLK)
if (RESET)  DATA_DOWN <= {WIDTH{1'b0}}                                          ;
else        DATA_DOWN <= (READY_UP && VALID_UP) ? DATA_UP : DATA_DOWN           ;
//READY with buble collapsing.
assign READY_UP = READY_DOWN || ~VALID_DOWN                                     ;
//READY with no buble collapsing.
//assign READY_UP = READY_DOWN                                                  ;

endmodule