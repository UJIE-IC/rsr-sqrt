% Generate independent, exact UQ1.8 reference codes for RTL simulation.
% Each output code is round-half-up(sqrt(X)) for X = 0 ... 65535.

clear;
clc;

output_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'sim', ...
    'data', 'rsr_newton_uq218');
if ~isfolder(output_dir)
    mkdir(output_dir);
end

output_file = fullfile(output_dir, 'expected_uq18.txt');
file_id = fopen(output_file, 'w');
if file_id < 0
    error('Cannot open %s for writing.', output_file);
end

trial_bits = uint64([128 64 32 16 8 4 2 1]);

for x_code = uint64(0):uint64(65535)
    % Exact integer floor(sqrt(X)) using an 8-step binary search.
    floor_root = uint64(0);
    for trial_bit = trial_bits
        candidate = floor_root + trial_bit;
        if candidate * candidate <= x_code
            floor_root = candidate;
        end
    end

    % Exact round-half-up test, without floating-point arithmetic.
    halfway_square = (2 * floor_root + 1)^2;
    if 4 * x_code >= halfway_square
        rounded_root = floor_root + 1;
    else
        rounded_root = floor_root;
    end

    fprintf(file_id, '%d %d\n', x_code, rounded_root);
end

fclose(file_id);
fprintf('Generated 65536 exact reference vectors: %s\n', output_file);
