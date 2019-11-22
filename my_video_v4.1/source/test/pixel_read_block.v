//读取单点像素
//原始图像以4*4为一块的方式储存
//每次读取ddr3后缓存一个4*4的像素矩阵
//板上测试OK
module pixel_read_block
#
(
  parameter FRAME_X = 11'd1920,//帧画面大小
  parameter FRAME_Y = 11'd1080
)
(
  input wire clk,
  input wire rst,
  
  //地址输入
  input wire [10:0] addr_x,
  input wire [10:0] addr_y,
  input wire [23:0] frame_base_addr0,//帧基址
  input wire [23:0] frame_base_addr1,
  input wire [23:0] frame_base_addr2,
  input wire [23:0] frame_base_addr3,
  input wire [1:0]  base_addr_index,//基址指针
  input wire addr_wr_en,//地址写入使能
  output addr_wr_almost_full,//地址写入FIFO满
  
  //像素输出
  output reg [15:0] wr_fifo_pixel_data,
  output reg wr_fifo_pixel_en,
  input wr_fifo_pixel_full,
  output [7:0] debug,//
  
  //ddr3控制器接口
  output reg              rd_ddr3_req,        // to external memory controller,send out a burst read request
  output     [10 - 1:0]   rd_ddr3_len,        // to external memory controller,data length of the burst read request, not bytes
  output reg [25 - 1:0]   rd_ddr3_addr,       // to external memory controller,base address of the burst read request 
  input wire              rd_ddr3_data_valid, // from external memory controller,read data valid 
  input wire [64 - 1:0]   rd_ddr3_data,       // from external memory controller,read request data
  input wire              rd_ddr3_finish,      // from external memory controller,burst read finish
  input wire              rd_ddr3_ready
);
assign rd_ddr3_len = 10'd4;

wire addr_fifo_rd_req;
wire addr_fifo_rd_empty;
wire [21:0] addr_x_y;
//地址输入FIFO
fifo_22i_22o fifo_addr_in (
    .clk(clk),
    .rst(rst),
    .wr_en(addr_wr_en),
    .wr_data({addr_x,addr_y}),
    .wr_full(),
    .almost_full(addr_wr_almost_full),
    .rd_en(addr_fifo_rd_req),
    .rd_data(addr_x_y),
    .rd_empty(addr_fifo_rd_empty),
    .almost_empty()
);

//像素块的地址
wire [8:0] block_addr_x;
wire [8:0] block_addr_y;
assign block_addr_x = addr_x_y[21:13];//同列每4个像素为一块
assign block_addr_y = addr_x_y[10:2];

wire [21:0] block_addr_x_y;
assign block_addr_x_y = {2'b00,block_addr_x,2'b00,block_addr_y};

//计算像素在块中的位置
//像素在块中的序列编号：
//0 , 4 , 8 , 12
//1 , 5 , 9 , 13
//2 , 6 , 10, 14
//3 , 7 , 11, 15
reg [3:0] pixel_loca_block;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
    pixel_loca_block <= 4'd0;
  else
    case(addr_x_y[12:11])//列
      2'd0:
        pixel_loca_block <= addr_x_y[1:0];//行
      2'd1:
        pixel_loca_block <= addr_x_y[1:0] + 4'd4;
      2'd2:
        pixel_loca_block <= addr_x_y[1:0] + 4'd8;
      2'd3:
        pixel_loca_block <= addr_x_y[1:0] + 4'd12;
    endcase
end


