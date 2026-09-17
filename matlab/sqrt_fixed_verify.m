% Bit-accurate reference model for rtl/sqrt_core.v.
% Generates the 24-entry UQ2.4 midpoint LUT and exhaustively checks all
% 16-bit input codes against round(sqrt(X)), where X is the input code.

clear;
clc;

SEED_FRAC = 4;
NR_FRAC = 18;
NR_ITER = 2;
INPUT_FRAC = 16;
OUTPUT_FRAC = 8;
THREE_Q218 = uint64(3 * 2^NR_FRAC);
MASK6 = uint64(2^6 - 1);
MASK16 = uint64(2^16 - 1);
MASK20 = uint64(2^20 - 1);
MASK40 = uint64(2^40 - 1);
MASK36 = uint64(2^36 - 1);
MASK9 = uint64(2^9 - 1);

% Generate the same midpoint LUT used by seed_lut.v.
lut_q24 = zeros(1, 24, 'uint64');
for k = 0:23
    midpoint = (k + 8.5) / 32;
    lut_q24(k + 1) = bitand( ...
        uint64(floor((2^SEED_FRAC / sqrt(midpoint)) + 0.5)), MASK6);
end

fprintf('UQ2.4 midpoint LUT (%d bits total):\n', 24 * (2 + SEED_FRAC));
fprintf('%s\n', sprintf('%02X ', lut_q24));

% Exhaustive bit-accurate verification.
error_count = 0;
first_errors = zeros(0, 3);
max_error = uint64(0);

for x_code = uint64(0):uint64(65535)
    if x_code == 0
        y_code = uint64(0);
    else
        % Normalize x = m * 2^(-2e), with m in [0.25, 1).
        msb = 15;
        while bitget(x_code, msb + 1) == 0
            msb = msb - 1;
        end
        e = floor((15 - msb) / 2);
        m_q016 = bitand(bitshift(x_code, 2 * e), MASK16); % m in UQ0.16
        m_q218 = bitand(bitshift(m_q016, NR_FRAC - INPUT_FRAC), MASK20);

        lut_addr = double(bitshift(m_q218, -13)) - 8;
        r_code = bitand( ...
            bitshift(lut_q24(lut_addr + 1), NR_FRAC - SEED_FRAC), MASK20);

        for iter = 1:NR_ITER
            % These masks model the destination register widths in RTL.
            % MASK40 models the output width of the shared 20x20 multiplier.
            r2_product = bitand(r_code * r_code, MASK40);
            r2_code = bitand(bitshift(r2_product, -NR_FRAC), MASK20);
            mr2_product = bitand(m_q218 * r2_code, MASK40);
            mr2_code = bitand(bitshift(mr2_product, -NR_FRAC), MASK20);
            correction_code = bitand(THREE_Q218 - mr2_code, MASK20);
            update_product = bitand(r_code * correction_code, MASK40);
            r_code = bitand(bitshift(update_product, -(NR_FRAC + 1)), MASK20);
        end

        % UQ2.18 x UQ2.18 = UQ4.36, then UQ4.36 -> UQ2.34.
        final_product_40 = bitand(m_q218 * r_code, MASK40);
        final_product = bitand(bitshift(final_product_40, -2), MASK36);

        % Restore the exponent, take UQ1.8, then round-half-up.
        sqrt_x_q234 = bitshift(final_product, -e);
        sqrt_x_q18_trunc = bitand(bitshift(sqrt_x_q234, -26), MASK9);
        y_code = sqrt_x_q18_trunc + uint64(bitget(sqrt_x_q234, 26));
    end

    reference_code = uint64(floor(sqrt(double(x_code)) + 0.5));
    this_error = abs(double(y_code) - double(reference_code));
    if this_error ~= 0
        error_count = error_count + 1;
        if size(first_errors, 1) < 10
            first_errors(end + 1, :) = [double(x_code), double(y_code), ...
                                         double(reference_code)]; %#ok<SAGROW>
        end
    end
    max_error = max(max_error, uint64(this_error));
end

fprintf('Inputs checked : %d\n', 65536);
fprintf('Error count    : %d\n', error_count);
fprintf('Maximum error  : %d LSB\n', max_error);
if isempty(first_errors)
    fprintf('PASS: all 65536 input codes match round(sqrt(X)).\n');
else
    fprintf('First mismatches [X, RTL, reference]:\n');
    disp(first_errors);
    error('Exhaustive verification failed.');
end
