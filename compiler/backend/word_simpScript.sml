open preamble wordLangTheory sptreeTheory asmSemTheory;

val _ = new_theory "word_simp";

(* function that makes all Seq associate to the left *)

val SmartSeq_def = Define `
  SmartSeq p1 (p2:'a wordLang$prog) =
    if p1 = Skip then p2 else Seq p1 p2`

val Seq_assoc_def = Define `
  (Seq_assoc p1 Skip = p1) /\
  (Seq_assoc p1 (Seq q1 q2) = Seq_assoc (Seq_assoc p1 q1) q2) /\
  (Seq_assoc p1 (If v n r q1 q2) =
     SmartSeq p1 (If v n r (Seq_assoc Skip q1) (Seq_assoc Skip q2))) /\
  (Seq_assoc p1 (MustTerminate n q) =
     SmartSeq p1 (MustTerminate n (Seq_assoc Skip q))) /\
  (Seq_assoc p1 (Call ret_prog dest args handler) =
     SmartSeq p1 (Call (case ret_prog of
           | NONE => NONE
           | SOME (x1,x2,q1,x3,x4) => SOME (x1,x2,Seq_assoc Skip q1,x3,x4))
       dest args
          (case handler of
           | NONE => NONE
           | SOME (y1,q2,y2,y3) => SOME (y1,Seq_assoc Skip q2,y2,y3)))) /\
  (Seq_assoc p1 other = SmartSeq p1 other)`;

val Seq_assoc_ind = fetch "-" "Seq_assoc_ind";

(* optimise certain consequtive If statements that arise from data-to-word

   If something (q1 ; n := X) (q2 ; n := Y) ;
   If (n == Z) p1 p2

   --> (in case X <> Y and Z == X)

   If something (q1 ; n := X ; p1) (q2 ; n := Y ; p2) ;

   similarly if Z == Y and X <> Y

*)

val dest_Seq_def = Define `
  (dest_Seq (Seq p1 p2) = (p1,p2:'a wordLang$prog)) /\
  (dest_Seq p = (Skip,p))`

val dest_If_def = Define `
  (dest_If (If x1 x2 x3 p1 p2) = SOME (x1,x2,x3,p1,p2:'a wordLang$prog)) /\
  (dest_If _ = NONE)`

val dest_If_Eq_Imm_def = Define `
  dest_If_Eq_Imm p =
    case dest_If p of
    | SOME (Equal,n,Imm w,p1,p2) => SOME (n,w,p1,p2)
    | _ => NONE`

val dest_Seq_Assign_Const_def = Define `
  dest_Seq_Assign_Const n p =
    let (p1,p2) = dest_Seq p in
      case p2 of
      | Assign m (Const w) => if m = n then SOME (p1,w) else NONE
      | _ => NONE`

val apply_if_opt_def = Define `
  apply_if_opt x1 x2 =
    case dest_If_Eq_Imm x2 of
    | NONE => NONE
    | SOME (v,w,p1,p2) =>
       let (x0,x1) = dest_Seq x1 in
         case dest_If x1 of
         | NONE => NONE
         | SOME (x1,x2,x3,q1,q2) =>
         case dest_Seq_Assign_Const v q1 of
         | NONE => NONE
         | SOME (_,w1) =>
         case dest_Seq_Assign_Const v q2 of
         | NONE => NONE
         | SOME (_,w2) =>
            if w1 = w2 then NONE
            else if w1 = w then
              SOME (SmartSeq x0 (If x1 x2 x3 (Seq q1 p1) (Seq q2 p2)))
            else if w2 = w then
              SOME (SmartSeq x0 (If x1 x2 x3 (Seq q1 p2) (Seq q2 p1)))
            else NONE`

val simp_if_def = tDefine "simp_if" `
  (simp_if (Seq x1 x2) =
     let y1 = simp_if x1 in
     let y2 = simp_if x2 in
       case apply_if_opt y1 y2 of
       | NONE => Seq y1 y2
       | SOME p => p) /\
  (simp_if (If v n r q1 q2) = If v n r (simp_if q1) (simp_if q2)) /\
  (simp_if (MustTerminate n q) = MustTerminate n (simp_if q)) /\
  (simp_if (Call ret_prog dest args handler) =
     Call (case ret_prog of
           | NONE => NONE
           | SOME (x1,x2,q1,x3,x4) => SOME (x1,x2,simp_if q1,x3,x4))
       dest args
          (case handler of
           | NONE => NONE
           | SOME (y1,q2,y2,y3) => SOME (y1,simp_if q2,y2,y3))) /\
  (simp_if x = x)`
  (WF_REL_TAC `measure (wordLang$prog_size (K 0))` \\ rw [])

val simp_if_ind = fetch "-" "simp_if_ind"

(* Constant folding and propagation optimization, e.g.

   x := 1;
   y := x + 4;
   z := y;

   becomes

   x := 1;
   y := 5;
   z := 5;

  Limitation: The current implementation forgets all constant values after a
  function call with a handler (for easier implementation and proofs). This is
  probably not difficult to improve, but would require some kind of theorem
  saying that a program does not change variables not mentioned in the program
  (because we cannot know beforehand/statically if the handler code is going to
  run, so we must throw away all variables mentioned in the handler).
 *)

val strip_const_def = Define `
  (strip_const [] = SOME []) /\
  (strip_const (Const w::cs) =
     case strip_const cs of
       | SOME ws => SOME (w::ws)
       | _ => NONE) /\
  (strip_const _ = NONE)`;

