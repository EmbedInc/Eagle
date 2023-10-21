{   Routines for writing to Eagle script files.
}
module eagle_scr;
define eagle_scr_open;
define eagle_scr_close;
define eagle_scr_echo_stdout;
define eagle_scr_char;
define eagle_scr_space;
define eagle_scr_strv;
define eagle_scr_str;
define eagle_scr_int;
define eagle_scr_fp;
define eagle_scr_xy;
define eagle_scr_line;
define eagle_scr_cmdend;
define eagle_scr_strlinev;
define eagle_scr_strline;
define eagle_scr_arcdir;
define eagle_scr_rndcor;
%include 'eagle2.ins.pas';
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_OPEN (EGL, FNAM, SCR_P, STAT)
*
*   Initialize for writing to an Eagle script file.  FNAM is the script file
*   name.  The ".scr" file name suffix may be omitted.
*
*   SCR_P is returned pointing to the state for writing to the script file.
}
procedure eagle_scr_open (             {start writing an Eagle script file}
  in out  egl: eagle_t;                {state for this use of the library}
  in      fnam: univ string_var_arg_t; {script file name, ".scr" suffix implied}
  out     scr_p: eagle_scr_p_t;        {pointer to new script writing state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  util_mem_grab (                      {allocate memory for script writing state}
    sizeof(scr_p^), egl.mem_p^, true, scr_p);

  scr_p^.next_p := egl.scr_p;          {init script writing state}
  scr_p^.egl_p := addr(egl);
  scr_p^.thick := -1.0;                {init line thickness to unknown}
  scr_p^.lstyle := eagle_lstyle_unk_k; {init line style to unknown}
  scr_p^.buf.max := size_char(scr_p^.buf.str);
  scr_p^.buf.len := 0;
  scr_p^.echout := false;

  file_open_write_text (               {open the script output file}
    fnam, '.scr',                      {file name and required suffix}
    scr_p^.conn,                       {returned connection to the file}
    stat);
  if sys_error(stat) then begin        {couldn't open file ?}
    util_mem_ungrab (scr_p, egl.mem_p^); {deallocate script writing state}
    return;                            {return with error}
    end;

  egl.scr_p := scr_p;                  {link to list of open scripts being written}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_CLOSE (SCR_P, STAT)
*
*   Close an Eagle script file that is open for writing.  SCR_P points to the
*   script file writing state, and is returned NIL.  Any partially built line
*   is first written to the file.
}
procedure eagle_scr_close (            {close Eagle script output file}
  in out  scr_p: eagle_scr_p_t;        {to script writing state, returned NIL}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  egl_p: eagle_p_t;                    {saved pointer to EAGLE lib use state}
  scr_pp: ^eagle_scr_p_t;              {to forward pointer in list}

begin
  sys_error_none (stat);               {init to no error encountered}
  egl_p := scr_p^.egl_p;               {save pointer to EAGLE lib use state}

  if scr_p^.buf.len > 0 then begin     {there is unwritten data ?}
    eagle_scr_line (scr_p^, stat);     {write the buffered data}
    if sys_error(stat) then return;
    end;

  file_close (scr_p^.conn);            {close the connection to the script file}

  scr_pp := addr(egl_p^.scr_p);        {init to start of list pointer}
  while true do begin                  {scan the list of script files being written}
    if scr_pp^ = nil then exit;        {hit end of list ?}
    if scr_pp^ = scr_p then begin      {found entry for this script ?}
      scr_pp^ := scr_p^.next_p;        {unlink this script from open list}
      exit;
      end;
    scr_pp := addr(scr_pp^^.next_p);   {to next forward pointer in list}
    end;

  util_mem_ungrab (scr_p, egl_p^.mem_p^); {deallocate script writing state memory}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_ECHO_STDOUT (SCR, ECHO, STAT)
*
*   Enable or disable echoing writing to the Eagle script open on SCR to STDOUT.
}
procedure eagle_scr_echo_stdout (      {enable/disable echo script writing to STDOUT}
  in out  scr: eagle_scr_t;            {script writing state}
  in      echo: boolean;               {enable echoing to STDOUT}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}

  scr.echout := echo;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_CHAR (SCR, C, STAT)
*
*   Append the character C to the end of the line being built for writing to the
*   Eagle script open on SCR.
}
procedure eagle_scr_char (             {write character to Eagle script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      c: char;                     {character to write}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}

  string_append1 (scr.buf, c);         {append the character}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_SPACE (SCR, STAT)
*
*   Make sure that there is a separator after whatever is previously on the
*   current script output line.  SCR is the script writing state.  A space is
*   added to the current output line unless that line is empty or already ends
*   in a space.
}
procedure eagle_scr_space (            {guarantee space separator after previous}
  in out  scr: eagle_scr_t;            {script writing state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}

  if scr.buf.len <= 0 then return;     {line is empty, nothing to separate from ?}
  if scr.buf.str[scr.buf.len] = ' ' then return; {already ends in space separator ?}

  eagle_scr_char (scr, ' ', stat);     {add space separator at end of line}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_STRV (SCR, S, STAT)
*
*   Append the var string S to the end of the line being built for writing to
*   the Eagle script open on SCR.
}
procedure eagle_scr_strv (             {write var string to script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      s: univ string_var_arg_t;    {the string to write}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}

  string_append (scr.buf, s);          {append the string}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_STR (SCR, S, STAT)
*
*   Append the Pascal string S to the end of the line being built for writing to
*   the Eagle script open on SCR.
}
procedure eagle_scr_str (              {write Pascal string to script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      s: string;                   {the string to write, blank pad or NULL term}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  eagle_scr_strv (scr, string_v(s), stat);
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_INT (SCR, II, STAT)
*
*   Append the integer value II to the end of the line being built for writing
*   to the Eagle script open on SCR.
}
procedure eagle_scr_int (              {write integer to script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      ii: sys_int_machine_t;       {integer value to write}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  tk: string_var32_t;                  {scratch string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int (tk, ii);               {make integer string}
  eagle_scr_strv (scr, tk, stat);      {append it to the current output line}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_FP (SCR, FP, N, STAT)
*
*   Append the floating point value FP to the end of the line being built for
*   writing to the Eagle script open on SCR.  N is the number of digits to write
*   right of the decimal point.
}
procedure eagle_scr_fp (               {write floating point value to script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      fp: real;                    {value to write}
  in      n: sys_int_machine_t;        {number of digits right of decimal point}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  tk: string_var32_t;                  {scratch string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_fp_fixed (tk, fp, n);       {make the floating point string}
  eagle_scr_strv (scr, tk, stat);      {append it to the current output line}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_XY (SCR, X, Y, STAT)
*
*   Append the X,Y coordinate to the end of the line being built for writing to
*   the Eagle script open on SCR.  The X,Y coordinate will be written in the
*   format required by Eagle commands.
*
*   The current 2D transform is applied to point X,Y before it is written.  The
*   last-written coordinate is updated to X,Y.
}
procedure eagle_scr_xy (               {write X,Y coor in Eagle format to script file}
  in out  scr: eagle_scr_t;            {script writing state}
  in      x, y: real;                  {X,Y coordinate, tranform applied before write}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  egl_p: eagle_p_t;                    {to EAGLE library use state}
  x2, y2: real;                        {transformed coordinate}

begin
  egl_p := scr.egl_p;                  {save pointer to library use state}
  eagle_xform_pnt (egl_p^, x, y, x2, y2); {transform the point}

  eagle_scr_str (scr, ' ('(0), stat);  {start 2D coordinate}
  if sys_error(stat) then return;
  eagle_scr_fp (scr, x2, 4, stat);     {write X}
  if sys_error(stat) then return;
  eagle_scr_char (scr, ' ', stat);     {space before Y}
  if sys_error(stat) then return;
  eagle_scr_fp (scr, y2, 4, stat);     {write Y}
  if sys_error(stat) then return;
  eagle_scr_char (scr, ')', stat);     {end the 2D coordinate}
  if sys_error(stat) then return;

  egl_p^.lastx := x;                   {update last point written}
  egl_p^.lasty := y;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_LINE (SCR, STAT)
*
*   Write the current bufferend output line to the Eagle script file.  SCR is
*   the script file writing state.  The current output line is reset to empty
*   after being written.  Nothing is done if the current output line is already
*   empty.
}
procedure eagle_scr_line (             {curr line to script file, reset line to empty}
  in out  scr: eagle_scr_t;            {script writing state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  if scr.buf.len <= 0 then begin       {the current output line is empty ?}
    scr.buf.len := 0;                  {set its length to exactly 0}
    sys_error_none (stat);             {indicate no error encountered}
    return;
    end;

  if scr.echout then begin             {need to echo to STDOUT ?}
    writeln (scr.buf.str:scr.buf.len);
    end;

  file_write_text (scr.buf, scr.conn, stat); {write buffered line to the file}
  if sys_error(stat) then return;
  scr.buf.len := 0;                    {reset the buffered line to empty}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_CMDEND (SCR, STAT)
*
*   End the current command if one is in progress, and write the line to the
*   script file.  SCR is the Eagle script file writing state.  The ";" command
*   terminator is appended to the current output line before it is written to the
*   file.
*
*   Nothing is done if the current output line is empty.
}
procedure eagle_scr_cmdend (           {end any cmd in progress, write line}
  in out  scr: eagle_scr_t;            {script writing state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}

  if scr.buf.len > 0 then begin        {command in progress ?}
    eagle_scr_char (scr, ';', stat);   {end the command}
    if sys_error(stat) then return;
    eagle_scr_line (scr, stat);        {write the line to the file, reset line to empty}
    end;
  end;
{
********************************************************************************
*
*   Subroutine EALGE_SCR_STRLINEV (SCR, S, STAT)
*
*   Write the var string S as a whole line to an Eagle script file.  SCR is the
*   script file writing state.
*
*   If there is any unwritten data, it is written as a separate line first.
}
procedure eagle_scr_strlinev (         {write vstring as whole line, old line finished first}
  in out  scr: eagle_scr_t;            {script writing state}
  in      s: univ string_var_arg_t;    {the string to write}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  if scr.buf.len > 0 then begin        {there is current unwritten data ?}
    eagle_scr_line (scr, stat);        {write it}
    if sys_error(stat) then return;
    end;

  eagle_scr_strv (scr, s, stat);       {copy the string to the output line}
  if sys_error(stat) then return;
  eagle_scr_line (scr, stat);          {write the output line to the file}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_STRLINE (SCR, S, STAT)
*
*   Write the Pascal string S as a whole line to an Eagle script file.  SCR is
*   the script file writing state.
*
*   If there is any unwritten data, it is written as a separate line first.
}
procedure eagle_scr_strline (          {write string as whole line, old line finished first}
  in out  scr: eagle_scr_t;            {script writing state}
  in      s: string;                   {the string to write, blank pad or NULL term}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  eagle_scr_strlinev (scr, string_v(s), stat);
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_ARCDIR (SCR, CW, STAT)
*
*   Write the keyword for setting the arc direction in an ARC command.  SCR is
*   the Eagle script writing state.  CW indicates the desired arc direction.
*   The direction is in model space.  The arc direction written will be opposite
*   when the 2D transform inverts.
*
*   The keyword will be separated from previous and subsequent text.
}
procedure eagle_scr_arcdir (           {write arc direction keyword, separators added}
  in out  scr: eagle_scr_t;            {script writing state}
  in      cw: boolean;                 {arc direction is clockwise}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  c: boolean;                          {final clockwise after transform}

begin
  eagle_scr_space (scr, stat);         {guarantee separator after previous text}
  if sys_error(stat) then return;

  c := cw;                             {init for normal transform}
  if scr.egl_p^.inv then c := not c;   {flip for inverted transform}
  if c
    then eagle_scr_str (scr, 'cw ', stat)
    else eagle_scr_str (scr, 'ccw ', stat);
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_RNDCOR (SCR_P, E1, E2, CORN, RAD, STAT)
*
*   Write the script commands to draw two edges meeting with a round corner.  E1
*   and E2 are the open ends of the two edges.  CORN is the corner point where
*   they would meet if the corner was not rounded.  RAD is the radius of
*   curvature for the round corner.
}
procedure eagle_scr_rndcor (           {draw edges with round corner between them}
  in out  scr: eagle_scr_t;            {script writing state}
  in      e1, e2: vect_2d_t;           {the open ends of the two edges}
  in      corn: vect_2d_t;             {common corner point}
  in      rad: real;                   {radius of curvature in the corner}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  v1, v2: vect_2d_t;                   {init vectors from corner along each edge}
  a1, a2: vect_2d_t;                   {the two arc endpoints}
  acent: vect_2d_t;                    {center of the circle the arc is on}
  cw: boolean;                         {draw arc clockwise}

begin
  v1.x := e1.x - corn.x;               {make unit vector along edge 1}
  v1.y := e1.y - corn.y;
  vect_2d_unitize (v1);

  v2.x := e2.x - corn.x;               {make unit vector along edge 2}
  v2.y := e2.y - corn.y;
  vect_2d_unitize (v2);

  eagle_rndcor_arc (                   {find the parameters of the corner arc}
    corn,                              {corner point where the two edges meet}
    v1, v2,                            {unit vectors from corner along each edge}
    rad,                               {radius of curvature to draw corner with}
    acent,                             {returned arc center point}
    a1, a2,                            {returned arc end points}
    cw);                               {returned arc direction}

  eagle_scr_cmdend (scr, stat);        {make sure no command in progress}
  if sys_error(stat) then return;

  eagle_scr_str (scr, 'WIRE'(0), stat); {draw edge leading up to corner}
  if sys_error(stat) then return;
  eagle_scr_xy (scr, e1.x, e1.y, stat);
  if sys_error(stat) then return;
  eagle_scr_xy (scr, a1.x, a1.y, stat);
  if sys_error(stat) then return;
  eagle_scr_cmdend (scr, stat);
  if sys_error(stat) then return;

  eagle_cmd_arc_2pc (scr, a1, a2, acent, cw, stat); {draw the corner arc}
  if sys_error(stat) then return;

  eagle_scr_str (scr, 'WIRE'(0), stat); {draw edge away from corner}
  if sys_error(stat) then return;
  eagle_scr_xy (scr, a2.x, a2.y, stat);
  if sys_error(stat) then return;
  eagle_scr_xy (scr, e2.x, e2.y, stat);
  if sys_error(stat) then return;
  eagle_scr_cmdend (scr, stat);
  end;
