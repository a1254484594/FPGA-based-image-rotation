//�������ؿ��ַ
//ÿ���麬4*4������
//���ϲ���OK
module calculate_ddr3_addr_block
#
(
  parameter FRAME_X = 11'd1920,//ԭʼͼ���С
  parameter FRAME_Y = 11'd1080
)
(
  input clk,
  input rst,
  
  input [21:0] addr_x_y,//���ؿ��ַx=21:11,y=10:0
  input [23:0] frame_base_addr0,//֡��ַ
  input [23:0] frame_base_addr1,
  input [23:0] frame_base_addr2,
  input [23:0] frame_base_addr3,
  input [1:0]  base_addr_index,//��ַָ��
  input fifo_rd_empty,//����FIFOΪ��
  output reg fifo_rd_req,//fifo��ȡ����
  
  input fifo_wr_full,//��Ҫд���fifo��
  output reg [25:0] ddr3_addr,//ӳ�䵽ddr3�ϵĵ�ַ
  output reg wr_fifo_en
);

//״̬������
reg [2:0] STATE;
localparam S_IDLE       = 0;
localparam S_RD_WAIT    = 1;//��fifo�ȴ�
localparam S_RD_FIFO    = 2;//��fifo
localparam S_CALCULATE  = 3;//������
localparam S_WR_REQ     = 4;//����������д��fifo
localparam S_WR         = 5;//����д��fifo

wire [23:0] mult_out_buff;//�˷������
reg  [23:0] add1_out;//�ӷ���1����
reg  [23:0] frame_base_addr;//֡����ַ
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

//״̬ת��
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
    STATE <= S_IDLE;
  else
    case(STATE)
      S_IDLE:
        if(!fifo_rd_empty_d2)//fifo��Ϊ��ʱ��ʼ��
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
        if(!fifo_wr_full)//fifo����ʱ����д��
          STATE <= S_IDLE;
        else
          STATE <= S_WR_REQ;
      
      default:STATE <= S_IDLE;
    endcase
end

//״̬����
always @(posedge clk or posedge rst)
begin
  if(rst == 1'b1)
  begin
    fifo_rd_req <= 1'b0;
    mult_en <= 1'b0;
    wr_fifo_en <= 1'b0;
    add1_out <= 24'd0;
    ddr3_addr <= 24'd0;//
    //ѡ����Ч��ַ
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
        if(!fifo_rd_empty_d2)//fifo��Ϊ��ʱ��ʼ��
          fifo_rd_req <= 1'b1;
        else
          fifo_rd_req <= 1'b0;
      end
      S_RD_WAIT://�ȴ�fifo����
        fifo_rd_req <= 1'b0;
      S_RD_FIFO://�Ѿ���ȡ��fifo�е�������
      begin
        mult_en <= 1'b1;//��ʼ�˷�
        add1_out <= frame_base_addr + {addr_x_y[21:11],2'b00};//ÿ����ռ4����ַ
      end
      S_CALCULATE:
      begin
        mult_en <= 1'b0;//�˷����
        ddr3_addr <= mult_out_buff + add1_out;//���
      end
      S_WR_REQ:
      begin
        if(!fifo_wr_full)//fifo����ʱ����д��
          wr_fifo_en <= 1'b1;
        else
          wr_fifo_en <= 1'b0;
      end
    endcase
end

endmodule
