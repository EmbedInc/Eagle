{   Private include file for routines implementing the EAGLE library.
}
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'math.ins.pas';
%include 'vect.ins.pas';
%include 'stuff.ins.pas';
%include 'part.ins.pas';
%include 'eagle.ins.pas';

procedure eagle_rend_init (            {init RENDlib, set up for writing 2D drawing to script}
  in      xlft, xrit: real;            {left/right Eagle coordinate limits to draw to}
  in      ybot, ytop: real;            {bottom/top Eagle coordinate limits to draw to}
  in out  scr: eagle_scr_t;            {script to write drawing commands to}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;
