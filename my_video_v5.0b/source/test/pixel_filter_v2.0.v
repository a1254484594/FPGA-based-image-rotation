//直接输入4个像素和小数部分
//使用decimal中的值对像素进行滤波
module pixel_filter
(
  input clk,
  input rst,
  
  input [63:0] pixelx4,
  input [15:0] decimal,
  input pixelx4_valid,
  
  output [15:0] wr_pixel,
  output wr_pixel_en
);
wire pipeline_start;
assign pipeline_start = pixelx4_valid;

reg [63:0] pixelx4_latch;
reg [15:0] decimal_latch;

wire [7:0] decimal_col;
wire [7:0] decimal_row;
assign decimal_col = decimal_latch[15:8];
assign decimal_row = decimal_latch[7:0 ];

//4个原始像素
wire [15:0] val11;
wire [15:0] val21;
wire [15:0] val12;
wire [15:0] val22;
assign val11 = pixelx4_latch[15:0];
assign val12 = pixelx4_latch[31:16];
assign val21 = pixelx4_latch[47:32];
assign val22 = pixelx4_latch[63:48];
//每个像素的三通道
wire signed [7:0] val11_r;//
wire signed [7:0] val11_g;
wire signed [7:0] val11_b;
wire signed [7:0] val21_r;//
wire signed [7:0] val21_g;
wire signed [7:0] val21_b;
wire signed [7:0] val12_r;//
wire signed [7:0] val12_g;
wire signed [7:0] val12_b;
wire signed [7:0] val22_r;//
wire signed [7:0] val22_g;
wire signed [7:0] val22_b;
assign val11_r = val11[15:11];
assign val11_g = val11[10:5];
assign val11_b = val21[4:0];
assign val21_r = val21[15:11];
assign val21_g = val21[10:5];
assign val21_b = val21[4:0];
assign val12_r = val12[15:11];
assign val12_g = val12[10:5];
assign val12_b = val12[4:0];
assign val22_r = val22[15:11];
assign val22_g = val22[10:5];
assign val22_b = val22[4:0];

//锁存数据
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    pixelx4_latch <= 64'd0;
    decimal_latch <= 16'd0;
  end
  else if(pipeline_start == 1'b1)
  begin
    pixelx4_latch <= pixelx4;
    decimal_latch[15:8] <= 8'hff - decimal[15:8];//col
    decimal_latch[7:0] <= 8'hff - decimal[7:0];//row
  end
end


//流水线
reg pipeline_s0;
reg pipeline_s1;
reg pipeline_s2;
reg pipeline_s3;
reg pipeline_s4;
reg pipeline_s5;
reg pipeline_s6;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1) begin
    pipeline_s0 <= 1'b0;
    pipeline_s1 <= 1'b0;
    pipeline_s2 <= 1'b0;
    pipeline_s3 <= 1'b0;
    pipeline_s4 <= 1'b0;
    pipeline_s5 <= 1'b0;
    pipeline_s6 <= 1'b0;
  end
  else begin
    pipeline_s0 <= pipeline_start;
    pipeline_s1 <= pipeline_s0;
    pipeline_s2 <= pipeline_s1;
    pipeline_s3 <= pipeline_s2;
    pipeline_s4 <= pipeline_s3;
    pipeline_s5 <= pipeline_s4;
    pipeline_s6 <= pipeline_s5;
  end
end


//锁存流水线用到的原始数据
reg signed [7:0] val11_r_d1,val11_r_d2;//
reg signed [7:0] val11_g_d1,val11_g_d2;
reg signed [7:0] val11_b_d1,val11_b_d2;
reg signed [7:0] val21_r_d1,val21_r_d2;//
reg signed [7:0] val21_g_d1,val21_g_d2;
reg signed [7:0] val21_b_d1,val21_b_d2;
reg signed [7:0] val12_r_d1,val12_r_d2;//
reg signed [7:0] val12_g_d1,val12_g_d2;
reg signed [7:0] val12_b_d1,val12_b_d2;
reg signed [7:0] val22_r_d1,val22_r_d2;//
reg signed [7:0] val22_g_d1,val22_g_d2;
reg signed [7:0] val22_b_d1,val22_b_d2;
reg [7:0] decimal_col_d1,decimal_col_d2,decimal_col_d3,decimal_col_d4;
reg [7:0] decimal_row_d1,decimal_row_d2,decimal_row_d3,decimal_row_d4;
always @(posedge clk)
begin
  //val11
  val11_r_d1 <= val11_r;
  val11_r_d2 <= val11_r_d1;
  val11_g_d1 <= val11_g;
  val11_g_d2 <= val11_g_d1;
  val11_b_d1 <= val11_b;
  val11_b_d2 <= val11_b_d1;
  //val21
  val21_r_d1 <= val21_r;
  val21_r_d2 <= val21_r_d1;
  val21_g_d1 <= val21_g;
  val21_g_d2 <= val21_g_d1;
  val21_b_d1 <= val21_b;
  val21_b_d2 <= val21_b_d1;
  //val12
  val12_r_d1 <= val12_r;
  val12_r_d2 <= val12_r_d1;
  val12_g_d1 <= val12_g;
  val12_g_d2 <= val12_g_d1;
  val12_b_d1 <= val12_b;
  val12_b_d2 <= val12_b_d1;
  //val22
  val22_r_d1 <= val22_r;
  val22_r_d2 <= val22_r_d1;
  val22_g_d1 <= val22_g;
  val22_g_d2 <= val22_g_d1;
  val22_b_d1 <= val22_b;
  val22_b_d2 <= val22_b_d1;
  
  //decimal_col
  decimal_col_d1 <= decimal_col;
  decimal_col_d2 <= decimal_col_d1;
  decimal_col_d3 <= decimal_col_d2;
  decimal_col_d4 <= decimal_col_d3;
  //decimal_row
  decimal_row_d1 <= decimal_row;
  decimal_row_d2 <= decimal_row_d1;
  decimal_row_d3 <= decimal_row_d2;
  decimal_row_d4 <= decimal_row_d3;
