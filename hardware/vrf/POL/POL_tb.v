`timescale  1 ns / 100 ps

module POL_tb();
parameter IDX_WIDTH             = 10                                                    ;
parameter ACT_WIDTH             = 8                                                     ;
parameter POOL_COMP_CORE        = 64                                                    ;
parameter POOL_MAP_DEPTH_WIDTH  = 5                                                     ;
parameter POOL_CORE             = 6                                                     ;
parameter CHN_WIDTH             = 12                                                    ;
parameter SRAM_WIDTH            = 256                                                   ;
  
// POL Inputs
reg   clk                                  = 1 ;
reg   rst_n                                = 1 ;
reg   CCUPOL_Rst                           = 0 ;
reg   CCUPOL_CfgVld                        = 1 ;
reg   [POOL_MAP_DEPTH_WIDTH                    -1 : 0]  CCUPOL_CfgK = 24 ;
reg   [IDX_WIDTH                               -1 : 0]  CCUPOL_CfgNip = 512 ;
reg   [CHN_WIDTH                               -1 : 0]  CCUPOL_CfgChi = 64 ;
reg   GLBPOL_MapVld                        = 1 ;
reg   [SRAM_WIDTH                              -1 : 0]  GLBPOL_Map = 0 ;
reg   [POOL_CORE                               -1 : 0]  GLBPOL_AddrRdy = 1 ;
reg   [(ACT_WIDTH*POOL_COMP_CORE)*POOL_CORE    -1 : 0]  GLBPOL_Ofm = 1 ;
reg   [POOL_CORE                               -1 : 0]  GLBPOL_OfmVld = 1 ;
reg   GLBPOL_OfmRdy                        = 0 ;

// POL Outputs
wire  POLCCU_CfgRdy                        ;
wire  POLGLB_MapRdy                        ;
wire  [POOL_CORE                               -1 : 0]  POLGLB_AddrVld ;
wire  [IDX_WIDTH*POOL_CORE                     -1 : 0]  POLGLB_Addr ;
wire  [POOL_CORE                               -1 : 0]  POLGLB_OfmRdy ;
wire  [ACT_WIDTH*POOL_COMP_CORE                -1 : 0]  POLGLB_Ofm;
wire  POLGLB_OfmVld                        ;

// POL Bidirs



initial
begin
    //$shm_open ("db_name", is_sequence_time, db_size, is_compression, incsize,incfiles);
    $shm_open ("dump.shm");
    $shm_probe( "AC");
end

initial
begin
    clk= 1;
    forever #10  clk=~clk;
end

initial
begin
    rst_n  =  1;
    #25  rst_n  =  0;
    #100 rst_n  =  1;
end

POL #(
    .IDX_WIDTH            ( 10                                                     ),
    .ACT_WIDTH            ( 8                                                      ),
    .POOL_COMP_CORE       ( 64                                                     ),
    .POOL_MAP_DEPTH_WIDTH ( 5                                                      ),
    .POOL_CORE            ( 6                                                      ),
    .CHN_WIDTH            ( 12                                                     ),
    .SRAM_WIDTH           ( 256                                                    )
)

 u_POL (
    .clk                            ( clk                                                                             ),
    .rst_n                          ( rst_n                                                                           ),
    .CCUPOL_Rst                     ( CCUPOL_Rst                                                                      ),
    .CCUPOL_CfgVld                  ( CCUPOL_CfgVld                                                                   ),
    .CCUPOL_CfgK                    ( CCUPOL_CfgK                     ),
    .CCUPOL_CfgNip                  ( CCUPOL_CfgNip                  ),
    .CCUPOL_CfgChi                  ( CCUPOL_CfgChi                  ),
    .GLBPOL_MapVld                  ( GLBPOL_MapVld                                                                   ),
    .GLBPOL_Map                     ( GLBPOL_Map                     ),
    .GLBPOL_AddrRdy                 ( GLBPOL_AddrRdy                ),
    .GLBPOL_Ofm                     ( GLBPOL_Ofm                   ),
    .GLBPOL_OfmVld                  ( GLBPOL_OfmVld                 ),
    .GLBPOL_OfmRdy                  ( GLBPOL_OfmRdy                                                                   ),

    .POLCCU_CfgRdy                  ( POLCCU_CfgRdy                                                                   ),
    .POLGLB_MapRdy                  ( POLGLB_MapRdy                                                                   ),
    .POLGLB_AddrVld                 ( POLGLB_AddrVld                ),
    .POLGLB_Addr                    ( POLGLB_Addr                  ),
    .POLGLB_OfmRdy                  ( POLGLB_OfmRdy                  ),
    .POLGLB_Ofm                     ( POLGLB_Ofm                    ),
    .POLGLB_OfmVld                  ( POLGLB_OfmVld                                                                   )
);
endmodule