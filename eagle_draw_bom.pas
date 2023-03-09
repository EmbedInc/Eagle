module eagle_draw_bom;
define eagle_draw_bom;
%include 'eagle2.ins.pas';

const
  page_dx = 10.0;                      {drawable page width}
  page_dy = 8.0;                       {drawable page height}
{
********************************************************************************
*
*   Subroutine EAGLE_DRAW_BOM (BOM, SCR, STAT)
*
*   Write script to draw a BOM at the end of the current schematic.  BOM is the
*   list of parts in the BOM.  SCR is the script writing state.
}
procedure eagle_draw_bom (             {write script to draw BOM at end of schematic}
  in      bom: part_list_t;            {BOM parts list}
  in out  scr: eagle_scr_t;            {Eagle script writing state}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  draw_p: eagle_draw_p_t;              {to drawing into script state}

begin
  eagle_draw_init (                    {set up for drawing to Eagle script}
    0.0, page_dx,                      {left/right drawing limits}
    0.0, page_dy,                      {bottom/top drawing limits}
    scr,                               {script writing state}
    draw_p,                            {returned pointer to script drawing state}
    stat);
  if sys_error(stat) then return;

  eagle_scr_strline (scr, 'change layer info;', stat);
  if sys_error(stat) then return;

  rend_set.enter_rend^;
  rend_set.cpnt_2d^ (page_dx/2.0, page_dy);
  rend_prim.vect_2d^ (0.0, page_dy/2.0);
  rend_prim.vect_2d^ (page_dx/2.0, 0.0);
  rend_prim.vect_2d^ (page_dx, page_dy/2.0);
  rend_prim.vect_2d^ (page_dx/2.0, page_dy);

  eagle_draw_text_size (draw_p^, 0.1);
  eagle_draw_text_anchor (draw_p^, rend_torg_um_k);

  rend_set.cpnt_2d^ (5.0, 7.0);
  eagle_draw_text (draw_p^, string_v('This is a test'));
  eagle_draw_text (draw_p^, string_v('Second line of text'));

  rend_set.exit_rend^;

  eagle_draw_end (draw_p, stat);       {end drawing to the Eagle script}
  end;
