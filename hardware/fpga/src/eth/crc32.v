// CRC32,input data 8bit
module crc32(
    input                 clk     ,  //时钟信号
    input                 rst_n   ,  //复位信号，低电平有效
    input         [7:0]   data_in    ,  //输入待校验8位数据
    input                 crc_en  ,  //crc使能，开始校验标志
    input                 crc_clear ,  //crc数据复位信号            
    output   reg  [31:0]  crc_data,  //CRC校验数据
    output        [31:0]  crc_next   //CRC下次校验完成数据
    );

//reverse bit location
wire    [7:0]  data_tmp;
assign data_tmp = {data_in[0],data_in[1],data_in[2],data_in[3],data_in[4],data_in[5],data_in[6],data_in[7]};

//CRC32的生成多项式为：G(x)= x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 
//+ x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x^1 + 1

assign crc_next[0] = crc_data[24] ^ crc_data[30] ^ data_tmp[0] ^ data_tmp[6];
assign crc_next[1] = crc_data[24] ^ crc_data[25] ^ crc_data[30] ^ crc_data[31] 
                     ^ data_tmp[0] ^ data_tmp[1] ^ data_tmp[6] ^ data_tmp[7];
assign crc_next[2] = crc_data[24] ^ crc_data[25] ^ crc_data[26] ^ crc_data[30] 
                     ^ crc_data[31] ^ data_tmp[0] ^ data_tmp[1] ^ data_tmp[2] ^ data_tmp[6] 
                     ^ data_tmp[7];
assign crc_next[3] = crc_data[25] ^ crc_data[26] ^ crc_data[27] ^ crc_data[31] 
                     ^ data_tmp[1] ^ data_tmp[2] ^ data_tmp[3] ^ data_tmp[7];
assign crc_next[4] = crc_data[24] ^ crc_data[26] ^ crc_data[27] ^ crc_data[28] 
                     ^ crc_data[30] ^ data_tmp[0] ^ data_tmp[2] ^ data_tmp[3] ^ data_tmp[4] 
                     ^ data_tmp[6];
assign crc_next[5] = crc_data[24] ^ crc_data[25] ^ crc_data[27] ^ crc_data[28] 
                     ^ crc_data[29] ^ crc_data[30] ^ crc_data[31] ^ data_tmp[0] 
                     ^ data_tmp[1] ^ data_tmp[3] ^ data_tmp[4] ^ data_tmp[5] ^ data_tmp[6] 
                     ^ data_tmp[7];
assign crc_next[6] = crc_data[25] ^ crc_data[26] ^ crc_data[28] ^ crc_data[29] 
                     ^ crc_data[30] ^ crc_data[31] ^ data_tmp[1] ^ data_tmp[2] ^ data_tmp[4] 
                     ^ data_tmp[5] ^ data_tmp[6] ^ data_tmp[7];
assign crc_next[7] = crc_data[24] ^ crc_data[26] ^ crc_data[27] ^ crc_data[29] 
                     ^ crc_data[31] ^ data_tmp[0] ^ data_tmp[2] ^ data_tmp[3] ^ data_tmp[5] 
                     ^ data_tmp[7];
assign crc_next[8] = crc_data[0] ^ crc_data[24] ^ crc_data[25] ^ crc_data[27] 
                     ^ crc_data[28] ^ data_tmp[0] ^ data_tmp[1] ^ data_tmp[3] ^ data_tmp[4];
assign crc_next[9] = crc_data[1] ^ crc_data[25] ^ crc_data[26] ^ crc_data[28] 
                     ^ crc_data[29] ^ data_tmp[1] ^ data_tmp[2] ^ data_tmp[4] ^ data_tmp[5];
assign crc_next[10] = crc_data[2] ^ crc_data[24] ^ crc_data[26] ^ crc_data[27] 
                     ^ crc_data[29] ^ data_tmp[0] ^ data_tmp[2] ^ data_tmp[3] ^ data_tmp[5];
assign crc_next[11] = crc_data[3] ^ crc_data[24] ^ crc_data[25] ^ crc_data[27] 
                     ^ crc_data[28] ^ data_tmp[0] ^ data_tmp[1] ^ data_tmp[3] ^ data_tmp[4];