val const_fp_exp_def = tDefine "const_fp_exp" `
  (const_fp_exp (Var v) cs =
     case lookup v cs of
       | SOME x => Const x
       | NONE => Var v) /\
  (const_fp_exp (Op op args) cs =
     let const_fp_args = MAP (\a. const_fp_exp a cs) args in
       case strip_const const_fp_args of
         | SOME ws => (case word_op op ws of
			| SOME w => Const w
		        | _ => Op op (MAP Const ws))
         | _ => Op op const_fp_args) /\
  (const_fp_exp (Shift sh e ne) cs =
     let const_fp_exp_e = const_fp_exp e cs in
       case const_fp_exp_e of
         | Const c => (case word_sh sh c (num_exp ne) of
                        | SOME w => Const w
                        | _ => Shift sh (Const c) ne)
         | _ => Shift sh e ne) /\
  (const_fp_exp e _ = e)`

  (WF_REL_TAC `measure (exp_size (\x.0) o FST)` \\ conj_tac
  >- (Induct \\ fs [exp_size_def] \\ rw [] \\ fs [] \\ res_tac \\ fs [])
  >- (rw []));

val const_fp_exp_ind = fetch "-" "const_fp_exp_ind";

val const_fp_move_cs_def = Define `
  (const_fp_move_cs [] _ cs = cs) /\
  (const_fp_move_cs (m::ms) ocs ncs =
    let v = FST m in
    let nncs =
      (case lookup (SND m) ocs of
        | SOME c => insert v c ncs
        | _ => delete v ncs) in
        const_fp_move_cs ms ocs nncs)`;

val const_fp_inst_cs_def = Define `
  (const_fp_inst_cs (Const r _) cs = delete r cs) /\
  (const_fp_inst_cs (Arith (Binop _ r _ _)) cs = delete r cs) /\
  (const_fp_inst_cs (Arith (Shift _ r _ _)) cs = delete r cs) /\
  (const_fp_inst_cs (Arith (AddCarry r1 _ _ r2)) cs = delete r2 (delete r1 cs)) /\
  (const_fp_inst_cs (Arith (LongMul r1 r2 _ _)) cs = delete r1 (delete r2 cs)) /\
  (const_fp_inst_cs (Arith (LongDiv r1 r2 _ _ _)) cs = delete r1 (delete r2 cs)) /\
  (const_fp_inst_cs (Mem Load r _) cs = delete r cs) /\
  (const_fp_inst_cs (Mem Load8 r _) cs = delete r cs) /\
  (const_fp_inst_cs _ cs = cs)`;

val get_var_imm_cs_def = Define `
  (get_var_imm_cs (Reg r) cs = lookup r cs) /\
  (get_var_imm_cs (Imm i) _ = SOME i)`;

val is_gc_const_def = Define `is_gc_const c = ((c && 1w) = 0w)`

val const_fp_loop_def = Define `
  (const_fp_loop (Move pri moves) cs = (Move pri moves, const_fp_move_cs moves cs cs)) /\
  (const_fp_loop (Inst i) cs = (Inst i, const_fp_inst_cs i cs)) /\
  (const_fp_loop (Assign v e) cs =
     let const_fp_e = const_fp_exp e cs in
       case const_fp_e of
         | Const c => (Assign v const_fp_e, insert v c cs)
         | _ => (Assign v const_fp_e, delete v cs)) /\
  (const_fp_loop (Get v name) cs = (Get v name, delete v cs)) /\
  (const_fp_loop (MustTerminate n p) cs =
    let (p', cs') = const_fp_loop p cs in
      (MustTerminate n p', cs')) /\
  (const_fp_loop (Seq p1 p2) cs =
    let (p1', cs') = const_fp_loop p1 cs in
    let (p2', cs'') = const_fp_loop p2 cs' in
      (Seq p1' p2', cs'')) /\
  (const_fp_loop (wordLang$If cmp lhs rhs p1 p2) cs =
    case (lookup lhs cs, get_var_imm_cs rhs cs) of
      | (SOME clhs, SOME crhs) =>
        (if word_cmp cmp clhs crhs then const_fp_loop p1 cs else const_fp_loop p2 cs)
      | _ => (let (p1', p1cs) = const_fp_loop p1 cs in
              let (p2', p2cs) = const_fp_loop p2 cs in
              (wordLang$If cmp lhs rhs p1' p2', inter_eq p1cs p2cs))) /\
  (const_fp_loop (Call ret dest args handler) cs =
    case ret of
      | NONE => (Call ret dest args handler, filter_v is_gc_const cs)
      | SOME (n, names, ret_handler, l1, l2) =>
        (if handler = NONE then
           (let cs' = delete n (filter_v is_gc_const (inter cs names)) in
            let (ret_handler', cs'') = const_fp_loop ret_handler cs' in
            (Call (SOME (n, names, ret_handler', l1, l2)) dest args handler, cs''))
         else
           (Call ret dest args handler, LN))) /\
  (const_fp_loop (FFI x0 x1 x2 names) cs = (FFI x0 x1 x2 names, inter cs names)) /\
  (const_fp_loop (LocValue v x0) cs = (LocValue v x0, delete v cs)) /\
  (const_fp_loop (Alloc n names) cs = (Alloc n names, filter_v is_gc_const (inter cs names))) /\
  (const_fp_loop p cs = (p, cs))`;

val const_fp_loop_ind = fetch "-" "const_fp_loop_ind";

val const_fp_def = Define `
  const_fp p = FST (const_fp_loop p LN)`;

(* all of them together *)

val compile_exp_def = Define `
  compile_exp (e:'a wordLang$prog) =
    let e = Seq_assoc Skip e in
    let e = simp_if e in
    let e = const_fp e in
      e`;

val _ = export_theory();
