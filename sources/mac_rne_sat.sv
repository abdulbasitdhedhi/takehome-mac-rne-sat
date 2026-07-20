`timescale 1ns/1ps

module mac_rne_sat (
    input  logic               clk,
    input  logic               rst,
    input  logic               en,
    input  logic               clr,
    input  logic               rd,
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [15:0] res,
    output logic               res_valid,
    output logic               ovf
);

    // Signed 16-bit saturation bounds, compared against the 28-bit rounded value.
    localparam logic signed [27:0] SAT_MAX = 28'sd32767;
    localparam logic signed [27:0] SAT_MIN = -28'sd32768;
    // Round-half-to-even tie point at the 8 LSBs (256/2).
    localparam logic        [7:0]  ROUND_HALF = 8'h80;

    logic signed [27:0] acc;

    logic signed [27:0] product_ext;
    logic signed [27:0] q;      // q = floor(acc / 256)
    logic        [7:0]  rem;    // rem = acc mod 256, always in [0, 255]
    logic signed [27:0] rounded;
    logic signed [15:0] res_next;
    logic               sat;

    always_comb begin
        product_ext = a * b;

        q   = acc >>> 8;
        rem = acc[7:0];

        rounded = q;

        // round-half-to-even
        if (rem > ROUND_HALF) begin
            rounded = q + 1;
        end
        else if (rem == ROUND_HALF) begin
            if (q[0])
                rounded = q + 1;
        end

        // saturation applied after rounding; res_next and sat share one source
        sat      = 1'b0;
        res_next = rounded[15:0];
        if (rounded > SAT_MAX) begin
            sat      = 1'b1;
            res_next = 16'sh7fff;
        end
        else if (rounded < SAT_MIN) begin
            sat      = 1'b1;
            res_next = 16'sh8000;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            acc       <= '0;
            res       <= '0;
            res_valid <= 1'b0;
            ovf       <= 1'b0;
        end
        else begin
            // default pulse behavior
            res_valid <= rd;

            // read snapshot BEFORE accumulator update
            if (rd) begin
                res <= res_next;
                if (sat)
                    ovf <= 1'b1;
            end

            // clr clears sticky overflow unless this same cycle
            // produces a saturating readout
            if (clr && !(rd && sat))
                ovf <= 1'b0;

            // accumulator priority:
            // clr+en -> load product
            // clr    -> zero
            // en     -> accumulate
            if (clr && en)
                acc <= product_ext;
            else if (clr)
                acc <= '0;
            else if (en)
                acc <= acc + product_ext;
        end
    end

endmodule