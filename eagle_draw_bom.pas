module eagle_draw_bom;
define eagle_draw_bom;
%include 'eagle2.ins.pas';

const
  page_dx = 10.0;                      {drawable page width}
  page_dy = 8.0;                       {drawable page height}

  txsize_normal = 0.075;               {size for normal text}
  bold_normal = 0.09;                  {boldness for normal text}
  bold_emphasis = 0.12;                {boldness for emphasis}
  linwid = 0.007;                      {line width for basic lines}

  mar_lft = 0.025;                     {left text margin, fraction of size}
  mar_rit = 0.020;                     {right text margin, fraction of size}
  mar_top = 0.030;                     {top text margin, fraction of size}
  mar_bot = 0.045;                     {bottom text margin, fraction of size}

  page_top = page_dy - 0.1;            {top drawing on page}
  page_bot = 0.8;                      {bottom drawing on page}
{
*   BOM columns.
}
  ncol = 10;                           {total number of columns}
  col_lft = 0.1;                       {left edge of left column}

type
  col_name_t = array[1..ncol] of string; {column names}
  col_width_t = array[1..ncol] of real; {width of each column}

var
  col_name: col_name_t := [            {column names}
    'Qty',                             {1}
    'Designators',                     {2}
    'Description',                     {3}
    'Value',                           {4}
    'Package',                         {5}
    'Part #',                          {6}
    'Manuf',                           {7}
    'Manuf #',                         {8}
    'Supplier',                        {9}
    'Supp #',                          {10}
    ];
  col_width: col_width_t := [          {column widths}
    0.3,                               {quantity}
    1.5,                               {component designators}
    1.2,                               {description}
    1.2,                               {value}
    0.7,                               {package}
    0.6,                               {in-house part number}
    0.8,                               {manufacturer}
    1.3,                               {manufacturer part number}
    0.8,                               {supplier}
    1.4,                               {supplier part number}
    ];
  col_rit: real;                       {right edge of right column}
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
*   Local subroutine NEW_PAGE (DRAW, PAGES)
*
*   Start a new page at the end of the Eagle schematic.  The page will be
*   initialized with the standard IS frame.  PAGES is the total number of BOM
*   pages created, and is updated to include the new page.
}
procedure new_page (                   {create and init new page at end of schematic}
  in out  draw: eagle_draw_t;          {state for drawing to Eagle script}
  in out  pages: sys_int_machine_t);   {total new pages created}
  val_param; internal;

var
  text: string_var80_t;                {scratch text string}
  stat: sys_err_t;

