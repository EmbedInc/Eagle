{   Routines that handle parts lists.
}
module eagle_parts;
define eagle_parts_bom;
%include 'eagle2.ins.pas';
{
********************************************************************************
*
*   Subroutine EAGLE_PARTS_BOM (FNAM, MEM, LIST_P, STAT)
*
*   Read a xxx_PARTS.CSV file as created by the BOM Eagle ULP.  The parts are
*   read into a newly created parts list.
*
*   The board name is assumed to be XXX in the xxx_PARTS.CSV file name.  No
*   board name is assumed when the input file name is not xxx_PARTS.CSV.  When
*   the board name can be determined, the bare circuit board is added to the
*   list of parts.
*
*   The list of reference parts is read, if available, and the information for
*   each part updated accordingly.  Parts referencing the same physical part are
*   then identified and grouped as required for a BOM.
*
*   MEM is the parent memory context to use in creating the parts list.  LIST_P
*   is returned pointing to the new list.
}
procedure eagle_parts_bom (            {read xxx_PARTS.CSV, make new BOM parts list}
  in      fnam: univ string_var_arg_t; {name of CSV file to read, ".csv" may be omitted}
  in out  mem: util_mem_context_t;     {parent memory context, will create subordinate}
  out     list_p: part_list_p_t;       {returned pointer to BOM parts list}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  part_p: part_p_t;                    {points to current part in parts list}
  reflist_p: part_reflist_p_t;         {points to reference parts list}

label
  abort2, abort1;

begin
{
*   Create a new parts list and read the parts from the input file into it.
}
  part_list_new (list_p, mem);         {create new empty parts list}

  eagle_parts_read (                   {read the xxx_PARTS.CSV file}
    fnam,                              {name of file to read}
    list_p^,                           {list to add parts to}
    stat);
  if sys_error(stat) then goto abort1;
{
*   Add the circuit board as a special part if the board name could be
*   determined.
}
  if list_p^.board.len > 0 then begin  {board name is known ?}
    part_list_ent_new_end (list_p^, part_p); {add new blank part to end of list}
    string_vstring (part_p^.desc, 'Circuit board'(0), -1);
    string_copy (list_p^.board, part_p^.val); {set board name as value string}
    string_upcase (part_p^.val);       {upper case}
    part_p^.flags := part_p^.flags - [part_flag_subst_k]; {not allowed to substitute}
    end;
{
*   Fill in information for each part from a reference list or other sources, as
*   available.
}
  part_reflist_new (reflist_p, mem);   {create empty reference parts list}

  part_reflist_read_csv (
    reflist_p^,                        {the list to add reference parts to}
    string_v('(cog)progs/eagle/parts/parts.csv'(0)), {name of file to read ref parts from}
    stat);
  discard( file_not_found(stat) );     {no refparts file is not error}
  if sys_error(stat) then goto abort2;

  part_ref_apply (list_p^, reflist_p^); {apply reference into to parts list}

  part_def_list (list_p^);             {fill in defaults from other fields as possible}
{
*   Scan the list of components and determine common part usage.
}
  part_comm_find (list_p^);            {find common parts}
  return;                              {normal return point}
{
*   Error exists.  STAT is already set to indicate the error.
}
abort2:                                {reference list exists, STAT all set}
  part_reflist_del (reflist_p);        {delete the reference parts list}

abort1:                                {parts list exists, STAT all set}
  part_list_del (list_p);              {delete the parts list}
  end;
