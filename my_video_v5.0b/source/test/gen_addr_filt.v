//产生带滤波的旋转图像像素地址和滤波权值
module gen_addr_filt
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
  
  input addr_fifo_full,
  output reg [25:0] x2_y2,//[25:17]块x地址 [16:15]L在块中位置 [14:13]R [12:4]块y地址 [3:2]T [1:0]B
  output reg [15:0] decimal,
  output wr_en
);

localparam signed [10:0] H_X_SIZE = -X_SIZE/2;//OK
localparam signed [10:0] H_Y_SIZE = -Y_SIZE/2;


//分频
reg [2:0] div_state;
localparam s_H  = 3'b100;
localparam s_L0 = 3'b010;
localparam s_L1 = 3'b001;
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
  else if(~addr_fifo_full & div_state[2])//FIFO不满时可以写入
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
reg new_addr_valid_d3;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    new_addr_valid_d0 <= 1'b0;
    new_addr_valid_d1 <= 1'b0;
    new_addr_valid_d2 <= 1'b0;
    new_addr_valid_d3 <= 1'b0;
  end
  else
  begin
    new_addr_valid_d0 <= new_addr_valid;
    new_addr_valid_d1 <= new_addr_valid_d0;
    new_addr_valid_d2 <= new_addr_valid_d1;
    new_addr_valid_d3 <= new_addr_valid_d2;
  end
end

// p1   new_addr_valid_d1===============================================================
//计算像素坐标和权重
reg signed [19:0] addr_x_L,addr_x_R;//周边四个像素的地址
reg signed [19:0] addr_y_T,addr_y_B;
reg [7:0] decimal_col;//小数部分
reg [7:0] decimal_row;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    addr_x_L <= 20'd0;
    addr_x_R <= 20'd0;
    addr_y_T <= 20'd0;
    addr_y_B <= 20'd0;
    decimal_col <= 8'd0;
    decimal_row <= 8'd0;
  end
  else if(new_addr_valid_d1)
  begin
    addr_x_L <= $signed(col_buf[32:14]) + X_OFFSET;//舍去后14位
    addr_y_T <= $signed(row_buf[32:14]) + Y_OFFSET;
    addr_x_R <= $signed(col_buf[32:14]) + X_OFFSET+1;
    addr_y_B <= $signed(row_buf[32:14]) + Y_OFFSET+1;
    decimal_col <= col_buf[14:7];//取小数部分再舍去后6位
    decimal_row <= row_buf[14:7];
  end
end


// p2   new_addr_valid_d2===============================================================
//判断是否在同一个像素块里
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    x2_y2 <= 26'd0;
    decimal <= 16'd0;
  end
  else if(new_addr_valid_d2)
  begin
    decimal <= {decimal_col,decimal_row};
    if(addr_x_L[10:2] == addr_x_R[10:2])//在同一个像素块里
      x2_y2[25:13] <= {addr_x_L[10:2],addr_x_L[1:0],addr_x_R[1:0]};
    else
      x2_y2[25:13] <= {addr_x_L[10:2],addr_x_L[1:0],addr_x_L[1:0]};
      
    if(addr_y_T[10:2] == addr_y_B[10:2])//在同一个像素块里
      x2_y2[12:0] <= {addr_y_T[10:2],addr_y_T[1:0],addr_y_B[1:0]};
    else
      x2_y2[12:0] <= {addr_y_T[10:2],addr_y_T[1:0],addr_y_T[1:0]};
  end
  else
  begin
    x2_y2 <= x2_y2;
    decimal <= decimal;
  end
end


// output   new_addr_valid_d3===============================================================
assign wr_en = new_addr_valid_d3;


endmodule





