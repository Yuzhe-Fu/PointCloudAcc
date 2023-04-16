# stop -condition { #EnTcf == 1'b0 }
dumptcf -scope TOP_tb.u_TOP -output tcf.dump -overwrite
run
dumptcf -end