wire fifo_ddr3_full;
wire wr_ddr3_fifo_en;
wire [25:0] ddr3_addr_in;//每个地址上储存4个像素
//ddr3地址计算,按块形式
calculate_ddr3_addr_block
#
(
  .FRAME_X    (FRAME_X),
  .FRAME_Y    (FRAME_Y)
)
calculate_ddr3_addr
(
    .clk        (clk          ),
    .rst        (rst          ),

    .addr_x_y            (block_addr_x_y   ),
    .frame_base_addr0    (frame_base_addr0 ),
    .frame_base_addr1    (frame_base_addr1 ),
    .frame_base_addr2    (frame_base_addr2 ),
    .frame_base_addr3    (frame_base_addr3 ),
    .base_addr_index     (base_addr_index  ),
    .fifo_rd_empty       (addr_fifo_rd_empty    ),
    .fifo_rd_req         (addr_fifo_rd_req      ),
    
    .fifo_wr_full        (fifo_ddr3_full   ),
    .ddr3_addr           (ddr3_addr_in     ),
    .wr_fifo_en          (wr_ddr3_fifo_en  )
);



reg rd_fifo_ddr3_en;
wire [25:0] rd_fifo_ddr3_data;
wire rd_fifo_ddr3_empty;
//ddr3地址
fifo_26i_26o fifo_ddr3_addr (
    .clk(clk),
    .rst(rst),
    .wr_en(wr_ddr3_fifo_en),
    .wr_data({ddr3_addr_in[21:0],pixel_loca_block}),//储存块的ddr3地址和像素在块中的地址
    .wr_full(),
    .almost_full(fifo_ddr3_full),
    .rd_en(rd_fifo_ddr3_en),
    .rd_data(rd_fifo_ddr3_data),
    .rd_empty(rd_fifo_ddr3_empty),
    .almost_empty()
);


reg rd_fifo_ddr3_empty_d0;
reg rd_fifo_ddr3_empty_d1;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    rd_fifo_ddr3_empty_d0 <= 1'b1;
    rd_fifo_ddr3_empty_d1 <= 1'b1;
  end
  else
  begin
    rd_fifo_ddr3_empty_d0 <= rd_fifo_ddr3_empty;
    rd_fifo_ddr3_empty_d1 <= rd_fifo_ddr3_empty_d0;
  end
end

