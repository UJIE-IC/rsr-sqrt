module mul_unit (
    input [20:0] a,
    input [20:0] b,
    output [41:0] p
);

assign p = a * b;

endmodule