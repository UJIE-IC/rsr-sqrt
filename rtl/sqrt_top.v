module sqrt_top (
    input clk,
    input rst_n,
    input start,
    input [15:0] x_in,

    output busy, 
    output done,
    output [8:0] sqrt_out
);

sqrt_core u_sqrt_core (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (start),
    .x_in     (x_in),
    .busy     (busy),
    .done     (done),
    .sqrt_out (sqrt_out)
);

endmodule