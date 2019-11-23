//////////////////////////////////////////////////////////////////////////////////
//  ov5640 lcd display                                                          //
//                                                                              //
//  Author: lhj                                                                 //
//                                                                              //
//          ALINX(shanghai) Technology Co.,Ltd                                  //
//          heijin                                                              //
//     WEB: http://www.alinx.cn/                                                //
//     BBS: http://www.heijin.org/                                              //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// Copyright (c) 2017,ALINX(shanghai) Technology Co.,Ltd                        //
//                    All rights reserved                                       //
//                                                                              //
// This source file may be used and distributed without restriction provided    //
// that this copyright statement is not removed from the file and that any      //
// derivative work contains the original copyright notice and the associated    //
// disclaimer.                                                                  //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//  2018/01/11     lhj          1.0         Original
//*******************************************************************************/
//  2019/11/16     zzl          5.0b
//单像素读使用axi port2，连续读出写入使用port1
//单像素读出整帧写入分辨率800*600
//测试OK！新帧写入使用axi port2时有bug
//角度读取OK
//任意角度旋转
//原图像使用块方式储存，提高帧率，测试OK
//按键设置旋转角度
//双线性插值OK
module top(

    input            key1,
    input            key3,
    input            key4,
    output           led,
    output           led_2,
    output           tx_pin,
    input            rx_pin,
    output           mpu_tx_pin,
    input            mpu_rx_pin,
    ///////////////
    input                       sys_clk,
    input                       rst_n,
    inout                       cmos_scl,         
    inout                       cmos_sda,         
    input                       cmos_vsync,       
    input                       cmos_href,        
    input                       cmos_pclk,         
    output                      cmos_xclk,         
    input[7:0]                  cmos_db,
    //ddr                                                           
    //output reg                           clk_led                ,
    //output                               pll_lock               ,
    //output                               ddr_init_done          ,
    //output                               ddrphy_rst_done        ,                                                                                                                          
    input                                pad_loop_in            ,
    input                                pad_loop_in_h          ,
    output                               pad_rstn_ch0           ,
    output                               pad_ddr_clk_w          ,
    output                               pad_ddr_clkn_w         ,
    output                               pad_csn_ch0            ,
    output [15:0]                        pad_addr_ch0           ,
    inout  [16-1:0]                      pad_dq_ch0             ,
    inout  [16/8-1:0]                    pad_dqs_ch0            ,
    inout  [16/8-1:0]                    pad_dqsn_ch0           ,
    output [16/8-1:0]                    pad_dm_rdqs_ch0        ,
    output                               pad_cke_ch0            ,
    output                               pad_odt_ch0            ,
    output                               pad_rasn_ch0           ,
    output                               pad_casn_ch0           ,
    output                               pad_wen_ch0            ,
    output [2:0]                         pad_ba_ch0             ,
    output                               pad_loop_out           ,
    output                               pad_loop_out_h         ,
    //output                               err_flag,   
    //hdmi output        
    output                             tmds_clk_p,
    output                             tmds_clk_n,
    output[2:0]                        tmds_data_p,       
    output[2:0]                        tmds_data_n                       
);
assign led_2 = ~wr_test_data_req;
assign led = tx_pin;
parameter MEM_DATA_BITS          = 64;             //external memory user interface data width
parameter ADDR_BITS              = 25;             //external memory user interface address width
parameter BUSRT_BITS             = 10;             //external memory user interface burst width
wire                            wr_burst_data_req;
wire                            wr_burst_finish;
wire                            rd_burst_finish;
wire                            rd_burst_req;
wire                            wr_burst_req;
wire[BUSRT_BITS - 1:0]          rd_burst_len;
wire[BUSRT_BITS - 1:0]          wr_burst_len;
wire[ADDR_BITS - 1:0]           rd_burst_addr;
wire[ADDR_BITS - 1:0]           wr_burst_addr;
wire                            rd_burst_data_valid;
wire[MEM_DATA_BITS - 1 : 0]     rd_burst_data;
wire[MEM_DATA_BITS - 1 : 0]     wr_burst_data;

wire                ddr3_wr_ing_ch;
wire                ddr3_rd_ing_ch;
wire                ddr3_wr_ready;
wire                ddr3_rd_ready;

wire                            read_req;
wire                            read_req_ack;
wire                            read_en;
wire[15:0]                      read_data;
wire                            write_en;
wire[15:0]                      write_data;
wire                            write_req;
wire                            write_req_ack;
wire                            video_clk;         //video pixel clock
wire                            video_clk5x;
wire                            hs;
wire                            vs;
wire                            de;
wire[15:0]                      vout_data;
wire[15:0]                      cmos_16bit_data;
wire                            cmos_16bit_wr;
wire[1:0]                       write_addr_index;
wire[1:0]                       read_addr_index;
wire[9:0]                       lut_index;
wire[31:0]                      lut_data;

