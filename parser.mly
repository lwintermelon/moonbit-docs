%{
(* Copyright International Digital Economy Academy, all rights reserved *)
open Parser_util
%}

%token <Basic.Uchar_utils.uchar> CHAR
%token <string> INT
%token <string> FLOAT
%token <string> STRING
%token <Interp.t> INTERP
%token <string> LIDENT
%token <string> UIDENT
%token <Comment.t> COMMENT
%token NEWLINE
%token <string> INFIX1


%token <string> INFIX2
%token <string> INFIX3
%token <string> INFIX4

%token EOF
%token FALSE
%token TRUE
%token PUB             "pub"
%token PRIV            "priv"
%token READONLY        "readonly"
%token IMPORT          "import"
%token BREAK           "break"
%token CONTINUE        "continue"
%token STRUCT          "struct"
%token ENUM            "enum"
%token EQUAL           "="

%token LPAREN          "("
%token RPAREN          ")"

%token COMMA          ","
%token MINUS           "-"

%token <string>DOT_IDENT
%token <int>DOT_INT
%token <string>COLONCOLON_UIDENT
%token <string>COLONCOLON_LIDENT
%token COLON           ":"
%token COLONEQUAL      ":="
%token SEMI
%token LBRACKET        "["
%token PLUS           "+"
%token RBRACKET       "]"

%token UNDERSCORE      "_"
%token BAR             "|"

%token LBRACE          "{"
%token RBRACE          "}"

%token AMPERAMPER     "&&"
%token BARBAR          "||"
%token <string>PACKAGE_NAME
/* Keywords */

%token AS              "as"
%token ELSE            "else"
%token FN            "fn"
%token TOPLEVEL_FN   "func"
%token IF             "if"
%token LET            "let"
%token VAR            "var"
%token MATCH          "match"
%token MUTABLE        "mut"
%token TYPE            "type"
%token FAT_ARROW     "=>"
%token THIN_ARROW     "->"
%token WHILE           "while"
%token RETURN          "return"
%token DOTDOT          ".."

%nonassoc "as"
%right "|"
%right BARBAR
%right AMPERAMPER


// x.f(...) should be [Pexpr_dot_apply], not [Pexpr_apply(Pexpr_field, ...)]
// these two precedences are used to resolve this.
%nonassoc prec_field
%nonassoc LPAREN
%left INFIX1
%left INFIX2 PLUS MINUS
%left INFIX3
%right INFIX4
%nonassoc prec_unary_minus
%start    structure


%type <Syntax.impls> structure
%type <Compact.semi_expr_prop > statement_expr
%%

non_empty_list_commas_rev(X):
  | x = X  {}
  | xs=non_empty_list_commas_rev(X) "," x=X {}

non_empty_list_commas( X):
  | xs = non_empty_list_commas_rev(X) ; ioption(",") {}

%inline list_commas( X):
  | {}
  | non_empty_list_commas(X) {}

non_empty_list_semi_rev_aux(X):
  | x = X  {}
  | xs=non_empty_list_semi_rev_aux(X) ; SEMI ;  x=X {}

%inline non_empty_list_semis_rev(X):
  | xs = non_empty_list_semi_rev_aux(X) ; ioption(SEMI) {}

non_empty_list_semis(X):
  | non_empty_list_semis_rev(X) {}

%inline list_semis_rev(X):
  | {}
  | non_empty_list_semis_rev(X) {}

%inline list_semis(X):
  | {}
  | non_empty_list_semis(X){}

%inline id(x): x {}
%inline opt_annot: option(":" t=type_ {}) {}
%inline parameters : delimited("(",separated_list(",",id(b=binder t=opt_annot {})), ")") {}
optional_type_parameters:
  | params = option(delimited("[",separated_nonempty_list(",",id(tvar_binder)), "]")) {}
optional_type_arguments:
  | params = option(delimited("[" ,separated_nonempty_list(",",type_), "]")) {}
fun_binder:
  | type_name=qual_ident_ty func_name=COLONCOLON_LIDENT {}
  | binder {}
fun_header:
  pub=ioption("pub") "func"
    fun_binder=fun_binder
    /* TODO: move the quants before self */
    quants=optional_type_parameters
    ps=option(parameters)
    ts=option("->" t=type_{})
    {}


