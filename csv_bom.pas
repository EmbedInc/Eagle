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
  lnam: string_leafname_t;             {scratch leafname}
  list_p: part_list_p_t;               {points to list of BOM parts}

  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status}

begin
  fnam.max := size_char(fnam.str);     {init local var strings}
  tnam.max := size_char(tnam.str);
  dir.max := size_char(dir.str);
  lnam.max := size_char(lnam.str);

  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (fnam, stat);    {get input file name}
  string_cmline_req_check (stat);      {input file name is required}
  string_cmline_end_abort;             {no additional command line arguments allowed}

  string_pathname_split (              {make directory containing the input file}
    fnam,                              {pathname to split}
    tnam,                              {returned directory containing the file}
    lnam);                             {leaf name, not used}
  string_treename (tnam, dir);         {make full directory treename}

  eagle_parts_bom (                    {read xxx_PARTS.CSV file, make BOM parts list}
    fnam,                              {name of file to read}
    util_top_mem_context,              {parent memory context for new lists}
    list_p,                            {returned pointer to BOM parts list}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
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
      string_copy (list_p^.board, lnam); {make upper case board name}
      string_upcase (lnam);
      sys_msg_parm_vstr (msg_parm[1], lnam);
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
*   Write the <name>_BOM.TSV file.  This is the BOM ready to import into a
*   spreadsheet.
}
  string_pathname_join (dir, list_p^.board, fnam); {make pathname of the output file}
  string_appends (fnam, '_bom.tsv'(0));

  sys_msg_parm_vstr (msg_parm[1], fnam); {announce writing TSV BOM file}
  sys_message_parms ('file', 'writing_file', msg_parm, 1);

  part_bom_tsv (list_p^, fnam, stat);  {write the BOM TSV file}
  sys_error_abort (stat, '', '', nil, 0);
{
*   Initialize the Excel spreadsheet file by copying the template.  This sets up
*   the formatting of the cells, which would not happen if the new BOM file was
*   imported into a empty spreadsheet.
}
  part_bom_template (dir, list_p^.board, stat); {get the BOM spreadsheet template}
  sys_error_abort (stat, '', '', nil, 0);
{
*   Write the <name>_BOM.CSV file.  This is the bare BOM for reading by other
*   applications.
}
  string_pathname_join (dir, list_p^.board, fnam); {make pathname of the output file}
  string_appends (fnam, '_bom.csv'(0));

  sys_msg_parm_vstr (msg_parm[1], fnam); {announce writing CSV BOM file}
  sys_message_parms ('file', 'writing_file', msg_parm, 1);

  part_bom_csv (list_p^, fnam, stat);  {write the BOM CSV file}
  sys_error_abort (stat, '', '', nil, 0);
{
*   Write the PARTS.CSV file.  This file contains one line for each unique part
*   used, in the same format as a parts reference file.  The fields on each line
*   are:
*
*     Desc,Value,Package,Subst,Inhouse #,Manuf,Manuf part #,Supplier,Supp part #
}
  string_pathname_join (dir, string_v('parts.csv'), fnam); {make file name}

  sys_msg_parm_vstr (msg_parm[1], fnam); {announce writing reference parts file}
  sys_message_parms ('file', 'writing_file', msg_parm, 1);

  part_ref_write (list_p^, fnam, stat); {write the reference parts list CSV file}
  sys_error_abort (stat, '', '', nil, 0);
  end.
