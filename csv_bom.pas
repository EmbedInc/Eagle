{   Program CSV_BOM filename
*
*   This program is used as one step in producing a bill of materials (BOM) from
*   an Eagle design.  See the documentation file for details.
}
program csv_bom;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'stuff.ins.pas';
%include 'part.ins.pas';

const
  max_msg_args = 2;                    {max arguments we can pass to a message}
  tab = chr(9);                        {ASCII TAB character}

var
  ii: sys_int_machine_t;               {scratch integer and loop counter}
  fnam: string_treename_t;             {scratch file name}
  gnam: string_leafname_t;             {generic name of board files}
  dir: string_treename_t;              {directory containing input and output files}
  conn: file_conn_t;                   {connection to input or output file}
  buf: string_var8192_t;               {one line input and output buffer}
  tk: string_var8192_t;                {scratch token}
  tk2, tk3: string_var80_t;            {secondary scratch tokens}
  housename: string_var80_t;           {organization to use private part numbers of}
  p: string_index_t;                   {BUF parse index}
  pf: string_index_t;                  {parse index into current field}
  partlist_p: part_list_p_t;           {points to list of BOM parts}
  part_p, p2_p: part_p_t;              {scratch part descriptors}
  line: sys_int_machine_t;             {output file line number being built}
  reflist_p: part_reflist_p_t;         {points to reference parts list}
  refpart_p: part_ref_p_t;             {points to current reference part}
  nunique: sys_int_machine_t;          {number of unique parts found}
  last_p: part_p_t;                    {to last part in common parts chain}
  nvent_p: nameval_ent_p_t;            {points to curr name/value list entry}
  cw: csv_out_t;                       {CSV file writing state}
  olempty: boolean;                    {output line is completely empty}
  absmatch: boolean;                   {absolute part match}

  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  pick: sys_int_machine_t;             {number of keyword picked from list}
  stat: sys_err_t;                     {completion status}

label
  infile_bad, loop_line, eof,
  refmatch, doneref, have_desc, commch_same, next_commch, next_comp, next_part,
  next_cw;
{
********************************************************************************
*
*   Subroutine GETFIELD (F)
*
*   Parse the next comma separated field from BUF and return it in F.  If BUF
*   is already exhausted, F is returned the empty string.
}
procedure getfield (                   {get next comma separated field from BUF}
  in out  f: univ string_var_arg_t);   {returned field string}
  val_param; internal;

var
  i: sys_int_machine_t;
  stat: sys_err_t;

begin
  pf := 1;                             {reset parse index into current field}
  f.len := 0;                          {init returned string to empty}
  if p > buf.len then return;          {BUF already exhausted ?}
  while buf.str[p] = ' ' do begin      {skip over leading blanks}
    p := p + 1;                        {skip over this blank}
    if p > buf.len then return;        {hit end of BUF ?}
    end;

  string_token_anyd (                  {parse the next field from BUF}
    buf,                               {input string}
    p,                                 {parse index}
    ',', 1,                            {list of token delimiters}
    0,                                 {number of delimiters that can repeat}
    [string_tkopt_quoteq_k],           {token may be within quotes ""}
    f,                                 {returned token}
    i,                                 {index of deciding delimiter}
    stat);
  discard (string_eos(stat));          {end of input string is not an error}
  sys_error_abort (stat, '', '', nil, 0);

  string_unpad (f);                    {delete any trailing spaces}
  end;
{
********************************************************************************
*
*   Subroutine GETNAME (F, P, NAME)
*
*   Extract the next name from the field string F.  P is the current parse index
*   into F.  Name and value pairs are separated by each other with semicolons.
*   Within a name/value pair, the name and value are separated by colons.  NAME
*   is returned the empty string if no new name is present in the input string.
}
procedure getname (                    {get the name of the next name/value pair}
  in      f: univ string_var_arg_t;    {string to parse the name from}
  in out  p: string_index_t;           {parse index, updated}
  in out  name: univ string_var_arg_t); {returned name string, empty = no name}
  val_param; internal;

var
  c: char;

begin
  name.len := 0;                       {init to no new name/value pair found}

  while (p <= f.len) and then (f.str[p] = ' ') {skip over leading blanks}
    do p := p + 1;

  while true do begin                  {loop until hit end of current name}
    if p > f.len then exit;            {exhausted input string ?}
    c := f.str[p];                     {get this input string char}
    if c = ':' then exit;              {start of value for this name ?}
    p := p + 1;                        {update parse index for next character}
    if c = ';' then exit;              {end of name/value pair ?}
    string_append1 (name, c);          {add this character to output name}
    end;
  string_unpad (name);                 {delete trailing spaces from the name}
  end;
{
********************************************************************************
*
*   Subroutine GETVAL (F, P, VAL)
*
*   Extract the next value from the field string F.  P is the current parse
*   index into F.  Name and value pairs are separated by each other with
*   semicolons.  Within a name/value pair, the name and value are separated by
*   colons.  VAL is returned the empty string if no value is available for the
*   current name.  GETVAL may only be called after the name of the name/value
*   pair is parsed with GETNAME.
}
procedure getval (                     {get the name of the next name/value pair}
  in      f: univ string_var_arg_t;    {string to parse the name from}
  in out  p: string_index_t;           {parse index, updated}
  in out  val: univ string_var_arg_t); {returned value string, empty = no value}
  val_param; internal;

var
  c: char;

begin
  val.len := 0;                        {init to no value found for current name}

  while (p <= f.len) and then (f.str[p] = ' ') {skip over leading blanks}
    do p := p + 1;
  if p > f.len then return;            {exhausted input string ?}
  if f.str[p] <> ':' then return;      {not at start of value for this name ?}
  p := p + 1;                          {advance to first value string character}

  while true do begin                  {loop until hit end or delimiter}
    if p > f.len then exit;            {exhausted input string ?}
    c := f.str[p];                     {get this input string char}
    p := p + 1;                        {update parse index for next character}
    if c = ';' then exit;              {hit ending delimiter ?}
    string_append1 (val, c);           {add this character to output val}
    end;
  string_unpad (val);                  {delete trailing spaces from the val}
  end;
{
********************************************************************************
*
*   Subroutine PUTFIELD (F)
*
*   Add the string F as a new field to the end of the current output file line
*   in BUF.
}
procedure putfield (                   {append field to current output line}
  in      f: univ string_var_arg_t);   {string to append as new field}
  val_param; internal;

