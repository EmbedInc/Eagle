module eagle_draw_bom;
define eagle_draw_bom;
%include 'eagle2.ins.pas';

const
  page_dx = 10.0;                      {drawable page width}
  page_dy = 8.0;                       {drawable page height}
{
********************************************************************************
*
*   Local Subroutine NEW_PAGE (DRAW)
*
*   Start a new page at the end of the Eagle schematic.  The page will be
*   initialized with the standard IS frame.
}
procedure new_page (                   {create and init new page at end of schematic}
  in out  draw: eagle_draw_t);         {drawing to Eagle script state}
  val_param; internal;

var
  stat: sys_err_t;

begin
  eagle_draw_cmdend (draw, stat);      {end any command in progress}
  sys_error_abort (stat, '', '', nil, 0);

  eagle_scr_strline (draw.scr_p^,      {create new sheet at end of schematic}
    'edit .s9999;',
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  eagle_scr_strline (draw.scr_p^,      {add the IS frame}
    'add FRAME-8X10-IS-H@Symbols (0 0);',
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  eagle_scr_strline (draw.scr_p^,      {zoom to fit the frame in the window}
    'window fit;',
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  eagle_scr_strline (draw.scr_p^,      {set our assumed grid units}
    'grid inch .1 1 dots on;',
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  eagle_scr_strline (draw.scr_p^,      {init to draw into the INFO layer}
    'change layer info;',
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  eagle_scr_strline (draw.scr_p^,      {configure text for page description}
    'change size 0.095;',
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  eagle_scr_strline (draw.scr_p^,
    'change ratio 8;',
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  eagle_scr_strline (draw.scr_p^,
    'change align left center;',
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  eagle_scr_strline (draw.scr_p^,      {write the page description text}
    'text ''Bill of Materials'' (6.525 .08);',
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
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

  rend_set.enter_rend^;

  new_page (draw_p^);                  {create and init new schematic page}

  eagle_draw_text_size (draw_p^, 0.1);
  eagle_draw_text_anchor (draw_p^, rend_torg_um_k);
  rend_set.cpnt_2d^ (5.0, 7.0);
  eagle_draw_text (draw_p^, string_v('Test ggg ///'));
  eagle_draw_text (draw_p^, string_v('XX//gggjjjiii'));

  rend_set.exit_rend^;
  eagle_draw_end (draw_p, stat);       {end drawing to the Eagle script}
  end;
