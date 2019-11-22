/*
 * Copyright (C)2014-2015 AQUAXIS TECHNOLOGY.
 *  Don't remove this header. 
 * When you use this source, there is a need to inherit this header.
 *
 * License
 *  For no commercial -
 *   License:     The Open Software License 3.0
 *   License URI: http://www.opensource.org/licenses/OSL-3.0
 *
 *  For commmercial -
 *   License:     AQUAXIS License 1.0
 *   License URI: http://www.aquaxis.com/licenses
 *
 * For further information please contact.
 *  URI:    http://www.aquaxis.com/
 *  E-Mail: info(at)aquaxis.com
 */
 
 //////////////////////////////////////////////////////////////////////////////////
// Company: ALINX
// Engineer: 
// 
// Create Date: 2016/11/17 10:27:06
// Design Name: 
// Module Name: mem_test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module my_aq_axi_master(
  // Reset, Clock
  input           ARESETN,
  input           ACLK,

  // Master Write Address
  output [0:0]  M_AXI_AWID,
  output [31:0] M_AXI_AWADDR,
  output [7:0]  M_AXI_AWLEN,    // Burst Length: 0-255
  output [2:0]  M_AXI_AWSIZE,   // Burst Size: Fixed 2'b011
  output [1:0]  M_AXI_AWBURST,  // Burst Type: Fixed 2'b01(Incremental Burst)
  output        M_AXI_AWLOCK,   // Lock: Fixed 2'b00
  output [3:0]  M_AXI_AWCACHE,  // Cache: Fiex 2'b0011
  output [2:0]  M_AXI_AWPROT,   // Protect: Fixed 2'b000
  output [3:0]  M_AXI_AWQOS,    // QoS: Fixed 2'b0000
  output [0:0]  M_AXI_AWUSER,   // User: Fixed 32'd0
  output        M_AXI_AWVALID,
  input         M_AXI_AWREADY,

  // Master Write Data
  output [63:0] M_AXI_WDATA,
  output [7:0]  M_AXI_WSTRB,
  output        M_AXI_WLAST,
  output [0:0]  M_AXI_WUSER,
  output        M_AXI_WVALID,
  input         M_AXI_WREADY,

  // Master Write Response
  input [0:0]   M_AXI_BID,
  input [1:0]   M_AXI_BRESP,
  input [0:0]   M_AXI_BUSER,
  input         M_AXI_BVALID,
  output        M_AXI_BREADY,
    
  // Master Read Address
  output [0:0]  M_AXI_ARID,
  output [31:0] M_AXI_ARADDR,
  output [7:0]  M_AXI_ARLEN,
  output [2:0]  M_AXI_ARSIZE,
  output [1:0]  M_AXI_ARBURST,
  output [1:0]  M_AXI_ARLOCK,
  output [3:0]  M_AXI_ARCACHE,
  output [2:0]  M_AXI_ARPROT,
  output [3:0]  M_AXI_ARQOS,
  output [0:0]  M_AXI_ARUSER,
  output        M_AXI_ARVALID,
  input         M_AXI_ARREADY,
    
  // Master Read Data 
  input [0:0]   M_AXI_RID,
  input [63:0]  M_AXI_RDATA,
  input [1:0]   M_AXI_RRESP,
  input         M_AXI_RLAST,
  input [0:0]   M_AXI_RUSER,
  input         M_AXI_RVALID,
  output        M_AXI_RREADY,
        
  // Local Bus
  input         MASTER_RST,
  
  input         WR_FIFO_EMPTY,
  input         WR_FIFO_AEMPTY,
  output        WR_READY,
  output        MUX_wr,
  
  input         WR_START_0,
  input [31:0]  WR_ADRS_0,
  input [31:0]  WR_LEN_0, 
  input [63:0]  WR_FIFO_DATA_0,
  output        WR_FIFO_RE_0,
  output        WR_DONE_0,
  input         WR_START_1,
  input [31:0]  WR_ADRS_1,
  input [31:0]  WR_LEN_1, 
  input [63:0]  WR_FIFO_DATA_1,
  output        WR_FIFO_RE_1,
  output        WR_DONE_1,

  input         RD_FIFO_FULL,
  input         RD_FIFO_AFULL,
  output        RD_READY,
  output [63:0] RD_FIFO_DATA,
  output        MUX_rd,
  
  input         RD_START_0,
  input [31:0]  RD_ADRS_0,
  input [31:0]  RD_LEN_0, 
  output        RD_FIFO_WE_0,
  output        RD_DONE_0,
  input         RD_START_1,
  input [31:0]  RD_ADRS_1,
  input [31:0]  RD_LEN_1, 
  output        RD_FIFO_WE_1,
  output        RD_DONE_1,

  output [31:0] DEBUG
);
reg [7:0] mydebug;
reg [7:0] mydebug_max;

  localparam S_WR_IDLE  = 3'd0;
  localparam S_WA_WAIT  = 3'd1;
  localparam S_WA_START = 3'd2;
  localparam S_WD_WAIT  = 3'd3;
  localparam S_WD_PROC  = 3'd4;
  localparam S_WR_WAIT  = 3'd5;
  localparam S_WR_DONE  = 3'd6;
  
  reg [2:0]   wr_state;
  reg [31:0]  reg_WR_ADRS;
  reg [31:0]  reg_wr_len;
  reg         reg_awvalid, reg_wvalid, reg_w_last;
  reg [7:0]   reg_w_len;
  reg [7:0]   reg_w_stb;
  reg [1:0]   reg_wr_status;
  reg [3:0]   reg_w_count, reg_r_count;

  reg [7:0]   rd_chkdata, wr_chkdata;
  reg [1:0]   resp;
  reg rd_first_data;
  reg rd_fifo_enable;
  reg[31:0] rd_fifo_cnt;

  reg MUX_wr;//写通道选择
  reg MUX_rd;//读

