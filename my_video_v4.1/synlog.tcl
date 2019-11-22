history clear
set wid1 [get_window_id]
set wid2 [open_file C:/Users/zzl/Desktop/FPGA/PANGO/my_video_v2.1/synthesize/synplify_impl/synplify.srs]
win_activate $wid2
run_tcl -fg C:/Users/zzl/Desktop/FPGA/PANGO/my_video_v2.1/top_rtl.tcl
project -close C:/Users/zzl/Desktop/FPGA/PANGO/my_video_v2.1/synthesize/synplify_impl/../synplify_pro.prj
