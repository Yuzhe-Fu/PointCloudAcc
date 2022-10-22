set period_clk $PERIOD
# set period_sck $PERIOD

create_clock -period $period_clk -add -name clock_clk -waveform [list 0 [expr $period_clk*0.5]] [get_ports I_SysClk]
# create_clock -period $period_sck -add -name clock_sck -waveform [list 0 [expr $period_sck*0.5]] [get_ports O_spi_sck_PAD_rd0/DI]

set_clock_uncertainty -setup 0.3  [get_ports I_SysClk]
set_clock_uncertainty -hold  0.15 [get_ports I_SysClk]

# set_clock_uncertainty -setup 0.4  [get_pins O_spi_sck_PAD_rd0/DI]
# set_clock_uncertainty -hold  0.15 [get_pins O_spi_sck_PAD_rd0/DI]


# set_false_path -from [get_clocks clock_clk] -to [get_clocks clock_sck]
# set_false_path -from [get_clocks clock_sck] -to [get_clocks clock_clk]

set_false_path -from [list \
  [get_ports I_SysRst_n] \
  [get_ports I_BypAsysnFIFO]  \
  [get_ports I_StartPulse]  \
    ] 

# set_input_delay  -clock clock_sck -clock_fall -add_delay [expr 0.0*$period_sck] [get_pins IO_spi_data_PAD_rd0_GEN*/DI]
# set_output_delay -clock clock_sck -clock_fall -add_delay [expr 0.2*$period_sck] [get_pins IO_spi_data_PAD_rd0_GEN*/DO]
set_input_delay  -clock clock_clk -clock_fall -add_delay [expr 0.0*$period_clk] [get_ports IO_Dat*]
set_input_delay  -clock clock_clk -clock_fall -add_delay [expr 0.0*$period_clk] [get_ports OI_DatRdy]

set_output_delay -clock clock_clk -clock_fall -add_delay [expr 0.2*$period_clk] [get_ports IO_Dat*]
set_output_delay -clock clock_clk -clock_fall -add_delay [expr 0.2*$period_clk] [get_ports OI_DatRdy]

set_output_delay -clock clock_clk -clock_fall -add_delay [expr 0.2*$period_clk] [get_ports O_DatOE]
set_output_delay -clock clock_clk -clock_fall -add_delay [expr 0.2*$period_clk] [get_ports O_NetFnh]


# set_input_delay -clock clock_sck -clock_fall -add_delay [expr 0.0*$period_sck] [get_pins OE_req_PAD_rd0/DI]
# set_max_delay 8 -from [get_ports I_OE_req] -to [get_ports IO*]

# set_input_delay -clock clock_sck -clock_fall -add_delay [expr 0.0*$period_sck] [get_pins O_spi_cs_n_PAD_rd0/DI]

set_input_transition -min 0.05 [filter_collection [all_inputs] "full_name !~I_SysClk && full_name !~I_SysRst_n "]
set_input_transition -max 0.5  [filter_collection [all_inputs] "full_name !~I_SysClk && full_name !~I_SysRst_n "]
set_input_transition -min 0.05 [get_ports IO*]
set_input_transition -max 0.5  [get_ports IO*]

#set_driving_cell -library u055lscspmvbdr_108c125_wc -lib_cell BUFM4TM -pin Z [all_inputs]
#set_load [expr 8 * [load_of u055lsclpmvbdr_108c125_wc/BUFM4TM/A]] [all_outputs]
set_load -pin_load -max 1 [all_outputs]

set_max_transition 0.5 ${TOP_MODULE}
set_max_fanout 32 ${TOP_MODULE}

