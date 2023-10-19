{   Routines to write ARC command to Eagle scripts.
}
module eagle_cmd_arc;
define eagle_cmd_arc_2pc;
%include 'eagle2.ins.pas';
{
********************************************************************************
*
*   Subroutine EAGLE_CMD_ARC_2PC (SRC, P1, P2, CENT, CW, STAT)
*
*   Write the command to draw an arc, given the two arc end points and the
*   center point of the circle the arc is on.
*
*   P1 and P2 are the two endpoints of the arc.  CENT is the center point of the
*   circle the arc is on.  CW means to draw the arc clockwise from P1 to P2 when
*   TRUE, and counter-clockwise when FALSE.
}
procedure eagle_cmd_arc_2pc (          {write arc, two endpoints and center}
  in out  scr: eagle_scr_t;            {script writing state}
  in      p1, p2: vect_2d_t;           {arc start and end points}
  in      cent: vect_2d_t;             {center point of circle arc is on}
  in      cw: boolean;                 {draw clockwise from P1 to P2}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  opp: vect_2d_t;                      {opposite circle point from P1}

begin
  opp.x := (2.0 * cent.x) - p1.x;      {make point on circle opposite P1}
  opp.y := (2.0 * cent.y) - p1.y;

  eagle_scr_str (scr, 'arc'(0), stat); {start the ARC command}
  if sys_error(stat) then return;
  eagle_scr_arcdir (scr, cw, stat);    {clockwise or counter-clockwise}
  if sys_error(stat) then return;

  eagle_scr_xy (scr, p1.x, p1.y, stat); {arc starting point}
  if sys_error(stat) then return;
  eagle_scr_xy (scr, opp.x, opp.y, stat); {point on circle opposite starting point}
  if sys_error(stat) then return;
  eagle_scr_xy (scr, p2.x, p2.y, stat); {arc ending point}
  if sys_error(stat) then return;
  eagle_scr_cmdend (scr, stat);
  end;
