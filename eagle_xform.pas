{   Routines to manage the 2D transform.
}
module eagle_xform;
define eagle_xform_reset;
define eagle_xform_move;
define eagle_xform_move_rel;
define eagle_xform_rot;
define eagle_xform_rot_rel;
define eagle_xform_scale_rel;
define eagle_xform_get;
define eagle_xform_set;
define eagle_xform_pnt;
define eagle_mm_inch;
define eagle_inch_mm;
%include 'eagle2.ins.pas';
{
********************************************************************************
*
*   Local subroutine MAKE_INV (EGL)
*
*   Set INV according to whether the transform inverts (is left handed) or not.
}
procedure make_inv (                   {set transform inverts indicator}
  in out  egl: eagle_t);               {library use state}
  val_param; internal;

begin
  egl.inv :=
    ((egl.xf.xb.x * egl.xf.yb.y) - (egl.xf.xb.y * egl.xf.yb.x))
    < 0.0;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_XFORM_RESET (EGL)
*
*   Reset the 2D transform to the identity.
}
procedure eagle_xform_reset (          {reset the 2D transform to the identity}
  in out  egl: eagle_t);               {state for use of this library}
  val_param;

begin
  egl.xf.xb.x := 1.0;
  egl.xf.xb.y := 0.0;
  egl.xf.yb.x := 0.0;
  egl.xf.yb.y := 1.0;
  egl.xf.ofs.x := 0.0;
  egl.xf.ofs.y := 0.0;
  egl.inv := false;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_XFORM_MOVE (EGL, X, Y)
*
*   Move the model space origin to the Eagle space X,Y.
}
procedure eagle_xform_move (           {move model space origin, absolute}
  in out  egl: eagle_t;                {state for use of this library}
  in      x, y: real);                 {Eagle coordinates of model space origin}
  val_param;

begin
  egl.xf.ofs.x := x;
  egl.xf.ofs.y := y;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_XFORM_MOVE_REL (EGL, X, Y)
*
*   Move the model space origin the relative avmount X,Y in model space.  After
*   this call, 0,0 maps to the same Eagle coordinate the X,Y mapped to before
*   the call.
}
procedure eagle_xform_move_rel (       {move model space origin, relative}
  in out  egl: eagle_t;                {state for use of this library}
  in      x, y: real);                 {model space point that will be 0,0 after call}
  val_param;

var
  x2, y2: real;

begin
  eagle_xform_pnt (egl, x, y, x2, y2); {make Eagle space coordinate of model X,Y}
  egl.xf.ofs.x := x2;
  egl.xf.ofs.y := y2;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_XFORM_ROT (EGL, ANG)
*
*   Set the 2D transform so that the output space is rotated ANG radians
*   counter-clockwise from the model space.  The scale factor is set to 1.  The
*   previous rotation and scaling is lost.  The current origin offset is not
*   altered.
}
procedure eagle_xform_rot (            {rotate, absolute, xform reset otherwise}
  in out  egl: eagle_t;                {state for use of this library}
  in      ang: real);                  {radians output rotation from input}
  val_param;

var
  s, c: real;                          {sine and cosine of the rotation angle}

begin
  s := sin(ang);
  c := cos(ang);

  egl.xf.xb.x := c;
  egl.xf.xb.y := s;
  egl.xf.yb.x := -s;
  egl.xf.yb.y := c;
  egl.inv := false;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_XFORM_ROT_REL (EGL, ANG)
*
*   Set the 2D transform so that the output space is rotated ANG radians
*   counter-clockwise relative to the current orientation.  The scale factor is
*   not altered.  The current origin offset is not altered.
}
procedure eagle_xform_rot_rel (        {rotate, relative}
  in out  egl: eagle_t;                {state for use of this library}
  in      ang: real);                  {radians new model space rotated left from old}
  val_param;

