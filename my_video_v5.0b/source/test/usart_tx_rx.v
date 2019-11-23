//通过FIFO的串口发送接收
//测试OK
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
localparam B_CNT_MAX = (INPUT_CLK/BUDO)-1;//波特率计数器最大值

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
  if (!nrst) begin//复位
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
//读取txFIFO，控制tx
always @(posedge clk or negedge nrst) begin
  if (!nrst) begin//复位
    tx_ctrl <= 1'b0;
    tx_fifo_rd_en <= 1'b0;
    tx_data_latch <= 8'd0;
  end
  else if(tx_fifo_rd_en) begin//读取到FIFO数据,开始发送
    tx_ctrl <= 1'b1;
    tx_fifo_rd_en <= 1'b0;
    tx_data_latch <= tx_fifo_rd_data;//锁存数据
  end
  else if(~txdone_d0 & txdone) begin//txdone信号上升沿,一帧发送完成
    if(!tx_fifo_rd_empty_d2) begin//fifo不空时读取后继续发送
      tx_ctrl <= 1'b1;
      tx_fifo_rd_en <= 1'b1;
    end
    else begin//停止
      tx_ctrl <= 1'b0;
      tx_fifo_rd_en <= 1'b0;
    end
  end
  else if(~tx_ctrl) begin//空闲且FIFO不为空时读FIFO
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

reg [3:0]CS_TX;    //状态
reg [10:0]b_cnt; //用来产生波特率时钟
reg [10:0]tx_buf;//包含起始位与停止位的数据缓冲区
reg r_tx_pin;
//输出
always @(posedge clk or negedge nrst) begin
    if (!nrst) begin//复位
        CS_TX <= 'd0;
        b_cnt <= 'd0;
        tx_buf <= 'd0;
        r_tx_pin <= 1'b1;
    end
    else if (tx_ctrl) begin
        //各状态输出
        if (CS_TX == 'd0)//开始
            tx_buf <= {2'b11,tx_data_latch,1'b0};
        else //正在发送数据位、停止位
            tx_buf <= tx_buf;
        
        //输出引脚数据更新
        r_tx_pin <= tx_buf[CS_TX];
        //状态转移
        CS_TX_increase;
    end
    else
        r_tx_pin <= 1'b1;
end

//CS_TX依据波特率计数器自增，实现状态转移
task CS_TX_increase;
    if(CS_TX == 'd10) begin  //一帧完成 
        CS_TX <= 'd0;
        b_cnt <= 'd0;
    end
    else if (b_cnt == B_CNT_MAX) begin//计数满1bti的发送时间，转移到下一个bit，计数器清零
        CS_TX <= CS_TX + 1'b1;
        b_cnt <= 'd0;
    end
    else //计数中
        b_cnt <= b_cnt + 1'b1;
endtask

//驱动输出声明
assign tx_pin = r_tx_pin;
assign txdone = (CS_TX == 'd9);//开始发送停止位

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
    WAIT = 4'd12,   //等待起始位状态
    STARD= 4'd13,   //起始位
    END  = 4'd8,    //停止位
    D0 = 0, D1 = 1, D2 = 2, D3 = 3, D4 = 4, D5 = 5, D6 = 6, D7 = 7;//8bit数据

reg [3:0]CS_RX;    //状态
reg [10:0]b_cnt_rx; //用来产生波特率时钟

//状态转移逻辑
always @(posedge clk or negedge nrst) begin
    if (!nrst) begin//复位
        CS_RX <= WAIT;
        b_cnt_rx <= 'd0;
    end
    
    else if(rx_en) begin
        case(CS_RX)
            WAIT:/*等待起始位*/
                begin
                    if(!rx_pin) CS_RX <= STARD;//rx被拉低后进入起始位
                    else CS_RX <= CS_RX;
                end
            STARD:/*起始位*/
                begin
                     if (b_cnt_rx == B_CNT_MAX) begin//计数满1bti时间，计数器清零，进入第一bit的接收
                        CS_RX <= 4'd0; //转移到接收第一bit的状态
                        b_cnt_rx <= 'd0;
                    end
                    else begin //计数中
                        b_cnt_rx <= b_cnt_rx + 1'b1;
                        CS_RX <= CS_RX;
                    end
                end
            END:/*停止位*/
                begin
                    if (b_cnt_rx == B_CNT_MAX) begin//计数满1bti时间，计数器清零，进入等待状态
                        CS_RX <= WAIT; //转移到等待状态
                        b_cnt_rx <= 'd0;
                    end
                    else begin //计数中
                        b_cnt_rx <= b_cnt_rx + 1'b1;
                        CS_RX <= CS_RX;
                    end
                end
            D0,D1,D2,D3,D4,D5,D6,D7:/*采样数据*/
                begin
                    if (b_cnt_rx == B_CNT_MAX) begin//计数满1bti时间，计数器清零，进入下一bit
                        CS_RX <= CS_RX + 1'b1; //转移到下一bit
                        b_cnt_rx <= 'd0;
                    end
                    else begin //计数中
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

//根据CS_RX状态和b_cnt_rx计数器值采样rx_pin
always @(posedge clk or negedge nrst) begin
    if (!nrst) begin//复位
        rx_data_buf <= 8'd0;
        rx_done <= 1'b0;
    end
    else if (CS_RX < 'd8) begin
        rx_done <= 1'b0;
        if (b_cnt_rx == B_CNT_MAX/2)//在中点采样
            rx_data_buf[CS_RX] <= rx_pin;
        else
            rx_data_buf <= rx_data_buf;
    end
    else if (CS_RX == 'd8) begin
        if (b_cnt_rx == B_CNT_MAX/2) begin
            if (!rx_pin) //停止位错误
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
    if (!nrst)//复位
    		rx_done_d0 <= 1'b0;
    else
    		rx_done_d0 <= rx_done;
end
//写入FIFO
always @(posedge clk or negedge nrst) begin
    if (!nrst)//复位
    		wr_rx_en <= 1'b0;
    else if(~rx_done_d0 & rx_done)
    		wr_rx_en <= 1'b1;
    else
    		wr_rx_en <= 1'b0;
end

endmodule