begin
  if not olempty then begin            {output line is not completely empty ?}
    string_append1 (buf, tab);         {add separator after previous field}
    end;
  string_append (buf, f);              {add the new field}
  olempty := false;                    {this line is defintely not empty now}
  end;
{
********************************************************************************
*
*   Subroutine PUTBLANK
*
*   Set the next field to blank.  This is the same as writing the empty string
*   to the field.
}
procedure putblank;                    {write empty string to next field}

var
  s: string_var4_t;

begin
  s.max := size_char(s.str);           {build a empty string}
  s.len := 0;
  putfield (s);                        {write it as the value of the next field}
  end;
{
********************************************************************************
*
*   Subroutine WOUT
*
*   Write the string in BUF as the next line to the output file.  BUF will be
*   reset to empty, and LINE will be advanced to indicate the new line that will
*   now be built.
}
procedure wout;                        {write BUF to output file}
  val_param; internal;

begin
  file_write_text (buf, conn, stat);   {write line to output file}
  sys_error_abort (stat, '', '', nil, 0);
  buf.len := 0;                        {reset output buffer to empty}
  line := line + 1;                    {indicate number of new line now working on}
  olempty := true;                     {init new line as being completely empty}
  end;
{
********************************************************************************
*
*   Function GET_HOUSENAME (DIR)
*
*   Try to read the HOUSENAME file in the directory DIR.  If it exists and can
*   be read, the first line of the file is saved in HOUSENAME and the function
*   returns TRUE.  If the HOUSENAME file does not exist or can not be read, then
*   the function returns FALSE.
}
function get_housename (               {try to get housename in specific dir}
  in      dir: string_treename_t)      {directory to try to find housename in}
  :boolean;                            {house name found, HOUSENAME set}
  val_param; internal;

var
  fnam: string_treename_t;             {full pathname of HOUSENAME file}
  conn: file_conn_t;                   {connection to the HOUSENAME file}
  stat: sys_err_t;

