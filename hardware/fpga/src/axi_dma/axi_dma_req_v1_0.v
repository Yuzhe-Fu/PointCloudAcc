
`timescale 1 ns / 1 ps

	module axi_dma_req_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Master Bus Interface M00_AXI
		parameter  C_M00_AXI_TARGET_SLAVE_BASE_ADDR	= 32'h40000000,
		parameter integer C_M00_AXI_ID_WIDTH	= 1,
		parameter integer C_M00_AXI_ADDR_WIDTH	= 32,
		// Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
		parameter integer C_M00_AXI_DATA_WIDTH	= 32
	)
	(
		// Users to add ports here
		input									wr_req,
		output									wr_ack,
		input	[C_M00_AXI_ADDR_WIDTH-1:0]		wr_addr,
		input	[31:0]							wr_len,
		input	[C_M00_AXI_DATA_WIDTH-1:0]		wr_data,
		output									wr_data_req,
		output									wr_req_done,
		input									wr_data_ready,
		
		input									rd_req,
		output									rd_ack,
		input	[C_M00_AXI_ADDR_WIDTH-1:0]		rd_addr,
		input	[31:0]							rd_len,
		output	[C_M00_AXI_DATA_WIDTH-1:0]		rd_data,
		output	 								rd_data_valid,
		output									rd_req_done,	
		input									rd_data_ready,
		
		output									error_reg,
		output									busy,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Master Bus Interface M00_AXI
		input wire  m00_axi_aclk,
		input wire  m00_axi_aresetn,
		output wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_awid,
		output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_awaddr,
		output wire [7 : 0] m00_axi_awlen,
		output wire [2 : 0] m00_axi_awsize,
		output wire [1 : 0] m00_axi_awburst,
		output wire  m00_axi_awlock,
		output wire [3 : 0] m00_axi_awcache,
		output wire [2 : 0] m00_axi_awprot,
		output wire [3 : 0] m00_axi_awqos,
		output wire  m00_axi_awvalid,
		input wire  m00_axi_awready,
		output wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_wdata,
		output wire [C_M00_AXI_DATA_WIDTH/8-1 : 0] m00_axi_wstrb,
		output wire  m00_axi_wlast,
		output wire  m00_axi_wvalid,
		input wire  m00_axi_wready,
		input wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_bid,
		input wire [1 : 0] m00_axi_bresp,
		input wire  m00_axi_bvalid,
		output wire  m00_axi_bready,
		output wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_arid,
		output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_araddr,
		output wire [7 : 0] m00_axi_arlen,
		output wire [2 : 0] m00_axi_arsize,
		output wire [1 : 0] m00_axi_arburst,
		output wire  m00_axi_arlock,
		output wire [3 : 0] m00_axi_arcache,
		output wire [2 : 0] m00_axi_arprot,
		output wire [3 : 0] m00_axi_arqos,
		output wire  m00_axi_arvalid,
		input wire  m00_axi_arready,
		input wire [C_M00_AXI_ID_WIDTH-1 : 0] m00_axi_rid,
		input wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_rdata,
		input wire [1 : 0] m00_axi_rresp,
		input wire  m00_axi_rlast,
		input wire  m00_axi_rvalid,
		output wire  m00_axi_rready
	);
	
wire 							wri_req;
wire 							wri_ack;
wire [C_M00_AXI_ADDR_WIDTH-1:0]	wri_addr;
wire [8:0]						wri_len;
wire 							wri_req_done;

wire 							rdi_req;
wire 							rdi_ack;
wire [C_M00_AXI_ADDR_WIDTH-1:0]	rdi_addr;
wire [8:0]						rdi_len;
wire 							rdi_req_done;
	
// Instantiation of Axi Bus Interface M00_AXI
axi_dma_req_v1_0_M00_AXI # ( 
	.C_M_TARGET_SLAVE_BASE_ADDR(C_M00_AXI_TARGET_SLAVE_BASE_ADDR),
	// .C_M_AXI_BURST_LEN(C_M00_AXI_BURST_LEN),
	.C_M_AXI_ID_WIDTH(C_M00_AXI_ID_WIDTH),
	.C_M_AXI_ADDR_WIDTH(C_M00_AXI_ADDR_WIDTH),
	.C_M_AXI_DATA_WIDTH(C_M00_AXI_DATA_WIDTH)
) axi_dma_req_v1_0_M00_AXI_inst (
	.M_AXI_ACLK(m00_axi_aclk),
	.M_AXI_ARESETN(m00_axi_aresetn),
	.M_AXI_AWID(m00_axi_awid),
	.M_AXI_AWADDR(m00_axi_awaddr),
	.M_AXI_AWLEN(m00_axi_awlen),
	.M_AXI_AWSIZE(m00_axi_awsize),
	.M_AXI_AWLOCK(m00_axi_awlock),
	.M_AXI_AWCACHE(m00_axi_awcache),
	.M_AXI_AWPROT(m00_axi_awprot),
	.M_AXI_AWQOS(m00_axi_awqos),
	.M_AXI_AWVALID(m00_axi_awvalid),
	.M_AXI_AWREADY(m00_axi_awready),
	.M_AXI_AWBURST(m00_axi_awburst),
	.M_AXI_WDATA(m00_axi_wdata),
	.M_AXI_WSTRB(m00_axi_wstrb),
	.M_AXI_WLAST(m00_axi_wlast),
	.M_AXI_WVALID(m00_axi_wvalid),
	.M_AXI_WREADY(m00_axi_wready),
	.M_AXI_BID(m00_axi_bid),
	.M_AXI_BRESP(m00_axi_bresp),
	.M_AXI_BVALID(m00_axi_bvalid),
	.M_AXI_BREADY(m00_axi_bready),
	.M_AXI_ARID(m00_axi_arid),
	.M_AXI_ARADDR(m00_axi_araddr),
	.M_AXI_ARLEN(m00_axi_arlen),
	.M_AXI_ARSIZE(m00_axi_arsize),
	.M_AXI_ARLOCK(m00_axi_arlock),
	.M_AXI_ARCACHE(m00_axi_arcache),
	.M_AXI_ARPROT(m00_axi_arprot),
	.M_AXI_ARQOS(m00_axi_arqos),
	.M_AXI_ARVALID(m00_axi_arvalid),
	.M_AXI_ARREADY(m00_axi_arready),
	.M_AXI_ARBURST(m00_axi_arburst),
	.M_AXI_RID(m00_axi_rid),
	.M_AXI_RDATA(m00_axi_rdata),
	.M_AXI_RRESP(m00_axi_rresp),
	.M_AXI_RLAST(m00_axi_rlast),
	.M_AXI_RVALID(m00_axi_rvalid),
	.M_AXI_RREADY(m00_axi_rready),
		
	.wr_req	 			(wri_req	 			),
	.wr_ack	            (wri_ack	            ),
	.wr_addr            (wri_addr            	),
	.wr_len             (wri_len             	),
	.wr_req_done        (wri_req_done       	),
	.wr_data            (wr_data            	),
	.wr_data_req        (wr_data_req        	),
	
	.rd_req             (rdi_req             	),
	.rd_ack             (rdi_ack             	),
	.rd_addr            (rdi_addr            	),
	.rd_len             (rdi_len             	),
	.rd_data            (rd_data            	),
	.rd_data_valid      (rd_data_valid      	),
	.rd_req_done 	    (rdi_req_done 	    	),
	.error_reg          (error_reg          	)
);

reg wr_busy;

always @(posedge m00_axi_aclk ) begin
	if(m00_axi_aresetn == 1'b0 ) begin
		wr_busy <= 0;
	end
	else if(wr_req)
		wr_busy <= 1;
	else if(wr_req_done)
		wr_busy <= 0;
	else 
		wr_busy	<= wr_busy;
end

reg rd_busy;

always @(posedge m00_axi_aclk ) begin
	if(m00_axi_aresetn == 1'b0 ) 
		rd_busy <= 0;
	else if(rd_req)
		rd_busy <= 1;
	else if(rd_req_done)
		rd_busy <= 0;
	else 
		rd_busy	<= rd_busy;
end

axi_addr4k_spilt #(
	.ADDR_WIDTH 		(C_M00_AXI_ADDR_WIDTH	),
	.DATA_WIDTH 		(C_M00_AXI_DATA_WIDTH	)
)u_wr_spilt(
	.sys_clk			(m00_axi_aclk			),
	.reset_n			(m00_axi_aresetn		),
	
	// .s_req				(wr_req	 && ~rd_busy	),
	.s_req				(wr_req	 				),
	.s_ack	            (wr_ack	            	),
	.s_addr		        (wr_addr            	),
	.s_len		        (wr_len             	),
	.s_req_done	        (wr_req_done        	),
	.s_ready			(wr_data_ready			),
	
	.m_req				(wri_req	 			),
	.m_ack	            (wri_ack	        	),
	.m_addr	            (wri_addr           	),
	.m_len	            (wri_len            	),
	.m_req_done         (wri_req_done       	)
);


axi_addr4k_spilt #(
	.ADDR_WIDTH 		(C_M00_AXI_ADDR_WIDTH	),
	.DATA_WIDTH 		(C_M00_AXI_DATA_WIDTH	)
)u_rd_spilt(
	.sys_clk			(m00_axi_aclk			),
	.reset_n			(m00_axi_aresetn		),
	
	// .s_req				(rd_req	 && ~wr_busy	),
	.s_req				(rd_req					),
	.s_ack	            (rd_ack	            	),
	.s_addr		        (rd_addr            	),
	.s_len		        (rd_len             	),
	.s_req_done	        (rd_req_done        	),
	.s_ready			(rd_data_ready			),	
	
	.m_req				(rdi_req	 			),
	.m_ack	            (rdi_ack	        	),
	.m_addr	            (rdi_addr           	),
	.m_len	            (rdi_len            	),
	.m_req_done         (rdi_req_done       	)
);

assign busy = wr_busy || rd_busy;

// ila_w256 u_wr(
	// .clk		(m00_axi_aclk	),
	// .probe0		({
		// wr_req,	
		// wr_ack,	
		// wr_addr,	
		// wr_len,	
		// wr_data,	
		// wr_data_req,	
		// wr_req_done,	
		// rd_req,	
		// rd_ack,	
		// rd_addr,	
		// rd_len,	
		// rd_data,	
		// rd_data_valid,	
		// rd_req_done,		
		// error_reg
	// })
// );


endmodule
