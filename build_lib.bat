@echo off
rem
rem   BUILD_LIB
rem
rem   Build the EAGLE library.
rem
setlocal
call build_pasinit

call src_insall %srcdir% %libname%

call src_pas %srcdir% %libname%_cmd
call src_pas %srcdir% %libname%_cmd_arc
call src_pas %srcdir% %libname%_draw
call src_pas %srcdir% %libname%_draw_bom
call src_pas %srcdir% %libname%_draw_text
call src_pas %srcdir% %libname%_lib
call src_pas %srcdir% %libname%_parts
call src_pas %srcdir% %libname%_parts_read
call src_pas %srcdir% %libname%_rndcor
call src_pas %srcdir% %libname%_scr
call src_pas %srcdir% %libname%_textwrap
call src_pas %srcdir% %libname%_xform

call src_lib %srcdir% %libname%
call src_msg %srcdir% %libname%

call src_get %srcdir% eagle_local.ins.pas
copya eagle_local.ins.pas ~/eagle/scr/source/eagle_local.ins.pas
call src_get %srcdir% egl.ins.pas
copya egl.ins.pas ~/eagle/scr/source/egl.ins.pas