begin
  fnam.max := size_char(fnam.str);     {init local var string}
  get_housename := false;              {init to house name not found}

  string_copy (dir, fnam);             {init pathname to directory name}
  string_appends (fnam, '/housename'(0)); {make complete pathname}

  file_open_read_text (fnam, '', conn, stat); {open connection to the file}
  if sys_error(stat) then return;      {couldn't open file ?}

  file_read_text (conn, fnam, stat);   {read first line of file}
  file_close (conn);                   {done with the file}
  if sys_error(stat) then return;      {couldn't read from the file ?}
  if fnam.len <= 0 then return;        {no house name string found ?}

  string_copy (fnam, housename);       {set the house name}
  get_housename := true;               {indicate house name found, HOUSENAME set}
  end;
{
********************************************************************************
*
*   Start of main routine.
}
begin
  fnam.max := size_char(fnam.str);     {init local var strings}
  gnam.max := size_char(gnam.str);
  dir.max := size_char(dir.str);
  buf.max := size_char(buf.str);
  tk.max := size_char(tk.str);
  tk2.max := size_char(tk2.str);
  tk3.max := size_char(tk3.str);
  housename.max := size_char(housename.str);

  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (fnam, stat);    {get input file name}
  string_cmline_req_check (stat);      {input file name is required}
  string_cmline_end_abort;             {no additional command line arguments allowed}
{
*   Open the CSV input file.  This allows us to abort now if there is a problem,
*   and also gets us the directory the CSV file is in.
*
*   The generic board name is saved in GNAM, and the input file directory is
*   saved in DIR.
}
  file_open_read_text (fnam, '_parts.csv', conn, stat); {open the input file}
  sys_error_abort (stat, '', '', nil, 0);

  string_pathname_split (conn.tnam, dir, fnam); {get name of directory containing input file}
  string_copy (conn.gnam, gnam);       {save generic name of board files}
{
*   Determine the organization name to use for in-house part numbers, if any.
*   This is defined in a file called HOUSENAME, which can be in the directory of
*   the CSV file or a parent directory.  The most local HOUSENAME file is used.
*
*   DIR contains the name of the directory the CSV file is in.
}
  housename.len := 0;                  {init to no organization specified}

  string_copy (dir, fnam);             {init directory to try first}
  while true do begin                  {loop up the chain of directories}
    if get_housename (fnam) then exit; {got house name here ?}
    string_pathname_split (            {make name of next directory up}
      fnam,                            {starting directory}
      buf,                             {returned parent directory}
      tk);                             {returned leafname (not used)}
    if string_equal (buf, fnam) then exit; {ended up in same place (at top dir) ?}
    string_copy (buf, fnam);           {try in the new parent directory}
    end;                               {back to try in the new directory}

  if housename.len > 0 then begin
    writeln ('House name is "', housename.str:housename.len, '"');
    end;
{
*   Verify the CSV file by checking the first line.  The first line contains the
*   name of each field.  These must be exactly right, or we assume that the file
*   was not created by BOM.ULP, or the wrong version of it.
}
  file_read_text (conn, buf, stat);    {read the first input file line into BUF}
  sys_error_abort (stat, '', '', nil, 0);
  string_unpad (buf);                  {delete any trailing spaces}
  if buf.len = 0 then begin            {input line is blank ?}
infile_bad:
    sys_message_bomb ('eagle', 'bom_infile_bad', nil, 0);
    end;
  p := 1;                              {init the input line parse index}
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('DESIGNATOR')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('LIBRARY')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('DEVICE')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('VALUE')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('PACKAGE')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('MANUF')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('PARTNUM')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('SUPPLIER')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('VALSTAT')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('BOM')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('SUBST')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('DESC')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('DVAL')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('QTY')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('INHOUSE')) then goto infile_bad;
  getfield (tk);
  string_upcase (tk);
  if not string_equal (tk, string_v('IS')) then goto infile_bad;

  if p <= buf.len then goto infile_bad; {additional unexpected field ?}
{
*   The first line checks out, so this is apparently a valid input file.
*
*   Create the parts list.
}
  part_list_new (partlist_p, util_top_mem_context);
{
*   The first line of the CSV input file has been read and verified.  The parts
*   list has been initialized to empty.
*
****************************************
*
*   Read the input file and create the list of individual parts.
}
loop_line:                             {back here each new input file line}
  file_read_text (conn, buf, stat);    {read this input file line}
  if file_eof(stat) then goto eof;     {hit end of input file ?}
  sys_error_abort (stat, '', '', nil, 0);
  string_unpad (buf);                  {delete any trailing spaces from input line}
  if buf.len <= 0 then goto loop_line; {ignore blank lines}
  p := 1;                              {init BUF parse index}
  part_list_ent_new_end (partlist_p^, part_p); {add new blank part to end of list}
{
*   Read the data from the input file line into the new part descriptor.  The
*   new descriptor is pointed to by PART_P.
}
  getfield (part_p^.desig);            {read designator name}
  string_upcase (part_p^.desig);

  getfield (part_p^.lib);              {read library name}
  string_upcase (part_p^.lib);

  getfield (part_p^.dev);              {read device name}
  for ii := 1 to part_p^.dev.len do begin {loop looking for first dash}
    if part_p^.dev.str[ii] = '-' then begin {found first dash ?}
      part_p^.dev.len := ii - 1;       {truncate string before the dash}
      exit;                            {no need to look further}
      end;
    end;                               {back to check next character in device name}
  string_copy (part_p^.dev, part_p^.devu); {make upper case version}
  string_upcase (part_p^.devu);

  getfield (part_p^.val);              {read value string}

  getfield (part_p^.pack);             {read package name}
  string_upcase (part_p^.pack);

  getfield (tk);                       {get manufacturers string}
  while true do begin                  {once for each manufacturer}
    getname (tk, pf, tk2);             {get manufacturer name into TK2}
    if tk2.len = 0 then exit;          {hit end of manufacturers list ?}
    if part_p^.manuf.len > 0 then begin {a previous manuf name already in list ?}
      string_appends (part_p^.manuf, ', '(0));
      end;
    string_append (part_p^.manuf, tk2);
    getval (tk, pf, tk2);              {try to get part number for this manuf}
    if tk2.len > 0 then begin          {there is part number ?}
      if part_p^.mpart.len > 0 then begin {a previous part name already in list ?}
        string_appends (part_p^.mpart, ', '(0));
        end;
      string_append (part_p^.mpart, tk2);
      end;
    end;                               {back for next manufacturer name}

  getfield (tk);                       {get part number string}
  if tk.len > 0 then begin             {specific part number is available ?}
    string_copy (tk, part_p^.mpart);   {set manufacturer part number from it}
    end;

  getfield (tk);                       {get suppliers string}
  while true do begin                  {once for each supplier}
    getname (tk, pf, tk2);             {get supplier name into TK2}
    if tk2.len = 0 then exit;          {hit end of suppliers list ?}
    if part_p^.supp.len > 0 then begin {a previous supp name already in list ?}
      string_appends (part_p^.supp, ', '(0));
      end;
    string_append (part_p^.supp, tk2);
    getval (tk, pf, tk2);              {try to get part number for this supp}
    if tk2.len > 0 then begin          {there is part number ?}
      if part_p^.spart.len > 0 then begin {a previous part number already in list ?}
        string_appends (part_p^.spart, ', '(0));
        end;
      string_append (part_p^.spart, tk2);
      end;
    end;                               {back for next supplier name}

  getfield (tk);                       {get VALSTAT value}
  string_upcase (tk);                  {make upper case for keyword matching}
  if tk.len <= 0 then begin            {no value, use default ?}
    string_vstring (tk, 'VAL'(0), -1);
    end;
  string_tkpick80 (tk,                 {determine which VALSTAT keyword}
    'VAL PARTNUM LABEL',
    pick);
  case pick of
1:  begin                              {VALSTAT VAL}
      end;
2:  begin                              {VALSTAT PARTNUM}
      if part_p^.mpart.len <= 0 then begin {part number not already set ?}
        string_copy (part_p^.val, part_p^.mpart); {set part number from value string}
        end;
      end;
3:  begin                              {VALSTAT LABEL}
      part_p^.val.len := 0;            {delete value string, not use to differentiate part}
      end;
otherwise
    sys_msg_parm_vstr (msg_parm[1], tk);
    sys_msg_parm_vstr (msg_parm[2], part_p^.desig);
    sys_message_bomb ('eagle', 'bom_valstat_bad', msg_parm, 2);
    end;

  getfield (tk);                       {get BOM attribute value}
  string_upcase (tk);                  {make upper case for keyword matching}
  if tk.len <= 0 then begin            {no value, use default ?}
    string_vstring (tk, 'YES'(0), -1);
    end;
  string_tkpick80 (tk,                 {determine which BOM keyword}
    'YES NO',
    pick);
  case pick of
1:  begin                              {BOM YES}
      part_p^.flags := part_p^.flags - [part_flag_nobom_k];
      end;
2:  begin                              {BOM NO}
      part_p^.flags := part_p^.flags + [part_flag_nobom_k];
      end;
otherwise
    sys_msg_parm_vstr (msg_parm[1], tk);
    sys_msg_parm_vstr (msg_parm[2], part_p^.desig);
    sys_message_bomb ('eagle', 'bom_bom_bad', msg_parm, 2);
    end;

  getfield (tk);                       {get SUBST attribute value}
  string_upcase (tk);                  {make upper case for keyword matching}
  if tk.len <= 0 then begin            {no value, use default ?}
    string_vstring (tk, 'YES'(0), -1);
    end;
  string_tkpick80 (tk,                 {determine which BOM keyword}
    'YES NO',
    pick);
  case pick of
1:  begin                              {SUBST YES}
      part_p^.flags := part_p^.flags + [part_flag_subst_k];
      end;
2:  begin                              {SUBST NO}
      part_p^.flags := part_p^.flags - [part_flag_subst_k];
      end;
otherwise
    sys_msg_parm_vstr (msg_parm[1], tk);
    sys_msg_parm_vstr (msg_parm[2], part_p^.desig);
    sys_message_bomb ('eagle', 'bom_subst_bad', msg_parm, 2);
    end;

  getfield (part_p^.desc);             {get explicit description string}

  getfield (tk);                       {get detailed value string}
  if tk.len > 0 then begin
    string_copy (tk, part_p^.val);     {detailed value overrides schematic value string}
    end;

  getfield (tk);                       {get quantity per use}
  if tk.len > 0 then begin
    string_t_fpm (tk, part_p^.qtyuse, stat);
    if sys_error(stat) then begin
      sys_msg_parm_vstr (msg_parm[1], tk);
      sys_msg_parm_vstr (msg_parm[2], part_p^.desig);
      sys_message_bomb ('eagle', 'bom_qty_bad', msg_parm, 2);
      end;
    part_p^.qty := part_p^.qtyuse;     {update total usage to this one part}
    end;

  getfield (tk);                       {get list of organizations and their part numbers}
  while true do begin                  {once for each organization in the list}
    getname (tk, pf, tk2);             {get this organization name into TK2}
    if tk2.len <= 0 then exit;         {done scanning this string}
    getval (tk, pf, tk3);              {get part number within this org into TK3}
    if string_equal (tk2, housename) then begin {this is for the org we care about ?}
      string_copy (tk3, part_p^.housenum); {save the in-house part number}
      exit;                            {no point looking further}
      end;
    end;

  getfield (tk);                       {get YES/NO critical to Intrinsic Safety}
  string_upcase (tk);                  {make upper case for keyword matching}
  if tk.len <= 0 then begin            {no value, use default ?}
    string_vstring (tk, 'NO'(0), -1);
    end;
  string_tkpick80 (tk,                 {determine which BOM keyword}
    'YES NO',
    pick);
  case pick of
1:  begin                              {SUBST YES}
      part_p^.flags := part_p^.flags + [part_flag_isafe_k];
      end;
2:  begin                              {SUBST NO}
      part_p^.flags := part_p^.flags - [part_flag_isafe_k];
      end;
otherwise
    sys_msg_parm_vstr (msg_parm[1], tk);
    sys_msg_parm_vstr (msg_parm[2], part_p^.desig);
    sys_message_bomb ('eagle', 'bom_is_bad', msg_parm, 2);
    end;

  goto loop_line;                      {back to get next input line}

eof:                                   {end of input file encountered}
  file_close (conn);                   {close the connection to the input file}
  sys_msg_parm_int (msg_parm[1], partlist_p^.nparts); {show number of parts read in}
  sys_message_parms ('eagle', 'bom_ncomponents', msg_parm, 1);
{
*   All done reading the input file.
*
****************************************
*
*   Add the circuit board as a special part.
}
  part_list_ent_new_end (partlist_p^, part_p); {add new blank part to end of list}

  string_vstring (part_p^.desc, 'Circuit board'(0), -1);
  string_copy (gnam, tk);              {make upper case circuit board name}
  string_upcase (tk);
  string_copy (tk, part_p^.val);
  part_p^.flags := part_p^.flags - [part_flag_subst_k]; {not allowed to substitute}
{
*   All the individual components are in the list pointed to by PARTLIST_P.
*
****************************************
*
*   Read the parts reference file, if it exists, and build the list of reference
*   parts.
}
  part_reflist_new (reflist_p, util_top_mem_context); {create empty reference parts list}
  part_reflist_read_csv (
    reflist_p^,                        {the list to add reference parts to}
    string_v('(cog)progs/eagle/parts/parts.csv'(0)), {name of file to read ref parts from}
    stat);
  discard( file_not_found(stat) );     {no refparts file is not error}
  sys_error_abort (stat, '', '', nil, 0);
  writeln (reflist_p^.nparts, ' reference parts found');
{
****************************************
*
*   Scan the list of parts and compare each to the reference parts.  Fill in
*   data from the reference part definition if the part matches the reference.
}
  part_p := partlist_p^.first_p;       {init to first part in list}
  while part_p <> nil do begin         {once for each part in the list}
    refpart_p := reflist_p^.first_p;   {init to first reference part}
    while refpart_p <> nil do begin    {scan list of reference parts}
{
*   PART_P is pointing to the part in this BOM, and REFPART_P is pointing to the
*   reference part to compare it to.
*
*   Look for absolute match first.  If a manufacturer part number, supplier part
*   number, or the inhouse number match, then this will be considered a matching
*   reference part.
}
  absmatch := true;                    {match will be absolute if found here}

  ii := nameval_match (                {get manufacturer part number match}
    refpart_p^.manuf,                  {the name/value pair to compare to}
    part_p^.manuf,                     {name to compare against}
    part_p^.mpart);                    {value to compare against}
  if ii > 0 then goto refmatch;        {definitely matches ?}
  if ii < 0 then goto doneref;         {definitely does not match ?}

  ii := nameval_match (                {get supplier part number match}
    refpart_p^.supplier,               {the name/value pair to compare to}
    part_p^.supp,                      {name to compare against}
    part_p^.spart);                    {value to compare against}
  if ii > 0 then goto refmatch;        {definitely matches ?}
  if ii < 0 then goto doneref;         {definitely does not match ?}

  ii := nameval_match (                {get inhouse part number match}
      refpart_p^.inhouse,              {the name/value pair to compare to}
      housename,                       {name to compare against}
      part_p^.housenum);               {value to compare against}
  if ii > 0 then goto refmatch;        {definitely matches ?}
  if ii < 0 then goto doneref;         {definitely does not match ?}
{
*   No absolute match was found.  These fields also did not indicate a absolute
*   mismatch.
*
*   For this reference part to match this BOM part, at least one of the
*   remaining fields must be a match, and none of them must be a mismatch.
}
  absmatch := false;                   {matches found here won't be absolute}
  ii := 0;                             {init number of fields with explicit matches}

  if (part_p^.desc.len > 0) and (refpart_p^.desc.len > 0) then begin
    if not string_equal(part_p^.desc, refpart_p^.desc) then goto doneref;
    ii := ii + 1;
    end;

  if (part_p^.val.len > 0) and (refpart_p^.value.len > 0) then begin
    if not string_equal(part_p^.val, refpart_p^.value) then goto doneref;
    ii := ii + 1;
    end;

  if (part_p^.pack.len > 0) and (refpart_p^.package.len > 0) then begin
    if not string_equal(part_p^.pack, refpart_p^.package) then goto doneref;
    ii := ii + 1;
    end;

  if ii <= 0 then goto doneref;        {no matching field found at all ?}
{
*   This reference part matches this BOM part.
*
*   Fill in or update fields in the BOM part from those in the reference part.
}
refmatch:                              {this is a matching reference part}
  if
      (refpart_p^.desc.len > 0) and    {reference description exists ?}
      ((part_p^.desc.len = 0) or absmatch)
      then begin
    string_copy (refpart_p^.desc, part_p^.desc); {use the reference description}
    end;

  if
      (refpart_p^.value.len > 0) and   {reference value exists ?}
      ((refpart_p^.value.len > part_p^.val.len) or absmatch) {longer than existing value ?}
      then begin
    string_copy (refpart_p^.value, part_p^.val); {use the reference part value}
    end;

  if
      (refpart_p^.package.len > 0) and {reference package name exists ?}
      ((part_p^.pack.len <= 0) or absmatch)
      then begin
    string_copy (refpart_p^.package, part_p^.pack);
    end;

  if
      refpart_p^.subst_set and
      (not refpart_p^.subst)
      then begin
    part_p^.flags := part_p^.flags - [part_flag_subst_k]; {disallow substitutions}
    end;

  nvent_p := refpart_p^.manuf.first_p; {get manuf name and part num if appropriate}
  if
      (nvent_p <> nil) and             {refernce manufacturer info exists ?}
      ((part_p^.manuf.len <= 0) or absmatch) {better than what we already have ?}
      then begin
    if nvent_p^.name_p <> nil then begin {ref manuf name exists ?}
      string_copy (nvent_p^.name_p^, part_p^.manuf);
      end;
    if nvent_p^.value_p <> nil then begin {ref manuf part number exists ?}
      string_copy (nvent_p^.value_p^, part_p^.mpart);
      end;
    end;

  nvent_p := refpart_p^.supplier.first_p; {get supplier name and partnum if appropriate}
  if
      (nvent_p <> nil) and             {reference supplier info exists ?}
      ((part_p^.supp.len <= 0) or absmatch) {better than what we already have ?}
      then begin
    if nvent_p^.name_p <> nil then begin {ref supplier name exists ?}
      string_copy (nvent_p^.name_p^, part_p^.supp);
      end;
    if nvent_p^.value_p <> nil then begin {ref supplier part number exists ?}
      string_copy (nvent_p^.value_p^, part_p^.spart);
      end;
    end;

  if part_p^.housenum.len <= 0 then begin {don't already have in-house number ?}
    if nameval_get_val (refpart_p^.inhouse, housename, tk) then begin {ref part has inhouse number ?}
      string_copy (tk, part_p^.housenum); {yes, copy it into BOM part}
      end;
    end;

doneref:                               {done with this ref part}
      refpart_p := refpart_p^.next_p;  {advance to next reference part in list}
      end;                             {back to compare against this new ref part}
    part_p := part_p^.next_p;          {advance to the next part in the list}
    end;                               {back to process this new part}
{
****************************************
*
*   For each part, attempt to fill in some empty fields from other fields.
}
  part_p := partlist_p^.first_p;       {init to current part is first in list}
  while part_p <> nil do begin         {once for each part in the list}
{
*   Try to fill in the description from other fields if the description was not
*   explicitly set.
}
    if part_p^.desc.len <= 0 then begin {no explicit description string ?}
      string_copy (part_p^.lib, part_p^.desc); {init description to library name}
      string_copy (part_p^.devu, tk2);
      string_copy (part_p^.lib, tk3);
      tk2.len := min(tk2.len, tk3.len);
      tk3.len := tk2.len;
      if string_equal (tk2, tk3)       {device name redundant with library name ?}
        then goto have_desc;
      if part_p^.val.len > 0 then begin {this part has a value string ?}
        string_copy (part_p^.devu, tk2);
        string_copy (part_p^.val, tk3);
        tk2.len := min(tk2.len, tk3.len);
        tk3.len := tk2.len;
        string_upcase (tk3);
        if string_equal (tk2, tk3)     {device name redundant with part value ?}
          then goto have_desc;
        end;
      string_appends (part_p^.desc, ', '(0));
      string_append (part_p^.desc, part_p^.dev); {add device name within library}
      end;
have_desc:                             {part description all set in TK}

    part_p := part_p^.next_p;          {advance to the next part in the list}
    end;                               {back to process this new part}
{
****************************************
*
*   Scan the list of components and determine common part usage.
}
  nunique := 0;                        {init number of unique parts found}

  part_p := partlist_p^.first_p;       {init current component to first in list}
  while part_p <> nil do begin         {scan thru the entire list of components}
    last_p := part_p;                  {init end of common parts chain for this component}
    if part_flag_nobom_k in part_p^.flags {this component not for the BOM ?}
      then goto next_comp;
    if part_flag_comm_k in part_p^.flags then goto next_comp; {this comp already processed ?}
    nunique := nunique + 1;            {count one more unique part found}
    p2_p := part_p^.next_p;            {init pointer to second comp to check for common}
    while p2_p <> nil do begin         {scan remaining components looking for commons}
      if part_flag_comm_k in p2_p^.flags then goto next_commch; {already common to other part ?}
      if not string_equal (p2_p^.housenum, part_p^.housenum) then goto next_commch;
      if part_p^.housenum.len > 0 then goto commch_same; {same in-house part number ?}
      if not string_equal (p2_p^.lib, part_p^.lib) then goto next_commch;
      if not string_equal (p2_p^.devu, part_p^.devu) then goto next_commch;
      if not string_equal (p2_p^.val, part_p^.val) then goto next_commch;
      if not string_equal (p2_p^.pack, part_p^.pack) then goto next_commch;
      {
      *   The component at P2_P uses the same device as the one at PART_P.
      }
commch_same:
      last_p^.same_p := p2_p;          {link this component to end of common parts chain}
      last_p := p2_p;                  {update pointer to end of common parts chain}
      p2_p^.flags := p2_p^.flags + [part_flag_comm_k]; {this comp is in common parts chain}
      part_p^.qty := part_p^.qty + p2_p^.qtyuse; {update total quantity}
next_commch:                           {advance to next component to check against curr}
      p2_p := p2_p^.next_p;
      end;                             {back to check new component same as curr comp}
next_comp:                             {done with current component}
    part_p := part_p^.next_p;          {advance to next component in this list}
    end;                               {back to process this new component}

  sys_msg_parm_int (msg_parm[1], nunique); {show number of unique parts found for the BOM}
  sys_message_parms ('eagle', 'bom_nbom', msg_parm, 1);
{
****************************************
*
*   Write the <name>_BOM.TSV file.  This is the BOM ready to import into a
*   spreadsheet.
}
  string_pathname_join (dir, conn.gnam, fnam); {make pathname of the output file}
  file_open_write_text (fnam, '_bom.tsv', conn, stat); {open output file}
  sys_error_abort (stat, '', '', nil, 0);
{
*   Write the column names as the first output file line.
}
  buf.len := 0;                        {init output line to empty}
  line := 1;                           {init number of output line being built now}
  olempty := true;                     {init this line is to empty}

  putfield (string_v('1'));            {A, quantity in production run}
  putfield (string_v('Qty'));          {B}
  putfield (string_v('Designators'));  {C}
  putfield (string_v('Desc'));         {D}
  putfield (string_v('Value'));        {E}
  putfield (string_v('Package'));      {F}
  putfield (string_v('Subst'));        {G}
  if housename.len > 0
    then begin                         {we have explicit name for in-house parts}
      string_copy (housename, tk);     {init with house name}
      string_appends (tk, ' #'(0));    {add "#"}
      end
    else begin                         {no housename}
      string_vstring (tk, 'Inhouse #'(0), -1);
      end
    ;
  putfield (tk);                       {H, in-house part number}
  putfield (string_v('Manuf'));        {I}
  putfield (string_v('Manuf part #')); {J}
  putfield (string_v('Supplier'));     {K}
  putfield (string_v('Supp part #'));  {L}
  putfield (string_v('$Part'));        {M}
  putfield (string_v('$Board'));       {N}
  putfield (string_v('$All'));         {O}

  wout;                                {write current line to output file}
{
*   Scan thru the components list and write one output file line for each unique
*   part.
}
  part_p := partlist_p^.first_p;       {init current component to first in list}
  while part_p <> nil do begin         {scan thru the entire list of components}
    if part_flag_nobom_k in part_p^.flags {this part not to be added to the BOM ?}
      then goto next_part;
    if part_flag_comm_k in part_p^.flags then goto next_part; {already on previous line ?}
    buf.len := 0;                      {init output line to empty}
    {
    *   Column A: Quantity in whole production run.  Cell A1 is the number of
    *   units in the run.
    }
    string_vstring (tk, '=B'(0), -1);  {A: =Bn*A$1}
    string_f_int (tk2, line);
    string_append (tk, tk2);
    string_appends (tk, '*A$1'(0));
    putfield (tk);
    {
    *   Column B: Quantity per unit.
    }
    ii := round(part_p^.qty);          {make integer quantity}
    if abs(part_p^.qty - ii) < 0.0001
      then begin                       {quantity really is integer ?}
        string_f_int (tk, ii);
        end
      else begin                       {quantity must be written with fraction digits}
        string_f_fp_fixed (tk, part_p^.qty, 3);
        end
      ;
    putfield (tk);                     {quantity}
    {
    *   Column C: List of component designators.
    }
    string_copy (part_p^.desig, tk);   {init designators list to first component}
    p2_p := part_p^.same_p;            {init to second component using this part}
    while p2_p <> nil do begin         {once for each component using this part}
      string_append1 (tk, ' ');        {separator before new designator}
      string_append (tk, p2_p^.desig); {add this designator}
      p2_p := p2_p^.same_p;            {advance to next component using this part}
      end;
    putfield (tk);                     {list of designators using this part}
    {
    *   Column D: Description
    }
    putfield (part_p^.desc);           {part description string}
    {
    *   Column E: Value
    }
    putfield (part_p^.val);            {part value}
    {
    *   Column F: Package
    }
    putfield (part_p^.pack);           {package}
    {
    *   Column G: Substitution allowed yes/no
    }
    if part_flag_subst_k in part_p^.flags
      then string_vstring (tk, 'Yes'(0), -1)
      else string_vstring (tk, 'No'(0), -1);
    putfield (tk);                     {substitution allowed Yes/No}
    {
    *   Column H: In-house part number.
    }
    putfield (part_p^.housenum);
    {
    *   Column I: Manufacturer name.
    }
    putfield (part_p^.manuf);          {manufacturer name}
    {
    *   Column J: Manufacturer part number.
    }
    putfield (part_p^.mpart);          {manufacturer part number}
    {
    *   Column K: Supplier name.
    }
    putfield (part_p^.supp);           {supplier name}
    {
    *   Column L: Supplier part number.
    }
    putfield (part_p^.spart);          {supplier part number}
    {
    *   Column M: Cost for each component.
    }
    tk.len := 0;
    putfield (tk);                     {$ for each component}
    {
    *   Column N: Cost of all these parts per unit.
    }
    string_vstring (tk, '=B'(0), -1);  {$Board: =Bn*Mn}
    string_f_int (tk2, line);
    string_append (tk, tk2);
    string_appends (tk, '*M'(0));
    string_append (tk, tk2);
    putfield (tk);
    {
    *   Column O: Cost of all these parts for all units.
    }
    string_vstring (tk, '=A'(0), -1);  {$All: =An*Mn}
    string_f_int (tk2, line);
    string_append (tk, tk2);
    string_appends (tk, '*M'(0));
    string_append (tk, tk2);
    putfield (tk);

    wout;                              {write this line to the output file, on to next}

next_part:                             {done processing the current part}
    part_p := part_p^.next_p;          {advance to next component}
    end;                               {back and process this new component}
{
*   Write the lines for additional costs that are not parts to install on the
*   board.
}
  {
  *   Kitting cost.
  }
  string_vstring (tk, '=B'(0), -1);    {A, Qty/lot, =Bn*A$1}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*A$1'(0));
  putfield (tk);

  putfield (string_v('1'));            {B, quantity}
  putblank;                            {C, designators}
  putfield (string_v('Kitting'));      {D, description}

  putblank;                            {E, value}
  putblank;                            {F, package}
  putblank;                            {G, substitution allowed}
  putblank;                            {H, In-house}
  putblank;                            {I, manufacturer}
  putblank;                            {J, manuf part number}
  putblank;                            {K, supplier}
  putblank;                            {L, supplier part number}
  putblank;                            {M, $Part}

  string_vstring (tk, '=B'(0), -1);    {N, $Board, =Bn*Mn}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*M'(0));
  string_append (tk, tk2);
  putfield (tk);

  string_vstring (tk, '=A'(0), -1);    {O, $All, =An*Mn}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*M'(0));
  string_append (tk, tk2);
  putfield (tk);

  wout;
  {
  *   Manufacturing cost.
  }
  string_vstring (tk, '=B'(0), -1);    {A, Qty/lot, =Bn*A$1}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*A$1'(0));
  putfield (tk);

  putfield (string_v('1'));            {B, quantity}
  putblank;                            {C, designators}

  putfield (string_v('Manufacturing')); {D, description}

  putblank;                            {E, value}
  putblank;                            {F, package}
  putblank;                            {G, substitution allowed}
  putblank;                            {H, In-house}
  putblank;                            {I, manufacturer}
  putblank;                            {J, manuf part number}
  putblank;                            {K, supplier}
  putblank;                            {L, supplier part number}
  putblank;                            {M, $Part}

  string_vstring (tk, '=B'(0), -1);    {N, $Board, =Bn*Mn}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*M'(0));
  string_append (tk, tk2);
  putfield (tk);

  string_vstring (tk, '=A'(0), -1);    {O, $All, =An*Mn}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*M'(0));
  string_append (tk, tk2);
  putfield (tk);

  wout;
  {
  *   Testing.
  }
  string_vstring (tk, '=B'(0), -1);    {A, Qty/lot, =Bn*A$1}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*A$1'(0));
  putfield (tk);

  putfield (string_v('1'));            {B, quantity}
  putblank;                            {C, designators}

  putfield (string_v('Testing'));      {D, description}

  putblank;                            {E, value}
  putblank;                            {F, package}
  putblank;                            {G, substitution allowed}
  putblank;                            {H, In-house}
  putblank;                            {I, manufacturer}
  putblank;                            {J, manuf part number}
  putblank;                            {K, supplier}
  putblank;                            {L, supplier part number}
  putblank;                            {M, $Part}

  string_vstring (tk, '=B'(0), -1);    {N, $Board, =Bn*Mn}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*M'(0));
  string_append (tk, tk2);
  putfield (tk);

  string_vstring (tk, '=A'(0), -1);    {O, $All, =An*Mn}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*M'(0));
  string_append (tk, tk2);
  putfield (tk);

  wout;
  {
  *   Delivery.
  }
  string_vstring (tk, '=B'(0), -1);    {A, Qty/lot, =Bn*A$1}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*A$1'(0));
  putfield (tk);

  putfield (string_v('1'));            {B, quantity}
  putblank;                            {C, designators}

  putfield (string_v('Delivery to stock')); {D, description}

  putblank;                            {E, value}
  putblank;                            {F, package}
  putblank;                            {G, substitution allowed}
  putblank;                            {H, In-house}
  putblank;                            {I, manufacturer}
  putblank;                            {J, manuf part number}
  putblank;                            {K, supplier}
  putblank;                            {L, supplier part number}
  putblank;                            {M, $Part}

  string_vstring (tk, '=B'(0), -1);    {N, $Board, =Bn*Mn}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*M'(0));
  string_append (tk, tk2);
  putfield (tk);

  string_vstring (tk, '=A'(0), -1);    {O, $All, =An*Mn}
  string_f_int (tk2, line);
  string_append (tk, tk2);
  string_appends (tk, '*M'(0));
  string_append (tk, tk2);
  putfield (tk);

  wout;
{
*   Write the final line that shows the total cost for the production run.
}
  putblank;                            {A, Qty/lot}
  putblank;                            {B, Qty/unit}
  putblank;                            {C, designators}
  putblank;                            {D, description}
  putblank;                            {E, value}
  putblank;                            {F, package}
  putblank;                            {G, substitution allowed}
  putblank;                            {H, In-house}
  putblank;                            {I, manufacturer}
  putblank;                            {J, manuf part number}
  putblank;                            {K, supplier}
  putblank;                            {L, supplier part number}
  putblank;                            {M, $Part}

  string_vstring (tk, '=SUM(N2:N'(0), -1); {N, $Board, =SUM(N2:Nn)}
  string_f_int (tk2, line-1);
  string_append (tk, tk2);
  string_appends (tk, ')'(0));
  putfield (tk);

  string_vstring (tk, '=SUM(O2:O'(0), -1); {O, $All, =SUM(O2:On)}
  string_f_int (tk2, line-1);
  string_append (tk, tk2);
  string_appends (tk, ')'(0));
  putfield (tk);

  wout;                                {write this line to output file}

  file_close (conn);                   {close the output file}
  sys_msg_parm_vstr (msg_parm[1], conn.tnam);
  sys_message_parms ('eagle', 'bom_outfile', msg_parm, 1);
{
*   Initialize the Excel spreadsheet file by copying the template.  This sets up
*   the formatting of the cells, which would not happen if the new .CSV file was
*   imported into a empty spreadsheet.
}
  string_pathname_join (dir, conn.gnam, fnam); {init to generic output file pathname}
  string_appends (fnam, '_bom.xls'(0)); {make spreadsheet file full pathname}
  file_copy (                          {copy template spreadsheet file}
    string_v('(cog)progs/eagle/bom_template.xls'(0)), {source file name}
    fnam,                              {destination file name}
    [file_copy_replace_k],             {overwrite existing file, if any}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
{
****************************************
*
*   Write the <name>_BOM.CSV file.  This is the bare BOM for reading by other
*   applications.
}
  string_pathname_join (dir, conn.gnam, fnam); {build the output file name}
  string_appends (fnam, '_bom'(0));
  csv_out_open (fnam, cw, stat);       {open the CSV output file}
  sys_error_abort (stat, '', '', nil, 0);
  writeln ('Writing "', cw.conn.tnam.str:cw.conn.tnam.len, '"');
{
*   Write the header line.  This line contains the names of each field.
}
  csv_out_str (cw, 'Qty', stat); sys_error_abort (stat, '', '', nil, 0);
  csv_out_str (cw, 'Designators', stat); sys_error_abort (stat, '', '', nil, 0);
  csv_out_str (cw, 'Desc', stat); sys_error_abort (stat, '', '', nil, 0);
  csv_out_str (cw, 'Value', stat); sys_error_abort (stat, '', '', nil, 0);
  csv_out_str (cw, 'Package', stat); sys_error_abort (stat, '', '', nil, 0);
  csv_out_str (cw, 'Subst', stat); sys_error_abort (stat, '', '', nil, 0);

  if housename.len > 0
    then begin                         {we have explicit name for in-house parts}
      string_copy (housename, tk);     {init with house name}
      string_appends (tk, ' #'(0));    {add "#"}
      csv_out_vstr (cw, tk, stat);
      sys_error_abort (stat, '', '', nil, 0);
      end
    else begin                         {no housename}
      csv_out_str (cw, 'Inhouse #', stat);
      sys_error_abort (stat, '', '', nil, 0);
      end
    ;

  csv_out_str (cw, 'Manuf', stat); sys_error_abort (stat, '', '', nil, 0);
  csv_out_str (cw, 'Manuf part #', stat); sys_error_abort (stat, '', '', nil, 0);
  csv_out_str (cw, 'Supplier', stat); sys_error_abort (stat, '', '', nil, 0);
  csv_out_str (cw, 'Supp part #', stat); sys_error_abort (stat, '', '', nil, 0);

  csv_out_line (cw, stat); sys_error_abort (stat, '', '', nil, 0);
{
*   Scan thru the components list and write one output file line for each unique
*   part.
}
  part_p := nil;                       {init to before all parts}
  while true do begin                  {back here to go to next part}
    if part_p = nil
      then begin                       {currently before first part}
        part_p := partlist_p^.first_p; {go to first part in list}
        end
      else begin                       {at an existing part}
        part_p := part_p^.next_p;      {to next part in list}
        end
      ;
    if part_p = nil then exit;         {hit end of list ?}

    if part_flag_nobom_k in part_p^.flags {this part not to be added to the BOM ?}
      then next;
    if part_flag_comm_k in part_p^.flags {already on a previous line ?}
      then next;
    {
    *   Quantity.
    }
    ii := round(part_p^.qty);          {make integer quantity}
    if abs(part_p^.qty - ii) < 0.0001
      then begin                       {quantity really is integer ?}
        string_f_int (tk, ii);
        end
      else begin                       {quantity must be written with fraction digits}
        string_f_fp_fixed (tk, part_p^.qty, 3);
        end
      ;
    csv_out_vstr (cw, tk, stat);
    sys_error_abort (stat, '', '', nil, 0);
    {
    *   Designators.
    }
    tk.len := 0;                       {init list of designators}
    p2_p := part_p;                    {init to first part of this type}
    while p2_p <> nil do begin         {once for each component of this type}
      if p2_p^.desig.len > 0 then begin {this part has a designator ?}
        if tk.len > 0 then begin       {not first designator in list ?}
          string_append1 (tk, ' ');    {separator before new designator}
          end;
        string_append (tk, p2_p^.desig); {add this designator to list}
        if part_flag_isafe_k in p2_p^.flags then begin {critical to Intrinsic Safety ?}
          string_append1 (tk, '*');
          end;
        end;
      p2_p := p2_p^.same_p;            {advance to next component using this part}
      end;
    csv_out_vstr (cw, tk, stat);
    sys_error_abort (stat, '', '', nil, 0);
    {
    *   Description.
    }
    csv_out_vstr (cw, part_p^.desc, stat);
    sys_error_abort (stat, '', '', nil, 0);
    {
    *   Value.
    }
    csv_out_vstr (cw, part_p^.val, stat);
    sys_error_abort (stat, '', '', nil, 0);
    {
    *   Package.
    }
    csv_out_vstr (cw, part_p^.pack, stat);
    sys_error_abort (stat, '', '', nil, 0);
    {
    *   Substitute yes/no.
    }
    if part_flag_subst_k in part_p^.flags
      then string_vstring (tk, 'Yes'(0), -1)
      else string_vstring (tk, 'No'(0), -1);
    csv_out_vstr (cw, tk, stat);
    sys_error_abort (stat, '', '', nil, 0);
    {
    *   Inhouse #
    }
    csv_out_vstr (cw, part_p^.housenum, stat);
    sys_error_abort (stat, '', '', nil, 0);
    {
    *   Manufacturer.
    }
    csv_out_vstr (cw, part_p^.manuf, stat);
    sys_error_abort (stat, '', '', nil, 0);
    {
    *   Manufacturer part #.
    }
    csv_out_vstr (cw, part_p^.mpart, stat);
    sys_error_abort (stat, '', '', nil, 0);
    {
    *   Supplier.
    }
    csv_out_vstr (cw, part_p^.supp, stat);
    sys_error_abort (stat, '', '', nil, 0);
    {
    *   Supplier part #.
    }
    csv_out_vstr (cw, part_p^.spart, stat);
    sys_error_abort (stat, '', '', nil, 0);

    csv_out_line (cw, stat);           {write this line to output file}
    sys_error_abort (stat, '', '', nil, 0);
    end;                               {back for next part in list}

  csv_out_close (cw, stat);            {close the output file}
  sys_error_abort (stat, '', '', nil, 0);
{
****************************************
*
*   Write the PARTS.CSV file.  This file contains one line for each unique part
*   used, in the same format as a parts reference file.  The fields on each line
*   are:
*
*     Desc,Value,Package,Subst,Inhouse #,Manuf,Manuf part #,Supplier,Supp part #
}
  string_pathname_join (               {make output file pathname}
    dir,                               {directory to contain the file}
    string_v('parts'),                 {generic name of the file, CSV suffix assumed later}
    fnam);                             {returned full pathname}
  csv_out_open (fnam, cw, stat);       {open CSV output file}
  sys_error_abort (stat, '', '', nil, 0);
  writeln ('Writing "', cw.conn.tnam.str:cw.conn.tnam.len, '"');

  part_p := partlist_p^.first_p;       {init current component to first in list}
  while part_p <> nil do begin         {scan thru the entire list of components}
    if part_flag_nobom_k in part_p^.flags {this part not to be added to the BOM ?}
      then goto next_cw;
    if part_flag_comm_k in part_p^.flags then goto next_cw; {already on previous line ?}

    csv_out_vstr (cw, part_p^.desc, stat); {description}
    sys_error_abort (stat, '', '', nil, 0);

    csv_out_vstr (cw, part_p^.val, stat); {value}
    sys_error_abort (stat, '', '', nil, 0);

    csv_out_vstr (cw, part_p^.pack, stat); {package}
    sys_error_abort (stat, '', '', nil, 0);

    if part_flag_subst_k in part_p^.flags
      then string_vstring (tk, 'Yes'(0), -1)
      else string_vstring (tk, 'No'(0), -1);
    csv_out_vstr (cw, tk, stat);       {substitute allowed yes/no}
    sys_error_abort (stat, '', '', nil, 0);

    csv_out_vstr (cw, part_p^.housenum, stat); {in-house part number}
    sys_error_abort (stat, '', '', nil, 0);

    csv_out_vstr (cw, part_p^.manuf, stat); {manufacturer name}
    sys_error_abort (stat, '', '', nil, 0);

    csv_out_vstr (cw, part_p^.mpart, stat); {manufacturer part number}
    sys_error_abort (stat, '', '', nil, 0);

    csv_out_vstr (cw, part_p^.supp, stat); {supplier name}
    sys_error_abort (stat, '', '', nil, 0);

    csv_out_vstr (cw, part_p^.spart, stat); {supplier part number}
    sys_error_abort (stat, '', '', nil, 0);

    csv_out_line (cw, stat);           {write this line to output file}
    sys_error_abort (stat, '', '', nil, 0);

next_cw:                               {done processing the current part}
    part_p := part_p^.next_p;          {advance to next component}
    end;                               {back and process this new component}

  csv_out_close (cw, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end.
