{   High level library manangement.
}
module eagle_lib;
define eagle_lib_new;
define eagle_lib_end;
%include 'eagle2.ins.pas';
{
********************************************************************************
*
*   Subroutine EAGLE_LIB_NEW (MEM, EGL_P, STAT)
*
*   Create a new use of the EAGLE library.  MEM is the parent memory context.  A
*   subordinate memory context will be created for the new library use.  EGL_P
*   is returned pointing to the new library use state.
}
procedure eagle_lib_new (              {create new use of the EAGLE library}
  in out  mem: util_mem_context_t;     {parent mem context, will create subordinate}
  out     egl_p: eagle_p_t;            {returned pointer to the new library state}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  mem_p: util_mem_context_p_t;         {to new mem context for this lib use}

begin
  util_mem_context_get (mem, mem_p);   {create new mem context}
  if util_mem_context_err (mem_p, stat) then return;

  util_mem_grab (                      {allocate mem for new library use state}
    sizeof(egl_p^), mem_p^, false, egl_p);
  if util_mem_grab_err (egl_p, sizeof(egl_p^), stat) then return;

  egl_p^.mem_p := mem_p;
  egl_p^.xf.xb.x := 1.0;
  egl_p^.xf.xb.y := 0.0;
  egl_p^.xf.yb.x := 0.0;
  egl_p^.xf.yb.y := 1.0;
  egl_p^.xf.ofs.x := 0.0;
  egl_p^.xf.ofs.y := 0.0;
  egl_p^.inv := false;
  egl_p^.lastx := 0.0;
  egl_p^.lasty := 0.0;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_LIB_END (EGL_P, STAT)
*
*   End the use of the EAGLE library pointed to by EGL_P.  EGL_P is returned
*   NIL.
}
procedure eagle_lib_end (              {end of use of the EAGLE library}
  in out  egl_p: eagle_p_t;            {library use state, returned NIL}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  mem_p: util_mem_context_p_t;         {to new mem context for this lib use}

begin
  sys_error_none (stat);               {init to no error encountered}

  mem_p := egl_p^.mem_p;               {save pointer to lib use mem context}
  util_mem_context_del (mem_p);        {del lib mem context, dealloc lib mem}
  egl_p := nil;                        {invalidate pointer to deleted lib use}
  end;
