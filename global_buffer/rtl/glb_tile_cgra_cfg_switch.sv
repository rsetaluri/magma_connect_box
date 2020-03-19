/*=============================================================================
** Module: glb_tile_cgra_cfg_switch.sv
** Description:
**              Global Buffer Tile Configuration Controller
** Author: Taeyoung Kong
** Change history: 03/02/2020 - Implement first version of global buffer tile
**===========================================================================*/
import global_buffer_pkg::*;

module glb_tile_cgra_cfg_switch (
    input  logic                            clk,
    input  logic                            reset,

    // parallel config ctrl on
    input  logic                            cfg_pc_dma_on,

    // parallel configuration
    input  cgra_cfg_t                       cgra_cfg_c2sw,
    input  cgra_cfg_t                       cgra_cfg_jtag_wsti,
    output cgra_cfg_t                       cgra_cfg_jtag_esto,
    input  cgra_cfg_t                       cgra_cfg_pc_wsti,
    output cgra_cfg_t                       cgra_cfg_pc_esto,
    output cgra_cfg_t                       cgra_cfg_g2f [CGRA_PER_GLB]
);

//============================================================================//
// Simple router
//============================================================================//
cgra_cfg_t cgra_cfg_pc_switched;
assign cgra_cfg_pc_switched = cfg_pc_dma_on ? cgra_cfg_c2sw : cgra_cfg_pc_wsti;

//============================================================================//
// pipeline registers
//============================================================================//
always_ff @ (posedge clk or posedge reset) begin
    if (reset) begin
        cgra_cfg_jtag_esto <= '0;
        cgra_cfg_pc_esto <= '0;
    end
    else begin
        cgra_cfg_jtag_esto <= cgra_cfg_jtag_wsti;
        cgra_cfg_pc_esto <= cgra_cfg_pc_switched;
    end
end

//============================================================================//
// output assignment
//============================================================================//
// Just ORing works
always_comb begin
    for (int i=0; i<CGRA_PER_GLB; i=i+1) begin
        cgra_cfg_g2f[i] = cgra_cfg_jtag_esto | cgra_cfg_pc_esto;
    end
end

endmodule