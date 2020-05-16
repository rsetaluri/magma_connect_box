#=========================================================================
# Design Constraints File
#=========================================================================

# This constraint sets the target clock period for the chip in
# nanoseconds. Note that the first parameter is the name of the clock
# signal in your verlog design. If you called it something different than
# clk you will need to change this. You should set this constraint
# carefully. If the period is unrealistically small then the tools will
# spend forever trying to meet timing and ultimately fail. If the period
# is too large the tools will have no trouble but you will get a very
# conservative implementation.

set clock_net  clk
set clock_name ideal_clock

create_clock -name ${clock_name} \
             -period ${dc_clock_period} \
             [get_ports ${clock_net}]

# Set voltage groups
set_attribute [get_lib *90tt0p8v25c] default_threshold_voltage_group SVT
set_attribute [get_lib *lvt*] default_threshold_voltage_group LVT
set_attribute [get_lib *ulvt*] default_threshold_voltage_group ULVT
             
# This constraint sets the load capacitance in picofarads of the
# output pins of your design.

set_load -pin_load $ADK_TYPICAL_ON_CHIP_LOAD [all_outputs]

# This constraint sets the input drive strength of the input pins of
# your design. We specifiy a specific standard cell which models what
# would be driving the inputs. This should usually be a small inverter
# which is reasonable if another block of on-chip logic is driving
# your inputs.

set_driving_cell -no_design_rule \
  -lib_cell $ADK_DRIVING_CELL [all_inputs]

# set_min_delay for all tile-connected inputs
set_min_delay -from [get_ports *_est* -filter "direction==in"] [expr ${dc_clock_period}*0.65]
set_min_delay -from [get_ports *_wst* -filter "direction==in"] [expr ${dc_clock_period}*0.65]

# min delay for if_cfg ports should be set low
set_min_delay -from [get_ports if_cfg_* -filter "direction==in"] [expr ${dc_clock_period}*0.50]

# min delay for pc ports should be set low
set_min_delay -from [get_ports pc_*_est* -filter "direction==in"] [expr ${dc_clock_period}*0.55]
set_min_delay -from [get_ports pc_*_wst* -filter "direction==in"] [expr ${dc_clock_period}*0.55]
set_min_delay -from [get_ports pc_rd_data*_est* -filter "direction==in"] [expr ${dc_clock_period}*0.50]
set_min_delay -from [get_ports pc_rd_data*_wst* -filter "direction==in"] [expr ${dc_clock_period}*0.50]

# set_min_delay for all outputs 
set_min_delay -to [get_ports *_esto*] [expr ${dc_clock_period}*0.65]
set_min_delay -to [get_ports *_wsto*] [expr ${dc_clock_period}*0.65]

# strm esto/wsto needs to have longer min delay to fix hold time
set_min_delay -to [get_ports strm_*_wsto*] [expr ${dc_clock_period}*0.70]
set_min_delay -to [get_ports strm_*_esto*] [expr ${dc_clock_period}*0.70]

# min delay for strm_rd_data should be set back to normal
set_min_delay -to [get_ports strm_rd_data*_wsto*] [expr ${dc_clock_period}*0.65]

# if_cfg ports should be set to low
set_min_delay -to [get_ports if_cfg_* -filter "direction==out"] [expr ${dc_clock_period}*0.50]

# all est<->wst connections
set_input_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports *_esti*]
set_input_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports *_wsti*]
set_input_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports if_cfg_est* -filter "direction==in"]
set_input_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports if_cfg_wst* -filter "direction==in"]
set_input_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports if_sram_cfg_est* -filter "direction==in"]
set_input_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports if_sram_cfg_wst* -filter "direction==in"]

# cfg_clk_en is negative edge triggered
# set_input_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] -clock_fall [get_ports *_clk_en -filter "direction==in"]
#
# Just get away clk_gating for configuration
set_false_path -from [get_ports *_clk_en -filter "direction==in"]
set_false_path -to [get_ports *_clk_en -filter "direction==out"]

# tile id is constant
set_input_delay -clock ${clock_name} 0 glb_tile_id

# set_output_delay constraints for output ports
# default output delay is 0.2
set_output_delay -clock ${clock_name} [expr ${dc_clock_period}*0.2] [all_outputs]

# set output ports to cgra output delay to high number 0.75
set_output_delay -clock ${clock_name} [expr ${dc_clock_period}*0.75] [get_ports stream_*_g2f]
set_output_delay -clock ${clock_name} [expr ${dc_clock_period}*0.75] [get_ports cgra_cfg_g2f*]

# all est<->wst connections
set_output_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports *_esto* -filter "direction==out"]
set_output_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports *_wsto* -filter "direction==out"]
set_output_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports if_cfg_est* -filter "direction==out"]
set_output_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports if_cfg_wst* -filter "direction==out"]
set_output_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports if_sram_cfg_est* -filter "direction==out"]
set_output_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] [get_ports if_sram_cfg_wst* -filter "direction==out"]
# cfg_clk_en is negative edge triggered
# set_output_delay -clock ${clock_name} [expr ${dc_clock_period}*0.5] -clock_fall [get_ports *_clk_en -filter "direction==out"]


