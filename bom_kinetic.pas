{   Program BOM_KINETIC
*
*   Creates CSV file to make spreadsheet that can be copied and pasted into
*   Epicor Kinetic software as a BOM (bill of materials).
}
program csv_bom;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'stuff.ins.pas';
%include 'math.ins.pas';
%include 'vect.ins.pas';
%include 'part.ins.pas';
%include 'img.ins.pas';
%include 'rend.ins.pas';
%include 'eagle.ins.pas';

const
  max_msg_args = 1;                    {max arguments we can pass to a message}

var
  fnam: string_treename_t;             {scratch file name}
  tnam: string_treename_t;             {full file treename}
  dir: string_treename_t;              {directory containing input file}
  board: string_leafname_t;            {Eagle board name}
  tk: string_var32_t;                  {scratch token}
  list_p: part_list_p_t;               {to list of parts}
  bom_p: part_bom_p_t;                 {to BOM created from parts list}
  ent_p: part_bom_ent_p_t;             {to current BOM entry}
  csv: csv_out_t;                      {CSV file writing state}
  mtln: sys_int_machine_t;             {Kinetic material sequence number}

  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status}
{
******************************
*
*   Local subroutine WSTRP (STR_P)
*
*   Write the string pointed to by STR_P to the CSV file as the next field.
*   STR_P may be NIL, in which case the empty string is written.
}
procedure wstrp (                      {write string as next CSV file field}
  in      str_p: string_var_p_t);      {to string to write, may be NIL}
  val_param; internal;

var
  stat: sys_err_t;                     {completion status}

begin
  if str_p = nil
    then begin                         {no input string, write empty string}
      csv_out_str (csv, ''(0), stat);
      end
    else begin                         {input string was supplied}
      csv_out_vstr (csv, str_p^, stat);
      end
    ;
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
******************************
*
*   Start of main routine.
}
begin
  fnam.max := size_char(fnam.str);     {init local var strings}
  tnam.max := size_char(tnam.str);
  dir.max := size_char(dir.str);
  board.max := size_char(board.str);
  tk.max := size_char(tk.str);

  string_cmline_init;                  {init for reading the command line}
  string_cmline_end_abort;             {no additional command line arguments allowed}
{
*   Read and process the <board>_parts.csv file.
}
  file_currdir_get (dir, stat);        {get current directory pathname}
  sys_error_abort (stat, '', '', nil, 0);

  string_pathname_split (              {extract directory leafname}
    dir,                               {pathname to split}
    tnam,                              {pathname without final leafname, not used}
    board);                            {get board name from directory leafname}

  string_copy (board, fnam);           {make name of Eagle parts list CSV file}
  string_appends (fnam, '_parts'(0));

  eagle_parts_bom (                    {read xxx_PARTS.CSV file, make BOM parts list}
    fnam,                              {name of file to read}
    util_top_mem_context,              {parent memory context for new lists}
    list_p,                            {returned pointer to BOM parts list}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  part_bom_list_make (list_p^, bom_p); {create BOM from the parts list}
{
*   Show some information about the BOM to the user.
}
  sys_msg_parm_vstr (msg_parm[1], list_p^.tnam); {show input file name}
  sys_message_parms ('eagle', 'read_parts', msg_parm, 1);

  sys_msg_parm_int (msg_parm[1], list_p^.nparts); {show number of parts read in}
  sys_message_parms ('eagle', 'bom_ncomponents', msg_parm, 1);

  if list_p^.board.len <= 0
    then begin                         {no board name}
      sys_message ('eagle', 'board_nname');
      end
    else begin                         {board name was determined}
      string_copy (list_p^.board, tk); {make upper case board name}
      string_upcase (tk);
      sys_msg_parm_vstr (msg_parm[1], tk);
      sys_message_parms ('eagle', 'board_name', msg_parm, 1);
      end
    ;

  if list_p^.housename.len > 0 then begin {house name applies ?}
    sys_msg_parm_vstr (msg_parm[1], list_p^.housename);
    sys_message_parms ('eagle', 'housename', msg_parm, 1);
    end;

  if list_p^.reflist_p <> nil then begin
    sys_msg_parm_int (msg_parm[1], list_p^.reflist_p^.nparts); {num of ref parts}
    sys_message_parms ('eagle', 'refparts_n', msg_parm, 1);
    end;

  sys_msg_parm_int (msg_parm[1], list_p^.nunique); {show number of unique BOM parts}
  sys_message_parms ('eagle', 'bom_nbom', msg_parm, 1);
{
*   Write the CSV file in the format we use with Kinetic.
}
  string_vstring (fnam, 'kinetic'(0), -1); {CSV output file name}
  csv_out_open (fnam, csv, stat);      {open CSV output file}
  sys_error_abort (stat, '', '', nil, 0);
  csv.flags := csv.flags + [csv_outflag_minchar_k]; {only min output chars}
  {
  *   Write CSV file header line.
  }
  csv_out_str (csv, 'Mtl', stat);
  sys_error_abort (stat, '', '', nil, 0);

  csv_out_str (csv, 'Part', stat);
  sys_error_abort (stat, '', '', nil, 0);

  csv_out_str (csv, 'Description', stat);
  sys_error_abort (stat, '', '', nil, 0);

  csv_out_str (csv, 'Qty/Parent', stat);
  sys_error_abort (stat, '', '', nil, 0);

  csv_out_str (csv, 'MfgComment', stat);
  sys_error_abort (stat, '', '', nil, 0);

  csv_out_line (csv, stat);
  sys_error_abort (stat, '', '', nil, 0);
  {
  *   Write one line for each BOM entry.
  }
  mtln := 10;                          {init next Kinetic material seq num to use}

  ent_p := bom_p^.first_p;             {init to first BOM entry}
  while ent_p <> nil do begin          {scan the list of BOM entries}
    csv_out_int (csv, mtln, stat);     {write material sequence number}
    sys_error_abort (stat, '', '', nil, 0);

    wstrp (ent_p^.inhouse_p);          {part number in Kinetic}

    csv_out_str (csv, ''(0), stat);    {part description, filled in by Kinetic}
    sys_error_abort (stat, '', '', nil, 0);

    csv_out_vstr (csv, ent_p^.qty, stat); {quantity of this part used}
    sys_error_abort (stat, '', '', nil, 0);

    wstrp (ent_p^.desig_p);            {list of part designators}

    csv_out_line (csv, stat);          {end this CSV output file line}
    sys_error_abort (stat, '', '', nil, 0);

    ent_p := ent_p^.next_p;            {to next BOM entry}
    mtln := mtln + 10;                 {to next material sequence number}
    end;                               {back to process this new BOM entry}

  csv_out_close (csv, stat);           {close the CSV output file}
  sys_error_abort (stat, '', '', nil, 0);
  end.
