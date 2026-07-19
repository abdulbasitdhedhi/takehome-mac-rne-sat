`timescale 1ns/1ps
//
// mac_rne_sat -- implement your golden solution in this file per
// docs/spec.md, and push it to your fork's mac_rne_sat_golden branch.
//
module mac_rne_sat (
    input  logic               clk,
    input  logic               rst,       // synchronous, active-high
    input  logic               en,        // accumulate a*b this cycle
    input  logic               clr,       // clear accumulator this cycle
    input  logic               rd,        // request readout snapshot this cycle
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [15:0] res,       // rounded + saturated snapshot
    output logic               res_valid, // 1-cycle pulse, one cycle after rd
    output logic               ovf        // sticky saturation flag
);

    // 28-bit signed accumulator
    logic signed [27:0] acc;

    // Readout pipeline
    logic rd_pending;
    logic signed [27:0] snapshot;

    // Intermediate arithmetic
    logic signed [15:0] product;
    logic signed [27:0] product_ext;

    logic signed [27:0] round_q;
    logic [7:0] round_r;
    logic signed [27:0] rounded_value;

    logic saturation;

    always_comb begin
        product = $signed(a) * $signed(b);
        product_ext = {{12{product[15]}}, product};

        // Round-half-to-even
        round_q = snapshot >>> 8;
        round_r = snapshot - (round_q <<< 8);

        rounded_value = round_q;

        if (round_r > 8'd128) begin
            rounded_value = round_q + 1;
        end
        else if (round_r == 8'd128) begin
            // tie: round to even
            if (round_q[0])
                rounded_value = round_q + 1;
        end

        saturation = 1'b0;

        if (rounded_value > 28'sd32767) begin
            saturation = 1'b1;
        end
        else if (rounded_value < -28'sd32768) begin
            saturation = 1'b1;
        end
    end


    always_ff @(posedge clk) begin

        if (rst) begin
            acc        <= '0;
            res        <= '0;
            res_valid  <= 1'b0;
            ovf        <= 1'b0;

            rd_pending <= 1'b0;
            snapshot   <= '0;
        end

        else begin

            // res_valid is delayed by one cycle after rd
            res_valid <= rd_pending;

            // Generate output from previous cycle snapshot
            if (rd_pending) begin

                if (rounded_value > 28'sd32767)
                    res <= 16'sh7fff;
                else if (rounded_value < -28'sd32768)
                    res <= -16'sd32768;
                else
                    res <= rounded_value[15:0];


                // Sticky overflow
                if (saturation)
                    ovf <= 1'b1;
            end


            // Capture read request
            rd_pending <= rd;

            // Snapshot BEFORE current cycle accumulator update
            if (rd)
                snapshot <= acc;


            // Accumulator update
            if (clr && en) begin
                acc <= product_ext;
            end
            else if (clr) begin
                acc <= '0;
            end
            else if (en) begin
                acc <= acc + product_ext;
            end


            // Clear overflow only if no saturation result lands now
            if (clr && !rd_pending)
                ovf <= 1'b0;

        end
    end

endmodule
