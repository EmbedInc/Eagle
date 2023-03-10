module eagle_draw_bom;
define eagle_draw_bom;
%include 'eagle2.ins.pas';

const
  page_dx = 10.0;                      {drawable page width}
  page_dy = 8.0;                       {drawable page height}
  txsize_normal = 0.075;               {size for normal text}
  txsize_title = 0.10;                 {size for title text}
  bold_normal = 0.09;                  {boldness for normal text}
  bold_emphasis = 0.12;                {boldness for emphasis}
  linwid = 0.007;                      {line width for basic lines}
  mar_lft = 0.025;                     {left text margin, fraction of size}
  mar_rit = 0.025;                     {right text margin, fracation of size}
  mar_top = 0.030;                     {top text margin, fraction of size}
  mar_bot = 0.045;                     {bottom text margin, fraction of size}
{
********************************************************************************
*
*   Local function LINES_HEIGHT (DRAW, N)
*
*   Return the total height of a box to contain N lines of text.  The height
*   includes the margins around text inside of a box.
}
function lines_height (                {find height of box to contain text}
  in      draw: eagle_draw_t;          {state for drawing to Eagle script}
  in      n: sys_int_machine_t)        {number of lines of text}
  :real;                               {box height, including margins around text}
  val_param; internal;

begin
  lines_height :=
    (draw.tparm.size * n) +            {the bare text lines}
    (draw.tparm.size * draw.tparm.lspace * max(n - 1, 0)) + {space between lines}
    mar_top + mar_bot;                 {top and bottom margins within the box}
  end;
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
  text: string_var8192_t;              {test text string}
  nlines: sys_int_machine_t;           {number of lines of wrapped text}
  xlft, xrit: real;                    {left/right X}
  ybot, ytop: real;                    {bottom/top Y}

begin
  text.max := size_char(text.str);     {init local var string}

  eagle_draw_init (                    {set up for drawing to Eagle script}
    0.0, page_dx,                      {left/right drawing limits}
    0.0, page_dy,                      {bottom/top drawing limits}
    scr,                               {script writing state}
    draw_p,                            {returned pointer to script drawing state}
    stat);
  if sys_error(stat) then return;

  rend_set.enter_rend^;
  new_page (draw_p^);                  {create and init new schematic page}
{
*   Draw a title.
}
  eagle_draw_text_size (draw_p^, txsize_title);
  eagle_draw_text_anchor (draw_p^, rend_torg_um_k);
  eagle_draw_text_bold (draw_p^, bold_emphasis);
  rend_set.cpnt_2d^ (page_dx/2.0, page_dy - 0.2);
  eagle_draw_text (draw_p^, string_v('Title For This Sheet'));
{
*   Test wrapped text and margins.
}
  text.len := 0;                       {make long text string to test wrapping}
  string_appends (text, 'Four score and twenty years ago, '(0));
  string_appends (text, 'our fathers brought forth on this continent a new nation '(0));
  string_appends (text, 'dedicated to the proposition that all men are created '(0));
  string_appends (text, 'mostly equal.'(0));

  xlft := 1.0;                         {box left edge}
  xrit := 3.0;                         {box right edge}
  ytop := 7.0;                         {box top edge}
  {
  *   Draw the text.
  }
  eagle_draw_text_size (draw_p^, txsize_normal);
  eagle_draw_text_bold (draw_p^, bold_normal);
  eagle_draw_text_anchor (draw_p^, rend_torg_ul_k);
  rend_set.cpnt_2d^ (xlft + mar_lft, ytop - mar_top); {to top left of text area}
  eagle_textwrap_draw (                {draw long text, wrap to multip lines}
    draw_p^,                           {drawing to script state}
    text,                              {the text to draw}
    xrit - xlft - mar_lft - mar_rit,   {max width allowed each line}
    nlines);                           {number of lines actually written}
  ybot := ytop - lines_height (draw_p^, nlines); {find box bottom edge}
  {
  *   Draw box around text.
  }
  eagle_draw_cmdend (draw_p^, stat);
  if sys_error(stat) then return;
  eagle_cmd_thick (scr, linwid, stat); {set line width}
  if sys_error(stat) then return;
  rend_set.cpnt_2d^ (xlft, ytop);      {draw the box}
  rend_prim.vect_2d^ (xlft, ybot);
  rend_prim.vect_2d^ (xrit, ybot);
  rend_prim.vect_2d^ (xrit, ytop);
  rend_prim.vect_2d^ (xlft, ytop);

  rend_set.exit_rend^;
  eagle_draw_end (draw_p, stat);       {end drawing to the Eagle script}
  end;
