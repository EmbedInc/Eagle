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
%include 'eagle.ins.pas';

const
  max_msg_args = 1;                    {max arguments we can pass to a message}

var
  fnam: string_treename_t;             {scratch file name}
  tnam: string_treename_t;             {full file treename}
  gnam: string_leafname_t;             {generic name of board files}
  dir: string_leafname_t;              {directory containing input file}
  tk: string_var8192_t;                {scratch token}
  partlist_p: part_list_p_t;           {points to list of BOM parts}
  part_p: part_p_t;                    {points to current part in parts list}
  reflist_p: part_reflist_p_t;         {points to reference parts list}

  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status}

begin
  fnam.max := size_char(fnam.str);     {init local var strings}
  tnam.max := size_char(tnam.str);
  gnam.max := size_char(gnam.str);
  dir.max := size_char(dir.str);
  tk.max := size_char(tk.str);

  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (fnam, stat);    {get input file name}
  string_cmline_req_check (stat);      {input file name is required}
  string_cmline_end_abort;             {no additional command line arguments allowed}

  string_pathname_split (              {make directory containing the input file}
    fnam,                              {pathname to split}
    tnam,                              {returned directory containing the file}
    tk);                               {leaf name, not used}
  string_treename (tnam, dir);         {make full directory treename}
{
*   Read the input file and create the list of parts.
}
  part_list_new (partlist_p, util_top_mem_context); {create empty parts list}

  part_housename_get (dir, partlist_p^.housename, stat); {try to find house name}
  sys_error_abort (stat, '', '', nil, 0);
  if partlist_p^.housename.len > 0 then begin {house name applies ?}
    sys_msg_parm_vstr (msg_parm[1], partlist_p^.housename);
    sys_message_parms ('eagle', 'housename', msg_parm, 1);
    end;

  eagle_parts_read (                   {read the xxx_PARTS.CSV file}
    fnam,                              {name of file to read}
    tk,                                {returned full treename of CSV file (unused)}
    gnam,                              {returned board name}
    partlist_p^,                       {list to add parts to}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  sys_msg_parm_int (msg_parm[1], partlist_p^.nparts); {show number of parts read in}
  sys_message_parms ('eagle', 'bom_ncomponents', msg_parm, 1);
{
*   Add the circuit board as a special part.
}
  part_list_ent_new_end (partlist_p^, part_p); {add new blank part to end of list}

  string_vstring (part_p^.desc, 'Circuit board'(0), -1);
  string_copy (gnam, tk);              {make upper case circuit board name}
  string_upcase (tk);
  string_copy (tk, part_p^.val);
  part_p^.flags := part_p^.flags - [part_flag_subst_k]; {not allowed to substitute}
{
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
*   Scan the list of parts and compare each to the reference parts.  Fill in
*   data from the reference part definition if the part matches the reference.
}
  part_ref_apply (partlist_p^, reflist_p^);
{
*   For each part, attempt to fill in some empty fields from other fields.
}
  part_def_list (partlist_p^);         {fill in defaults from other fields as possible}
{
*   Scan the list of components and determine common part usage.
}
  part_comm_find (partlist_p^);        {find common parts}

  sys_msg_parm_int (msg_parm[1], partlist_p^.nunique); {show number of unique BOM parts}
  sys_message_parms ('eagle', 'bom_nbom', msg_parm, 1);
{
*   Write the <name>_BOM.TSV file.  This is the BOM ready to import into a
*   spreadsheet.
}
  string_pathname_join (dir, gnam, fnam); {make pathname of the output file}
  string_appends (fnam, '_bom.tsv'(0));

  sys_msg_parm_vstr (msg_parm[1], fnam); {announce writing TSV BOM file}
  sys_message_parms ('file', 'writing_file', msg_parm, 1);

  part_bom_tsv (partlist_p^, fnam, stat); {write the BOM TSV file}
  sys_error_abort (stat, '', '', nil, 0);
{
*   Initialize the Excel spreadsheet file by copying the template.  This sets up
*   the formatting of the cells, which would not happen if the new BOM file was
*   imported into a empty spreadsheet.
}
  part_bom_template (dir, gnam, stat); {get the BOM spreadsheet template}
  sys_error_abort (stat, '', '', nil, 0);
{
*   Write the <name>_BOM.CSV file.  This is the bare BOM for reading by other
*   applications.
}
  string_pathname_join (dir, gnam, fnam); {make pathname of the output file}
  string_appends (fnam, '_bom.csv'(0));

  sys_msg_parm_vstr (msg_parm[1], fnam); {announce writing CSV BOM file}
  sys_message_parms ('file', 'writing_file', msg_parm, 1);

  part_bom_csv (partlist_p^, fnam, stat); {write the BOM CSV file}
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

  part_ref_write (partlist_p^, fnam, stat); {write the reference parts list CSV file}
  sys_error_abort (stat, '', '', nil, 0);
  end.
