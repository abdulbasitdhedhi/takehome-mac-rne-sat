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

    logic signed [27:0] snap;
    logic signed [27:0] q;
    logic [7:0] rem;
    logic signed [27:0] rounded;

    logic signed [15:0] next_res;
    logic next_sat;

    logic pending_valid;
    logic pending_sat;
    logic signed [15:0] pending_res;


    always_comb begin

        product_ext = $signed(a) * $signed(b);

        q   = snap >>> 8;
        rem = snap[7:0];

        rounded = q;

        if (rem > 8'd128) begin
            rounded = q + 1;
        end
        else if (rem == 8'd128) begin
            if (q[0])
                rounded = q + 1;
        end


        next_sat = 1'b0;

        if (rounded > 28'sd32767) begin
            next_res = 16'sh7fff;
            next_sat = 1'b1;
        end
        else if (rounded < -28'sd32768) begin
            next_res = -16'sd32768;
            next_sat = 1'b1;
        end
        else begin
            next_res = rounded[15:0];
        end

    end


    always_ff @(posedge clk) begin

        if (rst) begin

            acc <= '0;

            res <= '0;
            res_valid <= 1'b0;
            ovf <= 1'b0;

            pending_valid <= 1'b0;
            pending_sat <= 1'b0;
            pending_res <= '0;

            snap <= '0;

        end
        else begin

            // output previous read request
            res_valid <= pending_valid;

            if (pending_valid) begin
                res <= pending_res;

                if (pending_sat)
                    ovf <= 1'b1;
            end


            // clear ovf unless a saturating readout is landing now
            if (clr && !(pending_valid && pending_sat))
                ovf <= 1'b0;


            // capture read request
            pending_valid <= rd;

            if (rd) begin
                snap <= acc;
                pending_res <= next_res;
                pending_sat <= next_sat;
            end


            // accumulator update
            if (clr && en)
                acc <= product_ext;

            else if (clr)
                acc <= '0;

            else if (en)
                acc <= acc + product_ext;

        end

    end

endmodule