// This is a simple example.
// You can make a your own header file and set its path to settings.
// (Preferences > Package Settings > Verilog Gadget > Settings - User)
//
//      "header": "Packages/Verilog Gadget/template/verilog_header.v"
//
// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : zhouchch@pku.edu.cn
// File   : CCU.v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------
module PSS #(
    parameter SORT_LEN_WIDTH  = 5                 ,
    parameter IDX_WIDTH       = 10                ,
    parameter DIST_WIDTH      = 17                ,
    parameter NUM_SORT_CORE   = 8                 ,
    parameter SRAM_WIDTH      = 256                 

    )(
    input                                   clk,
    input                                   rst_n,
    input                                   CTRPSS_LopLast  ,
    input                                   CTRPSS_Rst      ,
    input   [IDX_WIDTH              -1 : 0] CTRPSS_Mask     ,
    input                                   CTRPSS_MaskVld  ,
    output                                  PSSCTR_MaskRdy  ,
    input   [IDX_WIDTH              -1 : 0] CTRPSS_CpIdx    ,
    // input   CTRPSS_CpIdxVld
    // output  PSSCTR_CpIdxRdy
    input   [IDX_WIDTH+DIST_WIDTH   -1 : 0] CTRPSS_Lop      ,  
    input                                   CTRPSS_LopVld   ,  
    output                                  PSSCTR_LopRdy   ,  
    output  [SRAM_WIDTH             -1 : 0] PSSCTR_Idx      , 
    output                                  PSSCTR_IdxVld   , 
    input                                   PSSCTR_IdxRdy    
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam SORT_LEN        = 2**SORT_LEN_WIDTH;
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [NUM_SORT_CORE         -1 : 0] INS_LopRdy;
reg  [$clog2(NUM_SORT_CORE)    : 0] addr;
reg  [2**IDX_WIDTH          -1 : 0] Mask_Array[0 : NUM_SORT_CORE-1];



wire [SRAM_WIDTH*NUM_SORT_CORE-1 : 0] PSSMap;
wire [NUM_SORT_CORE           -1 : 0] INSPSS_IdxVld;
wire [NUM_SORT_CORE           -1 : 0] PSSINS_IdxRdy;
wire [(IDX_WIDTH*SORT_LEN)*NUM_SORT_CORE-1 : 0] INSPSS_Idx;
wire                                  PISO_IN_RDY;
//=====================================================================================================================
// Logic Design 2: HandShake
//=====================================================================================================================


//=====================================================================================================================
// Logic Design 1: INSPSS_Idx
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if (CTRPSS_MaskVld & PSSCTR_MaskRdy) begin
        Mask_Array[addr] <= CTRPSS_Mask;
        addr <= addr + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        addr <= 0;
    end else if (CTRPSS_Rst) begin
        addr <= 0;
    end else if (CTRPSS_MaskVld & PSSCTR_MaskRdy) begin
        addr <= addr + 1;
    end
end

assign PSSCTR_MaskRdy = !addr[$clog2(NUM_SORT_CORE)];



//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================
genvar i;
generate
    for(i=0; i<NUM_SORT_CORE; i=i+1) begin
        wire                    PSSINS_LopVld;
        INS#(
            .SORT_LEN_WIDTH   ( SORT_LEN_WIDTH ),
            .IDX_WIDTH       ( IDX_WIDTH ),
            .DIST_WIDTH      ( DIST_WIDTH )
        )u_INS(
            .clk                 ( clk                 ),
            .rst_n               ( rst_n               ),
            .PSSINS_LopLast      ( CTRPSS_LopLast      ),
            .PSSINS_Lop          ( CTRPSS_Lop          ),
            .PSSINS_LopVld       ( PSSINS_LopVld       ),
            .PSSINS_LopRdy       ( INS_LopRdy[i]       ),
            .INSPSS_Idx          ( INSPSS_Idx[(IDX_WIDTH*SORT_LEN)*i +: (IDX_WIDTH*SORT_LEN)]),
            .INSPSS_IdxVld       ( INSPSS_IdxVld[i]       ),
            .PSSINS_IdxRdy       ( PSSINS_IdxRdy[i]       )
        );

        assign PSSINS_LopVld = Mask_Array[i][CTRPSS_Lop[IDX_WIDTH+DIST_WIDTH -1 -: IDX_WIDTH]];
        assign PSSMap[SRAM_WIDTH*i +: SRAM_WIDTH] = {54'd0, {CTRPSS_CpIdx, INSPSS_Idx[(IDX_WIDTH*SORT_LEN)*i +: (IDX_WIDTH*SORT_LEN)]}};
        
    end
endgenerate

assign PSSCTR_LopRdy = & INS_LopRdy;

assign PSSINS_IdxRdy = {NUM_SORT_CORE{PISO_IN_RDY}};

PISO#(
    .DATA_IN_WIDTH   ( SRAM_WIDTH*NUM_SORT_CORE  ), // (32+1)*10 /96 = 330 /96 <= 4
    .DATA_OUT_WIDTH  ( SRAM_WIDTH  )
)U_PISO(
    .CLK       ( clk            ),
    .RST_N     ( rst_n          ),
    .IN_VLD    ( &INSPSS_IdxVld ),
    .IN_LAST   ( 1'b0           ),
    .IN_DAT    ( PSSMap         ),
    .IN_RDY    ( PISO_IN_RDY  ),
    .OUT_DAT   ( PSSCTR_Idx     ),
    .OUT_VLD   ( PSSCTR_IdxVld  ),
    .OUT_LAST  (                ),
    .OUT_RDY   ( PSSCTR_IdxRdy  )
);

endmodule