assign WR_DONE_0 = ~MUX_wr & (wr_state == S_WR_DONE);
assign WR_DONE_1 = MUX_wr & (wr_state == S_WR_DONE);
wire WR_FIFO_RE;
assign WR_FIFO_RE         = rd_first_data | (reg_wvalid & ~WR_FIFO_EMPTY & M_AXI_WREADY & rd_fifo_enable);
assign WR_FIFO_RE_0       = ~MUX_wr & (rd_first_data | (reg_wvalid & ~WR_FIFO_EMPTY & M_AXI_WREADY & rd_fifo_enable));
assign WR_FIFO_RE_1       = MUX_wr & (rd_first_data | (reg_wvalid & ~WR_FIFO_EMPTY & M_AXI_WREADY & rd_fifo_enable));
//assign WR_FIFO_RE         = reg_wvalid & ~WR_FIFO_EMPTY & M_AXI_WREADY;
always @(posedge ACLK or negedge ARESETN)
begin
  if(!ARESETN)
    rd_fifo_cnt <= 32'd0;
  else if(WR_FIFO_RE)
    rd_fifo_cnt <= rd_fifo_cnt + 32'd1;//读取FIFO计数
  else if(wr_state == S_WR_IDLE)
    rd_fifo_cnt <= 32'd0; 
end

