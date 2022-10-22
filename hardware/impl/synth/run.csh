set DESIGN_NAME = "TOP"
set VT = "3vt"
set PERIOD = "1000"
set UNGROUP = "group"
set NOTE = "whole"

if ($DESIGN_NAME == "TOP") then
    set SDC_FILE=./TOP.sdc 
    echo "<<<<<<<<<<<<<<<<<<<set SDC=ASIC.sdc>>>>>>>>>>>>>>>>>>>>>>"
else 
    set SDC_FILE=./module.sdc 
    echo "<<<<<<<<<<<<<<<<<<<set SDC=module.sdc>>>>>>>>>>>>>>>>>>>>>>"
endif

if ($VT == "3vt") then
    set TECH_SETTING=tech_settings.tcl
else if($VT == "rvt") then
    set TECH_SETTING=tech_settings_rvt.tcl  
else 
    echo "<<<<<<<<<<<<<<<<<<<error VT>>>>>>>>>>>>>>>>>>>>>>"
    exit  
endif 

if($PERIOD == "") then 
    echo "<<<<<<<<<<<<<<<<<<<empty PERIOD>>>>>>>>>>>>>>>>>>>>>>"
    exit
endif

set DATE_VALUE = `date "+%y%m%d" ` 
set SYNTH_OUTDIR = ../../work/synth
set SYNTH_PROJDIR = ${SYNTH_OUTDIR}/$DESIGN_NAME/Date${DATE_VALUE}_Period${PERIOD}_${UNGROUP}_Track${VT}_Note${NOTE}
rm -rf ${SYNTH_PROJDIR}
mkdir -p ${SYNTH_OUTDIR}/$DESIGN_NAME ${SYNTH_PROJDIR}

cp -r ../../src ${SYNTH_PROJDIR}
cp -r ../synth ${SYNTH_PROJDIR}

rm ./config_temp.tcl

echo "set DESIGN_NAME $DESIGN_NAME" >> ./config_temp.tcl
echo "set PERIOD $PERIOD" >> ./config_temp.tcl
echo "set DATE_VALUE $DATE_VALUE" >> ./config_temp.tcl
echo "set TECH_SETTING $TECH_SETTING" >> ./config_temp.tcl
echo "set SDC_FILE $SDC_FILE" >> ./config_temp.tcl
echo "set SYNTH_PROJDIR $SYNTH_PROJDIR" >> ./config_temp.tcl

if( $UNGROUP == "group") then 
  echo "set UNGROUP none" >> ./config_temp.tcl
else if( $UNGROUP == "ungroup") then 
  echo "set UNGROUP both" >> ./config_temp.tcl
else
    echo "<<<<<<<<<<<<<<<<<<<error UNGROUP>>>>>>>>>>>>>>>>>>>>>>"
    exit  
endif 

echo "<<<<<<<<<<<<<<<<<<<rc syn>>>>>>>>>>>>>>>>>>>>>>"
genus -legacy_ui -no_gui -overwrite -f ./script/syn_RISC.scr -log ${SYNTH_PROJDIR}/$DESIGN_NAME.log
