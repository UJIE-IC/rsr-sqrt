module seed_lut (
    input      [4:0]  addr,
    output reg [15:0] seed_out
);

always @(*) begin
    case (addr)

        5'd0 : seed_out = 16'h7C2E;
        5'd1 : seed_out = 16'h7576;
        5'd2 : seed_out = 16'h6FBA;
        5'd3 : seed_out = 16'h6AC2;
        5'd4 : seed_out = 16'h6666;
        5'd5 : seed_out = 16'h6289;
        5'd6 : seed_out = 16'h5F13;
        5'd7 : seed_out = 16'h5BF5;

        5'd8 : seed_out = 16'h5921;
        5'd9 : seed_out = 16'h568B;
        5'd10: seed_out = 16'h542C;
        5'd11: seed_out = 16'h51FC;
        5'd12: seed_out = 16'h4FF6;
        5'd13: seed_out = 16'h4E14;
        5'd14: seed_out = 16'h4C53;
        5'd15: seed_out = 16'h4AAF;

        5'd16: seed_out = 16'h4925;
        5'd17: seed_out = 16'h47B2;
        5'd18: seed_out = 16'h4654;
        5'd19: seed_out = 16'h450A;
        5'd20: seed_out = 16'h43D1;
        5'd21: seed_out = 16'h42A8;
        5'd22: seed_out = 16'h418E;
        5'd23: seed_out = 16'h4082;

        default: seed_out = 16'h0000;

    endcase
end

endmodule