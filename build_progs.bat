@echo off
rem
rem   BUILD_PROGS
rem
rem   Build the executable programs from this source directory.
rem
setlocal
call build_pasinit

src_progl bom_draw
src_progl bom_kinetic
src_progl bom_labels
src_progl csv_bom