begin
  text.max := size_char(text.str);     {init local var string}

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

  string_vstring (text, 'Bill of Materials'(0), -1); {init text to write}
  if pages > 0 then begin              {this is not the first page ?}
    string_appends (text, ', continued'(0));
    end;
  eagle_cmd_text (                     {write the page description text}
    draw.scr_p^,                       {script writing state}
    6.525, 0.08,                       {X,Y coodinate to write at}
    text,                              {the text string to write}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  pages := pages + 1;                  {count one more BOM page created}
  end;
{
********************************************************************************
*
*   Local subroutine HEADERS (DRAW, CURRY)
*
*   Draw the headers for the BOM columns.  CURRY is the current Y coordinate on
*   the page.  It is updated to the top Y of the next row to draw.  The text
*   state is left ready for writing a BOM row.
}
procedure headers (                    {draw BOM column headers}
  in out  draw: eagle_draw_t;          {state for drawing to Eagle script}
  in out  curry: real);                {current Y on page, updated}
  val_param; internal;

var
  col: sys_int_machine_t;              {1-NCOL column number}
  currx: real;                         {current column left X}

begin
  eagle_draw_text_size (draw, txsize_normal); {set the text size}
  eagle_draw_text_bold (draw, bold_emphasis); {set text boldness}
  currx := col_lft;                    {init current X to first column}
{
*   Draw column 1 header, right justfied.
}
  eagle_draw_text_anchor (draw, rend_torg_ur_k); {set text anchor point}
  rend_set.cpnt_2d^ (currx + col_width[1] - mar_rit, curry);
  eagle_draw_text (draw, string_v(col_name[1])); {draw column name}
  currx := currx + col_width[1];       {update current X for next column}
{
*   Draw remaining columns, right justified.
}
  eagle_draw_text_anchor (draw, rend_torg_ul_k); {set text anchor point}
  for col := 2 to ncol do begin        {across the columns}
    rend_set.cpnt_2d^ (currx + mar_lft, curry);
    eagle_draw_text (draw, string_v(col_name[col])); {draw column name}
    currx := currx + col_width[col];   {update current X for next column}
    end;
{
*   Draw the line under the column names and update CURRY.
}
  curry := curry - draw.tparm.size - mar_bot;
  eagle_draw_thick (draw, linwid);     {set line thickness}
  rend_set.cpnt_2d^ (col_lft, curry);  {draw the horizontal line}
  rend_prim.vect_2d^ (col_rit, curry);
{
*   Set up text state for drawing normal BOM content.
}
  eagle_draw_text_bold (draw, bold_normal);
  end;
{
********************************************************************************
*
*   Local subroutine PAGE_FINISH (DRAW, CURRY)
*
*   Finish the current page.
}
procedure page_finish (                {finish drawing the current page}
  in out  draw: eagle_draw_t;          {state for drawing to Eagle script}
  in out  curry: real);                {current Y for the page}
  val_param; internal;

var
  topy: real;                          {Y at top of separator lines}
  x: real;                             {current X coordinate}
  col: sys_int_machine_t;              {1-N column number}

begin
{
*   Draw the vertical separators between fields.
}
  eagle_draw_thick (draw, linwid);     {set line thickness}
  topy := page_top - draw.tparm.size - mar_bot; {Y for top of lines}
  x := col_lft;                        {init to left-most line}

  for col := 1 to ncol+1 do begin      {once for each vertical line}
    rend_set.cpnt_2d^ (x, topy);       {draw this line}
    rend_prim.vect_2d^ (x, curry);
    if col <= ncol then begin
      x := x + col_width[col];         {advance across over this field}
      end;
    end;                               {back for next vertical line}
{
*   Write footnote about parts critical to intrinsic safety.
}
  eagle_draw_text_anchor (draw, rend_torg_ul_k); {anchor text in upper left corner}
  rend_set.cpnt_2d^ (
    col_lft + col_width[1] + mar_lft,
    curry - mar_top - (draw.tparm.size * 0.5));
  eagle_draw_text (draw,
    string_v('* Denotes part critical to Instrinsic Safety'(0))
    );
  end;
{
********************************************************************************
*
*   Local subroutine BOM_PAGE (DRAW, PAGES, ROWPG, CURRY)
*
*   Start a new page and init for writing the first BOM row.  If a page is
*   currently open, it is finished first.
}
procedure bom_page (                   {start new page for BOM}
  in out  draw: eagle_draw_t;          {state for drawing to Eagle script}
  in out  pages: sys_int_machine_t;    {total new pages created}
  in out  rowpg: sys_int_machine_t;    {current BOM row within page}
  in out  curry: real);                {current Y for the page}
  val_param; internal;

begin
  if pages > 0 then begin              {a page is currently open ?}
    page_finish (draw, curry);         {finish the current page}
    end;

  new_page (draw, pages);              {create a new page at end of schematic}

  curry := page_top;                   {start at the top of this new page}
  headers (draw, curry);               {draw the BOM column headers}
  rowpg := 1;                          {now on first row within current page}
  end;
{
********************************************************************************
*
*   Local subroutine FIELD_TEXT_GET (DRAW, PART, COL, TEXT)
*
*   Get the text for a BOM field.  DRAW is the state for drawing to an Eagle
*   script.  PART is the part for the BOM row.  COL is the 1-NCOL number of the
*   BOM column to generate the text for.  TEXT is returned the generated text.
}
procedure field_text_get (             {get text for one BOM field}
  in      draw: eagle_draw_t;          {state for drawing to Eagle script}
  in var  part: part_t;                {part the BOM row is for}
  in      col: sys_int_machine_t;      {1-NCOL column number of selected field}
  in out  text: univ string_var_arg_t); {returned text for the selected field}
  val_param; internal;

const
  ohmchar = 7;                         {char code for Ohm symbol in this font}

var
  ii: sys_int_machine_t;               {scratch integer}
  c: char;                             {scratch character}
  prt2_p: part_p_t;                    {to secondary part in list}

begin
  case col of                          {which field ?}
{
*   Quantity.
}
1: begin
  ii := round(part.qty);
  if abs(part.qty - ii) < 0.0001
    then begin                         {integer quantity}
      string_f_int (text, ii);
      end
    else begin                         {floating point quantity}
      string_f_fp_free (text, part.qty, 5);
      end
    ;
  end;
{
*   Designators.
}
2: begin
  text.len := 0;                       {init designator list to empty}
  prt2_p := addr(part);                {init to start of common parts chain}
  while prt2_p <> nil do begin         {scan the common parts chain}
    if text.len > 0 then begin
      string_append1 (text, ' ');      {add separator after previous designator}
      end;
    string_append (text, prt2_p^.desig); {add this designator}
    if part_flag_isafe_k in prt2_p^.flags then begin {IS-critical ?}
      string_append1 (text, '*');
      end;
    prt2_p := prt2_p^.same_p;          {to next of this common part}
    end;                               {back to do this new common part}
  end;
{
*   Description.
}
3: begin
  string_copy (part.desc, text);
  end;
{
*   Value.
}
4: begin
  text.len := 0;                       {init result string to empty}
  ii := 1;                             {init source string index}
  while ii <= part.val.len do begin    {scan the source string}
    c := part.val.str[ii];             {fetch this character}
    ii := ii + 1;                      {advance index to next}
    if                                 {check for "Ohm"}
        (c = 'O') and                  {current char is start of "Ohm" ?}
        (ii <= (part.val.len - 1)) and then {enough characters left ?}
        (part.val.str[ii] = 'h') and   {the next characters match ?}
        (part.val.str[ii+1] = 'm')
        then begin
      string_append1 (text, chr(ohmchar)); {replace with Ohm character}
      ii := ii + 2;                    {skip over "Ohm" in source string}
      if                               {next character is optional "s" ?}
          (ii <= part.val.len) and then {room left in source string}
          (part.val.str[ii] = 's')     {next char is "s" ?}
          then begin
        ii := ii + 1;                  {skip over the "s" after "Ohm"}
        end;
      next;                            {on to next source character}
      end;
    string_append1 (text, c);          {append this char to result string}
    end;                               {back for next source string char}
  end;
{
*   Package.
}
5: begin
  string_copy (part.pack, text);
  end;
{
*   In-house part number.
}
6: begin
  string_copy (part.housenum, text);
  end;
{
*   Manufacturer.
}
7: begin
  string_copy (part.manuf, text);
  end;
{
*   Manufacturer part number.
}
8: begin
  string_copy (part.mpart, text);
  end;
{
*   Supplier.
}
9: begin
  string_copy (part.supp, text);
  end;
{
*   Supplier part number.
}
10: begin
  string_copy (part.spart, text);
  end;

otherwise                              {unexpected field number}
    text.len := 0;                     {return the empty string}
    end;
  end;
{
********************************************************************************
*
*   Local function ROW_HEIGHT (DRAW, PART)
*
*   Find the height required to draw the BOM row for the part PART.
}
function row_height (                  {find height required for BOM row}
  in out  draw: eagle_draw_t;          {state for drawing to Eagle script}
  in var  part: part_t)                {part BOM row would be for}
  :real;                               {height on page required for BOM row}
  val_param; internal;

var
  col: sys_int_machine_t;              {1-NCOL column number of current field}
  maxlines: sys_int_machine_t;         {max lines required by any field}
  nlines: sys_int_machine_t;           {number of lines required by current field}
  text: string_var8192_t;              {string for current field}

begin
  text.max := size_char(text.str);     {init local var string}

  maxlines := 1;                       {init max number of lines required}
  for col := 1 to ncol do begin        {once for each field in the row}
    field_text_get (draw, part, col, text); {get the text for this field}
    eagle_textwrap_nlines (            {find number of lines for this field}
      draw,                            {state for drawing to Eagle script}
      text,                            {text string to wrap}
      col_width[col] - mar_lft - mar_rit, {max allowed width of each line}
      nlines);                         {returned number of lines wrapped to}
    maxlines := max(maxlines, nlines); {update max number of lines required}
    end;

  row_height := lines_height (draw, maxlines); {return required drawing height}
  end;
{
********************************************************************************
*
*   Local subroutine BOM_ROW (DRAW, PART, CURRY)
*
*   Draw the BOM row for the part PART.
}
procedure bom_row (                    {draw BOM row}
  in out  draw: eagle_draw_t;          {state for drawing to Eagle script}
  in var  part: part_t;                {part to write BOM row for}
  in out  curry: real);                {current Y on page, moved down}
  val_param; internal;

var
  col: sys_int_machine_t;              {1-NCOL column number of current field}
  currx: real;                         {left edge X of current field}
  nlines: sys_int_machine_t;           {number of lines used by current field}
  maxlines: sys_int_machine_t;         {max lines used by any field}
  text: string_var8192_t;              {string for current field}

begin
  text.max := size_char(text.str);     {init local var string}

  maxlines := 1;                       {init max number of lines required}
  currx := col_lft;                    {init left edge X of first field}
{
*   Field 1, right justified.
}
  col := 1;                            {set number of this field}
  eagle_draw_text_anchor (draw, rend_torg_ur_k); {anchor text at upper right}

  rend_set.cpnt_2d^ (                  {to top right of text}
    currx + col_width[col] - mar_rit,
    curry - mar_top);

  field_text_get (draw, part, col, text); {get the text for this field}
  eagle_textwrap_draw (                {draw the text for this field}
    draw,                              {state for drawing to Eagle script}
    text,                              {text string to wrap}
    col_width[col] - mar_lft - mar_rit, {max allowed width of each line}
    nlines);                           {returned number of lines wrapped to}
  maxlines := max(maxlines, nlines);   {update max number of lines required}

  currx := currx + col_width[col];     {advance across to next field}
{
*   Remaining fields, left justified.
}
  eagle_draw_text_anchor (draw, rend_torg_ul_k); {anchor text at upper left}

  for col := 2 to ncol do begin        {once for each field in the row}
    rend_set.cpnt_2d^ (                {to top left corner of text}
      currx + mar_lft,
      curry - mar_top);
    field_text_get (draw, part, col, text); {get the text for this field}
    eagle_textwrap_draw (              {draw the text for this field}
      draw,                            {state for drawing to Eagle script}
      text,                            {text string to wrap}
      col_width[col] - mar_lft - mar_rit, {max allowed width of each line}
      nlines);                         {returned number of lines wrapped to}
    maxlines := max(maxlines, nlines); {update max number of lines required}
    currx := currx + col_width[col];   {advance across to the next field}
    end;
{
*   Draw the line below this row, update state for the next row.
}
  curry := curry - lines_height (draw, maxlines); {make Y of row bottom}

  eagle_draw_thick (draw, linwid);     {set line width for row separator}
  rend_set.cpnt_2d^ (col_lft, curry);  {to left end of separator}
  rend_prim.vect_2d^ (col_rit, curry); {to right end of separator}
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
  part_p: part_p_t;                    {pointer to current part in BOM parts list}
  rowpg: sys_int_machine_t;            {1-N BOM row within page, 0 for no page}
  pages: sys_int_machine_t;            {number of new pages created}
  col: sys_int_machine_t;              {1-NCOL column number}
  curry: real;                         {current Y as progressing down the page}
  r: real;                             {scratch floating point}

label
  next_part;

begin
{
*   Set COL_RIT.  This is really static state, defined by the left columns edge
*   and the width of each column.
}
  r := col_lft;                        {init to left edge of left column}
  for col := 1 to ncol do begin        {add the widths of all the columns}
    r := r + col_width[col];
    end;
  col_rit := r;                        {save the right edge of the right column}
{
*   Initialize the state for drawing to an Eagle script.
}
  eagle_draw_init (                    {set up for drawing to Eagle script}
    0.0, page_dx,                      {left/right drawing limits}
    0.0, page_dy,                      {bottom/top drawing limits}
    scr,                               {script writing state}
    draw_p,                            {returned pointer to script drawing state}
    stat);
  if sys_error(stat) then return;

  rend_set.enter_rend^;
  pages := 0;                          {init number of new pages created}
  rowpg := 0;                          {init BOM row within page}

  part_p := bom.first_p;               {init to first part in BOM parts list}
  while part_p <> nil do begin         {scan the BOM parts list}
    if part_flag_nobom_k in part_p^.flags {this part is not for the BOM ?}
      then goto next_part;
    if part_flag_comm_k in part_p^.flags {common part already listed earlier ?}
      then goto next_part;

    if rowpg = 0 then begin            {no page currently open}
      bom_page (draw_p^, pages, rowpg, curry); {start new page for this BOM entry}
      end;

    if rowpg > 1 then begin            {not first row on current page ?}
      r := row_height (draw_p^, part_p^); {get height required for this row}
      if (curry - r) < page_bot then begin {this row would go too low on page ?}
        bom_page (draw_p^, pages, rowpg, curry); {start a new page}
        end;
      end;

    bom_row (draw_p^, part_p^, curry); {draw BOM row for this part}
    rowpg := rowpg + 1;                {on next row down on this page}

next_part:                             {done with this part, on to next}
    part_p := part_p^.next_p;          {to next part in BOM parts list}
    end;

  page_finish (draw_p^, curry);        {finish the last page}
  rend_set.exit_rend^;
  eagle_draw_end (draw_p, stat);       {end drawing to the Eagle script}
  end;