always @(posedge ACLK or negedge ARESETN)
begin
  if(!ARESETN)
    rd_fifo_enable <= 1'b0;
  else if((wr_state == S_WR_IDLE && WR_START_0)||(wr_state == S_WR_IDLE && WR_START_1))//改
    rd_fifo_enable <= 1'b1;
    else if(MUX_wr & WR_FIFO_RE && (rd_fifo_cnt == WR_LEN_1[31:3] - 32'd1))//改,写入完成后rd_fifo_enable置零
        rd_fifo_enable <= 1'b0;
    else if(~MUX_wr & WR_FIFO_RE && (rd_fifo_cnt == WR_LEN_0[31:3] - 32'd1))//改,写入完成后rd_fifo_enable置零
        rd_fifo_enable <= 1'b0;
end
  // Write State
  always @(posedge ACLK or negedge ARESETN) begin
    if(!ARESETN) begin
      wr_state            <= S_WR_IDLE;
      reg_WR_ADRS[31:0]   <= 32'd0;
      reg_wr_len[31:0]    <= 32'd0;
      reg_awvalid         <= 1'b0;
      reg_wvalid          <= 1'b0;
      reg_w_last          <= 1'b0;
      reg_w_len[7:0]      <= 8'd0;
      reg_w_stb[7:0]      <= 8'd0;
      reg_wr_status[1:0]  <= 2'd0;
      reg_w_count[3:0]    <= 4'd0;
      reg_r_count[3:0]  <= 4'd0;
      wr_chkdata          <= 8'd0;
      rd_chkdata <= 8'd0;
      resp <= 2'd0;
      rd_first_data <= 1'b0;
      MUX_wr <= 1'b0;//写选择指示器复位
  end else begin
    if(MASTER_RST) begin
      wr_state <= S_WR_IDLE;
    end else begin
      case(wr_state)
        S_WR_IDLE: begin
          if(WR_START_0) begin//开始响应写请求,ch0
            wr_state          <= S_WA_WAIT;
            reg_WR_ADRS[31:0] <= WR_ADRS_0[31:0];
            reg_wr_len[31:0]  <= WR_LEN_0[31:0] -32'd1;
            rd_first_data <= 1'b1;
            MUX_wr <= 1'b0;//写选择指示器
          end
          else if(WR_START_1) begin//ch1
            wr_state          <= S_WA_WAIT;
            reg_WR_ADRS[31:0] <= WR_ADRS_1[31:0];
            reg_wr_len[31:0]  <= WR_LEN_1[31:0] -32'd1;
            rd_first_data <= 1'b1;
            MUX_wr <= 1'b1;//写选择指示器
          end
          reg_awvalid         <= 1'b0;
          reg_wvalid          <= 1'b0;
          reg_w_last          <= 1'b0;
          reg_w_len[7:0]      <= 8'd0;
          reg_w_stb[7:0]      <= 8'd0;
          reg_wr_status[1:0]  <= 2'd0;
        end
        S_WA_WAIT: begin
          if(!WR_FIFO_AEMPTY | (reg_wr_len[31:11] == 21'd0)) begin
            wr_state          <= S_WA_START;
          end
          rd_first_data <= 1'b0;
        end
        S_WA_START: begin//开始写地址
          wr_state            <= S_WD_WAIT;
          reg_awvalid         <= 1'b1;
          reg_wr_len[31:11]    <= reg_wr_len[31:11] - 21'd1;
          if(reg_wr_len[31:11] != 21'd0) begin
            reg_w_len[7:0]  <= 8'hFF;
            reg_w_last      <= 1'b0;
            reg_w_stb[7:0]  <= 8'hFF;
          end else begin
            reg_w_len[7:0]  <= reg_wr_len[10:3];//真正的burst长度
            reg_w_last      <= 1'b1;//if reg_wr_len[31:11] = 21'd0,最后一位
            reg_w_stb[7:0]  <= 8'hFF;
/*
            case(reg_wr_len[2:0]) begin
              case 3'd0: reg_w_stb[7:0]  <= 8'b0000_0000;
              case 3'd1: reg_w_stb[7:0]  <= 8'b0000_0001;
              case 3'd2: reg_w_stb[7:0]  <= 8'b0000_0011;
              case 3'd3: reg_w_stb[7:0]  <= 8'b0000_0111;
              case 3'd4: reg_w_stb[7:0]  <= 8'b0000_1111;
              case 3'd5: reg_w_stb[7:0]  <= 8'b0001_1111;
              case 3'd6: reg_w_stb[7:0]  <= 8'b0011_1111;
              case 3'd7: reg_w_stb[7:0]  <= 8'b0111_1111;
              default:   reg_w_stb[7:0]  <= 8'b1111_1111;
            endcase
*/
          end
        end
        S_WD_WAIT: begin//写数据
          if(M_AXI_AWREADY) begin
            wr_state        <= S_WD_PROC;
            reg_awvalid     <= 1'b0;
            reg_wvalid      <= 1'b1;
          end
        end
        S_WD_PROC: begin
          if(M_AXI_WREADY & ~WR_FIFO_EMPTY) begin
            if(reg_w_len[7:0] == 8'd0) begin
              wr_state        <= S_WR_WAIT;
              reg_wvalid      <= 1'b0;
              reg_w_stb[7:0]  <= 8'h00;
            end else begin
              reg_w_len[7:0]  <= reg_w_len[7:0] -8'd1;//不进行转移，直至待写入的长度为0
            end
          end
        end
        S_WR_WAIT: begin
          if(M_AXI_BVALID) begin
            reg_wr_status[1:0]  <= reg_wr_status[1:0] | M_AXI_BRESP[1:0];
            if(reg_w_last) begin//最后一位
              wr_state          <= S_WR_DONE;
            end else begin
              wr_state          <= S_WA_WAIT;
              reg_WR_ADRS[31:0] <= reg_WR_ADRS[31:0] + 32'd2048;//一个burst写入64*4个像素，地址输入时左移了3bit，即64*4*8=2048
            end
          end
        end
        S_WR_DONE: begin
            wr_state <= S_WR_IDLE;
            MUX_wr <= 1'b0;//写选择指示器复位
          end
        
        default: begin
          wr_state <= S_WR_IDLE;
          MUX_wr <= 1'b0;//写选择指示器复位
        end
      endcase
/*
      if(WR_FIFO_RE) begin
        reg_w_count[3:0]  <= reg_w_count[3:0] + 4'd1;
      end
      if(RD_FIFO_WE)begin
        reg_r_count[3:0]  <= reg_r_count[3:0] + 4'd1;
      end
      if(M_AXI_AWREADY & M_AXI_AWVALID) begin
        wr_chkdata <= 8'hEE;
      end else if(M_AXI_WSTRB[7] & M_AXI_WVALID) begin
        wr_chkdata <= WR_FIFO_DATA_0[63:56];
      end
      if(M_AXI_AWREADY & M_AXI_AWVALID) begin
        rd_chkdata <= 8'hDD;
      end else if(M_AXI_WSTRB[7] & M_AXI_WREADY) begin
        rd_chkdata <= WR_FIFO_DATA_0[63:56];
      end
      if(M_AXI_BVALID & M_AXI_BREADY) begin
        resp <= M_AXI_BRESP;
      end
*/
      end
    end
  end
   
  assign M_AXI_AWID         = 1'b0;
  assign M_AXI_AWADDR[31:0] = reg_WR_ADRS[31:0];
  assign M_AXI_AWLEN[7:0]   = reg_w_len[7:0];
  assign M_AXI_AWSIZE[2:0]  = 2'b011;
  assign M_AXI_AWBURST[1:0] = 2'b10;//改,经试验，此参数没什么卵用
  assign M_AXI_AWLOCK       = 1'b0;
  assign M_AXI_AWCACHE[3:0] = 4'b0011;
  assign M_AXI_AWPROT[2:0]  = 3'b000;
  assign M_AXI_AWQOS[3:0]   = 4'b0000;
  assign M_AXI_AWUSER[0]    = 1'b1;
  assign M_AXI_AWVALID      = reg_awvalid;

  assign M_AXI_WDATA[63:0]  = (MUX_wr)? WR_FIFO_DATA_1[63:0] : WR_FIFO_DATA_0[63:0];//改
//  assign M_AXI_WSTRB[7:0]   = (reg_w_len[7:0] == 8'd0)?reg_w_stb[7:0]:8'hFF;
//  assign M_AXI_WSTRB[7:0]   = (wr_state == S_WD_PROC)?8'hFF:8'h00;
  assign M_AXI_WSTRB[7:0]   = (reg_wvalid & ~WR_FIFO_EMPTY)?8'hFF:8'h00;
  assign M_AXI_WLAST        = (reg_w_len[7:0] == 8'd0)?1'b1:1'b0;
  assign M_AXI_WUSER        = 1;
  assign M_AXI_WVALID       = reg_wvalid & ~WR_FIFO_EMPTY;
//  assign M_AXI_WVALID       = (wr_state == S_WD_PROC)?1'b1:1'b0;

  assign M_AXI_BREADY       = M_AXI_BVALID;

  assign WR_READY           = (wr_state == S_WR_IDLE)?1'b1:1'b0;
  
//  assign WR_FIFO_RE         = (wr_state == S_WD_PROC)?M_AXI_WREADY:1'b0;

  localparam S_RD_IDLE  = 3'd0;
  localparam S_RA_WAIT  = 3'd1;
  localparam S_RA_START = 3'd2;
  localparam S_RD_WAIT  = 3'd3;
  localparam S_RD_PROC  = 3'd4;
  localparam S_RD_DONE  = 3'd5;
  
  reg [2:0]   rd_state;
  reg [31:0]  reg_RD_ADRS;
  reg [31:0]  reg_RD_LEN;
  reg         reg_arvalid, reg_r_last;
  reg [7:0]   reg_r_len;
  assign RD_DONE_0 = ~MUX_rd & (rd_state == S_RD_DONE); 
  assign RD_DONE_1 = MUX_rd & (rd_state == S_RD_DONE); 
  // Read State
  always @(posedge ACLK or negedge ARESETN) begin
    if(!ARESETN) begin
      rd_state          <= S_RD_IDLE;
      reg_RD_ADRS[31:0] <= 32'd0;
      reg_RD_LEN[31:0]  <= 32'd0;
      reg_arvalid       <= 1'b0;
      reg_r_len[7:0]    <= 8'd0;
      MUX_rd <= 1'b0;//读选择指示器复位
      mydebug_max <= 0;//添加
    end else begin
      case(rd_state)
        S_RD_IDLE: begin
          mydebug <= 8'd0;//添加
          if(RD_START_0) begin//对读请求信号做出响应
            rd_state          <= S_RA_WAIT;
            reg_RD_ADRS[31:0] <= RD_ADRS_0[31:0];
            reg_RD_LEN[31:0]  <= RD_LEN_0[31:0] -32'd1;
            MUX_rd <= 1'b0;//读选择指示器
          end
          if(RD_START_1) begin//对读请求信号做出响应
            rd_state          <= S_RA_WAIT;
            reg_RD_ADRS[31:0] <= RD_ADRS_1[31:0];
            reg_RD_LEN[31:0]  <= RD_LEN_1[31:0] -32'd1;
            MUX_rd <= 1'b1;//读选择指示器
          end
          else
          reg_arvalid     <= 1'b0;
          reg_r_len[7:0]  <= 8'd0;
        end
        S_RA_WAIT: begin
          if(~RD_FIFO_AFULL) begin
            rd_state          <= S_RA_START;
          end
        end
        S_RA_START: begin
          rd_state          <= S_RD_WAIT;
          reg_arvalid       <= 1'b1;
          reg_RD_LEN[31:11] <= reg_RD_LEN[31:11] -21'd1;
          if(reg_RD_LEN[31:11] != 21'd0) begin
            reg_r_last      <= 1'b0;
            reg_r_len[7:0]  <= 8'd255;
          end else begin
            reg_r_last      <= 1'b1;
            reg_r_len[7:0]  <= reg_RD_LEN[10:3];
          end
        end
        S_RD_WAIT: begin
          if(M_AXI_ARREADY) begin
            mydebug_max[7:4] <= reg_r_len[3:0];//添加
            rd_state        <= S_RD_PROC;
            reg_arvalid     <= 1'b0;
          end
        end
        S_RD_PROC: begin
          if(M_AXI_RVALID) begin
            mydebug <= mydebug + 8'd1;//添加
            if(M_AXI_RLAST) begin//接收到axi上的最后一位标志
              if(reg_r_last) begin
                rd_state          <= S_RD_DONE;
              end else begin
                rd_state          <= S_RA_WAIT;
                reg_RD_ADRS[31:0] <= reg_RD_ADRS[31:0] + 32'd2048;
              end
            end else begin
              reg_r_len[7:0] <= reg_r_len[7:0] -8'd1;
            end
          end
        end
    S_RD_DONE:begin
      rd_state          <= S_RD_IDLE;
      MUX_rd <= 1'b0;//读选择指示器
      //mydebug_max <= mydebug;//添加
      mydebug_max[3:0] <= mydebug[3:0];
    end
      
    endcase
    end
  end
   
  // Master Read Address
  assign M_AXI_ARID         = 1'b0;
  assign M_AXI_ARADDR[31:0] = reg_RD_ADRS[31:0];
  assign M_AXI_ARLEN[7:0]   = reg_r_len[7:0];
  assign M_AXI_ARSIZE[2:0]  = 3'b011;
  assign M_AXI_ARBURST[1:0] = 2'b01;//改
  assign M_AXI_ARLOCK       = 1'b0;
  assign M_AXI_ARCACHE[3:0] = 4'b0011;
  assign M_AXI_ARPROT[2:0]  = 3'b000;
  assign M_AXI_ARQOS[3:0]   = 4'b0000;
  assign M_AXI_ARUSER[0]    = 1'b1;
  assign M_AXI_ARVALID      = reg_arvalid;

  assign M_AXI_RREADY       = M_AXI_RVALID & ~RD_FIFO_FULL;

  assign RD_READY           = (rd_state == S_RD_IDLE)?1'b1:1'b0;
  assign RD_FIFO_WE_0         = ~MUX_rd & M_AXI_RVALID;//改
  assign RD_FIFO_WE_1         = MUX_rd & M_AXI_RVALID;
  assign RD_FIFO_DATA[63:0] = M_AXI_RDATA[63:0];

//  assign DEBUG[31:0] = {reg_wr_len[31:8],
//                        1'd0, wr_state[2:0], 1'd0, rd_state[2:0]};

    assign DEBUG[7:0] = mydebug_max;
   
endmodule

