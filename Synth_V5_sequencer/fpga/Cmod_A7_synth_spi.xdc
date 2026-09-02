## Cmod A7 configuration voltage settings
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## 12 MHz board clock (onboard oscillator)
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports { clk }]
## NOTE: do NOT add create_clock here. The clk_wiz_0 IP already constrains the
## 12 MHz input clock (its in-context XDC). A second create_clock on this pin
## causes CRITICAL WARNING [Constraints 18-1056] "completely overrides clock",
## which corrupts audio-clock timing and makes the SPI slave unreliable.

## Onboard LED
set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports { led0 }]

## I2S to UDA1334A  (DIP pins 1/2/3 = pio1/2/3)
set_property -dict { PACKAGE_PIN M3  IOSTANDARD LVCMOS33 } [get_ports { i2s_bclk }]
set_property -dict { PACKAGE_PIN L3  IOSTANDARD LVCMOS33 } [get_ports { i2s_lrclk }]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports { i2s_sdin }]

## MIDI input  (DIP pin 4 = pio4, notes only)
set_property -dict { PACKAGE_PIN K3  IOSTANDARD LVCMOS33 } [get_ports { midi_rx }]

## ======================================================================
## SPI from Raspberry Pi (Pi = master, FPGA = slave)
## Placed on the high-numbered header pins, clear of audio/MIDI (pins 1-4)
## and the analog pins (15/16). Package pins verified against Digilent's
## Cmod A7 Master XDC (DIP pin N == pio[N]).
##
##   Signal     DIP pin (silkscreen)   pio     Package pin
##   spi_cs_n         17               pio17       M1
##   spi_sclk        18               pio18       N3
##   spi_mosi        19               pio19       P3
## ======================================================================
set_property -dict { PACKAGE_PIN M1  IOSTANDARD LVCMOS33 } [get_ports { spi_cs_n }]
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports { spi_sclk }]
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }]

## SPI is slow/async relative to clk_audio; synchronizers handle crossing.
## Mark the SPI inputs as false paths to avoid meaningless timing errors.
set_false_path -from [get_ports { spi_sclk spi_mosi spi_cs_n }]