wire                            ui_clk;
wire                            ui_clk_2;
wire                            ui_clk_sync_rst;
wire                            init_calib_complete;
// Master Write Address
wire [3:0]                      s00_axi_awid;
wire [63:0]                     s00_axi_awaddr;
wire [7:0]                      s00_axi_awlen;    // burst length: 0-255
wire [2:0]                      s00_axi_awsize;   // burst size: fixed 2'b011
wire [1:0]                      s00_axi_awburst;  // burst type: fixed 2'b01(incremental burst)
wire                            s00_axi_awlock;   // lock: fixed 2'b00
wire [3:0]                      s00_axi_awcache;  // cache: fiex 2'b0011
wire [2:0]                      s00_axi_awprot;   // protect: fixed 2'b000
wire [3:0]                      s00_axi_awqos;    // qos: fixed 2'b0000
wire [0:0]                      s00_axi_awuser;   // user: fixed 32'd0
wire                            s00_axi_awvalid;
wire                            s00_axi_awready;
// master write data
wire [63:0]                     s00_axi_wdata;
wire [7:0]                      s00_axi_wstrb;
wire                            s00_axi_wlast;
wire [0:0]                      s00_axi_wuser;
wire                            s00_axi_wvalid;
wire                            s00_axi_wready;
// master write response
wire [3:0]                      s00_axi_bid;
wire [1:0]                      s00_axi_bresp;
wire [0:0]                      s00_axi_buser;
wire                            s00_axi_bvalid;
wire                            s00_axi_bready;
// master read address
wire [3:0]                      s00_axi_arid;
wire [63:0]                     s00_axi_araddr;
wire [7:0]                      s00_axi_arlen;
wire [2:0]                      s00_axi_arsize;
wire [1:0]                      s00_axi_arburst;
wire [1:0]                      s00_axi_arlock;
wire [3:0]                      s00_axi_arcache;
wire [2:0]                      s00_axi_arprot;
wire [3:0]                      s00_axi_arqos;
wire [0:0]                      s00_axi_aruser;
wire                            s00_axi_arvalid;
wire                            s00_axi_arready;
// master read data
wire [3:0]                      s00_axi_rid;
wire [63:0]                     s00_axi_rdata;
wire [1:0]                      s00_axi_rresp;
wire                            s00_axi_rlast;
wire [0:0]                      s00_axi_ruser;
wire                            s00_axi_rvalid;
wire                            s00_axi_rready;
wire                            clk_200MHz;

//图像旋转读出写入用
// Master Write Address
wire [3:0]                      rotating_axi_awid;
wire [63:0]                     rotating_axi_awaddr;
wire [7:0]                      rotating_axi_awlen;    // burst length: 0-255
wire [2:0]                      rotating_axi_awsize;   // burst size: fixed 2'b011
wire [1:0]                      rotating_axi_awburst;  // burst type: fixed 2'b01(incremental burst)
wire                            rotating_axi_awlock;   // lock: fixed 2'b00
wire [3:0]                      rotating_axi_awcache;  // cache: fiex 2'b0011
wire [2:0]                      rotating_axi_awprot;   // protect: fixed 2'b000
wire [3:0]                      rotating_axi_awqos;    // qos: fixed 2'b0000
wire [0:0]                      rotating_axi_awuser;   // user: fixed 32'd0
wire                            rotating_axi_awvalid;
wire                            rotating_axi_awready;
// master write data
wire [63:0]                     rotating_axi_wdata;
wire [7:0]                      rotating_axi_wstrb;
wire                            rotating_axi_wlast;
wire [0:0]                      rotating_axi_wuser;
wire                            rotating_axi_wvalid;
wire                            rotating_axi_wready;
// master write response
wire [3:0]                      rotating_axi_bid;
wire [1:0]                      rotating_axi_bresp;
wire [0:0]                      rotating_axi_buser;
wire                            rotating_axi_bvalid;
wire                            rotating_axi_bready;
// master read address
wire [3:0]                      rotating_axi_arid;
wire [63:0]                     rotating_axi_araddr;
wire [7:0]                      rotating_axi_arlen;
wire [2:0]                      rotating_axi_arsize;
wire [1:0]                      rotating_axi_arburst;
wire [1:0]                      rotating_axi_arlock;
wire [3:0]                      rotating_axi_arcache;
wire [2:0]                      rotating_axi_arprot;
wire [3:0]                      rotating_axi_arqos;
wire [0:0]                      rotating_axi_aruser;
wire                            rotating_axi_arvalid;
wire                            rotating_axi_arready;
// master read data
wire [3:0]                      rotating_axi_rid;
wire [63:0]                     rotating_axi_rdata;
wire [1:0]                      rotating_axi_rresp;
wire                            rotating_axi_rlast;
wire [0:0]                      rotating_axi_ruser;
wire                            rotating_axi_rvalid;
wire                            rotating_axi_rready;

