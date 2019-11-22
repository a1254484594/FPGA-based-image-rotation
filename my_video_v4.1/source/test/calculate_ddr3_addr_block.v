//计算像素块地址
//每个块含4*4个像素
//板上测试OK
module calculate_ddr3_addr_block
#
(
  parameter FRAME_X = 11'd1920,//原始图像大小
  parameter FRAME_Y = 11'd1080
)
(
  input clk,
  input rst,
  
  input [21:0] addr_x_y,//像素块地址x=21:11,y=10:0
  input [23:0] frame_base_addr0,//帧基址
  input [23:0] frame_base_addr1,
  input [23:0] frame_base_addr2,
  input [23:0] frame_base_addr3,
  input [1:0]  base_addr_index,//基址指针
  input fifo_rd_empty,//输入FIFO为空
  output reg fifo_rd_req,//fifo读取请求
  
  input fifo_wr_full,//需要写入的fifo满
  output reg [25:0] ddr3_addr,//映射到ddr3上的地址
  output reg wr_fifo_en
);

//状态机定义
reg [2:0] STATE;
localparam S_IDLE       = 0;
localparam S_RD_WAIT    = 1;//读fifo等待
localparam S_RD_FIFO    = 2;//读fifo
localparam S_CALCULATE  = 3;//计算中
localparam S_WR_REQ     = 4;//计算结果请求写入fifo
localparam S_WR         = 5;//正在写入fifo

wire [23:0] mult_out_buff;//乘法器输出
reg  [23:0] add1_out;//加法器1数据
reg  [23:0] frame_base_addr;//帧基地址
reg mult_en;

reg fifo_rd_empty_d0;
reg fifo_rd_empty_d1;
reg fifo_rd_empty_d2;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    fifo_rd_empty_d0 <= 1'b1;
    fifo_rd_empty_d1 <= 1'b1;
    fifo_rd_empty_d2 <= 1'b1;
  end
  else
  begin
    fifo_rd_empty_d0 <= fifo_rd_empty;
    fifo_rd_empty_d1 <= fifo_rd_empty_d0;
    fifo_rd_empty_d2 <= fifo_rd_empty_d1;
  end
end

APM_11mult11 my_APM_11mult11 (
    .a    (addr_x_y[10:0] ),//y
    .b    (FRAME_X        ),
    .clk  (clk            ),
    .rst  (rst            ),
    .ce   (mult_en        ),
    .p    (mult_out_buff  )
);

//状态转移
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
    STATE <= S_IDLE;
  else
    case(STATE)
      S_IDLE:
        if(!fifo_rd_empty_d2)//fifo不为空时开始读
          STATE <= S_RD_WAIT;
        else
          STATE <= S_IDLE;
      S_RD_WAIT:
        STATE <= S_RD_FIFO;
      S_RD_FIFO:
        STATE <= S_CALCULATE;
      S_CALCULATE:
        STATE <= S_WR_REQ;
      S_WR_REQ:
        if(!fifo_wr_full)//fifo不满时可以写入
          STATE <= S_IDLE;
        else
          STATE <= S_WR_REQ;
      
      default:STATE <= S_IDLE;
    endcase
end

//状态任务
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    fifo_rd_req <= 1'b0;
    mult_en <= 1'b0;
    wr_fifo_en <= 1'b0;
    add1_out <= 24'd0;
    ddr3_addr <= 24'd0;//
    //选择有效基址
    if(base_addr_index == 2'd0)     
      frame_base_addr <= frame_base_addr0;
    else if(base_addr_index == 2'd1)
      frame_base_addr <= frame_base_addr1;
    else if(base_addr_index == 2'd2)
      frame_base_addr <= frame_base_addr2;
    else if(base_addr_index == 2'd3)
      frame_base_addr <= frame_base_addr3;
      
  end
  else
    case(STATE)
      S_IDLE:
      begin
        wr_fifo_en <= 1'b0;
        if(!fifo_rd_empty_d2)//fifo不为空时开始读
          fifo_rd_req <= 1'b1;
        else
          fifo_rd_req <= 1'b0;
      end
      S_RD_WAIT://等待fifo数据
        fifo_rd_req <= 1'b0;
      S_RD_FIFO://已经读取到fifo中的数据了
      begin
        mult_en <= 1'b1;//开始乘法
        add1_out <= frame_base_addr + {addr_x_y[21:11],2'b00};//每个块占4个地址
      end
      S_CALCULATE:
      begin
        mult_en <= 1'b0;//乘法完成
        ddr3_addr <= mult_out_buff + add1_out;//输出
      end
      S_WR_REQ:
      begin
        if(!fifo_wr_full)//fifo不满时请求写入
          wr_fifo_en <= 1'b1;
        else
          wr_fifo_en <= 1'b0;
      end
    endcase
end

endmodule