end


//pipeline_s0
//(val21 - val11)  (val22 - val12) ===========================================================
reg signed [7:0] val21_sub_val11_r;//(val21 - val11)  =N1
reg signed [7:0] val21_sub_val11_g;
reg signed [7:0] val21_sub_val11_b;
reg signed [7:0] val22_sub_val12_r;//(val22 - val12)
reg signed [7:0] val22_sub_val12_g;
reg signed [7:0] val22_sub_val12_b;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    val21_sub_val11_r <= 8'd0;
    val21_sub_val11_g <= 8'd0;
    val21_sub_val11_b <= 8'd0;
    val22_sub_val12_r <= 8'd0;
    val22_sub_val12_g <= 8'd0;
    val22_sub_val12_b <= 8'd0;
  end
  else if(pipeline_s0)
  begin
    val21_sub_val11_r <= val21_r - val11_r;
    val21_sub_val11_g <= val21_g - val11_g;
    val21_sub_val11_b <= val21_b - val11_b;
    val22_sub_val12_r <= val22_r - val12_r;
    val22_sub_val12_g <= val22_g - val12_g;
    val22_sub_val12_b <= val22_b - val12_b;
  end
end

//pipeline_s1
//* decimal_row * decimal_row  =============================================================
wire signed [15:0] val21_sub_val11_M_decimal_row_r;//(val21 - val11) * decimal_row  =N2
wire signed [15:0] val21_sub_val11_M_decimal_row_g;
wire signed [15:0] val21_sub_val11_M_decimal_row_b;
wire signed [15:0] val22_sub_val12_M_decimal_row_r;//(val22 - val12) * decimal_row
wire signed [15:0] val22_sub_val12_M_decimal_row_g;
wire signed [15:0] val22_sub_val12_M_decimal_row_b;
APM_s8_mult_us8 val21_mult_val11_r////
(
    .a(val21_sub_val11_r),
    .b(decimal_row_d1),
    .clk(clk),
    .rst(rst),
    .ce(pipeline_s1),
    .p(val21_sub_val11_M_decimal_row_r)
);
APM_s8_mult_us8 val21_mult_val11_g
(
    .a(val21_sub_val11_g),
    .b(decimal_row_d1),
    .clk(clk),
    .rst(rst),
    .ce(pipeline_s1),
    .p(val21_sub_val11_M_decimal_row_g)
);
APM_s8_mult_us8 val21_mult_val11_b
(
    .a(val21_sub_val11_b),
    .b(decimal_row_d1),
    .clk(clk),
    .rst(rst),
    .ce(pipeline_s1),
    .p(val21_sub_val11_M_decimal_row_b)
);
APM_s8_mult_us8 val22_mult_val12_r///
(
    .a(val22_sub_val12_r),
    .b(decimal_row_d1),
    .clk(clk),
    .rst(rst),
    .ce(pipeline_s1),
    .p(val22_sub_val12_M_decimal_row_r)
);
APM_s8_mult_us8 val22_mult_val12_g
(
    .a(val22_sub_val12_g),
    .b(decimal_row_d1),
    .clk(clk),
    .rst(rst),
    .ce(pipeline_s1),
    .p(val22_sub_val12_M_decimal_row_g)
);
APM_s8_mult_us8 val22_mult_val12_b
(
    .a(val22_sub_val12_b),
    .b(decimal_row_d1),
    .clk(clk),
    .rst(rst),
    .ce(pipeline_s1),
    .p(val22_sub_val12_M_decimal_row_b)
);


