## 时钟信号
set_property -dict { PACKAGE_PIN P17   IOSTANDARD LVCMOS33 } [get_ports { clk }]; 
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## 复位信号 (rst)
## 映射到 P15 (Minisys S6 按钮)
## 注意：Top 模块中 sys_rst = ~rst。如果 P15 是高电平有效按钮，则系统在按钮释放时(rst=0)处于复位状态(sys_rst=1)。
## 请确保按下按钮时系统运行，或者修改 Top 模块的复位逻辑。
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { rst }];

## 拨码开关 (sw[7:0])
## 映射：sw[7] -> P5 ... sw[0] -> R1
set_property -dict { PACKAGE_PIN P5    IOSTANDARD LVCMOS33 } [get_ports { sw[7] }];
set_property -dict { PACKAGE_PIN P4    IOSTANDARD LVCMOS33 } [get_ports { sw[6] }];
set_property -dict { PACKAGE_PIN P3    IOSTANDARD LVCMOS33 } [get_ports { sw[5] }];
set_property -dict { PACKAGE_PIN P2    IOSTANDARD LVCMOS33 } [get_ports { sw[4] }];
set_property -dict { PACKAGE_PIN R2    IOSTANDARD LVCMOS33 } [get_ports { sw[3] }];
set_property -dict { PACKAGE_PIN M4    IOSTANDARD LVCMOS33 } [get_ports { sw[2] }];
set_property -dict { PACKAGE_PIN N4    IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];
set_property -dict { PACKAGE_PIN R1    IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];

## 按钮 (btn[3:0])
## btn[0]: 确认/进入 (R11)
## btn[1]: 返回/退出 (V1) - 已更新为退出键
## btn[2]: 未使用 (R15)
## btn[3]: FSM 复位 (U17)
set_property -dict { PACKAGE_PIN R11   IOSTANDARD LVCMOS33 } [get_ports { btn[0] }];
set_property -dict { PACKAGE_PIN V1   IOSTANDARD LVCMOS33 } [get_ports { btn[1] }];
set_property -dict { PACKAGE_PIN R15   IOSTANDARD LVCMOS33 } [get_ports { btn[2] }];
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { btn[3] }];

## 7段数码管段选 (seg[7:0])
## seg[0]=CA ... seg[7]=DP
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { seg[0] }];
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { seg[1] }];
set_property -dict { PACKAGE_PIN D3    IOSTANDARD LVCMOS33 } [get_ports { seg[2] }];
set_property -dict { PACKAGE_PIN F4    IOSTANDARD LVCMOS33 } [get_ports { seg[3] }];
set_property -dict { PACKAGE_PIN F3    IOSTANDARD LVCMOS33 } [get_ports { seg[4] }];
set_property -dict { PACKAGE_PIN E2    IOSTANDARD LVCMOS33 } [get_ports { seg[5] }];
set_property -dict { PACKAGE_PIN D2    IOSTANDARD LVCMOS33 } [get_ports { seg[6] }];
set_property -dict { PACKAGE_PIN H2    IOSTANDARD LVCMOS33 } [get_ports { seg[7] }];

## 7段数码管位选 (an[3:0])
## an[0] (最右) ... an[3] (最左)
set_property -dict { PACKAGE_PIN G6    IOSTANDARD LVCMOS33 } [get_ports { an[0] }];
set_property -dict { PACKAGE_PIN E1    IOSTANDARD LVCMOS33 } [get_ports { an[1] }];
set_property -dict { PACKAGE_PIN F1    IOSTANDARD LVCMOS33 } [get_ports { an[2] }];
set_property -dict { PACKAGE_PIN G1    IOSTANDARD LVCMOS33 } [get_ports { an[3] }];

## LED 指示灯 (led[7:0])
## led[0] -> K2 ... led[7] -> F6
set_property -dict { PACKAGE_PIN K2    IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN J2    IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN J3    IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN H4    IOSTANDARD LVCMOS33 } [get_ports { led[3] }];
set_property -dict { PACKAGE_PIN J4    IOSTANDARD LVCMOS33 } [get_ports { led[4] }];
set_property -dict { PACKAGE_PIN G3    IOSTANDARD LVCMOS33 } [get_ports { led[5] }];
set_property -dict { PACKAGE_PIN G4    IOSTANDARD LVCMOS33 } [get_ports { led[6] }];
set_property -dict { PACKAGE_PIN F6    IOSTANDARD LVCMOS33 } [get_ports { led[7] }];

## UART 接口
set_property -dict { PACKAGE_PIN N5    IOSTANDARD LVCMOS33 } [get_ports { uart_rx }];
set_property -dict { PACKAGE_PIN T4    IOSTANDARD LVCMOS33 } [get_ports { uart_tx }];
