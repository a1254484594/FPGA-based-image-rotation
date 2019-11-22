//ͨ��FIFO�Ĵ��ڷ��ͽ���
//����OK
module usart_tx_rx
#
(
    parameter INPUT_CLK = 125000000,
    parameter BUDO = 115200
)
(
    input clk,
    input rst,
    input tx_en,
    input rx_en,
    
    input wr_tx_clk,
    input wr_tx_en,
    input [7:0] tx_data,
    output tx_fifo_full,
    
    input rd_rx_clk,
    input rd_rx_en,
    output [7:0] rx_data,
    output rx_fifo_empty,
    
    output tx_pin,
    input  rx_pin
);

wire nrst;
assign nrst = ~rst;
localparam B_CNT_MAX = (INPUT_CLK/BUDO)-1;//�����ʼ��������ֵ

wire tx_fifo_rd_empty;
wire [7:0] tx_fifo_rd_data;
reg tx_fifo_rd_en;
afifo_8in8out tx_fifo (
    .wr_data(tx_data),
    .wr_en(wr_tx_en),
    .wr_clk(wr_tx_clk),
    .full(),
    .wr_rst(rst),
    .almost_full(tx_fifo_full),
    .rd_data(tx_fifo_rd_data),
    .rd_en(tx_fifo_rd_en),
    .rd_clk(clk),
    .empty(tx_fifo_rd_empty),
    .rd_rst(rst),
    .almost_empty()
);

reg tx_fifo_rd_empty_d0;
reg tx_fifo_rd_empty_d1;
reg tx_fifo_rd_empty_d2;
wire txdone;
reg txdone_d0;
always @(posedge clk or negedge nrst) begin
  if (!nrst) begin//��λ
    tx_fifo_rd_empty_d0 <= 1'b1;
    tx_fifo_rd_empty_d1 <= 1'b1;
    tx_fifo_rd_empty_d2 <= 1'b1;
    txdone_d0 <= 1'b0;
  end
  else begin
    tx_fifo_rd_empty_d0 <= tx_fifo_rd_empty;
    tx_fifo_rd_empty_d1 <= tx_fifo_rd_empty_d0;
    tx_fifo_rd_empty_d2 <= tx_fifo_rd_empty_d1;
    txdone_d0 <= txdone;
  end
end

reg tx_ctrl;
reg [7:0] tx_data_latch;
//��ȡtxFIFO������tx
always @(posedge clk or negedge nrst) begin
  if (!nrst) begin//��λ
    tx_ctrl <= 1'b0;
    tx_fifo_rd_en <= 1'b0;
    tx_data_latch <= 8'd0;
  end
  else if(tx_fifo_rd_en) begin//��ȡ��FIFO����,��ʼ����
    tx_ctrl <= 1'b1;
    tx_fifo_rd_en <= 1'b0;
    tx_data_latch <= tx_fifo_rd_data;//��������
  end
  else if(~txdone_d0 & txdone) begin//txdone�ź�������,һ֡�������
    if(!tx_fifo_rd_empty_d2) begin//fifo����ʱ��ȡ���������
      tx_ctrl <= 1'b1;
      tx_fifo_rd_en <= 1'b1;
    end
    else begin//ֹͣ
      tx_ctrl <= 1'b0;
      tx_fifo_rd_en <= 1'b0;
    end
  end
  else if(~tx_ctrl) begin//������FIFO��Ϊ��ʱ��FIFO
  	if(~tx_fifo_rd_empty_d2 & tx_en) begin
	  	tx_ctrl <= 1'b0;
	    tx_fifo_rd_en <= 1'b1;
	  end
  end
  else begin
  	tx_ctrl <= tx_ctrl;
  	tx_fifo_rd_en <= tx_fifo_rd_en;
  end
end

