{   Program BOM_DRAW [fnam]
*
*   Create an Eagle script to draw the BOM on additional sheets at the end of
*   the current schematic.
}
program bom_draw;
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
  scrname = '~/eagle/scr/bom_draw';    {name of script to create}
  max_msg_args = 1;                    {max arguments we can pass to a message}

var
  dir: string_treename_t;              {directory containing input file}
  tnam: string_treename_t;             {full file treename}
  fnam: string_treename_t;             {scratch file name}
  list_p: part_list_p_t;               {points to list of BOM parts}
  egl_p: eagle_p_t;                    {points to Eagle library use state}
  scr_p: eagle_scr_p_t;                {Eagle script writing state}

  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status}

begin
  dir.max := size_char(dir.str);       {init local var strings}
  tnam.max := size_char(tnam.str);
  fnam.max := size_char(fnam.str);

  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (fnam, stat);
  if string_eos(stat) then begin
    fnam.len := 0;
    end;
  string_cmline_end_abort;             {no additional command line arguments allowed}

  if fnam.len = 0 then begin           {input file name not explicitly provided ?}
    string_treename (string_v('.'), dir); {get full treename of current directory}
    string_pathname_split (            {get directory leafname}
      dir,                             {full input treename}
      tnam,                            {parent tree, unused}
      fnam);                           {bare directory leafname}
    string_appends (fnam, '_parts.csv'); {make parts input file name}
    end;

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
      string_copy (list_p^.board, fnam); {make upper case board name}
      string_upcase (fnam);
      sys_msg_parm_vstr (msg_parm[1], fnam);
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
*   Set for writing the Eagle script.
}
  eagle_lib_new (                      {start a new use of the Eagle library}
    util_top_mem_context,              {parent memory context}
    egl_p,                             {returned pointer to new library use state}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  eagle_scr_open (                     {start writing new Eagle script}
    egl_p^,                            {Eagle library use state}
    string_v(scrname),                 {script file name}
    scr_p,                             {returned pointer to script writing state}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
{
*   Write the script to draw the BOM in the schematic.
}
  sys_msg_parm_vstr (msg_parm[1], scr_p^.conn.tnam); {announce writing script file}
  sys_message_parms ('file', 'writing_file', msg_parm, 1);

  eagle_draw_bom (                     {write the scrip to draw the BOM}
    list_p^,                           {BOM parts list}
    scr_p^,                            {Eagle script writing state}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  eagle_lib_end (egl_p, stat);         {end this use of the Eagle library}
  sys_error_abort (stat, '', '', nil, 0);
  end.
