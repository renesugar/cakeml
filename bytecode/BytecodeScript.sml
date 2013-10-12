(*Generated by Lem from bytecode.lem.*)
open bossLib Theory Parse res_quanTheory
open fixedPointTheory finite_mapTheory listTheory pairTheory pred_setTheory
open integerTheory set_relationTheory sortingTheory stringTheory wordsTheory

val _ = numLib.prefer_num();



open PrinterTheory CompilerLibTheory SemanticPrimitivesTheory AstTheory LibTheory

val _ = new_theory "Bytecode"

(*open Lib*)
(*open Ast*)
(*open SemanticPrimitives*)
(*open CompilerLib*)
(*open Printer*)

(* --- Syntax --- *)

val _ = Hol_datatype `

  bc_stack_op =
    Pop                     (* pop top of stack *)
  | Pops of num             (* pop n elements under stack top *)
  | Shift of num => num      (* shift top n elements down k places *)
  | PushInt of int          (* push int onto stack *)
  | Cons of num => num       (* push new cons with tag m and n elements *)
  | Load of num             (* push stack[n] *)
  | Store of num            (* pop and store in stack[n] *)
  | LoadRev of num          (* push rev(stack)[n] *)
  | El of num               (* read field n of cons block *)
  | TagEq of num            (* test tag of block *)
  | IsBlock                 (* test for a block *)
  | Equal                   (* test equality *)
  | Add | Sub | Mult | Div | Mod | Less`;
  (* arithmetic *)

val _ = Hol_datatype `

  loc =
    Lab of num              (* label *)
  | Addr of num`;
             (* address *)

val _ = Hol_datatype `

  bc_inst =
    Stack of bc_stack_op
  | Label of num            (* label location *)
  | Jump of loc             (* jump to location *)
  | JumpIf of loc           (* jump to location iff true *)
  | Call of loc             (* call location *)
  | CallPtr                 (* call based on code pointer *)
  | PushPtr of loc          (* push a CodePtr onto stack *)
  | Return                  (* pop return address, jump *)
  | PushExc                 (* push exception handler *)
  | PopExc                  (* pop exception handler *)
  | Ref                     (* create a new ref cell *)
  | Deref                   (* dereference a ref cell *)
  | Update                  (* update a ref cell *)
  | Stop                    (* halt execution *)
  | Tick                    (* use fuel *)
  | Print                   (* print value at top of stack *)
  | PrintC of char`;
      (* print a character *)

(* --- Semantics --- *)

(* the stack is a list of elements of bc_value *)

val _ = Hol_datatype `

  bc_value =
    Number of int                  (* integer *)
  | Block of num => bc_value list   (* cons block: tag and payload *)
  | CodePtr of num                 (* code pointer *)
  | RefPtr of num                  (* pointer to ref cell *)
  | StackPtr of num`;
                (* pointer into stack *)

val _ = Hol_datatype `

  bc_state =
   <| (* main state components *)
      stack : bc_value list;
      code : bc_inst list;
      pc : num;
      refs : (num, bc_value)fmap;
      handler : num;
      output : string;
      cons_names : (num # ( conN id) option) list;
      (* artificial state components *)
      inst_length : bc_inst -> num;
      clock : num option
   |>`;


 val bool_to_tag_def = Define `

(bool_to_tag F = 0)
/\
(bool_to_tag T = 1)`;


val _ = Define `
 unit_tag = 2`;

val _ = Define `
 closure_tag = 3`;

val _ = Define `
 block_tag = 4`;


val _ = Define `
 (bool_to_val b = (Block (bool_to_tag b) []))`;

val _ = Define `
 unit_val = (Block unit_tag [])`;


 val is_Block_def = Define `

(is_Block (Block _ _) = T)
/\
(is_Block _ = F)`;


(* comparing bc_values for equality *)

 val bc_equal_defn = Hol_defn "bc_equal" `

(bc_equal (CodePtr _) _ = Eq_type_error)
/\
(bc_equal _ (CodePtr _) = Eq_type_error)
/\
(bc_equal (StackPtr _) _ = Eq_type_error)
/\
(bc_equal _ (StackPtr _) = Eq_type_error)
/\
(bc_equal (Number n1) (Number n2) = (Eq_val (n1 = n2)))
/\
(bc_equal (Number _) _ = (Eq_val F))
/\
(bc_equal _ (Number _) = (Eq_val F))
/\
(bc_equal (RefPtr n1) (RefPtr n2) = (Eq_val (n1 = n2)))
/\
(bc_equal (RefPtr _) _ = (Eq_val F))
/\
(bc_equal _ (RefPtr _) = (Eq_val F))
/\
(bc_equal (Block t1 l1) (Block t2 l2) =  
(if (t1 = closure_tag) \/ (t2 = closure_tag)
  then Eq_closure else
    if (t1 = t2) /\ ( LENGTH l1 = LENGTH l2)
    then bc_equal_list l1 l2 else Eq_val F))
/\
(bc_equal_list [] [] = (Eq_val T))
/\
(bc_equal_list (v1::vs1) (v2::vs2) =  
((case bc_equal v1 v2 of
    Eq_val T => bc_equal_list vs1 vs2
  | Eq_val F => Eq_val F
  | bad => bad
  )))
/\
(bc_equal_list _ _ = (Eq_val F))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn bc_equal_defn;

 val bc_equality_result_to_val_def = Define `

