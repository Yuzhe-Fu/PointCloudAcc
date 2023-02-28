// 数据通路是: PC <--> FPGA（含DDR） <--> CHIP
// FPGA与CHIP的接口为简化版的AHB协议，CHIP为主机MASTER，有NUM_PORT组接口
module FPGA #( 
    parameter ADDR_WIDTH = 32   ,
    parameter DATA_WIDTH = 512  ,
    parameter NUM_PORT   = 2    
)(
    output                                          FPGACHIP_CLK    ,   // 给CHIP的时钟信号
	output                                          FPGACHIP_START  ,   // 给CHIP的脉冲启动信号
	input                                           CHIPFPGA_FINISH ,   // CHIP完成计算的信号

    // CHIP给FPGA的读写共享地址
    input   [NUM_PORT -1 : 0][ADDR_WIDTH    -1 : 0] CHIPFPGA_HADDR  ,
    input   [NUM_PORT -1 : 0]                       CHIPFPGA_HWRITE , 
    input   [NUM_PORT -1 : 0][2             -1 : 0] CHIPFPGA_HSIZE  , 
    input   [NUM_PORT -1 : 0][2             -1 : 0] CHIPFPGA_HBURST , 
    input   [NUM_PORT -1 : 0][3             -1 : 0] CHIPFPGA_HPORT  , 
    input   [NUM_PORT -1 : 0]                       CHIPFPGA_HMASTERLOCK, 
    input   [NUM_PORT -1 : 0][2             -1 : 0] CHIPFPGA_HTRANS , 
    input   [NUM_PORT -1 : 0][DATA_WIDTH    -1 : 0] CHIPFPGA_HWDATA ,   // CHIP WRITE DATA

    output  [NUM_PORT                       -1 : 0] FPGACHIP_HREADY ,
    output  [NUM_PORT                       -1 : 0] FPGACHIP_HRESP  ,
    output  [NUM_PORT -1 : 0][DATA_WIDTH    -1 : 0] FPGACHIP_HDATA      // CHIP READ DATA

);

endmodule