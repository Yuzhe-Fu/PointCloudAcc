// 复旦打拍系列，
// 握手协议对ready打拍：无气泡，还有直通模式，但valid没打拍，经验证是对的

// 参考（AXI）握手协议（pvld/prdy或者valid-ready）中ready打拍技巧
// https://zhuanlan.zhihu.com/p/212356622---------------------------------------

`timescale 1ns/1ns
module ready_flop        
    (
    CLK,
    RESET,
    VALID_UP,
    READY_UP,
    DATA_UP,
    VALID_DOWN,
    READY_DOWN,
    DATA_DOWN
    );
//---------------------------------------
parameter WIDTH            = 32;
//---------------------------------------
input                      CLK;
input                      RESET;
//Up stream
input                      VALID_UP;
output                     READY_UP;
input  [0:WIDTH-1]         DATA_UP;
//Down Stream
output                     VALID_DOWN;
input                      READY_DOWN;
output [0:WIDTH-1]         DATA_DOWN;
//---------------------------------------
wire                       CLK;
wire                       RESET;
//Up stream
wire                       VALID_UP;
reg                        READY_UP;
wire   [0:WIDTH-1]         DATA_UP;
//Down Stream
wire                       VALID_DOWN;
wire                       READY_DOWN;
wire   [0:WIDTH-1]         DATA_DOWN;
wire                       store_data;
reg    [0:WIDTH-1]         buffered_data;
reg                        buffer_valid;
//---------------------------------------
//buffer.
assign store_data = VALID_UP && READY_UP && ~READY_DOWN;
always @(posedge CLK)
    if (RESET)  buffer_valid <= 1'b0;
    else        buffer_valid <= buffer_valid ? ~READY_DOWN: store_data;
//Note: If now buffer has data, then next valid would be ~READY_DOWN:   
//If downstream is ready, next cycle will be un-valid.    
//If downstream is not ready, keeping high. 
// If now buffer has no data, then next valid would be store_data, 1 for store;
always @(posedge CLK)
    if (RESET)  buffered_data <= {WIDTH{1'b0}};
    else        buffered_data <= store_data ? DATA_UP : buffered_data;

always @(posedge CLK) begin
    if (RESET)  READY_UP <= 1'b1; //Reset can be 1.
    else        READY_UP <= READY_DOWN || ((~buffer_valid) && (~store_data)); //Bubule clampping
    end
//Downstream valid and data.
//Bypass
assign VALID_DOWN = READY_UP? VALID_UP : buffer_valid;
assign DATA_DOWN  = READY_UP? DATA_UP  : buffered_data;

endmodule