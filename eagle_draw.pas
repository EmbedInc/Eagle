{   Internal Eagle library routines that interface with RENDlib.
}
module eagle_draw;
define eagle_draw_init;
define eagle_draw_end;
define eagle_draw_update;
define eagle_draw_cpnt_2dim;
define eagle_draw_vect_2dim;
define eagle_draw_cmdend;
%include 'eagle2.ins.pas';

const
  text_size = 0.075;                   {default text size in Eagle coor}
  text_bold = 0.10;                    {default text boldness}
  pixu = 100.0;                        {virtual pixels per Eagle unit}

var
  rend_started: boolean := false;      {RENDlib has been globally started}

procedure eagle_draw_cpnt_2dim (       {called on RENDlib SET.CPNT_2DIM}
  in out  draw: eagle_draw_t;          {context passed back by RENDlib}
  in      xr, yr: real);               {new current point}
  val_param; forward;

procedure eagle_draw_vect_2dim (       {called on RENDlib PRIM.VECT_2DIM}
  in out  draw: eagle_draw_t;          {context passed back by RENDlib}
  in      xr, yr: real);               {vector end point, new current point}
  val_param; forward;
{
********************************************************************************
*
*   Subroutine EAGLE_DRAW_INIT (XLFT, XRIT, YBOT, YTOP, SCR, DRAW_P, STAT)
*
*   Set up RENDlib and initialize for capturing 2D drawing.  SCR is the script
*   writing state.  DRAW_P is returned pointing to the new Eagle script drawing
*   state.
*
*   XL, XR, YB, and YT are the Eagle coordinate extents of the virtual drawing
*   surface.  Drawing outside this region may get clipped and not written to the
*   script.
}
procedure eagle_draw_init (            {init RENDlib, set up for writing 2D drawing to script}
  in      xlft, xrit: real;            {left/right Eagle coordinate limits to draw to}
  in      ybot, ytop: real;            {bottom/top Eagle coordinate limits to draw to}
  in out  scr: eagle_scr_t;            {script to write drawing commands to}
  out     draw_p: eagle_draw_p_t;      {returned pointer to new script drawing state}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  tk: string_var132_t;                 {scratch token and string}
  xb, yb, of: vect_2d_t;               {2D transformation}

label
  abort1;

begin
  tk.max := size_char(tk.str);

  util_mem_grab (                      {alloc mem for this drawing to script state}
    sizeof(draw_p^), scr.egl_p^.mem_p^, true, draw_p);

  draw_p^.scr_p := addr(scr);          {save pointer to script writing state}
  draw_p^.xlft := xlft;                {save Eagle coordinate limits drawing to}
  draw_p^.xrit := xrit;
  draw_p^.ybot := ybot;
  draw_p^.ytop := ytop;
  draw_p^.dx := xrit - xlft;           {make Eagle coordinates width}
  draw_p^.dy := ytop - ybot;           {make Eagle coordinates height}
  draw_p^.cpnt.x := 0.0;
  draw_p^.cpnt.y := 0.0;
  draw_p^.moved := false;

  if not rend_started then begin       {RENDlib not already started ?}
    rend_start;                        {no, start it}
    rend_started := true;              {remember that RENDlib has been started}
    end;

  string_vstring (tk, '*SW* SIZE '(0), -1); {build RENDlib device string}
  string_append_intu (tk, round((xrit - xlft) * pixu), 0); {image width}
  string_append1 (tk, ' ');
  string_append_intu (tk, round((ytop - ybot) * pixu), 0); {image height}

  rend_open (tk, draw_p^.rendev, stat); {open our RENDlib device}
  if sys_error(stat) then goto abort1;

  rend_set.iterp_on^ (rend_iterp_red_k, true);
  rend_set.iterp_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_on^ (rend_iterp_blu_k, true);
{
*   Set up the RENDlib 2D transform so that the Eagle coordinate limits map to
*   the whole drawing area.
}
  if draw_p^.dx >= draw_p^.dy
    then begin                         {drawing area is wider than tall}
      yb.y := 2.0 / draw_p^.dy;        {scale factor}
      xb.x := yb.y;
      end
    else begin                         {drawing area is taller than wide}
      xb.x := 2.0 / draw_p^.dx;        {scale factor}
      yb.y := xb.x;
      end
    ;
  xb.y := 0.0;                         {no rotation}
  yb.x := 0.0;
  of.x := -xb.x * (xlft + xrit) / 2.0;
  of.y := -yb.y * (ybot + ytop) / 2.0;
  rend_set.xform_2d^ (xb, yb, of);     {set the new 2D transform}
{
*   Other RENDlib initialization.
}
  rend_get.text_parms^ (draw_p^.tparm);
  draw_p^.tparm.size := text_size;
  draw_p^.tparm.width := 0.72;
  draw_p^.tparm.height := 1.0;
  draw_p^.tparm.slant := 0.0;
  draw_p^.tparm.rot := 0.0;
  draw_p^.tparm.lspace := 0.7;
  draw_p^.tparm.coor_level := rend_space_2d_k;
  draw_p^.tparm.poly := false;
  rend_set.text_parms^ (draw_p^.tparm);
  draw_p^.boldfr := text_bold;

  rend_get.vect_parms^ (draw_p^.vparm);
  draw_p^.vparm.poly_level := rend_space_none_k;
  draw_p^.vparm.subpixel := false;
  rend_set.vect_parms^ (draw_p^.vparm);

  eagle_draw_update (draw_p^);         {set up callbacks}
{
*   Set Eagle state that is required for these drawing to script routines.
}
  eagle_cmd_bend_direct (scr, stat);   {draw straight between endpoints}
  return;                              {normal return point}
{
*   Error exits.  STAT has already been set to indicate the error.
}
abort1:                                {drawing state created}
  util_mem_ungrab (draw_p, scr.egl_p^.mem_p^); {deallocate drawing state}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_DRAW_END (DRAW_P, STAT)
*
*   End drawing to an Eagle script.  DRAW_P is the pointer to the Eagle script
*   drawing state.  The script file is closed, resources are deallocated, and
*   DRAW_P is returned NIL.
}
procedure eagle_draw_end (             {end drawing to Eagle script}
  in out  draw_p: eagle_draw_p_t;      {pointer to drawing state, returned NIL}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  scr_p: eagle_scr_p_t;                {to script writing state}

begin
  rend_set.close^;                     {close the RENDlib device}

  eagle_draw_cmdend (draw_p^, stat);   {end any script command in progress}

  scr_p := draw_p^.scr_p;              {save pointer to the script writing state}
  util_mem_ungrab (draw_p, scr_p^.egl_p^.mem_p^); {deallocate drawing state}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_DRAW_UPDATE (DRAW)
*
*   Update to RENDlib settings were made.  Calling some RENDlib setting routines
*   can undo configuration state we need.  This routine restores those
*   configuration settings.
}
procedure eagle_draw_update (          {update RENDlib to setting were made}
  in out  draw: eagle_draw_t);         {drawing to script state}
  val_param;

