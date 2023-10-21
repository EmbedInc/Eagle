{   Local Eagle utility routines.  This file should be included in the main
*   program after definitions of types, variables, and the like, and before the
*   first executable code.
*
*   This file defines one-off routines that are included in the main program in
*   source code form, not linked to from a library.
*
*   A brief description of each routine is listed here.  See the header comments
*   of the routines for details.
*
*   EGL_INIT
*
*     Init local state managed by this module.  Must be first call.
*
*   EGL_END
*
*     End use of these routines, close any associated open files.
*
*   OPEN_SCR
*
*     Opens the script output file.
*
*   XFORM_RESET
*
*     Resets the 2D transform to the identity.
*
*   XFORM (X1, Y1, X2, Y2)
*
*     2D transforms X1,Y1 to make X2,Y2.
*
*   XFORM_MOVE (X, Y)
*
*     Move transform origin to Eagle coordinates X,Y.
*
*   XFORM_MOVE_REL (X, Y)
*
*     Move transform origin to model coordinates X,Y.
*
*   XFORM_ROT (ANG)
*
*     Set absolute rotation ANG radians left about curr point.  Scale set to 1.
*
*   XFORM_ROT_REL (ANG)
*
*     Relative rotation ANG radians left about curr point.  Scale unchanged.
*
*   XFORM_SCALE_REL (S)
*
*     Scale transform by S.
*
*   XFORM_SAVE (SXF)
*
*     Save the current transform in SXF.
*
*   XFORM_REST (SXF)
*
*     Restore the current transform from SXF.
*
*   WARC_2PC (E1, E2, CENT, CW)
*
*     Write ARC, from two endpoints and circle center.
*
*   WBEND_DIRECT
*
*     Set bend style to no implied bends.
*
*   WCHAR (C)
*
*     Write character C.
*
*   WSTR (S)
*
*     Write Pascal string S.
*
*   WVSTR (S)
*
*     Write var string S.
*
*   WINT (I)
*
*     Write integer I.
*
*   WFP (FP, N)
*
*     Write floating point value FP with N fraction digits.
*
*   WXY (X, Y)
*
*     Write X,Y coordinate in Eagle format (2D transform applied).
*
*   WXYP (P)
*
*     Write 2D coordinate in Eagle format (2D transform applied).
*
*   WMOVE (NAME, NUM, X, Y)
*
*     Write MOVE command for <name><num> to location X,Y, Pascal string.
*
*   WMOVEV (NAME, NUM, X, Y)
*
*     Write MOVE command for <name><num> to location X,Y, var string.
*
*   WLINE
*
*     End current output line.
*
*   WEND
*
*     End Eagle command.  Writes ";", then ends the line.
*
*   WSTRLN (S)
*
*     End any current line, write Pascal string as whole new line.
*
*   WWIDTH (W)
*
*     Set line thickness.
*
*   WLINESEG (P1, P2)
*
*     Write WIRE command for line segment from P1 to P2.
*
*   WCIRC (X, Y, RAD)
*
*     Write CIRCLE command.
*
*   WHOLE (X, Y)
*
*     Write HOLE command.
*
*   WCORNER (E1, E2, CORN, RAD)
*
*     Write commands to draw corner with radius of curvature.
*
*   WTEXTV (X, Y, TEXT)
*
*     Write var string TEXT at X,Y.
*
*   WTEXT (X, Y, TEXT)
*
*     Write Pascal string TEXT at X,Y.
*
*   MM_INCH (DIST)
*   INCH_MM (DIST)
*
*     Function to convert from millimeters to inches, and inches to millimeters.
*
*   COIL (LEN, DIA, PHASE, NLOOPS)
*
*     Generates WIRE commands for drawing a looped coil.
*
*   ARCDIR (CW)
*
*     Write keyword for setting arc direction.  Considers transform.
}
var
  egl_p: eagle_p_t;                    {to EAGLE library use state}
  scr_p: eagle_scr_p_t;                {to state for writing script file}
{
********************************************************************************
*
*   Subroutine EGL_INIT
*
*   Initialize all the state managed by these Eagle script utility routines and
*   perform basic initialization of the calling program.
}
procedure egl_init;
  val_param; internal;

var
  stat: sys_err_t;                     {completion status}

