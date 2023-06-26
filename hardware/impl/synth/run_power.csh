
set SYNTH_PROJDIR = "../../work/synth/TOP/Date230417_Period10_group_Track3vt_NoteWoPAD&RTSEL10"
set TCF_DUMP_NAME = "tcf_period20_4.5us_KNN.dump"

set NOTE = ${TCF_DUMP_NAME}_report
set TCF_DUMP = ${SYNTH_PROJDIR}/report/${TCF_DUMP_NAME}
set DESIGN_NAME = "TOP"
set clk = "I_SysClk_PAD"
set TECH_SETTING="tech_settings.tcl"
set TCF_INST = "u_TOP"
################################################################################
rm ./config_temp.tcl

echo "set DESIGN_NAME $DESIGN_NAME"     >> ./config_temp.tcl
echo "set clk $clk"                     >> ./config_temp.tcl
echo "set NOTE $NOTE"                   >> ./config_temp.tcl
echo "set TECH_SETTING $TECH_SETTING"   >> ./config_temp.tcl
echo "set SYNTH_PROJDIR $SYNTH_PROJDIR" >> ./config_temp.tcl
echo "set TCF_INST $TCF_INST"           >> ./config_temp.tcl
echo "set TCF_DUMP $TCF_DUMP"           >> ./config_temp.tcl

genus -legacy_ui -no_gui -overwrite -f ./script/syn_RISC_power.scr -log ${SYNTH_PROJDIR}/${DESIGN_NAME}_power.log
