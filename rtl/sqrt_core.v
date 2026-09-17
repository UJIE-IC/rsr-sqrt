module sqrt_core (
    input clk,
    input rst_n,
    input start,
    input [15:0] x_in,       // UQ0.16 input 

    output reg busy,
    output reg done,
    output reg [8:0] sqrt_out    // UQ1.8 output 
);

    // FSM state
    localparam [3:0]
        S_IDLE        = 4'd0,
        S_LOAD_SEED   = 4'd1,
        S_NR1_SQ      = 4'd2,
        S_NR1_MUL_M   = 4'd3,
        S_NR1_SUB     = 4'd4,
        S_NR1_UPDATE  = 4'd5,
        S_NR2_SQ      = 4'd6,
        S_NR2_MUL_M   = 4'd7,
        S_NR2_SUB     = 4'd8,
        S_NR2_UPDATE  = 4'd9,
        S_FINAL_MUL   = 4'd10,
        S_FINAL_ROUND = 4'd11,
        S_DONE        = 4'd12;

    localparam [19:0] THREE_Q218 = 20'd786432;

    reg [3:0] state;

    // Normalization
    reg [15:0] norm_m;  // UQ0.16
    reg [2:0] norm_exp;

    always @(*) begin
        norm_m = 16'd0;
        norm_exp = 3'd0;

        if (|x_in[15:14]) begin
            norm_m = x_in;
            norm_exp = 3'd0;
        end else if (|x_in[13:12]) begin
            norm_m = x_in << 2;
            norm_exp = 3'd1;
        end else if (|x_in[11:10]) begin
            norm_m = x_in << 4;
            norm_exp = 3'd2;
        end else if (|x_in[9:8]) begin
            norm_m = x_in << 6;
            norm_exp = 3'd3;
        end else if (|x_in[7:6]) begin
            norm_m = x_in << 8;
            norm_exp = 3'd4;
        end else if (|x_in[5:4]) begin
            norm_m = x_in << 10;
            norm_exp = 3'd5;
        end else if (|x_in[3:2]) begin
            norm_m = x_in << 12;
            norm_exp = 3'd6;
        end else if (|x_in[1:0]) begin
            norm_m = x_in << 14;
            norm_exp = 3'd7;
        end
    end

    // r_next = r * (3 - m*r*r) / 2
    reg [19:0] m_reg;  // UQ2.18
    reg [2:0] exp_reg;

    reg [19:0] r_reg;
    reg [19:0] t1_reg;
    reg [19:0] t2_reg;
    reg [19:0] t3_reg;

    reg [35:0] final_product; // UQ2.34 -- m * r = sqrt(m)

    // Initial value generate
    wire [4:0] seed_addr;
    wire [5:0] seed_value;
    wire [19:0] seed_q218;

    assign seed_addr = m_reg[17:13] - 5'd8;
    assign seed_q218 = {seed_value, 14'b00000000000000};

    seed_lut u_seed_lut (
        .addr     (seed_addr),
        .seed_out (seed_value)
    );

    // Shared multiplier: UQ2.18 x UQ2.18 = UQ4.36
    reg [19:0] mul_a; // UQ2.18
    reg [19:0] mul_b; // UQ2.18
    wire [39:0] mul_p; // UQ4.36

    mul_unit u_mul_unit (
        .a (mul_a),
        .b (mul_b),
        .p (mul_p)
    );

    always @(*) begin
        mul_a = 20'd0;
        mul_b = 20'd0;

        case (state)
            S_NR1_SQ, S_NR2_SQ: begin
                mul_a = r_reg;
                mul_b = r_reg;
            end

            S_NR1_MUL_M, S_NR2_MUL_M: begin
                mul_a = m_reg;
                mul_b = t1_reg;
            end

            S_NR1_UPDATE, S_NR2_UPDATE: begin
                mul_a = r_reg;
                mul_b = t3_reg;
            end

            S_FINAL_MUL: begin
                mul_a = m_reg;
                mul_b = r_reg;
            end

            default: begin
                mul_a = 20'd0;
                mul_b = 20'd0;
            end
        endcase
    end

    // 1. Restore the exponent: sqrt(x) = sqrt(m) * 2^(-e), UQ2.34.
    // 2. Take [34:26] as UQ1.8.
    // 3. Round-half-up with bit [25].
    reg [35:0] sqrt_x_q234;
    reg [8:0] sqrt_x_q18_trunc;
    reg [8:0] rounded_result;

    always @(*) begin
        case (exp_reg)
            3'd0: sqrt_x_q234 = final_product;
            3'd1: sqrt_x_q234 = {1'b0, final_product[35:1]};
            3'd2: sqrt_x_q234 = {2'b00, final_product[35:2]};
            3'd3: sqrt_x_q234 = {3'b000, final_product[35:3]};
            3'd4: sqrt_x_q234 = {4'b0000, final_product[35:4]};
            3'd5: sqrt_x_q234 = {5'b00000, final_product[35:5]};
            3'd6: sqrt_x_q234 = {6'b000000, final_product[35:6]};
            3'd7: sqrt_x_q234 = {7'b0000000, final_product[35:7]};
            default: sqrt_x_q234 = 36'd0;
        endcase

        sqrt_x_q18_trunc = sqrt_x_q234[34:26];
        rounded_result = sqrt_x_q18_trunc + {8'd0, sqrt_x_q234[25]};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            sqrt_out <= 9'd0;
            m_reg <= 20'd0;
            exp_reg <= 3'd0;
            r_reg <= 20'd0;
            t1_reg <= 20'd0;
            t2_reg <= 20'd0;
            t3_reg <= 20'd0;
            final_product <= 36'd0;
        end
        else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        if (x_in == 16'd0) begin
                            sqrt_out <= 9'd0;
                            state <= S_DONE;
                        end
                        else begin
                            m_reg <= {2'b00, norm_m, 2'b00};
                            exp_reg <= norm_exp;
                            state <= S_LOAD_SEED;
                        end
                    end
                end

                S_LOAD_SEED: begin
                    r_reg <= seed_q218;
                    state <= S_NR1_SQ;
                end

                // r^2: UQ4.36 -> UQ2.18.
                S_NR1_SQ: begin
                    t1_reg <= mul_p[37:18];
                    state <= S_NR1_MUL_M;
                end

                // m*r^2: UQ4.36 -> UQ2.18.
                S_NR1_MUL_M: begin
                    t2_reg <= mul_p[37:18];
                    state <= S_NR1_SUB;
                end

                S_NR1_SUB: begin
                    t3_reg <= THREE_Q218 - t2_reg;
                    state <= S_NR1_UPDATE;
                end

                // r*(3-m*r^2): UQ4.36 -> UQ2.18
                S_NR1_UPDATE: begin
                    r_reg <= mul_p[38:19]; // r*(3-m*r^2)/2
                    state <= S_NR2_SQ;
                end

                S_NR2_SQ: begin
                    t1_reg <= mul_p[37:18];
                    state <= S_NR2_MUL_M;
                end

                S_NR2_MUL_M: begin
                    t2_reg <= mul_p[37:18];
                    state <= S_NR2_SUB;
                end

                S_NR2_SUB: begin
                    t3_reg <= THREE_Q218 - t2_reg;
                    state <= S_NR2_UPDATE;
                end

                S_NR2_UPDATE: begin
                    r_reg <= mul_p[38:19];
                    state <= S_FINAL_MUL;
                end

                // UQ4.36 -> UQ2.34
                S_FINAL_MUL: begin
                    final_product <= mul_p[37:2];
                    state <= S_FINAL_ROUND;
                end

                S_FINAL_ROUND: begin
                    sqrt_out <= rounded_result;
                    state <= S_DONE;
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule
