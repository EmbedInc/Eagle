{   Routines that deal with drawing RENDlib text into an Eagle script with line
*   wrapping.
}
module eagle_textwrap;
define eagle_textwrap_nlines;
define eagle_textwrap_draw;
%include 'eagle2.ins.pas';
{
********************************************************************************
*
*   Local function WRAP_LINE (DRAW, TEXT, P, WIDTH, LINE)
*
*   Determine the next line of wrapped text of TEXT, starting at the parse index
*   P.  WIDTH is the maximum allowed width of each line.  The next line contents
*   is returned in LINE, and P advanced to after the text of LINE.
*
*   DRAW is the state for RENDlib drawing to an Eagle script.  The current text
*   parameters are used to determine the width of text strings.
*
*   To get multiple wrapped lines of a text string, initialize P to 1 before the
*   first call.  Subsequent calls to this routine then return subsequent lines
*   of the wrapped text.
*
*   The function returns TRUE when returning with a line of text.  The function
*   returns FALSE with LINE set to the empty string when the input text has been
*   exhausted.
}
function wrap_line (                   {get next line of wrapped text}
  in      draw: eagle_draw_t;          {state for drawing to Eagle script}
  in      text: univ string_var_arg_t; {source text string}
  in out  p: string_index_t;           {parse index into TEXT, updated}
  in      width: real;                 {maximum allowed line width}
  in out  line: univ string_var_arg_t) {next line of wrapped text}
  :boolean;                            {returning with line, length not 0}
  val_param; internal;

var
  ln: string_var8192_t;                {line being built}
  fitlen: sys_int_machine_t;           {last LN length known to fit width}
  fitp: sys_int_machine_t;             {parse index after last known fit}
  c: char;                             {current character parse from TEXT}
  xb: vect_2d_t;                       {X basis vector for text string}
  yb: vect_2d_t;                       {y basis vector for text string}
  ll: vect_2d_t;                       {lower left corner of text string}
  lnwidth: real;                       {width of string in LN}

label
  leave;

begin
  ln.max := size_char(ln.str);         {init local var string}

  ln.len := 0;                         {init output line to empty}
  fitlen := 0;
  while p <= text.len do begin         {scan up to end of input string}
    c := text.str[p];                  {get this input string character}
    p := p + 1;                        {advance parse index for next character}
    if (c = ' ') and (ln.len = 0)      {compress out leading spaces}
      then next;
    string_append1 (ln, c);            {add this character to line being built}
    if ln.len = 1 then begin           {this is first character on line ?}
      fitlen := 1;                     {it fits whether it fits or not}
      fitp := p;                       {save parse index for after fit}
      next;
      end;
    if c = ' ' then begin              {this character is a blank ?}
      fitlen := ln.len - 1;            {fits to previous character}
      fitp := p;                       {save parse index at fit}
      next;
      end;
    rend_get.txbox_txdraw^ (           {get size of line so far}
      ln.str, ln.len,                  {the text string to measure}
      xb, yb,                          {returned X and Y basis vectors}
      ll);                             {returned lower left coordinate}
    lnwidth := sqrt(sqr(xb.x) + sqr(xb.y)); {length along text baseline}
    if lnwidth > width then begin      {too wide with this last character ?}
      ln.len := fitlen;                {truncate to what did fit}
      p := fitp;                       {restart after fit next line}
      exit;                            {done building candidate line in LN}
      end;
    end;                               {back for next input string character}

leave:                                 {common exit point}
  string_unpad (ln);                   {remove any trailing spaces}
  wrap_line := ln.len > 0;             {indicate whether got a new line}
  string_copy (ln, line);              {return the line}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_TEXTWRAP_NLINES (DRAW, TEXT, WIDTH, NLINES)
*
*   Determine the number of lines required to draw the text TEXT.  DRAW is the
*   state for drawing to the Eagle script.  WIDTH is the maximum width allowed
*   per line.  NLINES is returned the total number of lines required to draw the
*   text for this WIDTH and the current text parameters.
*
*   See the EAGLE_TEXTWRAP_DRAW description for details of the line wrapping
*   algorithm.
}
procedure eagle_textwrap_nlines (      {find number of lines to draw wrapped text}
  in out  draw: eagle_draw_t;          {drawing to script state}
  in      text: univ string_var_arg_t; {the text to draw}
  in      width: real;                 {max allowed width, wrap to new line as needed}
  out     nlines: sys_int_machine_t);  {total number of lines required}
  val_param;

var
  p: string_index_t;                   {input line parse index}
  tk: string_var32_t;                  {scratch token and text string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  nlines := 0;                         {init number of lines needed to draw text}
  p := 1;                              {init parse index to start of input line}
  while wrap_line (draw, text, p, width, tk) do begin {loop per line}
    nlines := nlines + 1;
    end;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_TEXTWRAP_DRAW (DRAW, TEXT, WIDTH, NLINES)
*
*   Draw the text TEXT wrapped to multiple lines as required.  DRAW is the state
*   for drawing to the Eagle script.  WIDTH is the maximum width allowed per
*   line.  NLINES is returned the total number of lines that were drawn.
*
*   A line break is allowed to occur at any space character.  If consecutive
*   characters without a space exceed the allowed line width, then they are
*   drawn on a single line anyway.  However, that line will contain only the
*   single section of unwrappable text.
}
procedure eagle_textwrap_draw (        {draw wrapped text to Eagle script}
  in out  draw: eagle_draw_t;          {drawing to script state}
  in      text: univ string_var_arg_t; {the text to draw}
  in      width: real;                 {max allowed width, wrap to new line as needed}
  out     nlines: sys_int_machine_t);  {total number of lines used}
  val_param;

var
  p: string_index_t;                   {input line parse index}
  line: string_var8192_t;              {one text line}

begin
  line.max := size_char(line.str);     {init local var string}

  nlines := 0;                         {init number of lines drawn}
  p := 1;                              {init parse index to start of input line}
  while wrap_line (draw, text, p, width, line) do begin {once for each wrapped line}
    rend_prim.text^ (line.str, line.len); {draw the text for this line}
    nlines := nlines + 1;              {count one more line drawn}
    end;                               {back to get the next line}
  end;