(bc_equality_result_to_val (Eq_val b) = ( bool_to_val b))
/\
(bc_equality_result_to_val Eq_closure = (Number ( & 0)))
/\
(bc_equality_result_to_val Eq_type_error = (Number ( & 1)))`;


(* fetching the next instruction from the code *)

 val is_Label_def = Define `

(is_Label (Label _) = T)
/\
(is_Label _ = F)`;


 val bc_fetch_aux_defn = Hol_defn "bc_fetch_aux" `

(bc_fetch_aux [] _ _ = NONE)
/\
(bc_fetch_aux (x::xs) len n =  
(if is_Label x then bc_fetch_aux xs len n else
    if n = 0 then SOME x else
      if n < len x + 1 then NONE else
        bc_fetch_aux xs len (n - (len x + 1))))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn bc_fetch_aux_defn;

val _ = Define `
 (bc_fetch s = ( bc_fetch_aux s.code s.inst_length s.pc))`;


(* most instructions just bump the pc along, for this we use bump_pc *)

val _ = Define `
 (bump_pc s = ((case bc_fetch s of
  NONE => s
| SOME x => ( s with<| pc := s.pc + s.inst_length x + 1 |>)
)))`;


(* finding the address of a location *)
 val bc_find_loc_aux_defn = Hol_defn "bc_find_loc_aux" `

(bc_find_loc_aux [] _ _ _ = NONE)
/\
(bc_find_loc_aux (x::xs) len l n =  
(if x = Label l then SOME n else
    bc_find_loc_aux xs len l (n + (if is_Label x then 0 else len x + 1))))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn bc_find_loc_aux_defn;

 val bc_find_loc_def = Define `

(bc_find_loc _ (Addr n) = (SOME n))
/\
(bc_find_loc s (Lab l) = ( bc_find_loc_aux s.code s.inst_length l 0))`;


(*val bv_to_ov : list (num * option (id conN)) -> bc_value -> ov*)
 val bv_to_ov_defn = Hol_defn "bv_to_ov" `

(bv_to_ov _ (Number i) = (OLit (IntLit i)))
/\
(bv_to_ov m (Block n vs) =  
(if n = (bool_to_tag F) then OLit (Bool F) else
  if n = (bool_to_tag T) then OLit (Bool T) else
  if n = unit_tag then OLit Unit else
  if n = closure_tag then OFn else
  OConv (the NONE (Lib$lookup (n - block_tag) m)) ( MAP (bv_to_ov m) vs)))