begin
  rend_callback_cpnt_2dim (            {install our routine for 2DIM current point}
    univ_ptr(addr(eagle_draw_cpnt_2dim)), {our routine to call}
    addr(draw));                       {context pointer to pass back}

  rend_callback_vect_2dim (            {install our routine for 2DIM vector draw}
    univ_ptr(addr(eagle_draw_vect_2dim)), {our routine to call}
    addr(draw));                       {context pointer to pass back}
  end;
{
********************************************************************************
*
*   Local subroutine COOR_2DIM_EAGLE (DRAW, XI, YI, XO, YO)
*
*   Transform the point XI,YI from the RENDlib 2DIM space to the Eagle space.
*   XO,YO is returned as the result.
}
procedure coor_2dim_eagle (            {transform point from 2DIM to Eagle space}
  in      draw: eagle_draw_t;          {Eagle script drawing state}
  in      xi, yi: real;                {input point in RENDlib 2DIM space}
  out     xo, yo: real);               {output point in Eagle space}
  val_param; internal;

begin
  xo := xi / pixu;
  yo := (-yi / pixu) + draw.ytop;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_DRAW_CMDEND (DRAW, STAT)
*
*   End any command that may be in progress.
}
procedure eagle_draw_cmdend (          {end any cmd in progress, write line}
  in out  draw: eagle_draw_t;          {drawing to script state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  eagle_scr_cmdend (draw.scr_p^, stat); {end any current command}
  if sys_error(stat) then return;

  draw.moved := true;                  {force new WIRE command next vector}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_DRAW_CPNT_2DIM (DRAW, XR, YR)
*
*   This routine is called by RENDlib whenever a SET.CPNT_2DIM is performed.
*   DRAW is our drawing context.  XR,YR is the new current point.
}
procedure eagle_draw_cpnt_2dim (       {called on RENDlib SET.CPNT_2DIM}
  in out  draw: eagle_draw_t;          {context passed back by RENDlib}
  in      xr, yr: real);               {new current point}
  val_param;

var
  x, y: real;                          {coordinate in Eagle space}

begin
  coor_2dim_eagle (draw, xr, yr, x, y); {make Eagle coordinate}

  if (x <> draw.cpnt.x) or (y <> draw.cpnt.y) then begin {moved ?}
    draw.cpnt.x := x;                  {update current point}
    draw.cpnt.y := y;
    draw.moved := true;                {indicate current point moved}
    end;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_DRAW_VECT_2DIM (DRAW, XR, YR)
*
*   This routine is called by RENDlib on attempt to draw a vector in the 2DIM
*   space.  DRAW is our drawing context.  XR,YR is the vector end point and new
*   current point.
}
procedure eagle_draw_vect_2dim (       {called on RENDlib PRIM.VECT_2DIM}
  in out  draw: eagle_draw_t;          {context passed back by RENDlib}
  in      xr, yr: real);               {vector end point, new current point}
  val_param;

var
  x, y: real;                          {coordinate in Eagle space}
  stat: sys_err_t;

begin
  coor_2dim_eagle (draw, xr, yr, x, y); {make Eagle coordinate of vector endpoint}

  if draw.moved then begin             {new vector start point ?}
    eagle_scr_cmdend (                 {end any previous command}
      draw.scr_p^, stat);
    sys_error_abort (stat, '', '', nil, 0);
    eagle_scr_str (                    {start a new WIRE command}
      draw.scr_p^, 'WIRE'(0), stat);
    sys_error_abort (stat, '', '', nil, 0);
    eagle_scr_xy (                     {start at the curr point}
      draw.scr_p^, draw.cpnt.x, draw.cpnt.y, stat);
    sys_error_abort (stat, '', '', nil, 0);
    end;

  eagle_scr_xy (draw.scr_p^, x, y, stat); {new point this line segment ends at}
  sys_error_abort (stat, '', '', nil, 0);

  draw.cpnt.x := x;                    {save the new current point}
  draw.cpnt.y := y;
  draw.moved := false;                 {not moved since this vector endpoint}
  end;
