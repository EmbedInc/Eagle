module eagle_parts_read;
define eagle_parts_read;
%include 'eagle2.ins.pas';
{
********************************************************************************
*
*   Local subroutine GETNAME (F, P, NAME)
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
*   Local subroutine GETVAL (F, P, VAL)
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
*   Subroutine EAGLE_PARTS_READ (FNAM, LIST, STAT)
*
*   Read the xxx_PARTS.CSV file written by the BOM Eagle ULP.  This file
*   contains the list of parts in a schematic/board, one per line.
*
*   FNAM indicates the CSV input file to read.  If FNAM specifies the CSV file
*   directly, then that file is read.  Otherwise, FNAM with "_parts.csv"
*   appended is tried.  In other words, FNAM can be the CSV file or the bare
*   board name when the input file follows the xxx_PARTS.CSV naming convention.
*
*   LIST is the list of parts to add to.  One part will be added for each
*   content line of the CSV file.  LIST.BOARD will be filled in from XXX in the
*   input file name, if it hasn't already been filled in and the input file name
*   is of the form xxx_PARTS.CSV.
*
*   If LIST.TNAM has not already been set, then it is set to the full pathname
*   of the input file.
*
*   If the HOUSENAME field in LIST has not been set (is the empty string), then
*   the HOUSENAME is determined and the field set if a housename is defined for
*   the directory containing FNAM.  When a house name is available, the HOUSENUM
*   fields in the new parts will be filled in with part numbers from that
*   organization, when such private part numbers are available.  Organization
*   names (house names) are case-sensitive.
*
*   The header line of the CSV file is checked and must match what is produced
*   by the BOM ULP.  This routine returns with error and without reading the
*   rest of the CSV file if the header is not as expected.
}
procedure eagle_parts_read (           {read xxx_PARTS.CSV file written by BOM ULP}
  in      fnam: univ string_var_arg_t; {name of CSV file to read, ".csv" may be omitted}
  in out  list: part_list_t;           {list to add to add the parts from file to}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  cin: csv_in_t;                       {CSV file readin stat}
  inam: string_treename_t;             {input file name after defaults}
  tk: string_var8192_t;                {scratch token and string}
  tk2, tk3: string_var80_t;            {scratch secondary tokens}
  pf: string_index_t;                  {parse index into current CSV file field}
  ii: sys_int_machine_t;               {scratch integer and loop counter}
  pick: sys_int_machine_t;             {number of keyword picked from list}
  part_p: part_p_t;                    {pointer to current part in parts list}
  stat2: sys_err_t;                    {to avoid overwriting error in STAT}

label
  infile_bad, loop_line, eof, err_atline, abort;

begin
  inam.max := size_char(inam.str);     {init local var strings}
  tk.max := size_char(tk.str);
  tk2.max := size_char(tk2.str);
  tk3.max := size_char(tk3.str);
{
*   Open the CSV file and verify that the header is correct.  The field names
*   in the header line must exactly match what the BOM Eagle ULP creates.
}
  string_fnam_extend (fnam, '.csv', inam); {try FNAM is file name directly}
  csv_in_open (inam, cin, stat);       {open the CSV input file}
  if file_not_found (stat) then begin  {didn't find xxx.CSV ?}
    string_fnam_extend (fnam, '_parts.csv', inam); {try FNAM is board name}
    csv_in_open (inam, cin, stat);     {open the CSV input file}
    end;
  if sys_error(stat) then return;

  csv_in_line (cin, stat);             {read the CSV input file header line}
  sys_error_abort (stat, '', '', nil, 0);

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('DESIGNATOR')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('LIBRARY')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('DEVICE')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('VALUE')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('PACKAGE')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('MANUF')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('PARTNUM')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('SUPPLIER')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('VALSTAT')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('BOM')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('SUBST')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('DESC')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('DVAL')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('QTY')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('INHOUSE')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);
  if sys_error(stat) then goto infile_bad;
  string_upcase (tk);
  if not string_equal (tk, string_v('IS')) then goto infile_bad;

  csv_in_field_str (cin, tk, stat);    {try to get one more field}
  if not string_eos(stat) then begin   {additional unexpected field ?}
infile_bad:
    sys_stat_set (eagle_subsys_k, eagle_stat_bomfile_bad_k, stat);
    sys_stat_parm_vstr (cin.conn.tnam, stat);
    goto abort;
    end;
{
*   The input file seems valid.
*
*   Use the input file name to fill in the board name and full input file
*   treename, if these are not already set.
}
  if list.board.len <= 0 then begin    {board name not already set ?}
    string_generic_fnam (inam, '.csv', tk); {get input file leafname}
    string_generic_fnam (tk, '_parts', tk2); {try to extract board name}
    if tk2.len < tk.len then begin     {file name fits pattern, have board name ?}
      string_copy (tk2, list.board);   {set the board name for this parts list}
      end;
    end;

  if list.tnam.len <= 0 then begin     {list source treename not already set ?}
    string_copy (cin.conn.tnam, list.tnam); {set to treename of this input file}
    end;
{
*   Try to find the name of the organization to use private part numbers of if
*   that has not already been determined.
}
  if list.housename.len <= 0 then begin {organization name not known yet ?}
    string_pathname_split (            {get dir the input file is in}
      fnam,                            {pathname to split}
      tk,                              {returned parent directory name}
      tk2);                            {returned leaf name, not used}
    part_housename_get (tk, list.housename, stat); {try to get house name}
    if sys_error(stat) then return;
    end;
{
*   Read the remaining lines of the input file and create a new part list entry
*   from each.
}
loop_line:                             {back here each new input file line}
  csv_in_line (cin, stat);             {read the next CSV input file line}
  if file_eof(stat) then goto eof;     {hit end of input file ?}
  if sys_error(stat) then goto abort;

  part_list_ent_new_end (list, part_p); {add new blank part to end of list}

  csv_in_field_strn (cin, part_p^.desig, stat); {read designator name}
  if sys_error(stat) then goto abort;
  string_upcase (part_p^.desig);

  csv_in_field_strn (cin, part_p^.lib, stat); {read library name}
  if sys_error(stat) then goto abort;
  string_upcase (part_p^.lib);

  csv_in_field_strn (cin, part_p^.dev, stat); {read device name}
  if sys_error(stat) then goto abort;
  for ii := 1 to part_p^.dev.len do begin {loop looking for first dash}
    if part_p^.dev.str[ii] = '-' then begin {found first dash ?}
      part_p^.dev.len := ii - 1;       {truncate string before the dash}
      exit;                            {no need to look further}
      end;
    end;                               {back to check next character in device name}
  string_copy (part_p^.dev, part_p^.devu); {make upper case version}
  string_upcase (part_p^.devu);

  csv_in_field_strn (cin, part_p^.val, stat); {read value string}
  if sys_error(stat) then goto abort;

  csv_in_field_strn (cin, part_p^.pack, stat); {read package name}
  if sys_error(stat) then goto abort;
  string_upcase (part_p^.pack);

  csv_in_field_strn (cin, tk, stat);   {get manufacturers string}
  if sys_error(stat) then goto abort;
  pf := 1;                             {init parse index into field}
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

  csv_in_field_strn (cin, tk, stat);   {get part number string}
  if sys_error(stat) then goto abort;
  if tk.len > 0 then begin             {specific part number is available ?}
    string_copy (tk, part_p^.mpart);   {set manufacturer part number from it}
    end;

  csv_in_field_strn (cin, tk, stat);   {get suppliers string}
  if sys_error(stat) then goto abort;
  pf := 1;                             {init parse index into field}
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

  csv_in_field_strn (cin, tk, stat);   {get VALSTAT value}
  if sys_error(stat) then goto abort;
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
    sys_stat_set (eagle_subsys_k, eagle_stat_valstat_bad_k, stat);
    sys_stat_parm_vstr (tk, stat);
    goto err_atline;
    end;

  csv_in_field_strn (cin, tk, stat);   {get BOM attribute value}
  if sys_error(stat) then goto abort;
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
    sys_stat_set (eagle_subsys_k, eagle_stat_bomattr_bad_k, stat);
    sys_stat_parm_vstr (tk, stat);
    goto err_atline;
    end;

  csv_in_field_strn (cin, tk, stat);   {get SUBST attribute value}
  if sys_error(stat) then goto abort;
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
    sys_stat_set (eagle_subsys_k, eagle_stat_subst_bad_k, stat);
    sys_stat_parm_vstr (tk, stat);
    goto err_atline;
    end;

  csv_in_field_strn (cin, part_p^.desc, stat); {get explicit description string}
  if sys_error(stat) then goto abort;

  csv_in_field_strn (cin, tk, stat);   {get detailed value string}
  if sys_error(stat) then goto abort;
  if tk.len > 0 then begin
    string_copy (tk, part_p^.val);     {detailed value overrides schematic value string}
    end;

  csv_in_field_strn (cin, tk, stat);   {get quantity per use}
  if sys_error(stat) then goto abort;
  if tk.len > 0 then begin
    string_t_fpm (tk, part_p^.qtyuse, stat);
    if sys_error(stat) then begin
      sys_stat_set (eagle_subsys_k, eagle_stat_subst_bad_k, stat);
      sys_stat_parm_vstr (tk, stat);
      goto err_atline;
      end;
    part_p^.qty := part_p^.qtyuse;     {update total usage to this one part}
    end;

  csv_in_field_strn (cin, tk, stat);   {get list of organizations and their part numbers}
  if sys_error(stat) then goto abort;
  pf := 1;                             {init parse index into field}
  while true do begin                  {once for each organization in the list}
    getname (tk, pf, tk2);             {get this organization name into TK2}
    if tk2.len <= 0 then exit;         {done scanning this string}
    getval (tk, pf, tk3);              {get part number within this org into TK3}
    if string_equal (tk2, list.housename) then begin {for the org we care about ?}
      string_copy (tk3, part_p^.housenum); {save the in-house part number}
      exit;                            {no point looking further}
      end;
    end;

  csv_in_field_strn (cin, tk, stat);   {get YES/NO critical to Intrinsic Safety}
  if sys_error(stat) then goto abort;
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
    sys_stat_set (eagle_subsys_k, eagle_stat_isafe_bad_k, stat);
    sys_stat_parm_vstr (tk, stat);
    goto err_atline;
    end;

  goto loop_line;                      {back to get next CSV input file line}

eof:                                   {end of input file encountered}
  csv_in_close (cin, stat);            {close the CSV input file}
  return;
{
*   An error has been enountered and STAT set accordingly.  The error message
*   requires the line number and file name of the error location as the next two
*   error parameters, which have not yet been set.  These parameters are added
*   here, the input file closed, and the complete error returned in STAT.
}
err_atline:
  sys_stat_parm_vstr (cin.conn.tnam, stat); {add file name error parameter}
  sys_stat_parm_int (cin.conn.lnum, stat); {add line number error parameter}

abort:                                 {error with file open, STAT set}
  csv_in_close (cin, stat2);           {close CSV file, return with original error}
  end;
