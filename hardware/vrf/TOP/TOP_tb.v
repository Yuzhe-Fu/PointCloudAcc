`timescale  1 ns / 100 ps

module TOP_tb();
parameter PORT_WIDTH       = 128                                                     ;

// TOP Inputs
reg   I_SysRst_n                           = 0 ;
reg   I_SysClk                             = 0 ;
reg   I_StartPulse                         = 0 ;
reg   I_BypAsysnFIFO                       = 0 ;

// TOP Outputs
wire  O_DatOE                              ;

// TOP Bidirs
wire  [PORT_WIDTH     -1 : 0]  IO_Dat      ;
wire  IO_DatVld                            ;
wire  IO_DatLast                           ;
wire  OI_DatRdy                            ;


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
    reset_b  =  1;
    #25  reset_b  =  0;
    #100 reset_b  =  1;
end

TOP u_TOP (
    .I_SysRst_n              ( I_SysRst_n                              ),
    .I_SysClk                ( I_SysClk                                ),
    .I_StartPulse            ( I_StartPulse                            ),
    .I_BypAsysnFIFO          ( I_BypAsysnFIFO                          ),

    .O_DatOE                 ( O_DatOE                                 ),

    .IO_Dat                  ( IO_Dat           ),
    .IO_DatVld               ( IO_DatVld                               ),
    .IO_DatLast              ( IO_DatLast                              ),
    .OI_DatRdy               ( OI_DatRdy                               )
);


endmodule