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
  mar_rit = 0.025;                     {right text margin, fracation of size}
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
    0.4,                               {quantity}
    1.2,                               {component designators}
    1.8,                               {description}
    0.9,                               {value}
    0.6,                               {package}
    0.5,                               {in-house part number}
    0.8,                               {manufacturer}
    1.4,                               {manufacturer part number}
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
*   Local subroutine NEW_PAGE (DRAW)
*
*   Start a new page at the end of the Eagle schematic.  The page will be
*   initialized with the standard IS frame.
}
procedure new_page (                   {create and init new page at end of schematic}
  in out  draw: eagle_draw_t);         {state for drawing to Eagle script}
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
*   Local subroutine HEADERS (DRAW, CURRY)
*
*   Draw the headers for the BOM columns.  CURRY is the current Y coordinage on
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
  curry := curry - lines_height (draw, 1); {down one line with margins}
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

begin
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

  new_page (draw);                     {create a new page at end of schematic}
  pages := pages + 1;                  {count one more total page created}

  curry := page_top;                   {start at the top of this new page}
  headers (draw, curry);               {draw the BOM column headers}
  rowpg := 1;                          {now on first row within current page}
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
  in      part: part_t)                {part BOM row would be for}
  :real;                               {height on page required for BOM row}
  val_param; internal;

begin
  row_height := 1.0;                   {TEMP PLACEHOLDER}
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
  in      part: part_t;                {part to write BOM row for}
  in out  curry: real);                {current Y on page, moved down}
  val_param; internal;

begin
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

  rend_set.exit_rend^;
  eagle_draw_end (draw_p, stat);       {end drawing to the Eagle script}
  end;