var
  s, c: real;                          {sine and cosine of the rotation angle}
  xb, yb: vect_2d_t;                   {new basis vectors}

begin
  s := sin(ang);
  c := cos(ang);

  xb.x := (egl.xf.xb.x * c) + (egl.xf.yb.x * s); {compute the new basis vectors}
  xb.y := (egl.xf.xb.y * c) + (egl.xf.yb.y * s);
  yb.x := (egl.xf.xb.x * -s) + (egl.xf.yb.x * c);
  yb.y := (egl.xf.xb.y * -s) + (egl.xf.yb.y * c);

  egl.xf.xb := xb;                     {udpate basis vectors in the transform}
  egl.xf.yb := yb;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_XFORM_SCALE_REL (EGL, M)
*
*   Apply the additional scaling M from the input to the output space.  For
*   example, if M is 2 then subsequent output will be 2 times larger than
*   previously.  The output coordinate that maps to the input coordinate origin
*   is not changed.  The new scale factor is applied relative to the current
*   scaling.  For example, calling this routine three times with a scale factor
*   of 2 is equivalent to calling it once with a scale factor of 8.
}
procedure eagle_xform_scale_rel (      {scale, relative}
  in out  egl: eagle_t;                {state for use of this library}
  in      m: real);                    {scale factor, output will be M times larger}
  val_param;

begin
  egl.xf.xb.x := egl.xf.xb.x * m;      {scale the basis vectors}
  egl.xf.xb.y := egl.xf.xb.y * m;
  egl.xf.yb.x := egl.xf.yb.x * m;
  egl.xf.yb.y := egl.xf.yb.y * m;

  make_inv (egl);                      {update whether transform inverts or not}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_XFORM_GET (EGL, XF)
*
*   Set XF to the current model space to Eagle space transform.
}
procedure eagle_xform_get (            {get copy of current 2D transform}
  in out  egl: eagle_t;                {state for use of this library}
  out     xf: vect_xf2d_t);            {returned 2D transform}
  val_param;

begin
  xf := egl.xf;
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_XFORM_SET (EGL, XF)
*
*   Set the model space to Eagle space transform to XF.
}
procedure eagle_xform_set (            {explicitly set whole 2D transform}
  in out  egl: eagle_t;                {state for use of this library}
  in      xf: vect_xf2d_t);            {new model to Eagle space transform}
  val_param;

begin
  egl.xf := xf;                        {set to the new transform}
  make_inv (egl);                      {update whether transform inverts or not}
  end;
{
********************************************************************************
*
*   Subroutine EAGLE_XFORM_PNT (EGL, X, Y, X2, Y2)
*
*   Apply the current 2D transform to the point X,Y.  The result is written to
*   X2, Y2.
}
procedure eagle_xform_pnt (            {apply current 2D transform to a point}
  in out  egl: eagle_t;                {state for use of this library}
  in      x, y: real;                  {model space coordinate to transform}
  out     x2, y2: real);               {resulting Eagle space coordinate}
  val_param;

begin
  x2 := egl.xf.xb.x * x + egl.xf.yb.x * y + egl.xf.ofs.x;
  y2 := egl.xf.xb.y * x + egl.xf.yb.y * y + egl.xf.ofs.y;
  end;
{
********************************************************************************
*
*   Function EAGLE_MM_INCH (MM)
*
*   Return MM millimeters in inches.
}
function eagle_mm_inch (               {convert from mm to inches}
  in      mm: real)                    {input in mm}
  :real;                               {output in inches}
  val_param;

begin
  eagle_mm_inch := mm / 25.4;
  end;
{
********************************************************************************
*
*   Function EAGLE_INCH_MM (INCH)
*
*   Return INCH inches in millimeters.
}
function eagle_inch_mm (               {convert from inches to mm}
  in      inch: real)                  {input in inches}
  :real;                               {output in mm}
  val_param;

begin
  eagle_inch_mm := inch * 25.4;
  end;