begin
  eagle_lib_new (util_top_mem_context, egl_p, stat);
  sys_error_abort (stat, '', '', nil, 0);

  scr_p := nil;
  end;
{
********************************************************************************
*
*   Subroutine EGL_END
*
*   End the current use of these local routines.  Any open script files are
*   closed first.
}
procedure egl_end;
  val_param; internal;

var
  stat: sys_err_t;                     {completion status}

begin
  eagle_lib_end (egl_p, stat);
  sys_error_abort (stat, '', '', nil, 0);

  scr_p := nil;                        {indicate no script output file open}
  end;
{
********************************************************************************
*
*   Subroutine OPEN_SCR
*
*   Open the Eagle script output file.
}
procedure open_scr;                    {open the script output file}
  val_param; internal;

var
  stat: sys_err_t;                     {completion status}

begin
  eagle_scr_open (egl_p^, string_v(scrname), scr_p, stat);
  sys_error_abort (stat, '', '', nil, 0);

  eagle_scr_echo_stdout (scr_p^, true, stat); {echo script writing to STDOUT}
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine XFORM_RESET
*
*   Reset the 2D transform to the identity.
}
procedure xform_reset;
  val_param; internal;

begin
  eagle_xform_reset (egl_p^);
  end;
{
********************************************************************************
*
*   Subroutine XFORM (X1, Y1, X2, Y2)
*
*   Apply the 2D transform to X1,Y1 to make X2,Y2.
}
procedure xform (                      {apply the 2D transform}
  in      x1, y1: real;                {input coordinate}
  out     x2, y2: real);               {output coordinate}
  val_param; internal;

begin
  eagle_xform_pnt (egl_p^, x1, y1, x2, y2);
  end;
{
********************************************************************************
*
*   Subroutine XFORM_MOVE (X, Y)
*
*   Move the origin of the 2D model space to map to X,Y in the output space.
}
procedure xform_move (                 {move coordinate origin}
  in      x, y: real);                 {output space that new origin will map to}
  val_param; internal;

begin
  eagle_xform_move (egl_p^, x, y);
  end;
{
********************************************************************************
*
*   Subroutine XFORM_MOVE_REL (X, Y)
*
*   Change the model space origin offset so that model space 0,0 after this call
*   maps to the same output location as X,Y before this call.
}
procedure xform_move_rel (             {move model space origin to current X,Y}
  in      x, y: real);                 {curr model space point that will be origin}
  val_param; internal;

begin
  eagle_xform_move_rel (egl_p^, x, y);
  end;
{
********************************************************************************
*
*   Subroutine XFORM_ROT (ANG)
*
*   Set the 2D transform so that the output space is rotated ANG radians
*   counter-clockwise from the model space.  The scale factor is set to 1.  The
*   previous rotation and scaling is lost.  The current origin offset is not
*   altered.
}
procedure xform_rot (                  {rotate output space, absolute}
  in      ang: real);                  {radians output rotation from input}
  val_param; internal;

begin
  eagle_xform_rot (egl_p^, ang);
  end;
{
********************************************************************************
*
*   Subroutine XFORM_ROT_REL (ANG)
*
*   Set the 2D transform so that the output space is rotated ANG radians
*   counter-clockwise relative to the current orientation.  The scale factor is
*   not altered.  The current origin offset is not altered.
}
procedure xform_rot_rel (              {rotate output space, relative}
  in      ang: real);                  {radians output rotation from input}
  val_param; internal;

begin
  eagle_xform_rot_rel (egl_p^, ang);
  end;
{
********************************************************************************
*
*   Subroutine XFORM_SCALE_REL (S)
*
*   Apply the additional scaling S from the input to the output space.  For
*   example, if S is 2 then subsequent output will be 2 times larger than
*   previously.  The output coordinate that maps to the input coordinate origin
*   is not changed.  The new scale factor is applied relative to the current
*   scaling.  For example, calling this routine three times with a scale factor
*   of 2 is equivalent to calling it once with a scale factor of 8.
}
procedure xform_scale_rel (            {relative scale output}
  in      s: real);                    {scale output by this much}
  val_param; internal;

