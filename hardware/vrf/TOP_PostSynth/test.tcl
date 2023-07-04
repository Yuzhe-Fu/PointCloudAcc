# stop -condition { #EnTcf == 1'b0 }
dumptcf -scope TOP_tb.u_TOP -output tcf_period10_0703.dump -overwrite
run
dumptcf -end