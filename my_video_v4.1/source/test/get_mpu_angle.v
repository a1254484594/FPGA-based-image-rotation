//获取角度数据
//测试OK
module get_mpu_angle
(
  input clk,
  input rst,
  
  input new_data_req,
  output reg [15:0] angle_data,
  output reg [15:0] angle_data_d0,
  
  input [7:0] fifo_data,
  input fifo_empty,
  output reg fifo_rd_en
);

reg new_data_req_d0;
always@(posedge clk or posedge rst)
begin
  if(rst == 1'b1) begin
    new_data_req_d0 <= 1'b0;
    angle_data_d0 <= 16'd0;
  end
  else begin
    new_data_req_d0 <= new_data_req;
    angle_data_d0 <= angle_data;
  end
end

reg [7:0] fifo_data_latch_d0;//锁存数据
reg [7:0] fifo_data_latch_d1;
reg [7:0] fifo_data_latch_d2;
always@(posedge clk or posedge rst)
begin
  if(rst == 1'b1) begin
    fifo_rd_en <= 1'b0;
    fifo_data_latch_d0 <= 8'd0;
    fifo_data_latch_d1 <= 8'd0;
    fifo_data_latch_d2 <= 8'd0;
  end
  else if(fifo_rd_en == 1'b1) begin//读取到FIFO数据
    fifo_rd_en <= 1'b0;
    fifo_data_latch_d0 <= fifo_data;//锁存数据
    fifo_data_latch_d1 <= fifo_data_latch_d0;
    fifo_data_latch_d2 <= fifo_data_latch_d1;
  end
  else if(fifo_empty == 1'b0) begin//不为空时发出读请求
    fifo_rd_en <= 1'b1;
  end
  else begin
    fifo_data_latch_d0 <= fifo_data_latch_d0;
    fifo_data_latch_d1 <= fifo_data_latch_d1;
    fifo_data_latch_d2 <= fifo_data_latch_d2;
  end
end

reg [15:0] new_angle_data;
always@(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
    new_angle_data <= 16'd0;
  else if((fifo_data == 8'h0a) && (fifo_data_latch_d0 == 8'h0d))//读取到数据结尾
    new_angle_data <= {fifo_data_latch_d2,fifo_data_latch_d1};
  else
    new_angle_data <= new_angle_data;
end

always@(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
    angle_data <= 16'd0;
  else if(~new_data_req & new_data_req_d0)//请求下降沿后更新数据
    angle_data <= new_angle_data;
end



endmodule