begin
  eagle_xform_scale_rel (egl_p^, s);
  end;
{
********************************************************************************
*
*   Subroutine XFORM_SAVE (SXF)
*
*   Save the current 2D transform into SXF.
}
procedure xform_save (                 {save current 2D transform}
  out     sxf: vect_xf2d_t);           {returned current 2D transform}
  val_param; internal;

begin
  eagle_xform_get (egl_p^, sxf);
  end;
{
********************************************************************************
*
*   Subroutine XFORM_REST (SXF)
*
*   Restore the current 2D transform from the saved state SXF.
}
procedure xform_rest (                 {restore 2D transform from saved state}
  in      sxf: vect_xf2d_t);           {saved state to restore to}
  val_param; internal;

begin
  eagle_xform_set (egl_p^, sxf);
  end;
{
********************************************************************************
*
*   Subroutine WCHAR (C)
*
*   Add the character C to the current output line.
}
procedure wchar (                      {add char to output line}
  in      c: char);                    {the character to add}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_char (scr_p^, c, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WSTR (S)
*
*   Add the string S to the current output line.
}
procedure wstr (                       {add string to output line}
  in      s: string);                  {string to add, blank pad or NULL terminate}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_str (scr_p^, s, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WVSTR (S)
*
*   Add the var string S to the current output line.
}
procedure wvstr (                      {add var string to output line}
  in      s: univ string_var_arg_t);   {the string to add}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_strv (scr_p^, s, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WINT (II)
*
*   Add the string representation of the integer II to the current output line.
}
procedure wint (                       {add integer to output line}
  in      ii: sys_int_machine_t);      {integer value to add}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_int (scr_p^, ii, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WFP (R, N)
*
*   Add the string representation of the floating point value R to the current
*   output line.  The string will have N digits right of the decimal point.
}
procedure wfp (                        {add floating point value to output line}
  in      r: real;                     {floating point value}
  in      n: sys_int_machine_t);       {number of digits right of decimal point}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_fp (scr_p^, r, n, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WXY (X, Y)
*
*   Write the X,Y coordinate in Eagle form to the current output line.  The 2D
*   transform is applied to the coordinate before it is written.
}
procedure wxy (                        {write Eagle X,Y coordinate to output line}
  in      x, y: real);                 {the coordinate to write}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_xy (scr_p^, x, y, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WXYP (P)
*
*   Write the 2D coordinate P in Eagle form to the current output line.  The 2D
*   transform is applied to the coordinate before it is written.
}
procedure wxyp (                       {write Eagle 2D coordinate to output line}
  in      p: vect_2d_t);               {the coordinate to write}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_xy (scr_p^, p.x, p.y, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WBEND_DIRECT
*
*   Set the wire bend style so that line segments are draw directly from one
*   endpoint to the other without any implied bends.
}
procedure wbend_direct;
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_cmd_bend_direct (scr_p^, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WMOVE (NAME, NUM, X, Y)
*
*   Write MOVE command for the component of designator NAME followed by the
*   number NUM to the coordinate X,Y.  NAME is a Pascal string.
}
procedure wmove (                      {write component MOVE command}
  in      name: string;                {generic component designator name}
  in      num: sys_int_machine_t;      {component designator number}
  in      x, y: real);                 {the coordinate to move the component to}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_cmd_move_cmp (scr_p^, string_v(name), num, x, y, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WMOVEV (NAME, NUM, X, Y)
*
*   Write MOVE command for the component of designator NAME followed by the
*   number NUM to the coordinate X,Y.  NAME is a var string.
}
procedure wmovev (                     {write component MOVE command}
  in      name: univ string_var_arg_t; {generic component designator name}
  in      num: sys_int_machine_t;      {component designator number}
  in      x, y: real);                 {the coordinate to move the component to}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_cmd_move_cmp (scr_p^, name, num, x, y, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WLINE
*
*   Write the line in BUF to the output file.  BUF is reset to empty.
}
procedure wline;                       {write out line in BUF, reset BUF to empty}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_line (scr_p^, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WEND
*
*   End the current line by adding a semicolon at the end, then write it to the
*   output.
}
procedure wend;                        {end line with semicolon, write the line}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_cmdend (scr_p^, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WSTRLN (S)
*
*   Write the string S as a whole line.  If something is already in the output
*   buffer, it as written as a separate line first.
}
procedure wstrln (                     {write string as whole line}
  in      s: string);                  {contents of the line to write}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_strline (scr_p^, s, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WWIDTH (W)
*
*   Set the line thickness.  Redundant line thickness settings are automatically
*   eliminated.  All line thickness changes must be made thru this routine or
*   EAGLE_CMD_THICK for this mechanism to work.
}
procedure wwidth (                     {set line thickness}
  in      w: real);                    {new line thickness}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_cmd_thick (scr_p^, w, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WLINESEG (P1, P2)
*
*   Write a WIRE command to draw a line segment from point P1 to point P2.
}
procedure wlineseg (                   {write line segment}
  in      p1, p2: vect_2d_t);          {line segment start and end points}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_line (scr_p^, stat);       {make sure any existing output line is ended}
  sys_error_abort (stat, '', '', nil, 0);

  eagle_scr_str (scr_p^, 'WIRE'(0), stat);
  sys_error_abort (stat, '', '', nil, 0);
  eagle_scr_xy (scr_p^, p1.x, p1.y, stat);
  sys_error_abort (stat, '', '', nil, 0);
  eagle_scr_xy (scr_p^, p2.x, p2.y, stat);
  sys_error_abort (stat, '', '', nil, 0);
  eagle_scr_cmdend (scr_p^, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WCIRC (X, Y, RAD)
*
*   Draw a circle centered at X,Y with radius RAD.  This will be a filled disc
*   if the current line width is 0.
}
procedure wcirc (                      {draw circle or filled disc}
  in      x, y: real;                  {center point}
  in      rad: real);                  {radius}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_cmd_circle (scr_p^, x, y, rad, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WHOLE (X, Y)
*
*   Create a hole at X,Y.  The current diameter is used, changed by CHANGE
*   DRILL.
}
procedure whole (                      {create hole}
  in      x, y: real);                 {hole center point}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_cmd_hole (scr_p^, x, y, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine ARCDIR (CW)
*
*   Write the keyword for setting the arc direction clockwise according to CW.
*   CW is for a non-inverted coordinate space.  If the transform inverts
*   according to INV, the direction of the arc is flipped.
}
procedure arcdir (                     {set arc direction}
  in      cw: boolean);                {clockwise}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_arcdir (scr_p^, cw, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WARC_2PC (E1, E2, CENT, CW)
*
*   Write an ARC command, with the arc defined by its two endpoints and the
*   center of the circle the arc is on.  E1 and E2 are the two endpoints, and
*   CENT the circle center.  The arc is drawn clockwise from E1 to E2 when CW
*   is TRUE, and counter-clockwise when it is false.
}
procedure warc_2pc (                   {write arc from two endpoints and circ center}
  in      e1, e2: vect_2d_t;           {the arc endpoints}
  in      cent: vect_2d_t;             {center of the circle the arc is on}
  in      cw: boolean);                {draw clockwise from E1 to E2}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_cmd_arc_2pc (                  {write the ARC command}
    scr_p^,                            {script writing state}
    e1, e2,                            {arc start and end points}
    cent,                              {circle center}
    cw,                                {clockwise}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WCORNER (E1, E2, CORN, RAD)
*
*   Draw edges meeting with round corner.  E1 and E2 are the open ends of the
*   two edges.  CORN is the corner point the edges would meet if the corner was
*   sharp.  RAD is the radius of curvature for the corner.
}
procedure wcorner (                    {draw two edges meeting in round corner}
  in      e1, e2: vect_2d_t;           {open endpoints of the two edges}
  in      corn: vect_2d_t;             {corner point}
  in      rad: real);                  {radius of curvature for the corner}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_scr_rndcor (                   {draw two edges with round corner between}
    scr_p^,                            {script writing state}
    e1, e2,                            {open endpoints of the two edges}
    corn,                              {corner point (if corner were sharp)}
    rad,                               {radius of curvature for the corner}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WTEXTV (X, Y, TEXT)
*
*   Draw the text TEXT anchored at X,Y.  TEXT is a var string.
}
procedure wtextv (                     {draw text from var string}
  in      x, y: real;                  {text anchor point}
  in      text: univ string_var_arg_t); {the text string to draw}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_cmd_text (scr_p^, x, y, text, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WTEXT (X, Y, TEXT)
*
*   Draw the text TEXT anchored at X,Y.  TEXT is a Pascal string.
}
procedure wtext (                      {draw text from Pascal string}
  in      x, y: real;                  {text anchor point}
  in      text: string);               {the text string to draw}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_cmd_text_s (scr_p^, x, y, text, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Function MM_INCH (DIST)
*
*   Converts the distance DIST from millimeters to inches.  This allows using
*   mm coordinates with a inch grid active.
}
function mm_inch (                     {convert from millimeters to inches}
  in      dist: real)                  {distance in millimeters}
  :real;                               {distance in inches}
  val_param; internal;

