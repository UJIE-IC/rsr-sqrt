`timescale 1ns/1ps

module sqrt_core_tb;

    localparam integer MAX_LATENCY_CYCLES = 20;

    logic        clk;
    logic        rst_n;
    logic        start;
    logic [15:0] x_in;
    wire         busy;
    wire         done;
    wire [8:0]   sqrt_out;

    integer expected_fd;
    integer result_fd;
    integer scan_status;
    integer input_code;
    integer expected_code;
    integer input_count;
    integer error_count;

    sqrt_top dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .x_in     (x_in),
        .busy     (busy),
        .done     (done),
        .sqrt_out (sqrt_out)
    );

    always #5 clk = ~clk;

    task automatic run_vector;
        input integer vector_input;
        input integer vector_expected;
        integer cycles_waited;
        integer actual_code;
        begin
            @(negedge clk);
            x_in = vector_input[15:0];
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            cycles_waited = 0;
            while ((done !== 1'b1) && (cycles_waited < MAX_LATENCY_CYCLES)) begin
                @(posedge clk);
                #1;
                cycles_waited = cycles_waited + 1;
            end

            actual_code = sqrt_out;
            input_count = input_count + 1;

            if ((done !== 1'b1) || (actual_code !== vector_expected)) begin
                error_count = error_count + 1;
                $fdisplay(result_fd, "%0d %0d %0d 0", vector_input,
                          vector_expected, actual_code);
                $display("FAIL X=%0d expected=%0d actual=%0d cycles=%0d",
                         vector_input, vector_expected, actual_code, cycles_waited);
            end
            else begin
                $fdisplay(result_fd, "%0d %0d %0d 1", vector_input,
                          vector_expected, actual_code);
            end

            if ((input_count % 4096) == 0)
                $display("Checked %0d vectors; errors=%0d", input_count, error_count);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        x_in = 16'd0;
        input_count = 0;
        error_count = 0;

        expected_fd = $fopen("data/rsr_newton_uq218/expected_uq18.txt", "r");
        result_fd = $fopen("data/rsr_newton_uq218/rtl_uq18_results.txt", "w");

        if (expected_fd == 0)
            $fatal(1, "Cannot open expected_uq18.txt");
        if (result_fd == 0)
            $fatal(1, "Cannot create rtl_uq18_results.txt");

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        while (!$feof(expected_fd)) begin
            scan_status = $fscanf(expected_fd, "%d %d\n", input_code, expected_code);
            if (scan_status == 2)
                run_vector(input_code, expected_code);
        end

        $fclose(expected_fd);
        $fclose(result_fd);

        if (input_count != 65536)
            $fatal(1, "Expected 65536 vectors, read %0d", input_count);
        if (error_count != 0)
            $fatal(1, "FAIL: %0d mismatches out of %0d vectors", error_count, input_count);

        $display("PASS: all %0d RTL vectors matched the exact reference.", input_count);
        $finish;
    end

endmodule
