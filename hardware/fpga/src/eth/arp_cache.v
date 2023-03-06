`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 		UESTCOC
// Engineer: 		Deam
// 
// Create Date: 
// Design Name:     
// Module Name:     arp_cache 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
/*
	从0 开始遍历 IP若IP缓存已满则存储到0号地址
*/
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module arp_cache #(
	parameter	DE_IP0	= {8'd192,8'd168,8'd0,8'd123},
	parameter	DE_MAC0	= 48'h123456789abc,
	parameter	NUM		= 5
)(
	input				sys_clk,
	input				reset_n,
	input				lookup_en,	// 查询使能
	input		[31:0]	lookup_ip,  // 查询IP
	output	reg	[47:0]	lookup_mac,//  返回MAC
	output	reg			lookup_done,// 查询完成
	input				store_en,
	input		[31:0]	store_ip,
	input		[47:0]	store_mac
);

integer i;
reg [31:0] 	ip  [NUM-1:0] ;
reg [47:0] 	mac [NUM-1:0] ;
reg [5:0]	cnt = 6'b10_0000;

reg lookup_en_f;

always @(posedge sys_clk) begin
	lookup_en_f <= lookup_en;
end

wire lookup_start = lookup_en & (!lookup_en_f);

/****************************************************/
// store
always @(posedge sys_clk ) begin
	if(reset_n == 1'b0 ) begin
		for(i=0;i<NUM;i=i+1) begin
			if(i == 0) begin		// 配置一个默认信息
				ip[i] 	<= DE_IP0	;	
				mac[i]	<= DE_MAC0	;
			end
			else begin	
				ip[i] 	<= 0;
				mac[i] 	<= 0;
			end
		end
		cnt	<= 6'b10_0000;
	end
	else if(store_en) begin
		cnt	<= 0;
	end if(cnt < NUM) begin
		if(ip[cnt] == 32'b0 || ip[cnt] == store_ip) begin // 空位置   or  mac 更新
			mac[cnt] <= store_mac;
			ip[cnt]  <= store_ip;
			cnt		 <= 6'b10_0000;
		end
		else 
			cnt		<= cnt + 1;
	end if(cnt == NUM) begin
		mac[0] 	<= store_mac;
		cnt		 <= 6'b10_0000;
	end
	else 
		;
end

// lookup
reg [5:0] cnt2 = 6'b10_0000;

always @(posedge sys_clk ) begin
	if(reset_n == 1'b0 ) begin
		lookup_mac	<= 0;
		lookup_done <= 0;
		cnt2	 	<= 6'b10_0000;
	end
	else if(lookup_start) begin
		if(lookup_ip == ip[0]) begin
			lookup_mac	<= mac[0];
			lookup_done	<= 1;
			cnt2		<= 6'b10_0000;
		end
		else 
			cnt2		<= 1;
	end
	else if(cnt2 < NUM) begin
		if(lookup_ip == ip[cnt2]) begin
			lookup_mac	<= mac[cnt2];
			lookup_done	<= 1;
			cnt2		<= 6'b10_0000;
		end
		else 
			cnt2		<= cnt2 + 1;
	end
	else if(cnt2 == NUM) begin
		cnt2		<= 6'b10_0000;
		lookup_done	<= 1;
		lookup_mac	<= 47'b0;
	end
	else 
		lookup_done <= 0;
end

endmodule
