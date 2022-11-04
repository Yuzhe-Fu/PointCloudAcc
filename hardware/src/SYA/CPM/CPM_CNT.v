//======================================================
// Copyright (C) 2020 By 
// All Rights Reserved
//======================================================
// Module : 
// Author : 
// Contact : 
// Date : 
//=======================================================
// Description :
//========================================================
module CPM_CNT #(
    parameter DW = 8
) (
    input            Clk   ,
    input            Rstn  ,
    input            Enable,

    output [DW -1:0] Cnt
);
  reg [DW -1:0] cnt_reg;
  assign Cnt = cnt_reg;
  always @ ( posedge Clk or negedge Rstn )begin
    if( ~Rstn )
      cnt_reg <= 'd0;
    else if( Enable )
      cnt_reg <= cnt_reg + 1'd1;
  end
endmodule
