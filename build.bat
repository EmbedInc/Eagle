@echo off
rem
rem   Build everything from this source directory.
rem
setlocal
call godir "(cog)source/eagle"

escr build_ulp
call build_progs