%inline block_expr: "{" ls=list_semis_rev(statement_expr) "}" {}
%inline error_block: error {}
val_header : pub=ioption("pub") "let" binder=binder t=opt_annot {}
structure : list_semis(structure_item) EOF {}
structure_item:
  | type_header=type_header {}
  | struct_header=struct_header "{" fs=list_semis(record_decl_field) "}" {}
  | enum_header=enum_header "{" cs=list_semis(enum_constructor) "}" {}
  | val_header=val_header  "=" expr = expr {}
  | t=fun_header "=" mname=STRING fname=STRING {}
  | t=fun_header body=block_expr {}
%inline visibility:
  | /* empty */ {}
  | "priv"      {}
  | "pub" attr=pub_attr {}
%inline pub_attr:
  | /* empty */ {}
  | "(" "readonly" ")" {}
type_header: vis=visibility "type" tycon=luident params=optional_type_parameters {}
struct_header: vis=visibility "struct" tycon=luident params=optional_type_parameters {}
enum_header: vis=visibility "enum" tycon=luident params=optional_type_parameters {}

luident:
  | i=LIDENT
  | i=UIDENT {}

qual_ident:
  | i=LIDENT {}
  | ps=PACKAGE_NAME id=DOT_IDENT {}

qual_ident_ty:
  | i=luident {}
  | ps=PACKAGE_NAME id=DOT_IDENT {}

%inline semi_expr_semi_opt: ls=non_empty_list_semis_rev(statement_expr)  {}

statement_expr:

  | "let" pat=pattern ty_opt=opt_annot "=" expr=expr
    {}
  | pat=shorthand_let_pattern ":=" expr=expr
    {}
  | "var" binder=binder ty=opt_annot "=" expr=expr
    {}
  | lv = left_value "=" e=expr {}
  | "fn" binder=binder params=parameters ty_opt=option("->" t=type_{}) block = block_expr
    {}
  | "break" {}
  | "continue" {}
  | while_expr {}
  | "return" expr = option(expr) {}
  | a=expr  {}

%inline shorthand_let_pattern:
  | UNDERSCORE {}
  | binder=binder {}

while_expr:
  | "while" cond=infix_expr b=block_expr
    {}
  | "while" cond=infix_expr b=error_block
    {}


if_expr:
   | "if"  b=infix_expr ifso=block_expr "else" ifnot=block_expr
   | "if"  b=infix_expr ifso=block_expr "else" ifnot=if_expr  {}
   | "if"  b=infix_expr ifso=block_expr {}
   | "if" b=infix_expr ifso=error_block {}


match_expr:
  | "match" e=infix_expr "{"  mat=non_empty_list_semis( pattern "=>" expr {})  "}"  {}
  | "match" e=infix_expr "{""}" {}
  | "match" e=infix_expr error {}

expr:
  | infix_expr
  | match_expr
  | if_expr {}


infix_expr:
  | op=id(PLUS {}) e=expr %prec prec_unary_minus {}
  | op=id(MINUS{}) e=expr %prec prec_unary_minus {}
  | simple_expr  {}
  | lhs=expr op=infixop rhs=expr {}

%inline left_value:
 | var=var {}
 | record=simple_expr  acc=accessor {}
 | obj=simple_expr  "[" ind=expr "]" {}

%inline constr:
  | name = UIDENT {}
  /* TODO: two tokens or one token here? */
  | type_name=qual_ident_ty constr_name=COLONCOLON_UIDENT
    {}

simple_expr:
  | "{" fs=record_defn "}" {}
  | "{" ".." oe=expr "," fs=record_defn "}" {}
  // | "{" fs=list_commas( l=label ":" e=expr {}) "}" {}
  // | "fn"  parameters "=>" atomic_expr
  | "{" x=semi_expr_semi_opt "}" {}
  | "fn" ps=parameters ty_opt=option("->" t=type_ {}) f=block_expr  {}
  | e = atomic_expr {}
  | "_" {}
  | v=var {}
  | c=constr {}
  | f=simple_expr "(" args=list_commas(expr) ")" {}
  | obj=simple_expr  "[" index=expr "]" {}
  | self=simple_expr method_=DOT_IDENT "(" args=list_commas(expr) ")" {}
  | record=simple_expr accessor=accessor %prec prec_field {}
  | type_name=qual_ident_ty method_name=COLONCOLON_LIDENT {}
  | "("  bs=list_commas(expr) ")" {}
  | "(" expr ":" type_ ")"
    {}
  | "[" es = list_commas(expr) "]" {}

