//产生旋转图像的像素读取地址
//需要Verilog2001编译才能正常运行，paango ads编译无法运行
module gen_raotation_addr
#
(
  parameter signed X_OFFSET = 11'd0,//图像中心偏置
  parameter signed Y_OFFSET = 11'd0,
  parameter X_SIZE = 11'd800,
  parameter Y_SIZE = 11'd480
)
(
  input clk,
  input rst,
  
  input signed [15:0] sin_a,//有符号数,原数值左移14位
  input signed [15:0] cos_a,
  
  input             addr_fifo_full,
  output reg        wr_en,
  output     [10:0] addr_x,
  output     [10:0] addr_y
);
localparam signed [10:0] H_X_SIZE = -X_SIZE/2;//OK
localparam signed [10:0] H_Y_SIZE = -Y_SIZE/2;

//分频
reg [3:0] div_state;
localparam s_H  = 4'b1000;
localparam s_L0 = 4'b0100;
localparam s_L1 = 4'b0010;
localparam s_L2 = 4'b0001;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
    div_state <= s_H;
  else
    case(div_state)
      s_H:
        div_state <= s_L0;
      s_L0:
        div_state <= s_L1;
      s_L1:
        div_state <= s_L2;
      s_L2:
        div_state <= s_H;
      default:
        div_state <= s_H;
    endcase
end

reg signed [10:0] new_addr_x;//新帧扫描地址
reg signed [10:0] new_addr_y;
reg frame_end;//帧结束
reg new_addr_valid;//新帧地址有效
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    new_addr_valid <= 1'b0;
    frame_end <= 1'b0;
    new_addr_x <= H_X_SIZE - 11'd1;
    new_addr_y <= H_Y_SIZE;
  end
  else if(frame_end)//一帧完成
  begin
    new_addr_valid <= 1'b0;
    new_addr_x <= new_addr_x;
    new_addr_y <= new_addr_y;
  end
  else if(~addr_fifo_full & div_state[3])//FIFO不满时可以写入
  begin
    if(new_addr_x == (X_SIZE/2 - 11'd1))
    begin
      if(new_addr_y == (Y_SIZE/2 - 11'd1))//一帧完成
      begin
        new_addr_valid <= 1'b0;
        new_addr_x <= new_addr_x;
        new_addr_y <= new_addr_y;
        frame_end <= 1'b1;
      end
      else//一行完成
      begin
        new_addr_valid <= 1'b1;
        new_addr_x <= H_X_SIZE;
        new_addr_y <= $signed(new_addr_y) + $signed('d1);
        frame_end <= 1'b0;
      end
    end
    else
    begin
      new_addr_valid <= 1'b1;
      new_addr_x <= $signed(new_addr_x) + $signed('d1);
      new_addr_y <= new_addr_y;
      frame_end <= 1'b0;
    end
  end
  else
  begin
    new_addr_valid <= 1'b0;
    new_addr_x <= new_addr_x;
    new_addr_y <= new_addr_y;
  end
end

wire signed [32:0] col_buf;
wire signed [32:0] row_buf;
APM_multi_add_s16 col_APM_multi_add_s16 (
    .a0     (new_addr_x ),
    .a1     (new_addr_y ),
    .b0     (cos_a      ),
    .b1     (sin_a      ),
    .clk    (clk        ),
    .rst    (rst        ),
    .ce     (new_addr_valid),
    .addsub (1'b1),
    .p      (col_buf)
);

APM_multi_add_s16 row_APM_multi_add_s16 (
    .a0     (new_addr_y ),
    .a1     (new_addr_x ),
    .b0     (cos_a      ),
    .b1     (sin_a      ),
    .clk    (clk        ),
    .rst    (rst        ),
    .ce     (new_addr_valid),
    .addsub (1'b0),
    .p      (row_buf)
);

//延迟
reg new_addr_valid_d0;
reg new_addr_valid_d1;
reg new_addr_valid_d2;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    new_addr_valid_d0 <= 1'b0;
    new_addr_valid_d1 <= 1'b0;
    new_addr_valid_d2 <= 1'b0;
  end
  else
  begin
    new_addr_valid_d0 <= new_addr_valid;
    new_addr_valid_d1 <= new_addr_valid_d0;
    new_addr_valid_d2 <= new_addr_valid_d1;
  end
end

//输出
reg signed [19:0] output_addr_x;
reg signed [19:0] output_addr_y;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    wr_en <= 1'b0;
    output_addr_x <= 23'd0;
    output_addr_y <= 23'd0;
  end
  else if(new_addr_valid_d1)
  begin
    wr_en <= 1'b1;
    output_addr_x <= $signed(col_buf[32:14]) + X_OFFSET;//舍去后14位
    output_addr_y <= $signed(row_buf[32:14]) + Y_OFFSET;
  end
  else
  begin
    wr_en <= 1'b0;
    output_addr_x <= output_addr_x;
    output_addr_y <= output_addr_y;
  end
end
assign addr_x = output_addr_x[10:0];
assign addr_y = output_addr_y[10:0];

endmodule