begin
  mm_inch := eagle_mm_inch (dist);
  end;
{
********************************************************************************
*
*   Function INCH_MM (DIST)
*
*   Converts the distance DIST from inches to millimeters.  This allows using
*   inch coordinates with a mm grid active.
}
function inch_mm (                     {convert from inches to millimeters}
  in      dist: real)                  {distance in inches}
  :real;                               {distance in mm}
  val_param; internal;

begin
  inch_mm := eagle_inch_mm (dist);
  end;
{
********************************************************************************
*
*   Subroutine COIL (LEN, DIA, PHASE, NLOOPS)
*
*   Draw a coil, like inductor symbol.
*
*   LEN is the overall length of the coil.  The coil will extend from (0,0) to
*   (LEN,0).
*
*   DIA is the diameter of individual loops if they were not stretched.  This
*   will also be the height of the coil.  The coil will extend DIA/2 both above
*   and below the X axis.
*
*   PHASE is the starting phase angle in units of a whole circle.  Within each
*   loop, 0 is the right side, 1/4 the top, 1/2 the left side, and 3/4 the
*   bottom.
*
*   NLOOPS is the number of whole loops to draw.  Loops will be drawn in
*   clockwise around the circle while the center point is advanced linearly to
*   the right.
*
*   This routine generates a single WIRE command with many points.
}
procedure coil (                       {draw coil}
  in      len: real;                   {length of coil along X axis}
  in      dia: real;                   {diameter of each loop}
  in      phase: real;                 {starting phase angle, units of circle}
  in      nloops: real);               {total number of loops to draw}
  val_param; internal;

