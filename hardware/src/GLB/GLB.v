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
`include "../source/include/dw_params_presim.vh"
module GLB #(
    parameter NUM_PEB         = 16,
    parameter FIFO_ADDR_WIDTH = 6  
    )(
    input                               clk                     ,
    input                               rst_n                   ,

    // Configure
input   CCUGLB_CfgPort_BankIdx
input  CCUGLB_CfgSA_Mod
output GLBCCU_Bank_fnh 
output CCUGLB_Bank_rst 
input  ITFGLB_Dat      
input  ITFGLB_DatVld   
output GLBITF_DatRdy   
output GLBITF_Dat      
output GLBITF_DatVld   
input  ITFGLB_DatRdy   
output GLBSYA_Act      
output GLBSYA_ActVld   
input  SYAGLB_ActRdy   
output GLBSYA_Wgt      
output GLBSYA_WgtVld   
input  SYAGLB_WgtRdy   
input  SYAGLB_Fm       
input  SYAGLB_FmVld    
output GLBSYA_FmRdy    
output GLBPOL_Fm       
output GLBPOL_FmVld    
input  POLGLB_FmRdy    
input  POLGLB_Fm       
input  POLGLB_FmVld    
output GLBPOL_FmRdy    

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE    = 3'b000;
localparam CFG     = 3'b001;
localparam CMP     = 3'b010;
localparam STOP    = 3'b011;
localparam WAITGBF = 3'b100;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                                start_cmp                       ;
wire [ 6                    -1 : 0] MEM_CCUGB_block[0 : NUM_PEB -1 ];
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE : if( ASICCCU_start)
                    next_state <= CFG; //A network config a time
                else
                    next_state <= IDLE;
        CFG: if( fifo_full)
                    next_state <= CMP;
                else
                    next_state <= CFG;
        CMP: if( all_finish) /// CMP_FRM CMP_PAT CMP_...
                    next_state <= IDLE;
                else
                    next_state <= CMP;
        default: next_state <= IDLE;
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
// Logic Design 2: Addr Gen.
//=====================================================================================================================

wire [ADDR_WIDTH                -1: 0] WrPortAddr_Array[0: NUM_WRPORT -1];
wire [ADDR_WIDTH                -1: 0] RdPortAddr_Array[0: NUM_RDPORT -1];
wire [1                         -1: 0] WrPortEn_Array[0  : NUM_WRPORT -1];
wire [1                         -1: 0] RdPortEn_Array[0  : NUM_RDPORT -1];
wire [`C_LOG_2(NUM_RDPORT)      -1: 0] BankRdPort[0      : NUM_BANK -1];
wire [`C_LOG_2(NUM_WRPORT)      -1: 0] BankWrPort[0      : NUM_BANK -1];
wire [SRAM_WIDTH*MAXPAR      -1: 0] RdPortDat_Array[0      : NUM_RDPORT -1];
wire [SRAM_WIDTH*MAXPAR      -1: 0] WrPortDat_Array[0      : NUM_WRPORT -1];


for(j=0; j)
wire [`C_LOG_2(NUM_BANK)    -1 : 0] Rel_BankIdx [0: NUM_BANK -1];
//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

genvar i;
generate
    for(i=0; i<NUM_BANK; i=i+1) begin: GEN_BANK
        RAM#(
                .SRAM_BIT     ( 128 ),
                .SRAM_BYTE    ( 1 ),
                .SRAM_WORD    ( 64 ),
                .CLOCK_PERIOD ( 10 )
            )U_RAM(
                .clk          ( clk          ),
                .rst_n        ( rst_n        ),
                .addr_r       ( addr_r       ),
                .addr_w       ( addr_w       ),
                .read_en      ( read_en      ),
                .write_en     ( write_en     ),
                .data_in      ( data_in      ),
                .data_out     ( data_out     )
            );

        assign RdAloc = ( (RdPortAddr_Array[BankRdPort[i]] >> SRAM_DEPTH_WIDTH )*RdPortParBank[BankRdPort[i]] == Rel_BankIdx[i]);
        assign read_en  = RdPortEn_Array[BankRdPort[i]] & RdAloc ;     
        assign addr_r   = RdPortAddr_Array[BankRdPort[i]]          ;



        assign WrAloc = ( (WrPortAddr_Array[BankRdPort[i]] >> SRAM_DEPTH_WIDTH )*WrPortParBank[BankRdPort[i]] == Rel_BankIdx[i]);
        assign write_en = !read_en & WrPortEn_Array[BankWrPort[i]] & WrAloc ;
        assign addr_w   = WrPortAddr_Array[BankWrPort[i]]          ;

        assign ParIdx  = WrPortNumBank[BankRdPort[i]] % WrPortParBank[BankRdPort[i]];
        assign data_in = WrPortDat_Array[BankRdPort[i]][SRAM_WIDTH*ParIdx +: SRAM_WIDTH];

    end
endgenerate

genvar j, k;
generate
    for(j=0; j<NUM_RDPORT; j=j+1) begin
        always @() begin
            for(k=0; k<RdPortNumBank[j]; k=k+1)
                if (GEN_BANK[RdPortBank[k]].read_en_d)
                    RdPortDat_Array[j][SRAM_WIDTH*k +: SRAM_WIDTH] = GEN_BANK[RdPortBank[k]].data_out;
        end
endgenerate




endmodule
