//eth control module
module eth_ctrl(
    input              clk       ,    //系统时钟
    input              rst_n     ,    //系统复位信号，低电平有效 

	//module top
	input				tx_start_en, 
	input	[47:0]		tx_des_mac,

    //arp port                                 
    input              arp_rx_done,   //ARP接收完成信号
    input              arp_rx_type,   //ARP接收类型 0:请求  1:应答
    output  reg        arp_tx_en,     //ARP发送使能信号
    output  reg        arp_tx_type =0,   //ARP发送类型 0:请求  1:应答
    input              arp_tx_done,   //ARP发送完成信号

    //gmii tx data 
    input              arp_gmii_txen,//ARP GMII输出数据有效信号 
    input     [7:0]    arp_gmii_txd,  //ARP GMII输出数据
	
    input              udp_gmii_txen,//UDP GMII输出数据有效信号  
    input     [7:0]    udp_gmii_txd,  //UDP GMII输出数据   
    output             gmii_txen,    //GMII输出数据有效信号 
    output    [7:0]    gmii_txd,       //UDP GMII输出数据 
    output             gmii_tlast       //UDP GMII输出数据 
);

//indicate whitch protocal
reg        udp_protocol; //协议切换信号
wire  arp_tx_en_temp   =  (arp_rx_done && (arp_rx_type == 1'b0)) || // 对方主机的arp请求
					      (tx_start_en && (tx_des_mac == 48'b0));  	// 请求对方arp请求
// assign gmii_txen = udp_protocol ? udp_gmii_txen : arp_gmii_txen;
// assign gmii_txd  = udp_protocol ? udp_gmii_txd : arp_gmii_txd;

//根据ARP发送使能/完成信号,切换GMII引脚
always @(posedge clk) begin
    if(rst_n==1'b0)           
		udp_protocol <= 1'b1;
    else if(arp_tx_en_temp)   
		udp_protocol <= 1'b0;
    else if(arp_tx_done) 
		udp_protocol <= 1'b1;
	else 
		udp_protocol <= udp_protocol;
end

always @(posedge clk) begin
	arp_tx_en <= arp_tx_en_temp;
	
	if((arp_rx_done && (arp_rx_type == 1'b0))) // arp request
		arp_tx_type	<= 1; 	// 发送 1:应答
	else if(tx_start_en && (tx_des_mac == 48'b0)) // arp response
		arp_tx_type	<= 0; 	// 发送 0:请求 
	else 
		arp_tx_type <= arp_tx_type;
end

/***********************************************/
reg gmii_txen_f;
reg [7:0] gmii_txd_f;
wire temp = udp_protocol ? udp_gmii_txen : arp_gmii_txen;

always @(posedge clk) begin
	gmii_txen_f <= temp;
	gmii_txd_f <=  udp_protocol ? udp_gmii_txd : arp_gmii_txd;
end

assign gmii_txen = gmii_txen_f;
assign gmii_txd  = gmii_txd_f;
assign gmii_tlast = (~temp) & gmii_txen_f;
endmodule