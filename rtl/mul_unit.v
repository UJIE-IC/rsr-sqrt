module mul_unit (
    input [19:0] a,
    input [19:0] b,
    output [39:0] p
);

assign p = a * b;

endmodule
