{   Routines to write whole commands to Eagle scripts.
}
module eagle_cmd;
define eagle_cmd_circle;
define eagle_cmd_hole;
define eagle_cmd_text;
define eagle_cmd_text_s;
define eagle_cmd_move_cmp;
define eagle_cmd_bend_direct;
define eagle_cmd_thick;
define eagle_cmd_lstyle;
%include 'eagle2.ins.pas';
{
********************************************************************************
*
*   Subroutine EAGLE_CMD_CIRCLE (SCR, X, Y, RAD, STAT)
*
*   Write a CIRCLE command to the Eagle script open for writing on SCR.  X,Y is
*   the circle center point and RAD its radius.  The current 2D transform is
*   applied before the circle is written.
}
procedure eagle_cmd_circle (           {write circle command to Eagle script}
  in out  scr: eagle_scr_t;            {script writing state}
  in      x, y: real;                  {center point}
  in      rad: real;                   {radius}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  eagle_scr_cmdend (scr, stat);        {make sure any previous command ended}
  if sys_error(stat) then return;

  eagle_scr_str (scr, 'circle'(0), stat);
  if sys_error(stat) then return;
  eagle_scr_xy (scr, x, y, stat);
  if sys_error(stat) then return;
  eagle_scr_xy (scr, x+rad, y, stat);
  if sys_error(stat) then return;
  eagle_scr_cmdend (scr, stat);
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_CMD_HOLE (SCR, X, Y, STAT)
*
*   Write a HOLE command to the Eagle script open for writing on SCR.  The
*   center of the hole will be at X,Y.  The hole diameter is from the current
*   setting, changed with a CHANGE DRILL command.  The current 2D transform is
*   applied before the command is written.
}
procedure eagle_cmd_hole (             {write hole command to Eagle script}
  in out  scr: eagle_scr_t;            {script writing state}
  in      x, y: real;                  {center point}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  eagle_scr_cmdend (scr, stat);        {make sure any previous command ended}
  if sys_error(stat) then return;

  eagle_scr_str (scr, 'hole'(0), stat);
  if sys_error(stat) then return;
  eagle_scr_xy (scr, x, y, stat);
  if sys_error(stat) then return;
  eagle_scr_cmdend (scr, stat);
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_CMD_TEXT (SCR, X, Y, S, STAT)
*
*   Write a TEXT command to the Eagle script open for writing on SCR.  S is the
*   text string to write, specified as a var string.  The text anchor point will
*   be at X,Y.  The current 2D transform is applied before the command is
*   written.
}
procedure eagle_cmd_text (             {write text command to Eagle script}
  in out  scr: eagle_scr_t;            {script writing state}
  in      x, y: real;                  {text anchor point}
  in      s: univ string_var_arg_t;    {text string to write}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  ii: sys_int_machine_t;               {text string index}
  c: char;                             {current text string character}

begin
  eagle_scr_cmdend (scr, stat);        {make sure any previous command ended}
  if sys_error(stat) then return;

  eagle_scr_str (scr, 'text '''(0), stat);
  if sys_error(stat) then return;

  for ii := 1 to s.len do begin        {loop over the text string characters}
    c := s.str[ii];                    {get this character}
    if c = '''' then begin             {apostrophy, requires special handling ?}
      eagle_scr_char (scr, c, stat);   {doubled up to cause single to be written}
      if sys_error(stat) then return;
      end;
    eagle_scr_char (scr, c, stat);     {write this char to command}
    if sys_error(stat) then return;
    end;                               {back for next character in text string}

  eagle_scr_str (scr, ''''(0), stat);  {end the text string}
  if sys_error(stat) then return;

  eagle_scr_xy (scr, x, y, stat);      {write the coordinate to draw the text at}
  if sys_error(stat) then return;

  eagle_scr_cmdend (scr, stat);
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_SCR_TEXT_S (SCR, X, Y, S, STAT)
*
*   Write a TEXT command to the Eagle script open for writing on SCR.  S is the
*   text string to write, specified as a Pascal string.  The text anchor point
*   will be at X,Y.  The current 2D transform is applied before the command is
*   written.
}
procedure eagle_cmd_text_s (           {write text command from Pascal string}
  in out  scr: eagle_scr_t;            {script writing state}
  in      x, y: real;                  {text anchor point}
  in      s: string;                   {text string to write}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  eagle_cmd_text (scr, x, y, string_v(s), stat);
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_CMD_MOVE_CMP (SCR, NAME, NUM, X, Y)
*
*   Write the command to move a particular component.  SCR is the state for
*   writing to the Eagle script.  NAME and NUM specify the component designator.
*   The command will cause the component to be moved to the coordinate X,Y.  The
*   2D transform is applied to X,Y.
}
procedure eagle_cmd_move_cmp (         {write MOVE command for a component}
  in out  scr: eagle_scr_t;            {script writing state}
  in      name: univ string_var_arg_t; {comp designator name, like "R" of R23}
  in      num: sys_int_machine_t;      {comp designator number, like 23 of R23}
  in      x, y: real;                  {where to move component to}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  eagle_scr_cmdend (scr, stat);        {make sure any previous command ended}
  if sys_error(stat) then return;

  eagle_scr_str (scr, 'move '''(0), stat); {command name, start comp name}
  if sys_error(stat) then return;

  eagle_scr_strv (scr, name, stat);    {component designator}
  if sys_error(stat) then return;
  eagle_scr_int (scr, num, stat);
  if sys_error(stat) then return;
  eagle_scr_char (scr, '''', stat);
  if sys_error(stat) then return;

  eagle_scr_xy (scr, x, y, stat);      {location to move the component to}
  if sys_error(stat) then return;

  eagle_scr_cmdend (scr, stat);        {end command, write to script file}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_CMD_BEND_DIRECT (SCR, STAT)
*
*   Set the Eagle setting so that vectors are drawn directly from their start
*   point to their end point.  This is opposed to settings that always draw
*   segments horizontally or vertically, for example.
}
procedure eagle_cmd_bend_direct (      {setting for wires directly from start to end coor}
  in out  scr: eagle_scr_t;            {script writing state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  eagle_scr_cmdend (scr, stat);        {make sure any previous command ended}
  if sys_error(stat) then return;

  eagle_scr_str (scr, 'SET WIRE_BEND 2'(0), stat);
  if sys_error(stat) then return;
  eagle_scr_cmdend (scr, stat);
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_CMD_THICK (SCR, THICK, STAT)
*
*   Set the Eagle line thickness to THICK.  Redundant attempts to set the same
*   value are silently eliminated.
}
procedure eagle_cmd_thick (            {write command to set line thickness}
  in out  scr: eagle_scr_t;            {script writing state}
  in      thick: real;                 {new line thickness}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  if scr.thick = thick then begin      {already set to this thickness ?}
    sys_error_none (stat);
    return;
    end;

  eagle_scr_cmdend (scr, stat);        {make sure any previous command ended}
  if sys_error(stat) then return;

  eagle_scr_str (scr, 'CHANGE WIDTH '(0), stat);
  if sys_error(stat) then return;
  eagle_scr_fp (scr, thick, 4, stat);
  if sys_error(stat) then return;
  eagle_scr_cmdend (scr, stat);
  if sys_error(stat) then return;

  scr.thick := thick;                  {remember new thickness setting}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_CMD_LSTYLE (SCR, LSTYLE, STAT)
*
*   Set the Eagle line drawing stule to LSTYLE.  Redundant attempts to set the
*   same value are silently eliminated.
}
procedure eagle_cmd_lstyle (           {write command to set line style}
  in out  scr: eagle_scr_t;            {script writing state}
  in      lstyle: eagle_lstyle_k_t;    {new line style, redundant settings eliminated}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  tk: string_var32_t;                  {new line style name}

begin
  tk.max := size_char(tk.str);         {init local var string}
  sys_error_none (stat);               {init to no error encountered}

  if scr.lstyle = lstyle then return;  {already set as desired ?}

  tk.len := 0;                         {init to no line style name}
  case lstyle of                       {which line style is selected ?}
eagle_lstyle_solid_k: string_vstring (tk, 'CONTINUOUS'(0), -1);
eagle_lstyle_dash_k: string_vstring (tk, 'SHORTDASH'(0), -1);
eagle_lstyle_dashlong_k: string_vstring (tk, 'LONGDASH'(0), -1);
eagle_lstyle_dashdot_k: string_vstring (tk, 'DASHDOT'(0), -1);
    end;
  scr.lstyle := lstyle;                {save new current line style ID}
  if tk.len = 0 then return;           {nothing to do ?}

  eagle_scr_cmdend (scr, stat);        {make sure any previous command ended}
  if sys_error(stat) then return;

  eagle_scr_str (scr, 'CHANGE STYLE '(0), stat);
  if sys_error(stat) then return;
  eagle_scr_strv (scr, tk, stat);      {write the new line style name}
  if sys_error(stat) then return;
  eagle_scr_cmdend (scr, stat);        {end the command}
  if sys_error(stat) then return;
  end;
