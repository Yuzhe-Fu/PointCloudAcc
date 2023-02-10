module FMC #( // Data Path: PC <--> DDR <--> FMC <--> CHIP
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 128
)(
    input                       clk,
    input                       rst_n,

    input [ADDR_WIDTH   -1 : 0] CHIPFMC_Addr, // Shared Address by Read and Write

    output[DATA_WIDTH   -1 : 0] FMCCHIP_RdDat, // Chip Reads DDR
    output                      FMCCHIP_RdDatVld,
    input                       CHIPFMC_RdDatRdy,

    input [DATA_WIDTH   -1 : 0] CHIPFMC_WrDat, // Chip Writes DDR
    input                       CHIPFMC_WrDatVld,
    output                      FMCCHIP_WrDatRdy    
);

endmodule