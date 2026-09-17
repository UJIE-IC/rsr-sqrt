module seed_lut (
    input      [4:0] addr,
    output reg [5:0] seed_out // UQ2.4
);

always @(*) begin
    case (addr)
        5'd0 : seed_out = 6'h1F;
        5'd1 : seed_out = 6'h1D;
        5'd2 : seed_out = 6'h1C;
        5'd3 : seed_out = 6'h1B;
        5'd4 : seed_out = 6'h1A;
        5'd5 : seed_out = 6'h19;
        5'd6 : seed_out = 6'h18;
        5'd7 : seed_out = 6'h17;
        5'd8 : seed_out = 6'h16;
        5'd9 : seed_out = 6'h16;
        5'd10: seed_out = 6'h15;
        5'd11: seed_out = 6'h14;
        5'd12: seed_out = 6'h14;
        5'd13: seed_out = 6'h14;
        5'd14: seed_out = 6'h13;
        5'd15: seed_out = 6'h13;
        5'd16: seed_out = 6'h12;
        5'd17: seed_out = 6'h12;
        5'd18: seed_out = 6'h12;
        5'd19: seed_out = 6'h11;
        5'd20: seed_out = 6'h11;
        5'd21: seed_out = 6'h11;
        5'd22: seed_out = 6'h10;
        5'd23: seed_out = 6'h10;

        default: seed_out = 6'h00;

    endcase
end

endmodule