reg [3:0]CS_TX;    //״̬
reg [10:0]b_cnt; //��������������ʱ��
reg [10:0]tx_buf;//������ʼλ��ֹͣλ�����ݻ�����
reg r_tx_pin;
//���
always @(posedge clk or negedge nrst) begin
    if (!nrst) begin//��λ
        CS_TX <= 'd0;
        b_cnt <= 'd0;
        tx_buf <= 'd0;
        r_tx_pin <= 1'b1;
    end
    else if (tx_ctrl) begin
        //��״̬���
        if (CS_TX == 'd0)//��ʼ
            tx_buf <= {2'b11,tx_data_latch,1'b0};
        else //���ڷ�������λ��ֹͣλ
            tx_buf <= tx_buf;
        
        //����������ݸ���
        r_tx_pin <= tx_buf[CS_TX];
        //״̬ת��
        CS_TX_increase;
    end
    else
        r_tx_pin <= 1'b1;
end

//CS_TX���ݲ����ʼ�����������ʵ��״̬ת��
task CS_TX_increase;
    if(CS_TX == 'd10) begin  //һ֡��� 
        CS_TX <= 'd0;
        b_cnt <= 'd0;
    end
    else if (b_cnt == B_CNT_MAX) begin//������1bti�ķ���ʱ�䣬ת�Ƶ���һ��bit������������
        CS_TX <= CS_TX + 1'b1;
        b_cnt <= 'd0;
    end
    else //������
        b_cnt <= b_cnt + 1'b1;
endtask

//�����������
assign tx_pin = r_tx_pin;
assign txdone = (CS_TX == 'd9);//��ʼ����ֹͣλ

//tx
/////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////
//rx

reg rx_done;
reg rx_done_d0;
reg wr_rx_en;
reg [7:0] rx_data_buf;
afifo_8in8out rx_fifo (
    .wr_data(rx_data_buf),
    .wr_en(wr_rx_en),
    .wr_clk(clk),
    .full(),
    .wr_rst(rst),
    .almost_full(),
    .rd_data(rx_data),
    .rd_en(rd_rx_en),
    .rd_clk(rd_rx_clk),
    .empty(rx_fifo_empty),
    .rd_rst(rst),
    .almost_empty()
);

parameter [3:0]
    WAIT = 4'd12,   //�ȴ���ʼλ״̬
    STARD= 4'd13,   //��ʼλ
    END  = 4'd8,    //ֹͣλ
    D0 = 0, D1 = 1, D2 = 2, D3 = 3, D4 = 4, D5 = 5, D6 = 6, D7 = 7;//8bit����

reg [3:0]CS_RX;    //״̬
reg [10:0]b_cnt_rx; //��������������ʱ��

//״̬ת���߼�
always @(posedge clk or negedge nrst) begin
    if (!nrst) begin//��λ
        CS_RX <= WAIT;
        b_cnt_rx <= 'd0;
    end
    
    else if(rx_en) begin
        case(CS_RX)
            WAIT:/*�ȴ���ʼλ*/
                begin
                    if(!rx_pin) CS_RX <= STARD;//rx�����ͺ������ʼλ
                    else CS_RX <= CS_RX;
                end
            STARD:/*��ʼλ*/
                begin
                     if (b_cnt_rx == B_CNT_MAX) begin//������1btiʱ�䣬���������㣬�����һbit�Ľ���
                        CS_RX <= 4'd0; //ת�Ƶ����յ�һbit��״̬
                        b_cnt_rx <= 'd0;
                    end
                    else begin //������
                        b_cnt_rx <= b_cnt_rx + 1'b1;
                        CS_RX <= CS_RX;
                    end
                end
            END:/*ֹͣλ*/
                begin
                    if (b_cnt_rx == B_CNT_MAX) begin//������1btiʱ�䣬���������㣬����ȴ�״̬
                        CS_RX <= WAIT; //ת�Ƶ��ȴ�״̬
                        b_cnt_rx <= 'd0;
                    end
                    else begin //������
                        b_cnt_rx <= b_cnt_rx + 1'b1;
                        CS_RX <= CS_RX;
                    end
                end
            D0,D1,D2,D3,D4,D5,D6,D7:/*��������*/
                begin
                    if (b_cnt_rx == B_CNT_MAX) begin//������1btiʱ�䣬���������㣬������һbit
                        CS_RX <= CS_RX + 1'b1; //ת�Ƶ���һbit
                        b_cnt_rx <= 'd0;
                    end
                    else begin //������
                        b_cnt_rx <= b_cnt_rx + 1'b1;
                        CS_RX <= CS_RX;
                    end
                end
            default:
                begin
                end
        endcase
    end //end else if (rx_en)
    
end

//����CS_RX״̬��b_cnt_rx������ֵ����rx_pin
always @(posedge clk or negedge nrst) begin
    if (!nrst) begin//��λ
        rx_data_buf <= 8'd0;
        rx_done <= 1'b0;
    end
    else if (CS_RX < 'd8) begin
        rx_done <= 1'b0;
        if (b_cnt_rx == B_CNT_MAX/2)//���е����
            rx_data_buf[CS_RX] <= rx_pin;
        else
            rx_data_buf <= rx_data_buf;
    end
    else if (CS_RX == 'd8) begin
        if (b_cnt_rx == B_CNT_MAX/2) begin
            if (!rx_pin) //ֹͣλ����
                rx_done <= 1'b0;
            else
                rx_done <= 1'b1;
        end
        else rx_done <= rx_done;
    end
    else begin
        rx_data_buf <= rx_data_buf;
        rx_done <= rx_done;
    end
end

always @(posedge clk or negedge nrst) begin
    if (!nrst)//��λ
    		rx_done_d0 <= 1'b0;
    else
    		rx_done_d0 <= rx_done;
end
//д��FIFO
always @(posedge clk or negedge nrst) begin
    if (!nrst)//��λ
    		wr_rx_en <= 1'b0;
    else if(~rx_done_d0 & rx_done)
    		wr_rx_en <= 1'b1;
    else
    		wr_rx_en <= 1'b0;
end

endmodule

