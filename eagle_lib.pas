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

  egl_p^.mem_p := mem_p;               {save pointer to our memory context}
  eagle_xform_reset (egl_p^);          {reset the 2D transform to identity}
  egl_p^.lastx := 0.0;                 {init last-written coordinate}
  egl_p^.lasty := 0.0;
  egl_p^.scr_p := nil;                 {init to not writing any script files}
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
  scr_p: eagle_scr_p_t;                {pointer to current script file writing state}

begin
  sys_error_none (stat);               {init to no error encountered}
{
*   Close any script files open for write.
}
  while true do begin                  {loop until no more open script files}
    scr_p := egl_p^.scr_p;             {get pointer to current start of list}
    if scr_p = nil then exit;          {list is now empty ?}
    eagle_scr_close (scr_p, stat);     {close this script file, remove from list}
    if sys_error(stat) then return;
    end;                               {back to close first in list again}
{
*   Deallocate all the dynamic memory of this library use.
}
  mem_p := egl_p^.mem_p;               {save pointer to lib use mem context}
  util_mem_context_del (mem_p);        {del lib mem context, dealloc lib mem}

  egl_p := nil;                        {invalidate pointer to deleted lib use}
  end;