const
  cirres = 20;                         {number of line segments to approximate a circle}

var
  rad: real;                           {loop radius}
  nseg: sys_int_machine_t;             {number of segments to draw}
  dang: real;                          {angle increment per segment}
  sang: real;                          {starting angle}
  eang: real;                          {ending angle}
  dxdisp: real;                        {X displacement per segment}
  stx: real;                           {starting X due to PHASE}
  enx: real;                           {ending X due to PHASE and NLOOPS}

  seg: sys_int_machine_t;              {0-NSEG coil segment number}
  ang: real;                           {current angle}
  xdisp: real;                         {X displacement at this segment}
  s, c: real;                          {sine and cosine}
  x, y: real;                          {scratch coordinate}

begin
  rad := dia / 2.0;                    {make loop radius}
  nseg := trunc((cirres * nloops) + 0.999); {number of segments to draw due to N loops}
  nseg := max(nseg, 4);                {minimum number of segments always drawn}
  sang := phase * pi2;                 {starting angle}
  eang := (phase - nloops) * pi2;      {ending angle}
  dang := (eang - sang) / nseg;        {angle increment per segment}
  stx := rad * cos(sang);              {starting X due to starting phase}
  enx := rad * cos(eang);              {ending X due to ending phase}
  x := enx - stx;                      {displacement due to phase change}
  dxdisp := (len - x) / nseg;          {X displacement to add per segment}

  wstr ('set wire_bend 2;');           {required for smooth curve}
  wline;

  wstr ('wire ');                      {start the Eagle WIRE command}
  for seg := 0 to nseg do begin        {once for each segment point}
    ang := sang + seg * dang;          {make angle at this point}
    xdisp := seg * dxdisp;             {make X displacement at this point}
    s := sin(ang);                     {make sine and cosine of this angle}
    c := cos(ang);
    x := xdisp - stx + c * rad;        {make X and Y of this point}
    y := s * rad;
    wxy (x, y);                        {write this point}
    if seg <> nseg then begin
      wline;
      end;
    end;
  wchar (';');
  wline;
  end;
