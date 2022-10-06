module inout_def(
input clk,
input z,
inout dinout,
input z2,
inout dinout2,
input z3,
inout dinout3,
output  reg  led_r1,
output  reg  led_r2,
output  reg  led_r3
    );
    
// reg dout = 0;
// wire din;
// assign dinout = z?1'bz:dout;
// assign din = z?dinout:1'bz;

//  always @(posedge clk)
// begin
//    if(din)
//        led_r1 <= 1;
//    else
//        led_r1 <= 0;
// end 

reg dout2 = 0;
wire din2;
assign dinout2 = z2?1'bz:dout2;
assign din2 = dinout2;

 always @(posedge clk)
 begin
    if(din2)
        led_r2 <= 1;
    else
        led_r2 <= 0;
 end 

// reg dout3 = 0;
// wire din3;

// IOBUF IOBUF(
// .I(dout3),
// .O(din3),
// .T(z3),
// .IO(dinout3)
// );

//  always @(posedge clk)
//  begin
//     if(din3)
//         led_r3 <= 1;
//     else
//         led_r3 <= 0;
//  end 
 
endmodule