assign crc_next[12] = crc_data[4] ^ crc_data[24] ^ crc_data[25] ^ crc_data[26] 
                     ^ crc_data[28] ^ crc_data[29] ^ crc_data[30] ^ data_tmp[0] 
                     ^ data_tmp[1] ^ data_tmp[2] ^ data_tmp[4] ^ data_tmp[5] ^ data_tmp[6];
assign crc_next[13] = crc_data[5] ^ crc_data[25] ^ crc_data[26] ^ crc_data[27] 
                     ^ crc_data[29] ^ crc_data[30] ^ crc_data[31] ^ data_tmp[1] 
                     ^ data_tmp[2] ^ data_tmp[3] ^ data_tmp[5] ^ data_tmp[6] ^ data_tmp[7];
assign crc_next[14] = crc_data[6] ^ crc_data[26] ^ crc_data[27] ^ crc_data[28] 
                     ^ crc_data[30] ^ crc_data[31] ^ data_tmp[2] ^ data_tmp[3] ^ data_tmp[4]
                     ^ data_tmp[6] ^ data_tmp[7];
assign crc_next[15] =  crc_data[7] ^ crc_data[27] ^ crc_data[28] ^ crc_data[29]
                     ^ crc_data[31] ^ data_tmp[3] ^ data_tmp[4] ^ data_tmp[5] ^ data_tmp[7];
assign crc_next[16] = crc_data[8] ^ crc_data[24] ^ crc_data[28] ^ crc_data[29] 
                     ^ data_tmp[0] ^ data_tmp[4] ^ data_tmp[5];
assign crc_next[17] = crc_data[9] ^ crc_data[25] ^ crc_data[29] ^ crc_data[30] 
                     ^ data_tmp[1] ^ data_tmp[5] ^ data_tmp[6];
assign crc_next[18] = crc_data[10] ^ crc_data[26] ^ crc_data[30] ^ crc_data[31] 
                     ^ data_tmp[2] ^ data_tmp[6] ^ data_tmp[7];
assign crc_next[19] = crc_data[11] ^ crc_data[27] ^ crc_data[31] ^ data_tmp[3] ^ data_tmp[7];
assign crc_next[20] = crc_data[12] ^ crc_data[28] ^ data_tmp[4];
assign crc_next[21] = crc_data[13] ^ crc_data[29] ^ data_tmp[5];
assign crc_next[22] = crc_data[14] ^ crc_data[24] ^ data_tmp[0];
assign crc_next[23] = crc_data[15] ^ crc_data[24] ^ crc_data[25] ^ crc_data[30] 
                      ^ data_tmp[0] ^ data_tmp[1] ^ data_tmp[6];
assign crc_next[24] = crc_data[16] ^ crc_data[25] ^ crc_data[26] ^ crc_data[31] 
                      ^ data_tmp[1] ^ data_tmp[2] ^ data_tmp[7];
assign crc_next[25] = crc_data[17] ^ crc_data[26] ^ crc_data[27] ^ data_tmp[2] ^ data_tmp[3];
assign crc_next[26] = crc_data[18] ^ crc_data[24] ^ crc_data[27] ^ crc_data[28] 
                      ^ crc_data[30] ^ data_tmp[0] ^ data_tmp[3] ^ data_tmp[4] ^ data_tmp[6];
assign crc_next[27] = crc_data[19] ^ crc_data[25] ^ crc_data[28] ^ crc_data[29] 
                      ^ crc_data[31] ^ data_tmp[1] ^ data_tmp[4] ^ data_tmp[5] ^ data_tmp[7];
assign crc_next[28] = crc_data[20] ^ crc_data[26] ^ crc_data[29] ^ crc_data[30] 
                      ^ data_tmp[2] ^ data_tmp[5] ^ data_tmp[6];
assign crc_next[29] = crc_data[21] ^ crc_data[27] ^ crc_data[30] ^ crc_data[31] 
                      ^ data_tmp[3] ^ data_tmp[6] ^ data_tmp[7];
assign crc_next[30] = crc_data[22] ^ crc_data[28] ^ crc_data[31] ^ data_tmp[4] ^ data_tmp[7];
assign crc_next[31] = crc_data[23] ^ crc_data[29] ^ data_tmp[5];

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)crc_data <= 32'hff_ff_ff_ff;
    else if(crc_clear) crc_data <= 32'hff_ff_ff_ff;//CRC value reset
    else if(crc_en)crc_data <= crc_next;
end

endmodule