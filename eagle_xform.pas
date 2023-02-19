{   Routines to manage the 2D transform.
}
module eagle_xform;
define eagle_xform_pnt;
%include 'eagle2.ins.pas';
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
