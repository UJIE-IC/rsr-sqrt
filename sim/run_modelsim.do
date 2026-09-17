if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vmap work work

vlog -sv ../rtl/mul_unit.v
vlog -sv ../rtl/seed_lut.v
vlog -sv ../rtl/sqrt_core.v
vlog -sv ../rtl/sqrt_top.v
vlog -sv tb/sqrt_core_tb.sv

vsim -c work.sqrt_core_tb
run -all
quit -f
