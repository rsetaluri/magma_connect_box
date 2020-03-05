/*=============================================================================
** Module: glb_tile_proc_router.sv
** Description:
**              Global Buffer Tile Router
** Author: Taeyoung Kong
** Change history: 
**      01/20/2020
**          - Implement first version of global buffer tile router
**      02/25/2020
**          - Add read packet router
**===========================================================================*/
import global_buffer_pkg::*;

module glb_tile_proc_router (
    input  logic                            clk,
    input  logic                            clk_en,
    input  logic                            reset,
    input  logic [TILE_SEL_ADDR_WIDTH-1:0]  glb_tile_id,

    // processor packet
    input  packet_t                         packet_wsti,
    output packet_t                         packet_wsto,
    input  packet_t                         packet_esti,
    output packet_t                         packet_esto,

    output wr_packet_t                      wr_packet_r2c,
    output rdrq_packet_t                    rdrq_packet_r2c,
    input  rdrs_packet_t                    rdrs_packet_c2r
);

//============================================================================//
// Internal Logic
//============================================================================//
// packet pipeline
packet_t packet_wsti_d1;
packet_t packet_esti_d1;

// res packet
rdrs_packet_t rdrs_packet_c2r_d1;

// is_even indicates If tile_id is even or not
// Warning: Tile id starts from 0
logic is_even;
assign is_even = (glb_tile_id[0] == 0);

//============================================================================//
// packet pipeline register
//============================================================================//
always_ff @ (posedge clk or posedge reset) begin
    if (reset) begin
        packet_wsti_d1 <= '0;
        packet_esti_d1 <= '0;
    end
    else if (clk_en) begin
        packet_wsti_d1 <= packet_wsti;
        packet_esti_d1 <= packet_esti;
    end
end

// response
always_ff @ (posedge clk or posedge reset) begin
    if (reset) begin
        proc_rs_packet_c2r_d1 <= '0;
    end
    else if (clk_en) begin
        proc_rs_packet_c2r_d1 <= proc_rs_packet_c2r;
    end
end

//============================================================================//
// request packet
//============================================================================//
// packet_esto
assign proc_rq_packet_esto = (is_even == 1'b1)
                           ? proc_rq_packet_wsti_d1 : proc_rq_packet_wsti;
// packet_wsto
assign proc_rq_packet_wsto = (is_even == 1'b0)
                           ? proc_rq_packet_esti_d1 : proc_rq_packet_esti;
// packet router to core
assign proc_rq_packet_r2c = (is_even == 1'b1)
                          ? proc_rq_packet_esto : proc_rq_packet_wsto;

//============================================================================//
// response packet
//============================================================================//
// packet core to router switch
assign proc_rs_packet_esto = (is_even == 1'b1)
                           ? (proc_rs_packet_c2r_d1.rd_data_valid == 1) 
                           ? proc_rs_packet_c2r_d1 : proc_rs_packet_wsti_d1
                           : proc_rs_packet_wsti;

assign proc_rs_packet_wsto = (is_even == 1'b0)
                           ? (proc_rs_packet_c2r_d1.rd_data_valid == 1) 
                           ? proc_rs_packet_c2r_d1 : proc_rs_packet_esti_d1
                           : proc_rs_packet_esti;

endmodule