# set false path
# glb_tile_id is constant
set_false_path -from {glb_tile_id*}

# these inputs are from configuration register
set_false_path -from {cfg_tile_connected_wsti}
set_false_path -from {cfg_pc_tile_connected_wsti}
set_false_path -to {cfg_tile_connected_esto}
set_false_path -to {cfg_pc_tile_connected_esto}

# jtag bypass mode is false path
set_false_path -from [get_ports cgra_cfg_jtag_wsti_rd_en_bypass] -to [get_ports cgra_cfg_jtag_esto_rd_en_bypass]
set_false_path -from [get_ports cgra_cfg_jtag_wsti_addr_bypass] -to [get_ports cgra_cfg_jtag_esto_addr_bypass]

# path from configuration registers are false path
set_false_path -through [get_cells glb_tile_int/glb_tile_cfg/glb_pio/pio_logic/*] -through [get_ports glb_tile_int/glb_tile_cfg/cfg_* -filter "direction==out"]
set_false_path -from [get_cells glb_tile_int/glb_tile_cfg/glb_pio/pio_logic/*] -through [get_ports glb_tile_int/glb_tile_cfg/cfg_* -filter "direction==out"]

# jtag cgra configuration read
# ignore timing when rd_en is 1
set_case_analysis 0 cgra_cfg_jtag_wsti_rd_en
set_multicycle_path -setup 10 -from cgra_cfg_jtag_wsti_rd_en
set_multicycle_path -hold 9 -from cgra_cfg_jtag_wsti_rd_en
set_multicycle_path -setup 10 -from cgra_cfg_jtag_wsti_addr -to cgra_cfg_jtag_esto_addr
set_multicycle_path -hold 9 -from cgra_cfg_jtag_wsti_addr -to cgra_cfg_jtag_esto_addr
set_multicycle_path -setup 10 -from cgra_cfg_jtag_wsti_data -to cgra_cfg_jtag_esto_data
set_multicycle_path -hold 9 -from cgra_cfg_jtag_wsti_data -to cgra_cfg_jtag_esto_data
set_false_path -from cgra_cfg_jtag_wsti_wr_en -to cgra_cfg_jtag_esto_wr_en

# jtag sram read
# jtag sram read is multicycle path because you assert rd_en for long cycles
set_multicycle_path -setup 10 -from [get_ports if_sram_cfg*rd* -filter "direction==in"]
set_multicycle_path -setup 10 -to [get_ports if_sram_cfg*rd* -filter "direction==out"]
set_multicycle_path -setup 10 -through [get_cells -hier if_sram_cfg*rd*]
set_multicycle_path -setup 10 -through [get_cells -hier cfg_sram_rd*]
set_multicycle_path -setup 10 -to [get_cells -hier if_sram_cfg*rd*]
set_multicycle_path -setup 10 -to [get_cells -hier cfg_sram_rd*]
set_multicycle_path -setup 10 -from [get_cells -hier if_sram_cfg*rd*]
set_multicycle_path -setup 10 -from [get_cells -hier cfg_sram_rd*]
set_multicycle_path -hold 9 -from [get_ports if_sram_cfg*rd* -filter "direction==in"]
set_multicycle_path -hold 9 -to [get_ports if_sram_cfg*rd* -filter "direction==out"]
set_multicycle_path -hold 9 -through [get_cells -hier if_sram_cfg*rd*]
set_multicycle_path -hold 9 -through [get_cells -hier cfg_sram_rd*]
set_multicycle_path -hold 9 -to [get_cells -hier if_sram_cfg*rd*]
set_multicycle_path -hold 9 -to [get_cells -hier cfg_sram_rd*]
set_multicycle_path -hold 9 -from [get_cells -hier if_sram_cfg*rd*]
set_multicycle_path -hold 9 -from [get_cells -hier cfg_sram_rd*]

# jtag write
# jtag sram write is asserted for 4 cycles from glc
set_multicycle_path -setup 4 -from [get_ports if_sram_cfg*wr* -filter "direction==in"]
set_multicycle_path -setup 4 -to [get_ports if_sram_cfg*wr* -filter "direction==out"]
set_multicycle_path -setup 4 -through [get_cells -hier if_sram_cfg*wr*]
set_multicycle_path -setup 4 -to [get_cells -hier if_sram_cfg*wr*]
set_multicycle_path -setup 4 -from [get_cells -hier if_sram_cfg*wr*]
set_multicycle_path -hold 3 -from [get_ports if_sram_cfg*wr* -filter "direction==in"]
set_multicycle_path -hold 3 -to [get_ports if_sram_cfg*wr* -filter "direction==out"]
set_multicycle_path -hold 3 -through [get_cells -hier if_sram_cfg*wr*]
set_multicycle_path -hold 3 -to [get_cells -hier if_sram_cfg*wr*]
set_multicycle_path -hold 3 -from [get_cells -hier if_sram_cfg*wr*]

# Make all signals limit their fanout
set_max_fanout 20 $dc_design_name

# Make all signals meet good slew
set_max_transition [expr 0.25*${dc_clock_period}] $dc_design_name

#set_input_transition 1 [all_inputs]
#set_max_transition 10 [all_outputs]