/\
(bv_to_ov _ (RefPtr n) = (OLoc n))
/\
(bv_to_ov _ _ = OError)`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn bv_to_ov_defn;

(* next state relation *)

val _ = Hol_reln `
(! x xs. T ==>
bc_stack_op Pop (x ::xs) (xs))
/\
(! x ys xs. T ==>
bc_stack_op (Pops ( LENGTH ys)) (x ::ys ++xs) (x ::xs))
/\
(! ys zs xs. T ==>
bc_stack_op (Shift ( LENGTH ys) ( LENGTH zs)) (ys ++(zs ++xs)) (ys ++xs))
/\
(! n xs. T ==>
bc_stack_op (PushInt n) (xs) (Number n ::xs))
/\
(! tag ys xs. T ==>
bc_stack_op (Cons tag ( LENGTH ys)) (ys ++xs) (Block tag ( REVERSE ys) ::xs))
/\
(! k xs. (k < LENGTH xs) ==>
bc_stack_op (Load k) xs ( EL  k  xs ::xs))
/\
(! y ys x xs. T ==>
bc_stack_op (Store ( LENGTH ys)) (y ::ys ++x ::xs) (ys ++y ::xs))
/\
(! k xs. (k < LENGTH xs) ==>
bc_stack_op (LoadRev k) xs ( EL  k  ( REVERSE xs) ::xs))
/\
(! k tag ys xs. (k < LENGTH ys) ==>
bc_stack_op (El k) ((Block tag ys) ::xs) ( EL  k  ys ::xs))
/\
(! t tag ys xs. T ==>
bc_stack_op (TagEq t) ((Block tag ys) ::xs) (bool_to_val (tag = t) ::xs))
/\
(! x xs. (! n. ~  (x = CodePtr n) /\ ~  (x = StackPtr n)) ==>
bc_stack_op IsBlock (x ::xs) ((bool_to_val (is_Block x)) ::xs))
/\
(! x2 x1 xs. ( ~  (bc_equal x1 x2 = Eq_type_error)) ==>
bc_stack_op Equal (x2 ::x1 ::xs) (bc_equality_result_to_val (bc_equal x1 x2) ::xs))
/\
(! n m xs. T ==>
bc_stack_op Less (Number n ::Number m ::xs) (bool_to_val ( int_lt m n) ::xs))
/\
(! n m xs. T ==>
bc_stack_op Add  (Number n ::Number m ::xs) (Number ( int_add m n) ::xs))
/\
(! n m xs. T ==>
bc_stack_op Sub  (Number n ::Number m ::xs) (Number ( (int_sub) m n) ::xs))
/\
(! n m xs. T ==>
bc_stack_op Mult (Number n ::Number m ::xs) (Number ( int_mul m n) ::xs))
/\
(! n m xs. ( ~  (n = & 0)) ==>
bc_stack_op Div  (Number n ::Number m ::xs) (Number ( int_div m n) ::xs))
/\
(! n m xs. ( ~  (n = & 0)) ==>
bc_stack_op Mod  (Number n ::Number m ::xs) (Number ( int_mod m n) ::xs))`;

val _ = Hol_reln `
(! s b ys.
((
bc_fetch s = SOME (Stack b)) /\ bc_stack_op b (s.stack) ys)
==>
bc_next s ((bump_pc s with<| stack := ys|>))) (* parens throughout: lem sucks *)
/\
(! s l n.
((bc_fetch s = SOME (Jump l)) /\ (bc_find_loc s l = SOME n))
==>
bc_next s ((s with<| pc := n|>)))
/\
(! s l n b xs s'.
((
bc_fetch s = SOME (JumpIf l)) /\ (bc_find_loc s l = SOME n) /\ (s.stack = (bool_to_val b) ::xs) /\ (s' = ((s with<| stack := xs|>))))
==>
bc_next s (if b then (s' with<| pc := n|>) else bump_pc s'))
/\
(! s l n x xs.
((
bc_fetch s = SOME (Call l)) /\ (bc_find_loc s l = SOME n) /\ (s.stack = x ::xs))
==>
bc_next s ((s with<| pc := n; stack := x ::CodePtr ((bump_pc s).pc) ::xs|>)))
/\
(! s ptr x xs.
((
bc_fetch s = SOME CallPtr) /\ (s.stack = CodePtr ptr ::x ::xs))
==>
bc_next s ((s with<| pc := ptr; stack := x ::CodePtr ((bump_pc s).pc) ::xs|>)))
/\
(! s l n.
((
bc_fetch s = SOME (PushPtr l)) /\ (bc_find_loc s l = SOME n))
==>
bc_next s ((bump_pc s with<| stack := (CodePtr n) ::s.stack |>)))
/\
(! s x n xs.
((
bc_fetch s = SOME Return) /\ (s.stack = x ::CodePtr n ::xs))
==>
bc_next s ((s with<| pc := n; stack := x ::xs|>)))
/\
(! s.
(bc_fetch s = SOME PushExc) (* parens: Lem sucks *)
==>
bc_next s ((bump_pc s with<|
               handler := LENGTH s.stack ;
               stack := (StackPtr s.handler) ::s.stack|>)))
/\
(! s sp x l1 l2.
((
bc_fetch s = SOME PopExc) /\
(s.stack = x ::l1 ++ StackPtr sp ::l2) /\ ( LENGTH l2 = s.handler))
==>
bc_next s ((bump_pc s with<| handler := sp; stack := x ::l2|>)))
/\
(! s x xs ptr.
((
bc_fetch s = SOME Ref) /\ (s.stack = x ::xs) /\ (ptr = $LEAST (\ ptr . ~  ( ptr IN FDOM  s.refs))))
==>
bc_next s ((bump_pc s with<| stack := (RefPtr ptr) ::xs; refs := FUPDATE  s.refs ( ptr, x)|>)))
/\
(! s ptr xs.
((
bc_fetch s = SOME Deref) /\ (s.stack = (RefPtr ptr) ::xs) /\  ptr IN FDOM  s.refs)
==>
bc_next s ((bump_pc s with<| stack := FAPPLY  s.refs  ptr ::xs|>)))
/\
(! s x ptr xs.
((
bc_fetch s = SOME Update) /\ (s.stack = x ::(RefPtr ptr) ::xs) /\  ptr IN FDOM  s.refs)
==>
bc_next s ((bump_pc s with<| stack := xs; refs := FUPDATE  s.refs ( ptr, x)|>)))
/\
(! s.
((
bc_fetch s = SOME Tick) /\ (! n. (s.clock = SOME n) ==> n > 0))
==>
bc_next s ((bump_pc s with<| clock := OPTION_MAP PRE s.clock|>)))
/\
(! s x xs.
((
bc_fetch s = SOME Print) /\ (s.stack = x ::xs))
==>
bc_next s ((bump_pc s with<| stack := xs;
  output := CONCAT [s.output;ov_to_string (bv_to_ov s.cons_names x)]|>)))
/\
(! s c.
(
bc_fetch s = SOME (PrintC c))
==>
bc_next s ((bump_pc s with<| output := SNOC c s.output|>)))`;
val _ = export_theory()

