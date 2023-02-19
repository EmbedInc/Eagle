{   Public include file for the EAGLE library.  This library provides routines
*   relating to the Eagle electrical CAD program.
}
const
  eagle_subsys_k = -77;                {subsystem ID for the EAGLE library}

type
  eagle_p_t = ^eagle_t;                {pointer to EAGLE library use state}

  eagle_scr_p_t = ^eagle_scr_t;
  eagle_scr_t = record                 {state for writing an EAGLE script file}
    next_p: eagle_scr_p_t;             {to next open script file in list}
    egl_p: eagle_p_t;                  {to library use state}
    conn: file_conn_t;                 {connection to .SCR output file}
    buf: string_var8192_t;             {one line output buffer}
    end;

  eagle_t = record                     {state for one use of EAGLE library}
    mem_p: util_mem_context_p_t;       {to private memory context}
    xf: vect_xf2d_t;                   {2D transform}
    inv: boolean;                      {2D transform inverts}
    lastx, lasty: real;                {last X,Y coordinate written, model space}
    scr_p: eagle_scr_p_t;              {to list of open script output files}
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

procedure eagle_scr_char (             {write character to Eagle script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      c: char;                     {character to write}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_circle (           {write circle command to Eagle script}
  in out  scr: eagle_scr_t;            {script writing state}
  in      x, y: real;                  {center point}
  in      rad: real;                   {radius}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_close (            {close Eagle script output file}
  in out  scr_p: eagle_scr_p_t;        {to script writing state, returned NIL}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_cmdend (           {";" command end and write line to script file}
  in out  scr: eagle_scr_t;            {script writing state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_fp (               {write floating point value to script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      fp: real;                    {value to write}
  in      n: sys_int_machine_t;        {number of digits right of decimal point}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_hole (             {write hole command to Eagle script}
  in out  scr: eagle_scr_t;            {script writing state}
  in      x, y: real;                  {center point}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_int (              {write integer to script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      ii: sys_int_machine_t;       {integer value to write}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_line (             {curr line to script file, reset line to empty}
  in out  scr: eagle_scr_t;            {script writing state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_open (             {start writing an Eagle script file}
  in out  egl: eagle_t;                {state for this use of the library}
  in      fnam: univ string_var_arg_t; {script file name, ".scr" suffix implied}
  out     scr_p: eagle_scr_p_t;        {pointer to new script writing state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_str (              {write Pascal string to script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      s: string;                   {the string to write, blank pad or NULL term}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_strline (          {write string as whole line, old line finished first}
  in out  scr: eagle_scr_t;            {script writing state}
  in      s: string;                   {the string to write, blank pad or NULL term}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_strlinev (         {write vstring as whole line, old line finished first}
  in out  scr: eagle_scr_t;            {script writing state}
  in      s: univ string_var_arg_t;    {the string to write}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_strv (             {write var string to script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      s: univ string_var_arg_t;    {the string to write}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_text (             {write text command to Eagle script}
  in out  scr: eagle_scr_t;            {script writing state}
  in      x, y: real;                  {text anchor point}
  in      s: string;                   {text string to write}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_textv (            {write text command to Eagle script}
  in out  scr: eagle_scr_t;            {script writing state}
  in      x, y: real;                  {text anchor point}
  in      s: univ string_var_arg_t;    {text string to write}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_scr_xy (               {write X,Y coor in Eagle format to script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      x, y: real;                  {X,Y coordinate, tranform applied before write}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure eagle_xform_pnt (            {apply current 2D transform to a point}
  in out  egl: eagle_t;                {state for use of this library}
  in      x, y: real;                  {model space coordinate to transform}
  out     x2, y2: real);               {resulting Eagle space coordinate}
  val_param; extern;
