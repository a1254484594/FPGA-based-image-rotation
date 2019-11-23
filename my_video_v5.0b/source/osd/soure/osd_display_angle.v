//osd��ʾ�Ƕ�
//����OK
module osd_display_angle(
  input                       rst_n,
  input                       pclk,
  input [15:0]                angle,
  
  input                       i_hs,
  input                       i_vs,
  input                       i_de,
  input[23:0]                 i_data,
  output                      o_hs,
  output                      o_vs,
  output                      o_de,
  output[23:0]                o_data
);

parameter CHAR_WIDTH  =  12'd24;//�����ַ���
parameter CHAR_HEGIHT =  12'd36;
parameter CHAR_SIZE   =  16'd864;

wire[11:0] pos_x;
wire[11:0] pos_y;
wire       pos_hs;
wire       pos_vs;
wire       pos_de;
wire[23:0] pos_data;
reg[23:0]  v_data;
reg        region_active_c1;//��һ���ַ���Χ����Ч
reg        region_active_c2;//�ڶ�
reg        region_active_c3;
reg        region_active_c4;
reg        region_active_c5;
reg        region_active_c6;
wire       osd_region_active;
assign osd_region_active = region_active_c1|region_active_c2|region_active_c3|region_active_c4|region_active_c5|region_active_c6;

reg[15:0]  ram_addr_c1;//��һ���ַ���ַ
reg[15:0]  ram_addr_c2;
reg[15:0]  ram_addr_c3;
reg[15:0]  ram_addr_c4;
reg[15:0]  ram_addr_c5;
reg[15:0]  ram_addr_c6;

reg[15:0]  osd_ram_addr;//��ȡram�õĵ�ַ
wire[7:0]  q;//����������
reg [2:0]  osd_local;//osd����q�е�λ��


reg        pos_vs_d0;
reg        pos_vs_d1;
always@(posedge pclk)
begin
  pos_vs_d0 <= pos_vs;
  pos_vs_d1 <= pos_vs_d0;
end