%inline label:
  name = LIDENT {}
%inline accessor:
  | name = DOT_IDENT {}
  | index = DOT_INT {}
%inline binder:
  name = LIDENT {}
%inline tvar_binder:
  | name = luident {}
  | name = luident COLON constraints = separated_nonempty_list(PLUS, tvar_constraint) {}
%inline tvar_constraint:
  | name=UIDENT {}
%inline var:
  name = qual_ident {}

%inline atomic_expr:
  | TRUE {}
  | FALSE {}
  | CHAR {}
  | INT {}
  | FLOAT {}
  | STRING {}
  | INTERP {}

 %inline infixop:
  | INFIX4
  | INFIX3
  | INFIX2
  | INFIX1 {}
  | PLUS {}
  | MINUS  {}
  | AMPERAMPER {}
  | BARBAR {}


pattern:
  | simple_pattern {}
  | p=pattern "as" b=binder {}
  | pat1=pattern "|" pat2=pattern {}

simple_pattern:
  | TRUE {}
  | FALSE {}
  | CHAR {}
  | INT {}
  | FLOAT {}
  | STRING {}
  | UNDERSCORE {}
  | b=binder  {}
  | constr=constr ps=option("(" t=separated_nonempty_list(",",pattern) ")" {}){}
  | "(" pattern ")" {}
  | "(" p = pattern "," ps=separated_nonempty_list(",",pattern) ")"  {}
  | "(" pat=pattern ":" ty=type_ ")" {}
  // | "#" "[" pat = pat_list "]" {}
  | "[" lst=array_sub_patterns "]" {}
  //| "{" p=separated_list(",", l=label ":" p=pattern {}) "}" {}
  | "{" p=fields_pat "}" {}

array_sub_patterns:
  | {}
  | separated_nonempty_list(",", pattern) {}
  | ".." {}
  | ".." preceded(",", pattern)+ {}
  | terminated(pattern, ",")+ ".." {}

type_:
  | "(" t=type_ "," ts=separated_nonempty_list(",", type_)")" {}
  | "(" t=type_ "," ts=separated_nonempty_list(",",type_) ")" "->" rty=type_ {}
  | "(" ")" "->" rty=type_ {}
  | "(" t=type_ ")" rty=option("->" t2=type_{})
      {}
  // | "(" type_ ")" {}
  | id=qual_ident_ty params=optional_type_arguments {}
  | "_" {}

record_decl_field:
  | field_vis=visibility mutflag=option("mut") name=LIDENT ":" ty=type_ {}

enum_constructor:
  | id=UIDENT opt=option("("  ts=separated_nonempty_list(",",type_)")"{}) {}

record_defn:
  | {}
  /* ending comma is required for single field {} for resolving the ambiguity between record punning {} and block {} */
  | l=label_pun "," fs=list_commas(record_defn_single ) {}
  | l=labeled_expr option(",") {}
  /* rule out {} */
  | l=labeled_expr "," fs=non_empty_list_commas(record_defn_single) {}

record_defn_single:
  | labeled_expr
  | label_pun {}

%inline labeled_expr:
  | l=label ":" e=expr {}
%inline label_pun:
  | l=label {}

(* A field pattern list is a nonempty list of label-pattern pairs or punnings, optionally
   followed with an underscore, separated-or-terminated with commas. *)
fields_pat:
  | {}
  | fps=non_empty_list_commas(fields_pat_single) {}
  | fps=non_empty_list_commas_rev(fields_pat_single) "," ".." ioption(",") {}

fields_pat_single:
  | fpat_labeled_pattern
  | fpat_label_pun {}

%inline fpat_labeled_pattern:
  | l=label ":" p=pattern {}

%inline fpat_label_pun:
  | l=label {}
