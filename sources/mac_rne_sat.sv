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

    logic signed [27:0] acc;

    logic signed [27:0] product_ext;
    logic signed [27:0] q;
    logic [7:0] rem;
    logic signed [27:0] rounded;
    logic sat;

    always_comb begin
        product_ext = $signed(a) * $signed(b);

        q   = acc >>> 8;
        rem = acc[7:0];

        rounded = q;

        // round-half-to-even
        if (rem > 8'h80) begin
            rounded = q + 1;
        end
        else if (rem == 8'h80) begin
            if (q[0])
                rounded = q + 1;
        end

        sat = 1'b0;
        if (rounded > 28'sd32767)
            sat = 1'b1;
        else if (rounded < -28'sd32768)
            sat = 1'b1;
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
                if (rounded > 28'sd32767)
                    res <= 16'sh7fff;
                else if (rounded < -28'sd32768)
                    res <= -16'sd32768;
                else
                    res <= rounded[15:0];

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