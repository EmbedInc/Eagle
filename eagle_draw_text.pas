{   Script drawing routines related to text.
}
module eagle_draw_text;
define eagle_draw_text_size;
define eagle_draw_text_bold;
define eagle_draw_text_anchor;
define eagle_draw_text_setup;
define eagle_draw_text;
%include 'eagle2.ins.pas';
{
********************************************************************************
*
*   Subroutine EAGLE_DRAW_TEXT_SIZE (DRAW, SIZE)
*
*   Set the size that subsequent text will be drawn at.  DRAW is the Eagle
*   script drawing state.  SIZE is the text size in Eagle units.  This will be
*   the height of a full character that does not have decenders.
}
procedure eagle_draw_text_size (       {set text size}
  in out  draw: eagle_draw_t;          {drawing to script state}
  in      size: real);                 {height of full size letter without decender}
  val_param;

begin
  draw.tparm.size := size;             {set new state in our text parameters}
  rend_set.text_parms^ (draw.tparm);   {update the RENDlib text control state}
  eagle_draw_text_setup (draw);        {update Eagle state to new text size}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_DRAW_TEXT_BOLD (DRAW, BOLDFR)
*
*   Set the boldness that subsequent text will be drawn with.  DRAW is the Eagle
*   script drawing state.  BOLDFR is the line thickness to draw text with, as
*   a fraction of the text size.  This boldness setting will be saved, and the
*   line thickness automatically adjusted whenever the text size is changed.
}
procedure eagle_draw_text_bold (       {set text boldness}
  in out  draw: eagle_draw_t;          {drawing to script state}
  in      boldfr: real);               {line thickness as fraction of text size}
  val_param;

begin
  draw.boldfr := boldfr;               {save new boldness fraction}

  eagle_draw_text_setup (draw);        {update Eagle state to new text size}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_DRAW_TEXT_ANCHOR (DRAW, ANCH)
*
*   Set where subsequent text strings will be anchored to the current point.
*   DRAW is the Eagle script drawing state.  ANCH is the ID of the anchor
*   position relative to the text string.  The ending current point position is
*   set so "one line down".  Drawing multiple text strings therefore draws
*   multiple lines of text down the page.
}
procedure eagle_draw_text_anchor (     {set where text string anchored to current point}
  in out  draw: eagle_draw_t;          {drawing to script state}
  in      anch: rend_torg_k_t);        {anchor position ID}
  val_param;

begin
  draw.tparm.start_org := anch;        {set new state in our text parameters}
  draw.tparm.end_org := rend_torg_down_k;
  rend_set.text_parms^ (draw.tparm);   {update the RENDlib text control state}
  end;
{
********************************************************************************
*
*   Local subroutine EAGLE_DRAW_TEXT_SETUP (DRAW)
*
*   Set up Eagle state for drawing text according to the current text
*   parameters.  Some Eagle parameters may be set independently and used for
*   drawing other than text.  Those parameters that text drawing is dependent on
*   are set here.  Specifically, the following Eagle state is set:
*
*     Line thickness  -  Derived from text size and boldness.
*
*   This routine does not need to be called after changing text parameters.
*   Eagle state required for text is automatically set when text parameters are
*   changed.
}
procedure eagle_draw_text_setup (      {set up Eagle state for drawing text}
  in out  draw: eagle_draw_t);         {drawing to script state}
  val_param;

var
  stat: sys_err_t;

begin
  eagle_cmd_thick (                    {write Eagle line thickness command}
    draw.scr_p^,                       {script writing state}
    draw.tparm.size * draw.boldfr,     {new line thickness}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_DRAW_TEXT (DRAW, STR)
*
*   Draw the text string STR.  DRAW is the eagle script drawing state.  The
*   current point will be left one line down at the same X coordinate.
}
procedure eagle_draw_text (            {draw text string, curr point done one line}
  in out  draw: eagle_draw_t;          {drawing to script state}
  in      str: univ string_var_arg_t); {text string to draw}
  val_param;

begin
  rend_prim.text^ (str.str, str.len);
  end;
