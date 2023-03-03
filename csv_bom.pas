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
  max_msg_args = 2;                    {max arguments we can pass to a message}

var
  ii: sys_int_machine_t;               {scratch integer and loop counter}
  fnam: string_treename_t;             {scratch file name}
  tnam: string_treename_t;             {full file treename}
  gnam: string_leafname_t;             {generic name of board files}
  dir: string_leafname_t;              {directory containing input file}
  tk: string_var8192_t;                {scratch token}
  partlist_p: part_list_p_t;           {points to list of BOM parts}
  part_p, p2_p: part_p_t;              {scratch part descriptors}
  reflist_p: part_reflist_p_t;         {points to reference parts list}
  cw: csv_out_t;                       {CSV file writing state}

  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status}

label
  next_cw;

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

  sys_msg_parm_vstr (msg_parm[1], fnam); {announce writing TSV file}
  sys_message_parms ('file', 'writing_file', msg_parm, 1);

  part_bom_tsv (partlist_p^, fnam, stat); {write the BOM TSV file}
  sys_error_abort (stat, '', '', nil, 0);
{
*   Initialize the Excel spreadsheet file by copying the template.  This sets up
*   the formatting of the cells, which would not happen if the new BOM file was
*   imported into a empty spreadsheet.
}
  string_pathname_join (dir, gnam, fnam); {init to generic output file pathname}
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
  string_pathname_join (dir, gnam, fnam); {build the output file name}
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

  if partlist_p^.housename.len > 0
    then begin                         {we have explicit name for in-house parts}
      string_copy (partlist_p^.housename, tk); {init with house name}
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
