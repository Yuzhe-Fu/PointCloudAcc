//arp module top
module arp_top(
    input                rst_n      	, //复位信号，低电平有效
    //GMII
    input                gmii_rxc		, //GMII接收数据时钟
    input                gmii_rxdv 		, //GMII输入数据有效信号
    input        [7:0]   gmii_rxd   	, //GMII输入数据
    input                gmii_txc		, //GMII发送数据时钟
    output               gmii_txen 		, //GMII输出数据有效信号
    output       [7:0]   gmii_txd   	, //GMII输出数据  
	
    //arp port
    output               arp_rx_done	, //ARP接收完成信号
    output               arp_rx_type	, //ARP接收类型 0:请求  1:应答
    output       [47:0]  source_mac     , //接收到目的MAC地址
    output       [31:0]  source_ip      , //接收到目的IP地址   
	
    input                arp_tx_en  	, //ARP发送使能信号
    input                arp_tx_type	, //ARP发送类型 0:请求  1:应答
	
    input        [47:0]  destination_mac, //发送的目标MAC地址
    input        [31:0]  desination_ip  , //发送的目标IP地址
	input		 [47:0]	 local_mac		, // 本机mac
	input		 [31:0]	 local_ip		, // 本机IP
    output               tx_done     	  //以太网发送完成信号    
    );


//wire
wire           crc_en  ; //CRC开始校验使能
wire           crc_clear ; //CRC数据复位信号 
wire   [7:0]   crc_d8  ; //输入待校验8位数据
wire   [31:0]  crc_data; //CRC校验数据
wire   [31:0]  crc_next; //CRC下次校验完成数据

assign  crc_d8 = gmii_txd;

//ARP接收模块    
arp_rxd arp_rxd_inst(		
    .clk             	(gmii_rxc			),
    .rst_n           	(rst_n				),
	.local_mac			(local_mac			),
	.local_ip			(local_ip			),	
    .gmii_rxdv       	(gmii_rxdv			),
    .gmii_rxd        	(gmii_rxd  			),
    .arp_rx_done     	(arp_rx_done		),
    .arp_rx_type     	(arp_rx_type		),
    .source_mac      	(source_mac    		),
    .source_ip       	(source_ip     		)
);                                           

//ARP TXD module
arp_txd  arp_txd_inst(	
    .clk            	(gmii_txc			),
    .rst_n          	(rst_n				),
	.local_mac			(local_mac			),
	.local_ip			(local_ip			),
    .arp_tx_en      	(arp_tx_en 			),
    .arp_tx_type    	(arp_tx_type		),
    .destination_mac	(destination_mac	),
    .destination_ip		(desination_ip		),
    .crc_data        	(crc_data  			),
    .crc_next        	(crc_next[31:24]	),
    .tx_done         	(tx_done   			),
    .gmii_txen      	(gmii_txen			),
    .gmii_txd        	(gmii_txd  			),
    .crc_en          	(crc_en    			),
    .crc_clear         	(crc_clear   		)
);     

// data packet crc ,do crc32
crc32   crc32_inst(
    .clk             	(gmii_txc		),                      
    .rst_n           	(rst_n      	),                          
    .data_in         	(crc_d8     	),            
    .crc_en          	(crc_en     	),                          
    .crc_clear			(crc_clear    	),                         
    .crc_data        	(crc_data   	),                        
    .crc_next        	(crc_next   	)                         
);

endmodule
