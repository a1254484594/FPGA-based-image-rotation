module key_adj_angle
(
  input clk,
  input rst,
  input inc,//加
  input dec,//减

  input [15:0] angle_in,
  output reg [15:0] angle_adj//用按键调整过的角度值
);

//根据按键调整角度
reg [15:0] angle_offset;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
    angle_offset <= 16'd0;
  else if(dec)
    angle_offset <= angle_offset - 16'd1;
  else if(inc)
    angle_offset <= angle_offset + 16'd1;
  else if(angle_offset > 16'd1439) begin
    if(angle_offset > 16'd1500)
      angle_offset <= 16'd1439;
    else
      angle_offset <= 16'd0;
  end
  else
    angle_offset <= angle_offset;
end


reg [15:0] temp;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
    temp <= 16'd0;
  else
    temp <= angle_in + angle_offset;

  if(rst == 1'b1)
    angle_adj <= 16'd0;
  else if(temp >16'd1439 )
    angle_adj <= temp - 16'd1440;
  else
    angle_adj <= temp;
end



endmodule