//读取fifo_ddr3_addr
//读取有效后置高new_addr
//收到addr_ack后再重新读取
reg new_addr;
reg addr_ack;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    new_addr <= 1'b0;
    rd_fifo_ddr3_en <= 1'b0;
  end
  else
  begin
    if(addr_ack == 1'b1)//地址数据被应答后就需要重新读取
      new_addr <= 1'b0;
    else
      new_addr <= new_addr;
      
    if(new_addr == 1'b0)//需要重新读
    begin
      if(rd_fifo_ddr3_en == 1'b1)//已经读取到新的
      begin
        rd_fifo_ddr3_en <= 1'b0;
        new_addr <= 1'b1;
      end
      else if(rd_fifo_ddr3_empty_d1 == 1'b0)//fifo不为空时读
        rd_fifo_ddr3_en <= 1'b1;
      else
        rd_fifo_ddr3_en <= 1'b0;
    end
  end
end


reg [255:0] last_data;//上次读出的数据
reg [255:0] last_last_data;//上上次读出的数据
reg [24:0]  last_addr;//上次读数据使用的地址
reg [24:0]  last_last_addr;//上上次读数据使用的地址
reg [3:0] pixel_loac;//像素在一段burst里的位置
wire [24:0] burst_addr;//burst读出时使用的ddr3地址
assign burst_addr = rd_fifo_ddr3_data[25:4];//后四位是像素在块中的位置

reg [2:0] STATE;
localparam S_RD_FIFO    = 0;//读到fifo数据
localparam S_RD_MEM_1   = 1;//读ddr3
localparam S_RD_MEM_2   = 2;//读ddr3
localparam S_RD_MEM_3   = 3;//读ddr3
localparam S_RD_MEM_4   = 4;//读ddr3
localparam S_WR_REQ     = 5;//像素数据写入fifo请求
localparam S_WR_REQ_2   = 6;//像素数据写入fifo请求
//状态任务
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    STATE <= S_RD_FIFO;
    
    wr_fifo_pixel_data  <= 16'd0;
    rd_ddr3_req         <= 1'b0;
    wr_fifo_pixel_en    <= 1'b0;
    
    pixel_loac      <= 4'd0;
    last_data       <= 256'd0;
    last_last_data  <= 256'd0;
    rd_ddr3_addr    <= 25'd0;
    last_addr       <= 25'd0;
    last_last_addr  <= 25'd0;
  end
  else
    case(STATE)
      S_RD_FIFO://读取到ddr3地址后，判断开始读ddr3 or直接写入FIFO
      begin
        wr_fifo_pixel_en <= 1'b0;
        if(new_addr == 1'b1)//如果新地址已经准备好
        begin
          if(burst_addr == last_addr)//如果该地址上的数据上次已被缓存
          begin
            STATE <= S_WR_REQ_2;//
            addr_ack <= 1'b1;//新地址数据读取应答
            case(rd_fifo_ddr3_data[3:0])//根据像素地址后四位进行数据采样
              4'd0://第一组
                wr_fifo_pixel_data <= last_data[15:0];
              4'd1:
                wr_fifo_pixel_data <= last_data[31:16];
              4'd2:
                wr_fifo_pixel_data <= last_data[47:32];
              4'd3:
                wr_fifo_pixel_data <= last_data[63:48];
              4'd4://第二组
                wr_fifo_pixel_data <= last_data[79:64];
              4'd5:
                wr_fifo_pixel_data <= last_data[95:80];
              4'd6:
                wr_fifo_pixel_data <= last_data[111:96];
              4'd7:
                wr_fifo_pixel_data <= last_data[127:112];
              4'd8://第三组
                wr_fifo_pixel_data <= last_data[143:128];
              4'd9:
                wr_fifo_pixel_data <= last_data[159:144];
              4'd10:
                wr_fifo_pixel_data <= last_data[175:160];
              4'd11:
                wr_fifo_pixel_data <= last_data[191:176];
              4'd12://第四组
                wr_fifo_pixel_data <= last_data[207:192];
              4'd13:
                wr_fifo_pixel_data <= last_data[223:208];
              4'd14:
                wr_fifo_pixel_data <= last_data[239:224];
              4'd15:
                wr_fifo_pixel_data <= last_data[255:240];
            endcase
          end
          else if(burst_addr == last_last_addr)//如果该地址上的数据上上次已被缓存
          begin
            STATE <= S_WR_REQ_2;
            addr_ack <= 1'b1;//新地址数据读取应答
            case(rd_fifo_ddr3_data[3:0])//根据像素地址后四位进行数据采样
              4'd0://第一组
                wr_fifo_pixel_data <= last_last_data[15:0];
              4'd1:
                wr_fifo_pixel_data <= last_last_data[31:16];
              4'd2:
                wr_fifo_pixel_data <= last_last_data[47:32];
              4'd3:
                wr_fifo_pixel_data <= last_last_data[63:48];
              4'd4://第二组
                wr_fifo_pixel_data <= last_last_data[79:64];
              4'd5:
                wr_fifo_pixel_data <= last_last_data[95:80];
              4'd6:
                wr_fifo_pixel_data <= last_last_data[111:96];
              4'd7:
                wr_fifo_pixel_data <= last_last_data[127:112];
              4'd8://第三组
                wr_fifo_pixel_data <= last_last_data[143:128];
              4'd9:
                wr_fifo_pixel_data <= last_last_data[159:144];
              4'd10:
                wr_fifo_pixel_data <= last_last_data[175:160];
              4'd11:
                wr_fifo_pixel_data <= last_last_data[191:176];
              4'd12://第四组
                wr_fifo_pixel_data <= last_last_data[207:192];
              4'd13:
                wr_fifo_pixel_data <= last_last_data[223:208];
              4'd14:
                wr_fifo_pixel_data <= last_last_data[239:224];
              4'd15:
                wr_fifo_pixel_data <= last_last_data[255:240];
            endcase
          end
          else if(rd_ddr3_ready == 1'b1)//ddr3接口准备好
          begin
            STATE <= S_RD_MEM_1;
            addr_ack <= 1'b1;//新地址数据读取应答
            rd_ddr3_addr <= burst_addr;//输出ddr3burst读取地址
            pixel_loac <= rd_fifo_ddr3_data[3:0];//像素位置
            rd_ddr3_req <= 1'b1;//发出读请求
          end
          else//等待
            STATE <= S_RD_FIFO;
        end
      end

      S_RD_MEM_1://正在读ddr3 采样第一组数据
      begin
        addr_ack <= 1'b0;
        wr_fifo_pixel_en <= 1'b0;
        if(rd_ddr3_data_valid)
        begin
          STATE <= S_RD_MEM_2;
          rd_ddr3_req <= 1'b0;//数据有效后读请求拉低
          last_data[63:0] <= rd_ddr3_data;//更新数据缓存
          last_last_data <= last_data;
          last_addr <= rd_ddr3_addr;//更新burst读取使用的地址
          last_last_addr <= last_addr;
        end
      end
      
      S_RD_MEM_2://正在读ddr3 采样第二组数据
      begin
        if(rd_ddr3_data_valid)
        begin
          STATE <= S_RD_MEM_3;
          last_data[127:64] <= rd_ddr3_data;
        end
      end

      S_RD_MEM_3://正在读ddr3 采样第三组数据
      begin
        if(rd_ddr3_data_valid)
        begin
          STATE <= S_RD_MEM_4;
          last_data[191:128] <= rd_ddr3_data;
        end
      end

      S_RD_MEM_4://正在读ddr3 采样第四组数据
      begin
        if(rd_ddr3_data_valid)
        begin
          STATE <= S_WR_REQ;
          last_data[255:192] <= rd_ddr3_data;
        end
      end

      S_WR_REQ:
      begin
        addr_ack <= 1'b0;
        case(pixel_loac[3:0])//每次burst读出了16个像素，根据像素地址后四位进行数据采样
          4'd0://第一组
            wr_fifo_pixel_data <= last_data[15:0];
          4'd1:
            wr_fifo_pixel_data <= last_data[31:16];
          4'd2:
            wr_fifo_pixel_data <= last_data[47:32];
          4'd3:
            wr_fifo_pixel_data <= last_data[63:48];
          4'd4://第二组
            wr_fifo_pixel_data <= last_data[79:64];
          4'd5:
            wr_fifo_pixel_data <= last_data[95:80];
          4'd6:
            wr_fifo_pixel_data <= last_data[111:96];
          4'd7:
            wr_fifo_pixel_data <= last_data[127:112];
          4'd8://第三组
            wr_fifo_pixel_data <= last_data[143:128];
          4'd9:
            wr_fifo_pixel_data <= last_data[159:144];
          4'd10:
            wr_fifo_pixel_data <= last_data[175:160];
          4'd11:
            wr_fifo_pixel_data <= last_data[191:176];
          4'd12://第四组
            wr_fifo_pixel_data <= last_data[207:192];
          4'd13:
            wr_fifo_pixel_data <= last_data[223:208];
          4'd14:
            wr_fifo_pixel_data <= last_data[239:224];
          4'd15:
            wr_fifo_pixel_data <= last_data[255:240];
        endcase
        if(!wr_fifo_pixel_full)//fifo不满时请求写入
        begin
          STATE <= S_RD_FIFO;
          wr_fifo_pixel_en <= 1'b1;
        end
        else
          wr_fifo_pixel_en <= 1'b0;
      end
      
      S_WR_REQ_2:
      begin
        addr_ack <= 1'b0;
        if(!wr_fifo_pixel_full)//fifo不满时请求写入
        begin
          STATE <= S_RD_FIFO;
          wr_fifo_pixel_en <= 1'b1;
        end
        else
          wr_fifo_pixel_en <= 1'b0;
      end
      
      default: STATE <= S_RD_FIFO;
    endcase//case(STATE)
end


endmodule




