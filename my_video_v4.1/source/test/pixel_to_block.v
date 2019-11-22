//ͼ��ת��Ϊ4*4�Ŀ��������
//���ϲ���OK
module pixel_to_block
#
(
  parameter LINE_SIZE = 1280//�д�С
)
(
  input pclk,
  input rst,
  input wr_in_en,
  input [15:0] pixel,
  
  output reg wr_out_en,
  output [63:0] pixel_4row //һ�����й�4������
);
//wire [15:0] p1;
//wire [15:0] p2;
//wire [15:0] p3;
//wire [15:0] p4;
//assign p1 = pixel_4row[63:48];
//assign p2 = pixel_4row[47:32];
//assign p3 = pixel_4row[31:16];
//assign p4 = pixel_4row[15:0 ];

reg wr_in_en_d0;
reg wr_in_en_d1;
reg wr_in_en_d2;
reg wr_in_en_d3;
always @(posedge pclk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    wr_in_en_d0 <= 1'b0;
    wr_in_en_d1 <= 1'b0;
    wr_in_en_d2 <= 1'b0;
    wr_in_en_d3 <= 1'b0;
  end
  else
  begin
    wr_in_en_d0 <= wr_in_en;
    wr_in_en_d1 <= wr_in_en_d0;
    wr_in_en_d2 <= wr_in_en_d1;
    wr_in_en_d3 <= wr_in_en_d2;
  end
end


reg rd_en;
linebuffer_Wapper#
(
  .no_of_lines(4),
  .samples_per_line(LINE_SIZE),
  .data_width(16)
)
linebuffer_Wapper_m0(
  .ce         (1'b1         ),
  .wr_clk     (pclk         ),
  .wr_en      (wr_in_en     ),
  .wr_rst     (rst          ),
  .data_in    (pixel        ),
  .rd_en      (wr_in_en_d3  ),
  .rd_clk     (pclk         ),
  .rd_rst     (rst          ),
  .data_out   (pixel_4row   )
);


reg wr_en;
always @(posedge pclk or posedge rst)
begin
  if(rst == 1'b1)
    wr_out_en <= 1'b0;
  else
    wr_out_en <= wr_en;
end


//�������
reg [12:0] state_cnt;
reg STATE;
localparam S_WAIT = 0;//�ȴ�
localparam S_RD   = 1;//����
always @(posedge pclk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    STATE <= S_WAIT;
    state_cnt <= 13'd0;
    wr_en <= 1'b0;
  end
  else
  begin
    case(STATE)
      S_WAIT:
      begin
        wr_en <= 1'b0;
        if(state_cnt == LINE_SIZE*3) begin//�ȴ������е�����
          STATE <= S_RD;
          state_cnt <= 13'd0;
        end
        else begin
          STATE <= S_WAIT;
          if(wr_in_en_d3 == 1'b1)
            state_cnt <= state_cnt + 13'd1;//��ȡ����
          else
            state_cnt <= state_cnt;
        end
      end
      
      S_RD:
      begin
        if(state_cnt == LINE_SIZE) begin//��ȡ���
          STATE <= S_WAIT;
          state_cnt <= 13'd0;
          wr_en <= 1'b0;
        end
        else begin
          STATE <= S_RD;
          if(wr_in_en_d3 == 1'b1) begin
            wr_en <= 1'b1;
            state_cnt <= state_cnt + 13'd1;//��ȡ����
          end
          else begin
            wr_en <= 1'b0;
            state_cnt <= state_cnt;
          end
        end
      end
    endcase
  end
end


endmodule