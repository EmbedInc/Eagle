@echo off
rem
rem   Build everything from this source directory.
rem
setlocal
call godir "(cog)source/eagle"

escr build_ulp
call build_lib
call build_progs
call build_doc
