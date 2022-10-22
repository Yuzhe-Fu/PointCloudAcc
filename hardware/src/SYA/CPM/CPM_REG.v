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
module CPM_REG #(
    parameter DW = 8
) (
    input            Clk   ,
    input            Rstn  ,

    input  [DW -1:0] DataIn,
    output [DW -1:0] DataOut
);
  reg [DW -1:0] data_out;
  assign DataOut = data_out;
  always @ ( posedge Clk or negedge Rstn )begin
    if( ~Rstn )
      data_out <= 'd0;
    else
      data_out <= DataIn;
  end
endmodule
