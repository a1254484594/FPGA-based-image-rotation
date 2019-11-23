//产生新帧信号
module gen_new_frame_sign
(
    input clk,
    input rst,
    input old_frame_finish,
    output reg new_frame,
    output reg [1:0] new_write_index,
    output reg [1:0] new_read_index
);

reg new_frame_d0;
reg new_frame_d1;
reg old_frame_finish_d0;
reg old_frame_finish_d1;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    new_frame_d0 <= 1'b0;
    new_frame_d1 <= 1'b0;
    old_frame_finish_d0 <= 1'b0;
    old_frame_finish_d1 <= 1'b0;
  end
  else
  begin
    new_frame_d0 <= new_frame;
    new_frame_d1 <= new_frame_d0;
    old_frame_finish_d0 <= old_frame_finish;
    old_frame_finish_d1 <= old_frame_finish_d0;
  end
end

always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
    new_frame <= 1'b1;
  else if(new_frame_d1 == 1'b1)
    new_frame <= 1'b0;
  else if(old_frame_finish_d0 == 1'b1)
    new_frame <= 1'b1;
  else
    new_frame <= new_frame;
end

//管理新帧地址指针new_base_addr_index
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    new_write_index <= 2'd0;
    new_read_index <= 2'd0;
  end
  else if(~new_frame_d0 & new_frame)
  begin
    new_read_index <= new_write_index;
    new_write_index <= new_write_index + 2'd1;
  end
  else
  begin
    new_read_index <= new_read_index;
    new_write_index <= new_write_index;
  end
end

endmodule
