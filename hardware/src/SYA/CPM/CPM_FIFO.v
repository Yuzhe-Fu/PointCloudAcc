module CPM_FIFO
#(  // Parameters
    parameter   DATA_WIDTH          = 64,
    parameter   INIT                = "init.mif",
    parameter   ADDR_WIDTH          = 4,
    parameter   RAM_DEPTH           = (1 << ADDR_WIDTH),
    parameter   INITIALIZE_FIFO     = "no",
    parameter   TYPE                = "MLAB",
    parameter		REG_OUT							= "false"
)(  // Ports
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         Reset,
    input  wire                         push,
    input  wire                         pop,
    input  wire [ DATA_WIDTH -1 : 0 ]   data_in,
    output reg  [ DATA_WIDTH -1 : 0 ]   data_out,
    output reg                          empty,
    output reg                          full,
    output reg  [ ADDR_WIDTH    : 0 ]   fifo_count
);

// Port Declarations
// ******************************************************************
// Internal variables
// ******************************************************************
reg     [ADDR_WIDTH-1:0]        wr_pointer;             //Write Pointer
reg     [ADDR_WIDTH-1:0]        rd_pointer;             //Read Pointer
//(* ram_style = TYPE *)
reg     [DATA_WIDTH-1:0]        mem[0:RAM_DEPTH-1];     //Memory/*synthesis ramstyle = "MLAB" */
// ******************************************************************
// INSTANTIATIONS
// ******************************************************************
initial begin
  if (INITIALIZE_FIFO == "yes") begin
    $readmemb(INIT, mem, 0, RAM_DEPTH-1);
  end
end

always @ (fifo_count)
begin : FIFO_STATUS
  empty   = (fifo_count == 0);
  full    = (fifo_count == RAM_DEPTH);
end

always @ (posedge clk or negedge rst_n)
begin : FIFO_COUNTER
  if (!rst_n) begin
    if( INITIALIZE_FIFO == "yes")
      fifo_count <= RAM_DEPTH;
    else
      fifo_count <= 0;
  end else if( Reset) begin
      fifo_count <= 0;
  end else if (push && (!pop||pop&&empty) && !full)
    fifo_count <= fifo_count + 1;
  else if (pop && (!push||push&&full) && !empty)
    fifo_count <= fifo_count - 1;
end

always @ (posedge clk or negedge rst_n)
begin : WRITE_PTR
  if (!rst_n) begin
    wr_pointer <= 0;
  end else if( Reset )begin
    wr_pointer <= 0;
  end else if (push && !full) begin
    wr_pointer <= wr_pointer + 1;
  end
end

always @ (posedge clk or negedge rst_n)
begin : READ_PTR
  if (!rst_n) begin
    rd_pointer <= 0;
  end else if( Reset )begin
    rd_pointer <= 0;
  end else if (pop && !empty) begin
    rd_pointer <= rd_pointer + 1;
  end
end

integer i;
always @ (posedge clk or negedge rst_n) begin :WRITE
  if( !rst_n) begin
  	for(i=0; i<RAM_DEPTH; i=i+1)begin
    	mem[i] <= 0;
  	end
  end else if (push && !full) begin
    mem[wr_pointer] <= data_in;
  end
end

generate
	if( REG_OUT=="true" )begin
		always @ (posedge clk or negedge rst_n)
		begin : READ
		  if (!rst_n) begin
		    data_out <= 0;
		  end else if (pop && !empty) begin
		    data_out <= mem[rd_pointer];
		  end else begin
		    data_out <= data_out;
		  end
		end
	end
	else begin
		always @ ( * )begin
		    data_out = mem[rd_pointer];
		end
	end
endgenerate

endmodule
