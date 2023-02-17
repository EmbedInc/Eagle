{   Public include file for the EAGLE library.  This library provides routines
*   relating to the Eagle electrical CAD program.
}
const
  eagle_subsys_k = -77;                {subsystem ID for the EAGLE library}

type
  eagle_p_t = ^eagle_t;
  eagle_t = record                     {state for one use of EAGLE library}
    mem_p: util_mem_context_p_t;       {to private memory context}
    xf: vect_xf2d_t;                   {2D transform}
    inv: boolean;                      {2D transform inverts}
    lastx, lasty: real;                {last X,Y coordinate written, model space}
    end;

  eagle_scr_p_t = ^eagle_scr_t;
  eagle_scr_t = record                 {state for writing an EAGLE script file}
    egl_p: eagle_p_t;                  {to library use state}
    conn: file_conn_t;                 {connection to .SCR output file}
    buf: string_var8192_t;             {one line output buffer}
    end;
{
*   Subroutines and functions.
}
procedure eagle_lib_end (              {end of use of the EAGLE library}
  in out  egl_p: eagle_p_t;            {library use state, returned NIL}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_lib_new (              {create new use of the EAGLE library}
  in out  mem: util_mem_context_t;     {parent mem context, will create subordinate}
  out     egl_p: eagle_p_t;            {returned pointer to the new library state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;