wire                            osd_hs;
wire                            osd_vs;
wire                            osd_de;
wire[23:0]                      osd_data;//叠加osd后的视频信号
wire                            hdmi_hs;
wire                            hdmi_vs;
wire                            hdmi_de;
wire[7:0]                       hdmi_r;
wire[7:0]                       hdmi_g;
wire[7:0]                       hdmi_b;
//叠加osd输出
assign  hdmi_hs    = osd_hs;
assign  hdmi_vs    = osd_vs;
assign  hdmi_de    = osd_de;
assign hdmi_r      = {osd_data[15:11],3'd0};
assign hdmi_g      = {osd_data[10:5],2'd0};
assign hdmi_b      = {osd_data[4:0],3'd0};
/*//原视频
assign hdmi_hs     = hs;
assign hdmi_vs     = vs;
assign hdmi_de     = de;
assign hdmi_r      = {vout_data[15:11],3'd0};
assign hdmi_g      = {vout_data[10:5],2'd0};
assign hdmi_b      = {vout_data[4:0],3'd0};
*/

assign write_en = cmos_16bit_wr;
assign write_data = {cmos_16bit_data[4:0],cmos_16bit_data[10:5],cmos_16bit_data[15:11]};


////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire button_posedge;
wire button_negedge;
wire                            wr_test_data_req;
wire                            rd_test_req;
wire                            wr_test_req;
wire[BUSRT_BITS - 1:0]          rd_test_len;
wire[BUSRT_BITS - 1:0]          wr_test_len;
wire[ADDR_BITS - 1:0]           rd_test_addr;
wire[ADDR_BITS - 1:0]           wr_test_addr;
wire[MEM_DATA_BITS - 1 : 0]     wr_test_data;
wire[MEM_DATA_BITS - 1 : 0]     rd_test_data;
wire                            wr_test_finish;
wire                            rd_test_data_valid;
wire                            rd_test_finish;
wire                            rd_test_ready;
ax_debounce ax_debounce_m0
(
    .clk             (ui_clk),
    .rst             (~rst_n),
    .button_in       (key1),
    .button_posedge  (button_posedge),//
    .button_negedge  (button_negedge),
    .button_out      ()
);
wire key3_button_negedge;
ax_debounce ax_debounce_m1
(
    .clk             (ui_clk),
    .rst             (~rst_n),
    .button_in       (key3),
    .button_posedge  (),//
    .button_negedge  (key3_button_negedge),
    .button_out      ()
);
wire key4_button_negedge;
ax_debounce ax_debounce_m2
(
    .clk             (ui_clk),
    .rst             (~rst_n),
    .button_in       (key4),
    .button_posedge  (),//
    .button_negedge  (key4_button_negedge),
    .button_out      ()
);

reg tx_wr_en;
reg [7:0] tx_wr_data;
wire [15:0] mydebug;

wire [10:0] x;
wire [10:0] y;
wire wr_en;

usart_tx_rx
#(
    .INPUT_CLK        (50000000),
    .BUDO             (115200)
)
usart_tx_rx (
    .clk        (sys_clk),
    .rst        (~rst_n),
    .tx_en      (1'b1),
    .rx_en      (1'b1),

    .wr_tx_clk      (ui_clk),
    .wr_tx_en       (tx_wr_en),
    .tx_data        (tx_wr_data),
    .tx_fifo_full   (),
//    .rd_rx_clk      (ui_clk),
//    .rd_rx_en       (rd_rx_en),
//    .rx_data        (rx_data),
//    .rx_fifo_empty  (rx_fifo_empty),
    .tx_pin    (tx_pin),
    .rx_pin    (rx_pin)
);

//管理发送
wire [7:0] pixel_read_debug;
reg [1:0] tx_wr_cnt;
always @(posedge ui_clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        tx_wr_data <= 8'd0;
        tx_wr_en <= 1'b0;
        tx_wr_cnt <= 2'd0;
    end
    else if(frame_write_finish) begin//frame_write_finish
        tx_wr_data <= mydebug[15:8];
        tx_wr_en <= 1'b1;
        tx_wr_cnt <= 2'd1;
    end
    else if(tx_wr_cnt == 2'd1) begin
        tx_wr_data <= mydebug[7:0];
        tx_wr_en <= 1'b1;
        tx_wr_cnt <= 2'd2;
    end
    else if(tx_wr_cnt == 2'd2) begin
        tx_wr_data <= 8'h44;
        tx_wr_en <= 1'b1;
        tx_wr_cnt <= 2'd3;
    end
    else if(tx_wr_cnt == 2'd3) begin
        tx_wr_data <= 8'h44;
        tx_wr_en <= 1'b1;
        tx_wr_cnt <= 2'd0;
    end
    else
        tx_wr_en <= 1'b0;
end

wire mpu_rd_rx_en;
wire mpu_rx_fifo_empty;
wire [7:0] mpu_rx_data;
//mpu串口
usart_tx_rx
#(
    .INPUT_CLK        (50000000),
    .BUDO             (115200)
)
usart_rx_mpu (
    .clk        (sys_clk),
    .rst        (~rst_n),
    .tx_en      (),
    .rx_en      (1'b1),

    .rd_rx_clk      (ui_clk),
    .rd_rx_en       (mpu_rd_rx_en),
    .rx_data        (mpu_rx_data),
    .rx_fifo_empty  (mpu_rx_fifo_empty),

    .tx_pin    (),//mpu_tx_pin
    .rx_pin    (mpu_rx_pin)
);

//根据原始帧信号获取角度数据
wire [15:0] angle_data;
reg [15:0] angle_data_latch;
get_mpu_angle get_mpu_angle (
    .clk    (ui_clk),
    .rst    (~rst_n),

    .new_data_req    (write_req),
    .fifo_data       (mpu_rx_data),
    .fifo_empty      (mpu_rx_fifo_empty),
    .fifo_rd_en      (mpu_rd_rx_en),
    .angle_data      (angle_data),
    .angle_data_d0   ()
);
//使用按键调整角度
wire [15:0] angle_adj;
key_adj_angle key_adj_angle (
    .clk    (ui_clk),
    .rst    (~rst_n),
    .inc(key4_button_negedge),
    .dec(key3_button_negedge),
    .angle_in(angle_data),
    .angle_adj(angle_adj)
);
//根据新帧信号锁存角度数据
always@(posedge ui_clk_2 or negedge rst_n) begin
    if(!rst_n)
        angle_data_latch <= 16'd0;
    else if(new_frame)
        angle_data_latch <= 16'd1440 - angle_adj;
    else
        angle_data_latch <= angle_data_latch;
end

wire signed [15:0] sin;
wire signed [15:0] coa;
//输出对应角度的三角函数值
lut_sin_cos lut_sin_cos
(
    .angle_div4  (angle_data_latch),
    .sin_data    (sin),
    .cos_data    (coa)
);

wire frame_write_finish;
wire addr_fifo_full;
wire new_frame;
localparam new_frame_base_addr0 = 24'd2073600;
localparam new_frame_base_addr1 = 24'd2592000;
localparam new_frame_base_addr2 = 24'd3110400;
localparam new_frame_base_addr3 = 24'd3628800;
localparam new_frame_len = 24'd120000;//帧长度=像素/4
wire [1:0] new_read_addr_index;//
wire [1:0] new_write_addr_index;//新帧写入地址指针


//产生新帧信号new_frame
gen_new_frame_sign gen_new_frame_sign
(
    .clk              (ui_clk_2),
    .rst              (~rst_n),
    .old_frame_finish (frame_write_finish),
    .new_frame        (new_frame),
    .new_write_index  (new_write_addr_index),//产生新帧写入地址
    .new_read_index   (new_read_addr_index)//产生新帧读出地址
);

wire [25:0] x2_y2;
wire [15:0] decimal_wr;
wire [63:0] write_pixel_data;
wire write_pixel_en;
wire wr_fifo_pixel_full;
//产生旋转图像地址和地址小数部分，双线性插值
gen_addr_filt
#
(
    .X_OFFSET  (640),//中心点偏置
    .Y_OFFSET  (480),
    .X_SIZE    (800),
    .Y_SIZE    (600)
)
gen_raotation_addr
(
    .clk    (ui_clk_2),
    .rst    (new_frame),

    .addr_fifo_full   (addr_fifo_full),
    .wr_en            (wr_en),
    .sin_a            (sin),//sin左移16位
    .cos_a            (coa),//coa
    .x2_y2            (x2_y2),
    .decimal          (decimal_wr)
);

//输入地址读出像素,块形式,用于滤波
wire [15:0] wr_decimal_data;
pixel_read_block_filt
#
(
    .FRAME_X    (11'd1280    ),
    .FRAME_Y    (11'd960     )
)
pixel_read
(
    .clk(ui_clk_2),
    .rst(new_frame),

    .x2_y2                 (x2_y2             ),
    .decimal               (decimal_wr        ),
    .frame_base_addr0      (24'd0            ),
    .frame_base_addr1      (24'd518400      ),
    .frame_base_addr2      (24'd1036800      ),
    .frame_base_addr3      (24'd1555200      ),
    .base_addr_index       (read_addr_index  ),
    .addr_wr_en            (wr_en            ),
    .addr_wr_almost_full   (addr_fifo_full   ),
    
    .wr_fifo_pixel_data   (write_pixel_data      ),//读出的像素数据
    .wr_decimal_data      (wr_decimal_data       ),//用于滤波
    .wr_fifo_pixel_en     (write_pixel_en        ),
    .wr_fifo_pixel_full   (wr_fifo_pixel_full    ),
    .debug                (mydebug               ),
    
    .rd_ddr3_req               (rd_test_req             ),
    .rd_ddr3_len               (rd_test_len             ),
    .rd_ddr3_addr              (rd_test_addr            ),
    .rd_ddr3_data_valid        (rd_test_data_valid      ),
    .rd_ddr3_data              (rd_test_data            ),
    .rd_ddr3_finish            (rd_test_finish          ),
    .rd_ddr3_ready             (rd_test_ready           )//rotating_axi_arready
);

wire wr_pixel_filt_en;
wire [15:0] wr_pixel_filt;//滤波后像素数据
//像素滤波
pixel_filter pixel_filter (
    .clk(ui_clk_2),
    .rst(new_frame),
    .pixelx4(write_pixel_data),
    .decimal(wr_decimal_data),
    .pixelx4_valid(write_pixel_en),

    .wr_pixel_en(wr_pixel_filt_en),
    .wr_pixel(wr_pixel_filt)
);

//像素输出重新写入ddr3控制器
frame_read_write frame_write_m0
(
  .rst                        (~rst_n                   ),
  .mem_clk                    (ui_clk                   ),
    
  .wr_burst_req               (wr_test_req             ),
  .wr_burst_len               (wr_test_len             ),
  .wr_burst_addr              (wr_test_addr            ),
  .wr_burst_data_req          (wr_test_data_req        ),
  .wr_burst_data              (wr_test_data            ),
  .wr_burst_finish            (wr_test_finish          ),
  .write_clk                  (ui_clk_2                ),
  .write_req                  (new_frame               ),//
  .write_req_ack              (             ),//
  .write_finish               (frame_write_finish           ),
  .write_addr_0               (new_frame_base_addr0         ),//
  .write_addr_1               (new_frame_base_addr1         ),
  .write_addr_2               (new_frame_base_addr2         ),
  .write_addr_3               (new_frame_base_addr3         ),
  .write_addr_index           (new_write_addr_index         ),
  .write_len                  (new_frame_len                ),
  .write_en                   (wr_pixel_filt_en            ),//write_pixel_en
  .write_data                 (wr_pixel_filt               ),//write_pixel_data
  .write_almost_full          (             )//wr_fifo_pixel_full
);

wire wr_block_en;
wire [63:0] pixel_4row_n;
wire [63:0] pixel_4row;
assign pixel_4row = {pixel_4row_n[15:0],pixel_4row_n[31:16],pixel_4row_n[47:32],pixel_4row_n[63:48]};
//原始图像转换为块形式写入
pixel_to_block pixel_to_block
(
    .pclk        (cmos_pclk),
    .rst         (write_req),
    .wr_in_en    (write_en),
    .pixel       (write_data),

    .wr_out_en    (wr_block_en),
    .pixel_4row   (pixel_4row_n)
);

//osd叠加显示
osd_display_angle  osd_display_angle(
  .rst_n                 (rst_n                      ),
  .pclk                  (video_clk                  ),
    .angle                 (angle_data_latch           ),//角度
  .i_hs                  (hs                         ),
  .i_vs                  (vs                         ),
  .i_de                  (de                         ),
  .i_data                (vout_data                  ),//原视频信号

  .o_hs                  (osd_hs                     ),
  .o_vs                  (osd_vs                     ),
  .o_de                  (osd_de                     ),
  .o_data                (osd_data                   )
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////

video_pll video_pll_m0
(
  .clkin1                    (sys_clk                  ),
  .clkout0                   (video_clk                ),
  .clkout1                   (video_clk5x              ),
  .clkout2                   (cmos_xclk                ),
  .pll_rst                   (1'b0                     ),
  .pll_lock                  (                         )
);

dvi_encoder dvi_encoder_m0
(
  .pixelclk      (video_clk          ),// system clock
  .pixelclk5x    (video_clk5x        ),// system clock x5
  .rstin         (~rst_n             ),// reset
  .blue_din      (hdmi_b            ),// Blue data in
  .green_din     (hdmi_g            ),// Green data in
  .red_din       (hdmi_r            ),// Red data in
  .hsync         (hdmi_hs           ),// hsync data
  .vsync         (hdmi_vs           ),// vsync data
  .de            (hdmi_de         ),// data enable
  .tmds_clk_p    (tmds_clk_p         ),
  .tmds_clk_n    (tmds_clk_n         ),
  .tmds_data_p   (tmds_data_p        ),//rgb
  .tmds_data_n   (tmds_data_n        ) //rgb
);

//I2C master controller
i2c_config i2c_config_m0(
  .rst                        (~rst_n                   ),
  .clk                        (sys_clk                  ),
  .clk_div_cnt                (16'd99                   ),
  .i2c_addr_2byte             (1'b1                     ),
  .lut_index                  (lut_index                ),
  .lut_dev_addr               (lut_data[31:24]          ),
  .lut_reg_addr               (lut_data[23:8]           ),
  .lut_reg_data               (lut_data[7:0]            ),
  .error                      (                         ),
  .done                       (                         ),
  .i2c_scl                    (cmos_scl                 ),
  .i2c_sda                    (cmos_sda                 )
);
//configure look-up table
lut_ov5640_rgb565_1280_960 lut_ov5640_rgb565_1280_960_m0(
  .lut_index                  (lut_index                ),
  .lut_data                   (lut_data                 )
);
//CMOS sensor 8bit data is converted to 16bit data
cmos_8_16bit cmos_8_16bit_m0(
  .rst                        (~rst_n                   ),
  .pclk                       (cmos_pclk                ),
  .pdata_i                    (cmos_db                  ),
  .de_i                       (cmos_href                ),
  .pdata_o                    (cmos_16bit_data          ),
  .hblank                     (                         ),
  .de_o                       (cmos_16bit_wr            )
);
//CMOS sensor writes the request and generates the read and write address index
cmos_write_req_gen cmos_write_req_gen_m0(
  .rst                        (~rst_n                   ),
  .pclk                       (cmos_pclk                ),
  .cmos_vsync                 (cmos_vsync               ),
  .write_req                  (write_req                ),
  .write_addr_index           (write_addr_index         ),
  .read_addr_index            (read_addr_index          ),
  .write_req_ack              (write_req_ack            )
);

//The video output timing generator and generate a frame read data request
video_timing_data video_timing_data_m0
(
  .video_clk                  (video_clk                ),
  .rst                        (~rst_n                   ),
  .read_req                   (read_req                 ),
  .read_req_ack               (read_req_ack             ),
  .read_en                    (read_en                  ),
  .read_data                  (read_data                ),
  .hs                         (hs                       ),
  .vs                         (vs                       ),
  .de                         (de                       ),
  .vout_data                  (vout_data                )
);


//video frame data read-write control
//写入接口64位宽
my_frame_read_write frame_read_write_m0
(
  .rst                        (~rst_n                   ),
  .mem_clk                    (ui_clk                   ),
  .rd_burst_req               (rd_burst_req             ),
  .rd_burst_len               (rd_burst_len             ),
  .rd_burst_addr              (rd_burst_addr            ),
  .rd_burst_data_valid        (rd_burst_data_valid      ),
  .rd_burst_data              (rd_burst_data            ),
  .rd_burst_finish            (rd_burst_finish          ),
  .read_clk                   (video_clk                ),
  .read_req                   (read_req                 ),
  .read_req_ack               (read_req_ack             ),
  .read_finish                (                         ),
  .read_addr_0                (new_frame_base_addr0            ), //读新帧
  .read_addr_1                (new_frame_base_addr1            ), 
  .read_addr_2                (new_frame_base_addr2            ),
  .read_addr_3                (new_frame_base_addr3            ),
  .read_addr_index            (new_read_addr_index             ),//new_read_addr_index
  .read_len                   (new_frame_len                   ),//frame size 
  .read_en                    (read_en                  ),
  .read_data                  (read_data                ),
    
  .wr_burst_req               (wr_burst_req             ),
  .wr_burst_len               (wr_burst_len             ),
  .wr_burst_addr              (wr_burst_addr            ),
  .wr_burst_data_req          (wr_burst_data_req        ),
  .wr_burst_data              (wr_burst_data            ),
  .wr_burst_finish            (wr_burst_finish          ),
  .write_clk                  (cmos_pclk                ),
  .write_req                  (write_req                ),//
  .write_req_ack              (write_req_ack            ),//
  .write_finish               (                         ),
  .write_addr_0               (24'd0                    ),//每帧储存空间预留1920*1080*16bit
  .write_addr_1               (24'd518400               ),
  .write_addr_2               (24'd1036800              ),
  .write_addr_3               (24'd1555200              ),
  .write_addr_index           (write_addr_index         ),
  .write_len                  (24'd307200               ), //frame size = 像素/4，因为每次burst写入64bit即4个像素
  .write_en                   (wr_block_en              ),//write_en
  .write_data                 (pixel_4row               ) //write_data
);


//多通道同时写入，测试ok
my_aq_axi_master u_aq_axi_master
  (
      .ARESETN                     (rst_n                                     ),
   // .ARESETN                     (~ui_clk_sync_rst                          ),
    .ACLK                        (ui_clk                                    ),
    .M_AXI_AWID                  (s00_axi_awid                              ),
    .M_AXI_AWADDR                (s00_axi_awaddr                            ),
    .M_AXI_AWLEN                 (s00_axi_awlen                             ),
    .M_AXI_AWSIZE                (s00_axi_awsize                            ),
    .M_AXI_AWBURST               (s00_axi_awburst                           ),
    .M_AXI_AWLOCK                (s00_axi_awlock                            ),
    .M_AXI_AWCACHE               (s00_axi_awcache                           ),
    .M_AXI_AWPROT                (s00_axi_awprot                            ),
    .M_AXI_AWQOS                 (s00_axi_awqos                             ),
    .M_AXI_AWUSER                (s00_axi_awuser                            ),
    .M_AXI_AWVALID               (s00_axi_awvalid                           ),
    .M_AXI_AWREADY               (s00_axi_awready                           ),
    .M_AXI_WDATA                 (s00_axi_wdata                             ),
    .M_AXI_WSTRB                 (s00_axi_wstrb                             ),
    .M_AXI_WLAST                 (s00_axi_wlast                             ),
    .M_AXI_WUSER                 (s00_axi_wuser                             ),
    .M_AXI_WVALID                (s00_axi_wvalid                            ),
    .M_AXI_WREADY                (s00_axi_wready                            ),
    .M_AXI_BID                   (s00_axi_bid                               ),
    .M_AXI_BRESP                 (s00_axi_bresp                             ),
    .M_AXI_BUSER                 (s00_axi_buser                             ),
    .M_AXI_BVALID                (s00_axi_bvalid                            ),
    .M_AXI_BREADY                (s00_axi_bready                            ),
    .M_AXI_ARID                  (s00_axi_arid                              ),
    .M_AXI_ARADDR                (s00_axi_araddr                            ),
    .M_AXI_ARLEN                 (s00_axi_arlen                             ),
    .M_AXI_ARSIZE                (s00_axi_arsize                            ),
    .M_AXI_ARBURST               (s00_axi_arburst                           ),
    .M_AXI_ARLOCK                (s00_axi_arlock                            ),
    .M_AXI_ARCACHE               (s00_axi_arcache                           ),
    .M_AXI_ARPROT                (s00_axi_arprot                            ),
    .M_AXI_ARQOS                 (s00_axi_arqos                             ),
    .M_AXI_ARUSER                (s00_axi_aruser                            ),
    .M_AXI_ARVALID               (s00_axi_arvalid                           ),
    .M_AXI_ARREADY               (s00_axi_arready                           ),
    .M_AXI_RID                   (s00_axi_rid                               ),
    .M_AXI_RDATA                 (s00_axi_rdata                             ),
    .M_AXI_RRESP                 (s00_axi_rresp                             ),
    .M_AXI_RLAST                 (s00_axi_rlast                             ),
    .M_AXI_RUSER                 (s00_axi_ruser                             ),
    .M_AXI_RVALID                (s00_axi_rvalid                            ),
    .M_AXI_RREADY                (s00_axi_rready                            ),
    .MASTER_RST                  (1'b0                                     ),

    .WR_FIFO_EMPTY               (1'b0                                     ),
    .WR_FIFO_AEMPTY              (1'b0                                     ),
    .WR_READY                    (                                         ),
    .MUX_wr                      (                          ),//通道指示

    .WR_START_1                    (   wr_test_req                          ),
    .WR_ADRS_1                     (   {wr_test_addr,3'd0}                  ),
    .WR_LEN_1                      (   {wr_test_len,3'd0}                   ),
    .WR_FIFO_DATA_1                (   wr_test_data                         ),
    .WR_FIFO_RE_1                  (   wr_test_data_req                     ),
    .WR_DONE_1                     (   wr_test_finish                       ),

    .WR_START_0                    (wr_burst_req                             ),
    .WR_ADRS_0                     ({wr_burst_addr,3'd0}                     ),
    .WR_LEN_0                      ({wr_burst_len,3'd0}                      ),
    .WR_FIFO_DATA_0                (wr_burst_data                            ),
    .WR_FIFO_RE_0                  (wr_burst_data_req                        ),
    .WR_DONE_0                     (wr_burst_finish                          ),

////////////////////////////
    .RD_FIFO_FULL                (1'b0                                     ),
    .RD_FIFO_AFULL               (1'b0                                     ),
    .RD_READY                    (                           ),
    .RD_FIFO_DATA                (rd_burst_data                            ),
    .MUX_rd                      (                          ),//通道指示

//    .RD_START_0                    (   rd_test_req                          ),
//    .RD_ADRS_0                     (   {rd_test_addr,3'b110}                ),//经测试，后三位完全没什么卵用，完全！
//    .RD_LEN_0                      (   {rd_test_len,3'd0}                   ),
//    .RD_FIFO_WE_0                  (   rd_test_data_valid                   ),
//    .RD_DONE_0                     (   rd_test_finish                       ),

    .RD_START_1                    (rd_burst_req                             ),
    .RD_ADRS_1                     ({rd_burst_addr,3'd0}                     ),
    .RD_LEN_1                      ({rd_burst_len,3'd0}                      ),
    .RD_FIFO_WE_1                  (rd_burst_data_valid                      ),
    .RD_DONE_1                     (rd_burst_finish                          ),

    .DEBUG                       (                                     )
);

//用于图像旋转的读出axi控制器
aq_axi_master rotating_aq_axi_master
(
      .ARESETN                     (rst_n                                     ),
   // .ARESETN                     (~ui_clk_sync_rst                          ),
    .ACLK                        (ui_clk_2                                    ),
    .M_AXI_AWID                  (rotating_axi_awid                              ),
    .M_AXI_AWADDR                (rotating_axi_awaddr                            ),
    .M_AXI_AWLEN                 (rotating_axi_awlen                             ),
    .M_AXI_AWSIZE                (rotating_axi_awsize                            ),
    .M_AXI_AWBURST               (rotating_axi_awburst                           ),
    .M_AXI_AWLOCK                (rotating_axi_awlock                            ),
    .M_AXI_AWCACHE               (rotating_axi_awcache                           ),
    .M_AXI_AWPROT                (rotating_axi_awprot                            ),
    .M_AXI_AWQOS                 (rotating_axi_awqos                             ),
    .M_AXI_AWUSER                (rotating_axi_awuser                            ),
    .M_AXI_AWVALID               (rotating_axi_awvalid                           ),
    .M_AXI_AWREADY               (rotating_axi_awready                           ),
    .M_AXI_WDATA                 (rotating_axi_wdata                             ),
    .M_AXI_WSTRB                 (rotating_axi_wstrb                             ),
    .M_AXI_WLAST                 (rotating_axi_wlast                             ),
    .M_AXI_WUSER                 (rotating_axi_wuser                             ),
    .M_AXI_WVALID                (rotating_axi_wvalid                            ),
    .M_AXI_WREADY                (rotating_axi_wready                            ),
    .M_AXI_BID                   (rotating_axi_bid                               ),
    .M_AXI_BRESP                 (rotating_axi_bresp                             ),
    .M_AXI_BUSER                 (rotating_axi_buser                             ),
    .M_AXI_BVALID                (rotating_axi_bvalid                            ),
    .M_AXI_BREADY                (rotating_axi_bready                            ),
    .M_AXI_ARID                  (rotating_axi_arid                              ),
    .M_AXI_ARADDR                (rotating_axi_araddr                            ),
    .M_AXI_ARLEN                 (rotating_axi_arlen                             ),
    .M_AXI_ARSIZE                (rotating_axi_arsize                            ),
    .M_AXI_ARBURST               (rotating_axi_arburst                           ),
    .M_AXI_ARLOCK                (rotating_axi_arlock                            ),
    .M_AXI_ARCACHE               (rotating_axi_arcache                           ),
    .M_AXI_ARPROT                (rotating_axi_arprot                            ),
    .M_AXI_ARQOS                 (rotating_axi_arqos                             ),
    .M_AXI_ARUSER                (rotating_axi_aruser                            ),
    .M_AXI_ARVALID               (rotating_axi_arvalid                           ),
    .M_AXI_ARREADY               (rotating_axi_arready                           ),
    .M_AXI_RID                   (rotating_axi_rid                               ),
    .M_AXI_RDATA                 (rotating_axi_rdata                             ),
    .M_AXI_RRESP                 (rotating_axi_rresp                             ),
    .M_AXI_RLAST                 (rotating_axi_rlast                             ),
    .M_AXI_RUSER                 (rotating_axi_ruser                             ),
    .M_AXI_RVALID                (rotating_axi_rvalid                            ),
    .M_AXI_RREADY                (rotating_axi_rready                            ),
    .MASTER_RST                  (1'b0                                     ),

//    .WR_START                    (wr_test_req                             ),
//    .WR_ADRS                     ({wr_test_addr,3'd0}                     ),
//    .WR_LEN                      ({wr_test_len,3'd0}                      ),
//    .WR_READY                    (wr_test_ready                           ),
//    .WR_FIFO_RE                  (wr_test_data_req                        ),
//    .WR_FIFO_EMPTY               (1'b0                                    ),
//    .WR_FIFO_AEMPTY              (1'b0                                    ),
//    .WR_FIFO_DATA                (wr_test_data                            ),
//    .WR_DONE                     (wr_test_finish                          ),
    .RD_START                    (rd_test_req                             ),
    .RD_ADRS                     ({rd_test_addr,3'd0}                     ),
    .RD_LEN                      ({rd_test_len,3'd0}                      ),
    .RD_READY                    (rd_test_ready                           ),
    .RD_FIFO_WE                  (rd_test_data_valid                      ),
    .RD_FIFO_FULL                (1'b0                                    ),
    .RD_FIFO_AFULL               (1'b0                                    ),
    .RD_FIFO_DATA                (rd_test_data                            ),
    .RD_DONE                     (rd_test_finish                          ),
    .DEBUG                       (                                        )
);

//ddr3控制器
ddr3 u_ipsl_hmemc_top (
    .pll_refclk_in        (sys_clk    ),
    .ddr_rstn_key         (rst_n      ),   
    .pll_aclk_0           (           ),
    .pll_aclk_1           (ui_clk     ),
    .pll_aclk_2           (ui_clk_2   ),
    .pll_lock             (           ),
    .ddrphy_rst_done      (           ),
 
    .ddrc_init_done       (),
   // .pll_lock             (pll_lock      ),
   // .ddrphy_rst_done      (ddrphy_rst_done),
  //  .ddrphy_rst_done      (ui_clk_sync_rst),
   // .ddrc_init_done       (ddr_init_done ),
    .ddrc_rst         (0),    
      
    .areset_1         (0),               
    .aclk_1           (ui_clk),                                                        
    .awid_1           (s00_axi_awid),       
    .awaddr_1         (s00_axi_awaddr),     
    .awlen_1          (s00_axi_awlen),      
    .awsize_1         (s00_axi_awsize),     
    .awburst_1        (s00_axi_awburst),    
    .awlock_1         (s00_axi_awlock),                       
    .awvalid_1        (s00_axi_awvalid),    
    .awready_1        (s00_axi_awready),
    .awurgent_1       (1'b0),  //? 
    .awpoison_1       (1'b0),   //?                 
    .wdata_1          (s00_axi_wdata),      
    .wstrb_1          (s00_axi_wstrb),      
    .wlast_1          (s00_axi_wlast),      
    .wvalid_1         (s00_axi_wvalid),     
    .wready_1         (s00_axi_wready),                       
    .bid_1            (s00_axi_bid),        
    .bresp_1          (s00_axi_bresp),      
    .bvalid_1         (s00_axi_bvalid),     
    .bready_1         (s00_axi_bready),                                    
    .arid_1           (s00_axi_arid     ),  
    .araddr_1         (s00_axi_araddr   ),  
    .arlen_1          (s00_axi_arlen    ),  
    .arsize_1         (s00_axi_arsize   ),  
    .arburst_1        (s00_axi_arburst  ),  
    .arlock_1         (s00_axi_arlock   ),                      
    .arvalid_1        (s00_axi_arvalid  ),  
    .arready_1        (s00_axi_arready  ),
    .arpoison_1       (1'b0 ),   //?                  
    .rid_1            (s00_axi_rid      ),  
    .rdata_1          (s00_axi_rdata    ),  
    .rresp_1          (s00_axi_rresp    ),  
    .rlast_1          (s00_axi_rlast    ),  
    .rvalid_1         (s00_axi_rvalid   ),  
    .rready_1         (s00_axi_rready   ),
    .arurgent_1       (1'b0),    //?        
    .csysreq_1        (1'b1),               
    .csysack_1        (),           
    .cactive_1        (), 

    .areset_2         (0),               
    .aclk_2           (ui_clk_2),                                                        
    .awid_2           (rotating_axi_awid),
    .awaddr_2         (rotating_axi_awaddr),     
    .awlen_2          (rotating_axi_awlen),      
    .awsize_2         (rotating_axi_awsize),     
    .awburst_2        (rotating_axi_awburst),    
    .awlock_2         (rotating_axi_awlock),                       
    .awvalid_2        (rotating_axi_awvalid),    
    .awready_2        (rotating_axi_awready),
    .awurgent_2       (1'b0),  //? 
    .awpoison_2       (1'b0),   //?                 
    .wdata_2          (rotating_axi_wdata),      
    .wstrb_2          (rotating_axi_wstrb),      
    .wlast_2          (rotating_axi_wlast),      
    .wvalid_2         (rotating_axi_wvalid),     
    .wready_2         (rotating_axi_wready),                       
    .bid_2            (rotating_axi_bid),        
    .bresp_2          (rotating_axi_bresp),      
    .bvalid_2         (rotating_axi_bvalid),     
    .bready_2         (rotating_axi_bready),                                    
    .arid_2           (rotating_axi_arid     ),  
    .araddr_2         (rotating_axi_araddr   ),  
    .arlen_2          (rotating_axi_arlen    ),  
    .arsize_2         (rotating_axi_arsize   ),  
    .arburst_2        (rotating_axi_arburst  ),  
    .arlock_2         (rotating_axi_arlock   ),                      
    .arvalid_2        (rotating_axi_arvalid  ),  
    .arready_2        (rotating_axi_arready  ),  
    .arpoison_2       (1'b0 ),   //?                  
    .rid_2            (rotating_axi_rid      ),  
    .rdata_2          (rotating_axi_rdata    ),  
    .rresp_2          (rotating_axi_rresp    ),  
    .rlast_2          (rotating_axi_rlast    ),  
    .rvalid_2         (rotating_axi_rvalid   ),  
    .rready_2         (rotating_axi_rready   ),  
    .arurgent_2       (1'b0),    //?        
    .csysreq_2        (1'b1),
    .csysack_2        (),
    .cactive_2        (), 
          
    .csysreq_ddrc     (1'b1),
    .csysack_ddrc     (),
    .cactive_ddrc     (),
             
    .pad_loop_in           (pad_loop_in),
    .pad_loop_in_h         (pad_loop_in_h),
    .pad_rstn_ch0          (pad_rstn_ch0),
    .pad_ddr_clk_w         (pad_ddr_clk_w),
    .pad_ddr_clkn_w        (pad_ddr_clkn_w),
    .pad_csn_ch0           (pad_csn_ch0),
    .pad_addr_ch0          (pad_addr_ch0),
    .pad_dq_ch0            (pad_dq_ch0),
    .pad_dqs_ch0           (pad_dqs_ch0),
    .pad_dqsn_ch0          (pad_dqsn_ch0),
    .pad_dm_rdqs_ch0       (pad_dm_rdqs_ch0),
    .pad_cke_ch0           (pad_cke_ch0),
    .pad_odt_ch0           (pad_odt_ch0),
    .pad_rasn_ch0          (pad_rasn_ch0),
    .pad_casn_ch0          (pad_casn_ch0),
    .pad_wen_ch0           (pad_wen_ch0),
    .pad_ba_ch0            (pad_ba_ch0),
    .pad_loop_out          (pad_loop_out),
    .pad_loop_out_h        (pad_loop_out_h)                                
);   
endmodule