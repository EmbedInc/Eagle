/*   Error and other messages specific to the EAGLE library.
/*
/*   Messages for the error status codes.
/*
msg err1
  lan english -def
    The name_PARTS.CSV file "%p1s" is not of the expected format.  This
    can mean the version of the BOM ULP and this program are out of sync.
msg err2
  lan english -def
    Invalid VALSTAT value of "%p1s" found on line %p3i of file "%p2s".
msg err3
  lan english -def
    Invalid BOM value of "%p1s" found on line %p3i of file "%p2s".
msg err4
  lan english -def
    Invalid SUBST value of "%p1s" found on line %p3i of file "%p2s".
msg err5
  lan english -def
    Invalid QTY value of "%p1s" found on line %p3i of file "%p2s".
msg err6
  lan english -def
    Invalid IS (intrinsic safety) value of "%p1s" found on line %p3i of file "%p2s".
/*
/*   Messages related to reading the name_PARTS.CSV file produced by the Eagle
/*   BOM.ULP.
/*
msg board_name
  lan english -def
    Circuit board name is "%p1s".
msg board_nname
  lan english -def
    Circuit board name could not be determined.
msg bom_nbom
  lan english -def
    %p1i unique BOM parts found.
msg bom_ncomponents
  lan english -def
    %p1i individual components read.
msg housename
  lan english -def
    In-house part numbers are for the organization "%p1s".
msg read_parts
  lan english -def
    Read parts file "%p1s".
msg refparts_n
  lan english -def
    %p1i reference parts read.