assign o_data = v_data;
assign o_hs = pos_hs;
assign o_vs = pos_vs;
assign o_de = pos_de;
//��1���ַ�������
always@(posedge pclk)
begin
  if(pos_y >= 12'd9 && pos_y <= 12'd9 + CHAR_HEGIHT - 12'd1 &&  
     pos_x >= 12'd9 && pos_x  <= 12'd9 + CHAR_WIDTH - 12'd1)
    region_active_c1 <= 1'b1;
  else
    region_active_c1 <= 1'b0;
end
always@(posedge pclk)//��2
begin
  if(pos_y >= 12'd9 && pos_y <= 12'd9 + CHAR_HEGIHT - 12'd1 &&  
     pos_x >= 12'd9 + CHAR_WIDTH && pos_x  <= 12'd9 + CHAR_WIDTH*2 - 12'd1)
    region_active_c2 <= 1'b1;
  else
    region_active_c2 <= 1'b0;
end
always@(posedge pclk)
begin
  if(pos_y >= 12'd9 && pos_y <= 12'd9 + CHAR_HEGIHT - 12'd1 &&  
     pos_x >= 12'd9 + CHAR_WIDTH*2 && pos_x  <= 12'd9 + CHAR_WIDTH*3 - 12'd1)
    region_active_c3 <= 1'b1;
  else
    region_active_c3 <= 1'b0;
end
always@(posedge pclk)
begin
  if(pos_y >= 12'd9 && pos_y <= 12'd9 + CHAR_HEGIHT - 12'd1 && 
     pos_x >= 12'd9 + CHAR_WIDTH*3 && pos_x  <= 12'd1 + CHAR_WIDTH*4 - 12'd1)//�ַ�.��24
    region_active_c4 <= 1'b1;
  else
    region_active_c4 <= 1'b0;
end
always@(posedge pclk)
begin
  if(pos_y >= 12'd9 && pos_y <= 12'd9 + CHAR_HEGIHT - 12'd1 && 
     pos_x >= 12'd1 + CHAR_WIDTH*4 && pos_x  <= 12'd1 + CHAR_WIDTH*5 - 12'd1)
    region_active_c5 <= 1'b1;
  else
    region_active_c5 <= 1'b0;
end
always@(posedge pclk)
begin
  if(pos_y >= 12'd9 && pos_y <= 12'd9 + CHAR_HEGIHT - 12'd1 && 
     pos_x >= 12'd1 + CHAR_WIDTH*5 && pos_x  <= 12'd1 + CHAR_WIDTH*6 - 12'd1)
    region_active_c6 <= 1'b1;
  else
    region_active_c6 <= 1'b0;
end

//delay
reg osd_region_active_d0;
reg osd_region_active_d1;
always@(posedge pclk)
begin
  osd_region_active_d0 <= osd_region_active;
  osd_region_active_d1 <= osd_region_active_d0;
end


//�����Ƕ�
//reg [15:0] angle = 512;
wire [3:0] n_100;//��λ
wire [3:0] n_10;//ʮ
wire [3:0] n_1;
reg [3:0] n_01;
reg [3:0] n_001;
wire [11:0] outData;
Binary2BCD Binary2BCD_m0 (
    .clk      (pclk),
    .flash    (pos_vs_d0 == 1'b0 && pos_vs == 1'b1),//������
    .inData   (angle[11:2]),
    .outData  (outData)
);
assign n_100 = outData[11:8];
assign n_10  = outData[7:4];
assign n_1   = outData[3:0];
always@(posedge pclk)
begin
  if(pos_vs_d1 == 1'b0 && pos_vs_d0 == 1'b1)//������
  begin
    case(angle[1:0])
      2'd0:begin
        n_01  <= 4'd0;
        n_001 <= 4'd0;
      end
      2'd1:begin
        n_01  <= 4'd2;
        n_001 <= 4'd5;
      end
      2'd2:begin
        n_01  <= 4'd5;
        n_001 <= 4'd0;
      end
      2'd3:begin
        n_01  <= 4'd7;
        n_001 <= 4'd5;
      end
    endcase
  end
  else begin
    n_01  <= n_01;
    n_001 <= n_001;
  end
end


//ѡ���ַ���ʼ��ַ
always@(posedge pclk)
begin
  if(pos_vs_d1 == 1'b1 && pos_vs_d0 == 1'b0)//�½���
    ram_addr_c1 <= CHAR_SIZE*n_100;
  else if(region_active_c1 == 1'b1)
    ram_addr_c1 <= ram_addr_c1 + 16'd1;
end
always@(posedge pclk)
begin
  if(pos_vs_d1 == 1'b1 && pos_vs_d0 == 1'b0)
    ram_addr_c2 <= CHAR_SIZE*n_10;
  else if(region_active_c2 == 1'b1)
    ram_addr_c2 <= ram_addr_c2 + 16'd1;
end
always@(posedge pclk)
begin
  if(pos_vs_d1 == 1'b1 && pos_vs_d0 == 1'b0)
    ram_addr_c3<= CHAR_SIZE*n_1;
  else if(region_active_c3 == 1'b1)
    ram_addr_c3 <= ram_addr_c3 + 16'd1;
end
always@(posedge pclk)
begin
  if(pos_vs_d1 == 1'b1 && pos_vs_d0 == 1'b0)
    ram_addr_c4 <= CHAR_SIZE*10;//.
  else if(region_active_c4 == 1'b1)
    ram_addr_c4 <= ram_addr_c4 + 16'd1;
end
always@(posedge pclk)
begin
  if(pos_vs_d1 == 1'b1 && pos_vs_d0 == 1'b0)
    ram_addr_c5 <= CHAR_SIZE*n_01;
  else if(region_active_c5 == 1'b1)
    ram_addr_c5 <= ram_addr_c5 + 16'd1;
end
always@(posedge pclk)
begin
  if(pos_vs_d1 == 1'b1 && pos_vs_d0 == 1'b0)
    ram_addr_c6 <= CHAR_SIZE*n_001;
  else if(region_active_c6 == 1'b1)
    ram_addr_c6 <= ram_addr_c6 + 16'd1;
end




//ѡ���ַ
always@(posedge pclk)
begin
  if(pos_vs_d1 == 1'b1 && pos_vs_d0 == 1'b0)//�½��ظ�λ
    osd_ram_addr <= 16'd0;
  else if(region_active_c1 == 1'b1)
    osd_ram_addr <= ram_addr_c1;
  else if(region_active_c2 == 1'b1)
    osd_ram_addr <= ram_addr_c2;
  else if(region_active_c3 == 1'b1)
    osd_ram_addr <= ram_addr_c3;
  else if(region_active_c4 == 1'b1)
    osd_ram_addr <= ram_addr_c4;
  else if(region_active_c5 == 1'b1)
    osd_ram_addr <= ram_addr_c5;
  else if(region_active_c6 == 1'b1)
    osd_ram_addr <= ram_addr_c6;
end

always@(posedge pclk)
begin
  if(osd_region_active_d1 == 1'b1)
    osd_local <= osd_ram_addr[2:0];
  else
    osd_local <= 3'd0;
end

always@(posedge pclk)
begin
  if(osd_region_active_d1 == 1'b1)
    if(q[osd_local] == 1'b1)
      v_data <= 24'hfff000;//��ʾ�ַ������ص�
    else
      v_data <= pos_data;
  else
    v_data <= pos_data;
end

osd_rom osd_rom_m0 (
    .addr(osd_ram_addr[15:3]),//һ����ַ�ϵ�������8bit��һ��������1bit��ʾ
    .clk(pclk),
    .rst(1'b0),
    .rd_data(q));

//������ͬ����ͬ���źŲ�����������
timing_gen_xy timing_gen_xy_m0(
  .rst_n    (rst_n    ),
  .clk      (pclk     ),
  .i_hs     (i_hs     ),
  .i_vs     (i_vs     ),
  .i_de     (i_de     ),
  .i_data   (i_data   ),
  .o_hs     (pos_hs   ),
  .o_vs     (pos_vs   ),
  .o_de     (pos_de   ),
  .o_data   (pos_data ),
  .x        (pos_x    ),
  .y        (pos_y    )
);









endmodule



