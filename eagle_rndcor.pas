{   Routines that deal with round corners that are pieces of a circle.
}
module eagle_rndcor;
define eagle_rndcor_arc;
%include 'eagle2.ins.pas';
{
********************************************************************************
*
*   Subroutine EAGLE_RNDCOR_ARC (CORN, V1, V2, RAD, ARCP, ARC1, ARC2, CW)
*
*   Compute the parameters for an arc to draw a rounded corner.
*
*   CORN is the corner point.  This is where the corner would be if it were not
*   rounded.
*
*   V1 and V2 are the unit vectors from the corner point along the two edges
*   that the rounded corner is between.  This is a low level routine that
*   requires V1 and V2 to be of unit length.  Results are undefined when that is
*   not the case.  Results are also not defined when V1 and V2 are parallel.
*
*   RAD is the radius of curvature of that the corner must have.
*
*   ARCP is returned the center point of the circle the arc of the rounded
*   corner is on.  ARC1 and ARC2 are returned the two endpoints of the arc.
*   Both these points will be RAD distance from ARCP.
*
*   CW is returned TRUE when the corner arc extend clockwise from ARC1 to ARC2,
*   and FALSE for counter-clockwise.
}
procedure eagle_rndcor_arc (           {find arc parameters for round corner}
  in      corn: vect_2d_t;             {corner point with no arc (0 rad of curve)}
  in      v1, v2: vect_2d_t;           {unit vectors for the two edges from corner}
  in      rad: real;                   {radius of curvature for corner arc}
  out     arcp: vect_2d_t;             {arc center point}
  out     arc1, arc2: vect_2d_t;       {arc start and end points}
  out     cw: boolean);                {draw arc clockwise from ARC1 to ARC2}
  val_param;

const
  mindiv = 1.0e-30;                    {min valid magnitude to divide by}

var
  r: real;                             {scratch value}
  vm: vect_2d_t;                       {unit vector from corner to arc center}
  vp: vect_2d_t;                       {unit vector perpendicular to base vector}
  l: real;                             {length from corner to arc endpoints}

begin
{
*   Find clockwise versus counter-clockwise arc direction.
}
  r :=                                 {make Z component of V1 x V2}
    (v1.x * v2.y) - (v1.y * v2.x);
  cw := r >= 0.0;                      {clockwise}
{
*   Fill in arbitrary return values in case we need to abort later.  That only
*   happens if the input values are invalid such that a divide by zero or the
*   like would be performed.  Instead, this routine is just aborted.
}
  arcp.x := 0.0;
  arcp.y := 0.0;
  arc1.x := -1.0;
  arc1.y := 0.0;
  arc2.x := 1.0;
  arc2.y := 0.0;
{
*   Do the actual computations.
}
  vm.x := v1.x + v2.x;                 {make vector thru middle of corner}
  vm.y := v1.y + v2.y;
  r := sqrt(sqr(vm.x) + sqr(vm.y));    {find raw magnitude}
  if r < mindiv then return;           {too small to use ?}
  vm.x := vm.x / r;                    {unitize middle vector}
  vm.y := vm.y / r;

  if cw
    then begin                         {clockwise, use V1 as base}
      vp.x := -v1.y;                   {unitv into corner perpendicular to base}
      vp.y := v1.x;
      end
    else begin                         {counter-clockwise, use V2 as base}
      vp.x := -v2.y;                   {unitv into corner perpendicular to base}
      vp.y := v2.x;
      end
    ;

  r := (vm.x * vp.x) + (vm.y * vp.y);  {projection of mid vector along radius line}
  if r < mindiv then return;           {too small to be usable ?}
  l := sqrt(1.0 - sqr(r));             {L relative to distance to arc center}
  r := rad / r;                        {make mult factor for real distance}
  l := l * r;                          {make absolute L, dist from corner to arc ends}

  arcp.x := corn.x + (vm.x * r);       {find arc center point}
  arcp.y := corn.y + (vm.y * r);

  arc1.x := corn.x + (v1.x * l);       {arc point along V1}
  arc1.y := corn.y + (v1.y * l);

  arc2.x := corn.x + (v2.x * l);       {arc point along V2}
  arc2.y := corn.y + (v2.y * l);
  end;
