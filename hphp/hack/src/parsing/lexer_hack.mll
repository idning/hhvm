{
(**
 * Copyright (c) 2014, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

open Utils

(*****************************************************************************)
(* Comments accumulator. *)
(*****************************************************************************)

let (comment_list: (Pos.t * string) list ref) = ref []

(*****************************************************************************)
(* Fixmes accumulators *)
(*****************************************************************************)
let (fixmes: Pos.t IMap.t IMap.t ref) = ref IMap.empty

let add_fixme err_nbr pos =
  let line, _, _ = Pos.info_pos pos in
  let line_value =
    match IMap.get line !fixmes with
    | None -> IMap.empty
    | Some x -> x
  in
  fixmes := IMap.add line (IMap.add err_nbr pos line_value) !fixmes;
  ()

(*****************************************************************************)
(* The type for tokens. Some of them don't represent "real" tokens comming
 * from the buffer. For example Terror can be used to tag an error, or Tyield
 * doesn't really correspond to a string, it's just there to encode the
 * priority.
 *)
(*****************************************************************************)

type token =
  | Tlvar
  | Tint
  | Tfloat
  | Tat
  | Tclose_php
  | Tword
  | Tbacktick
  | Tphp
  | Thh
  | Tlp
  | Trp
  | Tsc
  | Tcolon
  | Tcolcol
  | Tcomma
  | Teq
  | Tbareq
  | Tpluseq
  | Tstareq
  | Tslasheq
  | Tdoteq
  | Tminuseq
  | Tpercenteq
  | Txoreq
  | Tampeq
  | Tlshifteq
  | Trshifteq
  | Teqeq
  | Teqeqeq
  | Tdiff
  | Tdiff2
  | Tbar
  | Tbarbar
  | Tampamp
  | Tplus
  | Tminus
  | Tstar
  | Tslash
  | Tbslash
  | Txor
  | Tlcb
  | Trcb
  | Tlb
  | Trb
  | Tdot
  | Tlte
  | Tlt
  | Tgt
  | Tgte
  | Tltlt
  | Tgtgt
  | Tsarrow
  | Tnsarrow
  | Tarrow
  | Tlambda
  | Tem
  | Tqm
  | Tamp
  | Ttild
  | Tincr
  | Tdecr
  | Tunderscore
  | Trequired
  | Tellipsis
  | Tdollar
  | Tpercent
  | Teof
  | Tquote
  | Tdquote
  | Tunsafe
  | Tunsafeexpr
  | Tfallthrough
  | Theredoc
  | Txhpname
  | Tref
  | Tspace
  | Topen_comment
  | Tclose_comment
  | Tline_comment
  | Topen_xhp_comment
  | Tclose_xhp_comment

(* Fake tokens *)
  | Tyield
  | Tawait
  | Tinclude
  | Tinclude_once
  | Teval
  | Trequire
  | Trequire_once
  | Tprint
  | Tinstanceof
  | Tnew
  | Tclone
  | Telseif
  | Telse
  | Tendif
  | Tcast
  | Terror
  | Tnewline
  | Tany

(*****************************************************************************)
(* Backtracking. *)
(*****************************************************************************)

let yyback n lexbuf =
  Lexing.(
  lexbuf.lex_curr_pos <- lexbuf.lex_curr_pos - n;
  let currp = lexbuf.lex_curr_p in
  lexbuf.lex_curr_p <-
    { currp with pos_cnum = currp.pos_cnum - n }
 )

let back lb =
  let n = Lexing.lexeme_end lb - Lexing.lexeme_start lb in
  yyback n lb

(*****************************************************************************)
(* Pretty printer (pretty?) *)
(*****************************************************************************)

let token_to_string = function
  | Tat           -> "@"
  | Tbacktick     -> "`"
  | Tlp           -> "("
  | Trp           -> ")"
  | Tsc           -> ";"
  | Tcolon        -> ":"
  | Tcolcol       -> "::"
  | Tcomma        -> ","
  | Teq           -> "="
  | Tbareq        -> "|="
  | Tpluseq       -> "+="
  | Tstareq       -> "*="
  | Tslasheq      -> "/="
  | Tdoteq        -> ".="
  | Tminuseq      -> "-="
  | Tpercenteq    -> "%="
  | Txoreq        -> "^="
  | Tampeq        -> "&="
  | Tlshifteq     -> "<<="
  | Trshifteq     -> ">>="
  | Teqeq         -> "=="
  | Teqeqeq       -> "==="
  | Tdiff         -> "!="
  | Tdiff2        -> "!=="
  | Tbar          -> "|"
  | Tbarbar       -> "||"
  | Tampamp       -> "&&"
  | Tplus         -> "+"
  | Tminus        -> "-"
  | Tstar         -> "*"
  | Tslash        -> "/"
  | Tbslash       -> "\\"
  | Txor          -> "^"
  | Tlcb          -> "{"
  | Trcb          -> "}"
  | Tlb           -> "["
  | Trb           -> "]"
  | Tdot          -> "."
  | Tlte          -> "<="
  | Tlt           -> "<"
  | Tgt           -> ">"
  | Tgte          -> ">="
  | Tltlt         -> "<<"
  | Tgtgt         -> ">>"
  | Tsarrow       -> "=>"
  | Tnsarrow      -> "?->"
  | Tarrow        -> "->"
  | Tlambda       -> "==>"
  | Tem           -> "!"
  | Tqm           -> "?"
  | Tamp          -> "&"
  | Ttild         -> "~"
  | Tincr         -> "++"
  | Tdecr         -> "--"
  | Tunderscore   -> "_"
  | Tellipsis     -> "..."
  | Tdollar       -> "$"
  | Tpercent      -> "%"
  | Tquote        -> "'"
  | Tdquote       -> "\""
  | Tclose_php    -> "?>"
  | Tlvar         -> "lvar"
  | Tint          -> "int"
  | Tfloat        -> "float"
  | Tword         -> "word"
  | Tphp          -> "php"
  | Thh           -> "hh"
  | Trequired     -> "required"
  | Teof          -> "eof"
  | Tyield        -> "yield"
  | Tawait        -> "await"
  | Tinclude      -> "include"
  | Tinclude_once -> "include_once"
  | Teval         -> "eval"
  | Trequire      -> "require"
  | Trequire_once -> "require_once"
  | Tprint        -> "print"
  | Tinstanceof   -> "instanceof"
  | Tnew          -> "new"
  | Tclone        -> "clone"
  | Telseif       -> "elseif"
  | Telse         -> "else"
  | Tendif        -> "endif"
  | Tcast         -> "cast"
  | Tref          -> "ref"
  | Theredoc      -> "heredoc"
  | Txhpname      -> "xhpname"
  | Terror        -> "error"
  | Tunsafe       -> "unsafe"
  | Tunsafeexpr   -> "unsafeexpr"
  | Tfallthrough  -> "fallthrough"
  | Tnewline      -> "newline"
  | Tany          -> "any"
  | Tspace        -> "space"
  | Topen_comment -> "open_comment"
  | Tclose_comment -> "close_comment"
  | Tline_comment  -> "line_comment"
  | Topen_xhp_comment -> "open_xhp_comment"
  | Tclose_xhp_comment -> "close_xhp_comment"

}

let digit = ['0'-'9']
let letter = ['a'-'z''A'-'Z''_']
let alphanumeric = digit | letter
let varname = letter alphanumeric*
let word_part = (letter alphanumeric*) | (['a'-'z'] (alphanumeric | '-')* alphanumeric)
let word = ('\\' | word_part)+ (* Namespaces *)
let xhpname = ('%')? letter (alphanumeric | ':' [^':''>'] | '-')*
let otag = '<' ['a'-'z''A'-'Z'] (alphanumeric | ':' | '-')*
let ctag = '<' '/' (alphanumeric | ':' | '-')+ '>'
let lvar = '$' varname
let reflvar = '&' '$' varname
let ws = [' ' '\t' '\r' '\x0c']
let wsnl = [' ' '\t' '\r' '\x0c''\n']
let hex = digit | ['a'-'f''A'-'F']
let hex_number = '0' 'x' hex+
let bin_number = '0' 'b' ['0'-'1']+
let decimal_number = '0' | ['1'-'9'] digit*
let octal_number = '0' ['0'-'7']+
let int = decimal_number | hex_number | bin_number | octal_number
let float =
  (digit* ('.' digit+) ((('e'|'E') ('+'?|'-') digit+))?) |
  (digit+ ('.' digit*) ((('e'|'E') ('+'?|'-') digit+))?) |
  (digit+ ('e'|'E') ('+'?|'-') digit+)
let unsafe = "//" ws* "UNSAFE" [^'\n']*
let unsafeexpr_start = "/*" ws* "UNSAFE_EXPR"
let fixme_start = "/*" ws* "HH_FIXME"
let fallthrough = "//" ws* "FALLTHROUGH" [^'\n']*

rule token = parse
  (* ignored *)
  | ws+                { token lexbuf }
  | '\n'               { Lexing.new_line lexbuf; token lexbuf }
  | unsafeexpr_start   { let buf = Buffer.create 256 in
                         ignore (comment buf lexbuf);
                         Tunsafeexpr
                       }
  | fixme_start        { fixme_state0 lexbuf;
                         token lexbuf
                       }
  | "/*"               { let buf = Buffer.create 256 in
                         comment_list := comment buf lexbuf :: !comment_list;
                         token lexbuf
                       }
  | "//"               { line_comment lexbuf; token lexbuf }
  | "#"                { line_comment lexbuf; token lexbuf }
  | '\"'               { Tdquote      }
  | '''                { Tquote       }
  | "<<<"              { Theredoc     }
  | int                { Tint         }
  | float              { Tfloat       }
  | '@'                { Tat          }
  | "?>"               { Tclose_php   }
  | word               { Tword        }
  | lvar               { Tlvar        }
  | '$'                { Tdollar      }
  | '`'                { Tbacktick    }
  | "<?php"            { Tphp         }
  | "<?hh"             { Thh          }
  | '('                { Tlp          }
  | ')'                { Trp          }
  | ';'                { Tsc          }
  | ':'                { Tcolon       }
  | "::"               { Tcolcol      }
  | ','                { Tcomma       }
  | '='                { Teq          }
  | "|="               { Tbareq       }
  | "+="               { Tpluseq      }
  | "*="               { Tstareq      }
  | "/="               { Tslasheq     }
  | ".="               { Tdoteq       }
  | "-="               { Tminuseq     }
  | "%="               { Tpercenteq   }
  | "^="               { Txoreq       }
  | "&="               { Tampeq       }
  | "<<="              { Tlshifteq    }
  | ">>="              { Trshifteq    }
  | "=="               { Teqeq        }
  | "==="              { Teqeqeq      }
  | "!="               { Tdiff        }
  | "!=="              { Tdiff2       }
  | '|'                { Tbar         }
  | "||"               { Tbarbar      }
  | "&&"               { Tampamp      }
  | '+'                { Tplus        }
  | '-'                { Tminus       }
  | '*'                { Tstar        }
  | '/'                { Tslash       }
  | '^'                { Txor         }
  | '%'                { Tpercent     }
  | '{'                { Tlcb         }
  | '}'                { Trcb         }
  | '['                { Tlb          }
  | ']'                { Trb          }
  | '.'                { Tdot         }
  | "<="               { Tlte         }
  | '<'                { Tlt          }
  | '>'                { Tgt          }
  | ">="               { Tgte         }
  | "<<"               { Tltlt        }
  | ">>"               { Tgtgt        }
  | "=>"               { Tsarrow      }
  | "?->"              { Tnsarrow     }
  | "->"               { Tarrow       }
  | "==>"              { Tlambda      }
  | '!'                { Tem          }
  | '?'                { Tqm          }
  | '&'                { Tamp         }
  | '~'                { Ttild        }
  | "++"               { Tincr        }
  | "--"               { Tdecr        }
  | "_"                { Tunderscore  }
  | "@required"        { Trequired    }
  | "..."              { Tellipsis    }
  | unsafe             { Tunsafe      }
  | fallthrough        { Tfallthrough }
  | eof                { Teof         }
  | _                  { Terror       }

and xhpname = parse
  | eof                { Terror      }
  | '\n'               { Lexing.new_line lexbuf; xhpname lexbuf }
  | ws+                { xhpname lexbuf }
  | "/*"               { ignore (comment (Buffer.create 256) lexbuf);
                         xhpname lexbuf
                       }
  | "//"               { line_comment lexbuf; xhpname lexbuf }
  | "#"                { line_comment lexbuf; xhpname lexbuf }
  | word               { Txhpname    }
  | xhpname            { Txhpname    }
  | _                  { Terror      }

and xhptoken = parse
  | eof                { Teof        }
  | '\n'               { Lexing.new_line lexbuf; xhptoken lexbuf }
  | '<'                { Tlt         }
  | '>'                { Tgt         }
  | '{'                { Tlcb        }
  | '}'                { Trcb        }
  | '/'                { Tslash      }
  | '\"'               { Tdquote     }
  | word               { Tword       }
  | "<!--"             { xhp_comment lexbuf; xhptoken lexbuf }
  | _                  { xhptoken lexbuf }

and xhpattr = parse
  | eof                { Teof        }
  | ws+                { xhpattr lexbuf }
  | '\n'               { Lexing.new_line lexbuf; xhpattr lexbuf }
  | "/*"               { ignore (comment (Buffer.create 256) lexbuf);
                         xhpattr lexbuf
                       }
  | "//"               { line_comment lexbuf; xhpattr lexbuf }
  | '\n'               { Lexing.new_line lexbuf; xhpattr lexbuf }
  | '<'                { Tlt         }
  | '>'                { Tgt         }
  | '{'                { Tlcb        }
  | '}'                { Trcb        }
  | '/'                { Tslash      }
  | '\"'               { Tdquote     }
  | word               { Tword       }
  | _                  { Terror      }

and heredoc_token = parse
  | eof                { Teof        }
  | '\n'               { Lexing.new_line lexbuf; Tnewline }
  | word               { Tword       }
  | ';'                { Tsc         }
  | _                  { Tany        }

and comment buf = parse
  | eof                { let pos = Pos.make lexbuf in
                         Errors.unterminated_comment pos;
                         pos, Buffer.contents buf
                       }
  | '\n'               { Lexing.new_line lexbuf;
                         Buffer.add_char buf '\n';
                         comment buf lexbuf
                       }
  | "*/"               { Pos.make lexbuf, Buffer.contents buf }
  | _                  { Buffer.add_string buf (Lexing.lexeme lexbuf);
                         comment buf lexbuf
                       }

(* HH_FIXME... *)
and fixme_state0 = parse
  | eof                { let pos = Pos.make lexbuf in
                         Errors.unterminated_comment pos;
                       }
  | ws+                { fixme_state0 lexbuf
                       }
  | '\n'               { Lexing.new_line lexbuf;                        
                         fixme_state0 lexbuf
                       }
  | '['                { fixme_state1 lexbuf }
  | _                  { Errors.fixme_format (Pos.make lexbuf);
                         ignore (comment (Buffer.create 256) lexbuf)
                       }

(* HH_FIXME[... *)
and fixme_state1 = parse
  | eof                { let pos = Pos.make lexbuf in
                         Errors.unterminated_comment pos
                       }
  | ws+                { fixme_state1 lexbuf }
  | '\n'               { Lexing.new_line lexbuf;
                         fixme_state1 lexbuf
                       }
  | int                { let err_nbr = Lexing.lexeme lexbuf in
                         let err_nbr = int_of_string err_nbr in
                         fixme_state2 err_nbr lexbuf }
  | _                  { Errors.fixme_format (Pos.make lexbuf);
                         ignore (comment (Buffer.create 256) lexbuf)
                       }

(* HH_FIXME[NUMBER... *)
and fixme_state2 err_nbr = parse
  | eof                { let pos = Pos.make lexbuf in
                         Errors.unterminated_comment pos
                       }
  | "*/" ws* '\n'      { Lexing.new_line lexbuf;
                         let pos = Pos.make lexbuf in
                         let line, _, _ = Pos.info_pos pos in
                         let pos = Pos.set_line pos (line+1) in
                         (* Nothing after */, the HH_FIXME applies to the
                          * next line.
                          *)
                         add_fixme err_nbr pos
                       }
  | "*/"               { add_fixme err_nbr (Pos.make lexbuf) }
  | '\n'               { Lexing.new_line lexbuf;
                         fixme_state2 err_nbr lexbuf
                       }
  | _                  { fixme_state2 err_nbr lexbuf }

and line_comment = parse
  | eof                { () }
  | '\n'               { Lexing.new_line lexbuf }
  | _                  { line_comment lexbuf }

and xhp_comment = parse
  | eof                { let pos = Pos.make lexbuf in
                         Errors.unterminated_xhp_comment pos;
                         ()
                       }
  | '\n'               { Lexing.new_line lexbuf; xhp_comment lexbuf }
  | "-->"              { () }
  | _                  { xhp_comment lexbuf }

and gt_or_comma = parse
  | eof                { Terror }
  | ws+                { gt_or_comma lexbuf }
  | '\n'               { Lexing.new_line lexbuf; gt_or_comma lexbuf }
  | "/*"               { ignore (comment (Buffer.create 256) lexbuf);
                         gt_or_comma lexbuf
                       }
  | "//"               { line_comment lexbuf; gt_or_comma lexbuf }
  | '\n'               { Lexing.new_line lexbuf; gt_or_comma lexbuf }
  | '>'                { Tgt  }
  | ','                { Tcomma  }
  | _                  { Terror }

and no_space_id = parse
  | eof                { Terror }
  | word               { Tword  }
  | _                  { Terror }

and string = parse
  | eof                { Teof }
  | '\n'               { Lexing.new_line lexbuf; string lexbuf }
  | '\\'               { string_backslash lexbuf; string lexbuf }
  | '''                { Tquote }
  | _                  { string lexbuf }

and string_backslash = parse
  | eof                { let pos = Pos.make lexbuf in
                         Errors.unexpected_eof pos;
                         ()
                       }
  | '\n'               { Lexing.new_line lexbuf }
  | _                  { () }

and string2 = parse
  | eof                { Teof }
  | '\n'               { Lexing.new_line lexbuf; string2 lexbuf }
  | '\\'               { string_backslash lexbuf; string2 lexbuf }
  | '\"'               { Tdquote }
  | '{'                { Tlcb }
  | '}'                { Trcb }
  | '['                { Tlb }
  | ']'                { Trb }
  | "->"               { Tarrow }
  | '$'                { Tdollar }
  | '''                { Tquote }
  | int                { Tint }
  | word_part          { Tword  }
  | lvar               { Tlvar }
  | _                  { Tany }

and header = parse
  | eof                         { `error }
  | ws+                         { header lexbuf }
  | '\n'                        { Lexing.new_line lexbuf; header lexbuf }
  | "//"                        { line_comment lexbuf; header lexbuf }
  | "/*"                        { ignore (comment (Buffer.create 256) lexbuf);
                                  header lexbuf
                                }
  | "#"                         { line_comment lexbuf; header lexbuf }
  | "<?hh"                      { `default_mode }
  | "<?hh" ws* "//"             { `explicit_mode }
  | "<?php" ws* "//" ws* "decl" { `php_decl_mode }
  | "<?php"                     { `php_mode }
  | _                           { `error }

and next_newline_or_close_cb = parse
  | eof                { () }
  | '\n'               { Lexing.new_line lexbuf }
  | '}'                { back lexbuf }
  | _                  { next_newline_or_close_cb lexbuf }

and look_for_open_cb = parse
  | eof                { () }
  | '\n'               { Lexing.new_line lexbuf; look_for_open_cb lexbuf }
  | '{'                { () }
  | _                  { look_for_open_cb lexbuf }

and format_token = parse
  | ' '                { Tspace        }
  | '\n'               { Tnewline      }
  | "/*"               { Topen_comment }
  | "*/"               { Tclose_comment }
  | "//"               { Tline_comment }
  | "#"                { Tline_comment }
  | '\"'               { Tdquote       }
  | '''                { Tquote        }
  | "<<<"              { Theredoc      }
  | int                { Tint          }
  | float              { Tfloat        }
  | '@'                { Tat           }
  | "?>"               { Tclose_php    }
  | word_part          { Tword         }
  | lvar               { Tlvar         }
  | '$'                { Tdollar       }
  | '`'                { Tbacktick     }
  | "<?php"            { Tphp          }
  | "<?hh"             { Thh           }
  | '('                { Tlp           }
  | ')'                { Trp           }
  | ';'                { Tsc           }
  | ':'                { Tcolon        }
  | "::"               { Tcolcol       }
  | ','                { Tcomma        }
  | '='                { Teq           }
  | "|="               { Tbareq        }
  | "+="               { Tpluseq       }
  | "*="               { Tstareq       }
  | "/="               { Tslasheq      }
  | ".="               { Tdoteq        }
  | "-="               { Tminuseq      }
  | "%="               { Tpercenteq    }
  | "^="               { Txoreq        }
  | "&="               { Tampeq        }
  | "<<="              { Tlshifteq     }
  | ">>="              { Trshifteq     }
  | "=="               { Teqeq         }
  | "==="              { Teqeqeq       }
  | "!="               { Tdiff         }
  | "!=="              { Tdiff2        }
  | '|'                { Tbar          }
  | "||"               { Tbarbar       }
  | "&&"               { Tampamp       }
  | '+'                { Tplus         }
  | '-'                { Tminus        }
  | '*'                { Tstar         }
  | '/'                { Tslash        }
  | '\\'               { Tbslash       }
  | '^'                { Txor          }
  | '%'                { Tpercent      }
  | '{'                { Tlcb          }
  | '}'                { Trcb          }
  | '['                { Tlb           }
  | ']'                { Trb           }
  | '.'                { Tdot          }
  | "<="               { Tlte          }
  | '<'                { Tlt           }
  | '>'                { Tgt           }
  | ">="               { Tgte          }
  | "<<"               { Tltlt         }
  | "=>"               { Tsarrow       }
  | "?->"              { Tnsarrow      }
  | "->"               { Tarrow        }
  | "==>"              { Tlambda       }
  | '!'                { Tem           }
  | '?'                { Tqm           }
  | '&'                { Tamp          }
  | '~'                { Ttild         }
  | "++"               { Tincr         }
  | "--"               { Tdecr         }
  | "_"                { Tunderscore   }
  | "..."              { Tellipsis     }
  | eof                { Teof          }
  | _                  { Terror        }

and format_xhptoken = parse
  | eof                { Teof        }
  | '\n'               { Tnewline    }
  | ' '                { Tspace      }
  | '<'                { Tlt         }
  | '>'                { Tgt         }
  | '{'                { Tlcb        }
  | '}'                { Trcb        }
  | '/'                { Tslash      }
  | '\"'               { Tdquote     }
  | "/*"               { Topen_comment      }
  | "*/"               { Tclose_comment     }
  | "//"               { Tline_comment      }
  | word               { Tword              }
  | "<!--"             { Topen_xhp_comment  }
  | "-->"              { Tclose_xhp_comment }
  | _                  { Terror             }
