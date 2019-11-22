`timescale 1ns / 1ns
module gen_pixel_addr_tb(

   );

reg clk;
reg rst;

reg addr_fifo_full;
wire [10:0] x;
wire [10:0] y;
//²úÉúÏñËØµØÖ·
gen_addr_get_frame gen_addr_get_frame
(
    .clk(clk),
    .rst(rst),

    .addr_fifo_full   (addr_fifo_full    ),
    .wr_en            (wr_en             ),
    .addr_x           (x                 ),
    .addr_y           (y                 )
);

initial begin
    clk <= 0;
    rst <= 1;
    #1000;
    rst <= 0;
    #1000;
    forever #10 clk <= ~clk;
end

initial begin
    addr_fifo_full <= 0;
    #10000;
    addr_fifo_full <= 1;
    #500;
    addr_fifo_full <= 0;
end

endmodule