//pipeline_s2
//+bitshift(val11, 8, 'int64')   +bitshift(val12, 8, 'int64')   ===========================================================
reg signed [15:0] N3_1_r;//N2 + bitshift(val11, 8, 'int64') = temp_b
reg signed [15:0] N3_1_g;
reg signed [15:0] N3_1_b;
reg signed [15:0] N3_2_r;
reg signed [15:0] N3_2_g;
reg signed [15:0] N3_2_b;
reg signed [15:0] N3_1_r_d4,N3_1_r_d5;//temp_b锁存
reg signed [15:0] N3_1_g_d4,N3_1_g_d5;
reg signed [15:0] N3_1_b_d4,N3_1_b_d5;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    N3_1_r <= 16'd0;
    N3_1_g <= 16'd0;
    N3_1_b <= 16'd0;
    N3_2_r <= 16'd0;
    N3_2_g <= 16'd0;
    N3_2_b <= 16'd0;
  end
  else if(pipeline_s2 == 1'b1)
  begin
    N3_1_r <= val21_sub_val11_M_decimal_row_r + {val11_r_d2,8'd0};
    N3_1_g <= val21_sub_val11_M_decimal_row_g + {val11_g_d2,8'd0};
    N3_1_b <= val21_sub_val11_M_decimal_row_b + {val11_b_d2,8'd0};
    N3_2_r <= val22_sub_val12_M_decimal_row_r + {val12_r_d2,8'd0};
    N3_2_g <= val22_sub_val12_M_decimal_row_g + {val12_g_d2,8'd0};
    N3_2_b <= val22_sub_val12_M_decimal_row_b + {val12_b_d2,8'd0};
  end
end
always @(posedge clk)
begin
  N3_1_r_d4 <= N3_1_r;
  N3_1_r_d5 <= N3_1_r_d4;
  N3_1_g_d4 <= N3_1_g;
  N3_1_g_d5 <= N3_1_g_d4;
  N3_1_b_d4 <= N3_1_b;
  N3_1_b_d5 <= N3_1_b_d4;
end


//pipeline_s3
//   -temp_b  ===========================================================
reg signed [15:0] N4_r;//temp_a
reg signed [15:0] N4_g;
reg signed [15:0] N4_b;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    N4_r <= 16'd0;
    N4_g <= 16'd0;
    N4_b <= 16'd0;
  end
  else if(pipeline_s3 == 1'b1)
  begin
    N4_r <= N3_2_r - N3_1_r;
    N4_g <= N3_2_g - N3_1_g;
    N4_b <= N3_2_b - N3_1_b;
  end
end


//pipeline_s4
//temp_a * decimal_col ===========================================================
wire signed [23:0] N5_r;
wire signed [23:0] N5_g;
wire signed [23:0] N5_b;
APM_s16_mult_us8 temp_a_mult_decimal_col_r////
(
    .a(N4_r),
    .b(decimal_col_d4),
    .clk(clk),
    .rst(rst),
    .ce(pipeline_s4),
    .p(N5_r)
);
APM_s16_mult_us8 temp_a_mult_decimal_col_g////
(
    .a(N4_g),
    .b(decimal_col_d4),
    .clk(clk),
    .rst(rst),
    .ce(pipeline_s4),
    .p(N5_g)
);
APM_s16_mult_us8 temp_a_mult_decimal_col_b////
(
    .a(N4_b),
    .b(decimal_col_d4),
    .clk(clk),
    .rst(rst),
    .ce(pipeline_s4),
    .p(N5_b)
);



//pipeline_s5
//>>8 + temp_b  end  ===========================================================
reg signed [15:0] N6_r;
reg signed [15:0] N6_g;
reg signed [15:0] N6_b;
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    N6_r <= 16'd0;
    N6_g <= 16'd0;
    N6_b <= 16'd0;
  end
  else if(pipeline_s5 == 1'b1)
  begin
    N6_r <= N5_r[23:8] + N3_1_r_d5;
    N6_g <= N5_g[23:8] + N3_1_g_d5;
    N6_b <= N5_b[23:8] + N3_1_b_d5;
  end
end


//pipeline_s6
//  end  ===========================================================
wire [7:0] pixel_r;
wire [7:0] pixel_g;
wire [7:0] pixel_b;
assign pixel_r = N6_r[15:8];
assign pixel_g = N6_g[15:8];
assign pixel_b = N6_b[15:8];
assign wr_pixel = {pixel_r[4:0],pixel_g[5:0],pixel_b[4:0]};
assign wr_pixel_en = pipeline_s6;


////测试
//assign wr_pixel = pixelx4[15:0];
//assign wr_pixel_en = pixelx4_valid;


endmodule

