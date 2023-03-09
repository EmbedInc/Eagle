{   Script drawing routines related to text.
}
module eagle_draw_text;
define eagle_draw_text_size;
define eagle_draw_text_anchor;
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
