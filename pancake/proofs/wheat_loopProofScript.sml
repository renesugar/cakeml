(*
  Correctness proof for wheat_loop
*)

open preamble wheatLangTheory wheatSemTheory
local open wordSemTheory in end

val _ = new_theory"wheat_loopProof";

val _ = set_grammar_ancestry ["wheatSem"];

Definition every_prog_def:
  (every_prog p (Seq p1 p2) <=>
    p (Seq p1 p2) /\ every_prog p p1 /\ every_prog p p2) /\
  (every_prog p (Loop l1 body l2) <=>
    p (Loop l1 body l2) /\ every_prog p body) /\
  (every_prog p (If x1 x2 x3 p1 p2 l1) <=>
    p (If x1 x2 x3 p1 p2 l1) /\ every_prog p p1 /\ every_prog p p2) /\
  (every_prog p (Mark p1) <=>
    p (Mark p1) /\ every_prog p p1) /\
  (every_prog p (Call ret dest args handler l) <=>
    p (Call ret dest args handler l) /\
    (case handler of SOME (n,q) => every_prog p q | NONE => T)) /\
  (every_prog p prog <=> p prog)
End

Definition no_Loop_def:
  no_Loop = every_prog (\q. !l1 x l2. q <> Loop l1 x l2)
End

Definition syntax_ok_def:
  (syntax_ok (Seq p1 p2) <=>
    ~(no_Loop (Seq p1 p2)) ∧ syntax_ok p1 /\ syntax_ok p2) /\
  (syntax_ok (Loop l1 body l2) <=>
    syntax_ok body) /\
  (syntax_ok (If x1 x2 x3 p1 p2 l1) <=>
    ~(no_Loop (If x1 x2 x3 p1 p2 l1)) ∧ syntax_ok p1 /\ syntax_ok p2) /\
  (syntax_ok (Mark p1) <=>
    no_Loop p1) /\
  (syntax_ok (Call ret dest args handler l) <=>
    ~(no_Loop (Call ret dest args handler l)) ∧
    (case handler of SOME (n,q) => syntax_ok q | NONE => F)) /\
  (syntax_ok prog <=> F)
End

Definition mark_all_def:
  (mark_all (Seq p1 p2) =
     let (p1,t1) = mark_all p1 in
     let (p2,t2) = mark_all p2 in
     let t3 = (t1 /\ t2) in
       (if t3 then Mark (Seq p1 p2) else Seq p1 p2, t3)) /\
  (mark_all (Loop l1 body l2) =
     let (body,t1) = mark_all body in
       (Loop l1 body l2, F)) /\
  (mark_all (If x1 x2 x3 p1 p2 l1) =
     let (p1,t1) = mark_all p1 in
     let (p2,t2) = mark_all p2 in
     let p3 = If x1 x2 x3 p1 p2 l1 in
     let t3 = (t1 /\ t2) in
       (if t3 then Mark p3 else p3, t3)) /\
  (mark_all (Mark p1) = mark_all p1) /\
  (mark_all (Call ret dest args handler l) =
     case handler of
     | NONE => (Mark (Call ret dest args handler l), T)
     | SOME (n,p1) =>
         let (p1,t1) = mark_all p1 in
         let p2 = Call ret dest args (SOME (n,p1)) l in
           (if t1 then Mark p2 else p2, t1)) /\
  (mark_all prog = (Mark prog,T))
End

Theorem evaluate_Loop_body_same:
  (∀(s:('a,'b)state). evaluate (body,s) = evaluate (body',s)) ⇒
  ∀(s:('a,'b)state). evaluate (Loop l1 body l2,s) = evaluate (Loop l1 body' l2,s)
Proof
  rw [] \\ completeInduct_on ‘s.clock’
  \\ rw [] \\ fs [PULL_EXISTS,PULL_FORALL]
  \\ once_rewrite_tac [evaluate_def]
  \\ CASE_TAC \\ fs []
  \\ pairarg_tac \\ fs []
  \\ rw [] \\ fs []
  \\ fs [cut_state_def] \\ rveq
  \\ first_x_assum (qspec_then ‘dec_clock s1’ mp_tac)
  \\ imp_res_tac evaluate_clock \\ fs [dec_clock_def]
QED

Theorem mark_all_syntax_ok:
  ∀prog q b.
     mark_all prog = (q,b) ==>
     b = no_Loop q ∧ syntax_ok q
Proof
  recInduct mark_all_ind \\ rpt conj_tac
  \\ rpt gen_tac \\ strip_tac
  THEN1
   (fs [mark_all_def]
    \\ rpt (pairarg_tac \\ fs []) \\ rveq
    \\ IF_CASES_TAC
    \\ fs [evaluate_def,every_prog_def,no_Loop_def,syntax_ok_def])
  THEN1
   (fs [mark_all_def]
    \\ rpt (pairarg_tac \\ fs []) \\ rveq
    \\ fs [every_prog_def,no_Loop_def,syntax_ok_def])
  THEN1
   (fs [mark_all_def]
    \\ rpt (pairarg_tac \\ fs []) \\ rveq
    \\ IF_CASES_TAC \\ fs []
    \\ fs [no_Loop_def,every_prog_def,syntax_ok_def])
  THEN1 fs [mark_all_def,syntax_ok_def]
  THEN1
   (fs [mark_all_def] \\ rveq
    \\ every_case_tac \\ fs []
    \\ fs [no_Loop_def,every_prog_def,syntax_ok_def]
    \\ rpt (pairarg_tac \\ fs []) \\ rveq
    \\ IF_CASES_TAC \\ fs []
    \\ fs [every_prog_def,syntax_ok_def,no_Loop_def])
  \\ fs [mark_all_def] \\ rveq
  \\ fs [every_prog_def,no_Loop_def,syntax_ok_def]
QED

Theorem mark_all_evaluate:
  ∀prog q b.
     mark_all prog = (q,b) ==>
     ∀s. evaluate (prog,s) = evaluate (q,s)
Proof
  recInduct mark_all_ind \\ rpt conj_tac
  \\ rpt gen_tac \\ strip_tac
  THEN1
   (fs [mark_all_def]
    \\ rpt (pairarg_tac \\ fs []) \\ rveq
    \\ IF_CASES_TAC \\ fs [evaluate_def])
  THEN1
   (fs [mark_all_def]
    \\ rpt (pairarg_tac \\ fs []) \\ rveq
    \\ match_mp_tac evaluate_Loop_body_same \\ fs [])
  THEN1
   (fs [mark_all_def]
    \\ rpt (pairarg_tac \\ fs []) \\ rveq
    \\ IF_CASES_TAC \\ fs []
    \\ fs [every_prog_def,evaluate_def]
    \\ fs [no_Loop_def,every_prog_def]
    \\ rw [] \\ every_case_tac \\ fs [])
  THEN1 fs [mark_all_def,evaluate_def]
  THEN1
   (fs [mark_all_def] \\ rveq
    \\ every_case_tac \\ fs []
    \\ fs [no_Loop_def,every_prog_def,evaluate_def]
    \\ rpt (pairarg_tac \\ fs []) \\ rveq
    \\ IF_CASES_TAC \\ fs []
    \\ fs [every_prog_def,evaluate_def])
  \\ fs [mark_all_def] \\ rveq
  \\ simp [evaluate_def]
  \\ fs [every_prog_def,no_Loop_def]
QED

Definition comp_no_loop_def:
  (comp_no_loop p (Seq p1 p2) =
    Seq (comp_no_loop p p1) (comp_no_loop p p2)) /\
  (comp_no_loop p (If x1 x2 x3 p1 p2 l1) =
    If x1 x2 x3 (comp_no_loop p p1) (comp_no_loop p p2) l1) /\
  (comp_no_loop p (Call ret dest args handler l) =
    Call ret dest args (case handler of
                        | SOME (n,q) => SOME (n,comp_no_loop p q)
                        | NONE => NONE) l) /\
  (comp_no_loop p Break = FST p) /\
  (comp_no_loop p Continue = SND p) /\
  (comp_no_loop p (Mark prog) = comp_no_loop p prog) /\
  (comp_no_loop p prog = prog)
End

Definition store_cont_def:
  store_cont live code (n,funs) =
    let params = MAP FST (toSortedAList live) in
    let funs = (n,params,code) :: funs in
    let cont = Call NONE (SOME n) params NONE LN in
      (cont:'a wheatLang$prog, (n+1,funs))
End

Definition comp_with_loop_def:
  (comp_with_loop p (Seq p1 p2) cont s =
     let (q2,s) = comp_with_loop p p2 cont s in
       comp_with_loop p p1 q2 s) ∧
  (comp_with_loop p (If x1 x2 x3 p1 p2 l1) cont s =
     let (cont,s) = store_cont l1 cont s in
     let (q1,s) = comp_with_loop p p1 cont s in
     let (q2,s) = comp_with_loop p p2 cont s in
       (If x1 x2 x3 q1 q2 LN,s)) /\
  (comp_with_loop p (Call ret dest args handler l) cont s =
     case handler of
     | NONE => (Seq (Call ret dest args NONE l) cont,s)
     | SOME (n,q) =>
         let (cont,s) = store_cont l cont s in
         let (q,s) = comp_with_loop p q cont s in
           (Seq (Call ret dest args (SOME (n,q)) l) cont,s)) /\
  (comp_with_loop p Break cont s = (FST p,s)) /\
  (comp_with_loop p Continue cons s = (SND p,s)) /\
  (comp_with_loop p (Mark prog) cont s = (Seq (comp_no_loop p prog) cont,s)) /\
  (comp_with_loop p (Loop live_in body live_out) cont s =
     let (cont,s) = store_cont live_out cont s in
     let params = MAP FST (toSortedAList live_in) in
     let enter = Call NONE (SOME (FST s)) params NONE LN in
     let (body,n,funs) = comp_with_loop (cont,enter) body Skip s in
     let funs = (n,params,body) :: funs in
       (enter,(n+1,funs))) ∧
  (comp_with_loop p prog cont s = (Skip,s)) (* impossible case *)
End

Definition comp_def:
  comp (name,params,prog) s =
    let (body,n,funs) = comp_with_loop (Fail,Fail) prog Fail s in
      (n,(name,params,body)::funs)
End

Definition comp_all_def:
  comp_all code =
    let n = FOLDR MAX 0 (MAP FST code) + 1 in
      SND (FOLDR comp (n,[]) code)
End

Definition has_code_def:
  has_code (n,funs) code =
    EVERY (\(n,p,b). lookup n code = SOME (p,b)) funs
End

Definition state_rel_def:
  state_rel s t <=>
    ∃c. t = s with code := c ∧
        ∀n params body.
          lookup n s.code = SOME (params, body) ⇒
          syntax_ok body ∧
          ∃init. has_code (comp (n,params,body) init) t.code
End

Definition break_ok_def:
  break_ok Fail = T ∧
  break_ok (Call NONE _ _ _ _) = T ∧
  break_ok _ = F
End

Definition breaks_ok_def:
  breaks_ok (p,q) <=> break_ok p ∧ break_ok q
End

val goal =
  ``λ(prog, s). ∀res s1 t p.
    evaluate (prog,s) = (res,s1) ∧ state_rel s t ∧ res ≠ SOME Error ∧
    breaks_ok p ⇒
    (syntax_ok prog ⇒
      ∀cont s q s'.
        comp_with_loop p prog cont s = (q,s') ∧
        has_code s' t.code ⇒
        ∃t1.
         (let result = evaluate (q,t) in
            state_rel s1 t1 ∧ t1.code = t.code ∧
            case res of
            | NONE => result = evaluate (cont,t1)
            | SOME Break => result = evaluate (FST p,t1)
            | SOME Continue => result = evaluate (SND p,t1)
            | _ => result = (res,t1))) ∧
    (no_Loop prog ⇒
        ∃t1.
         (let result = evaluate (comp_no_loop p prog,t) in
            state_rel s1 t1 ∧ t1.code = t.code ∧
            case res of
            | SOME Continue => result = evaluate (SND p,t1)
            | SOME Break => result = evaluate (FST p,t1)
            | _ => result = (res,t1)))``

local
  val ind_thm = wheatSemTheory.evaluate_ind
    |> ISPEC goal
    |> CONV_RULE (DEPTH_CONV PairRules.PBETA_CONV) |> REWRITE_RULE [];
  fun list_dest_conj tm = if not (is_conj tm) then [tm] else let
    val (c1,c2) = dest_conj tm in list_dest_conj c1 @ list_dest_conj c2 end
  val ind_goals = ind_thm |> concl |> dest_imp |> fst |> list_dest_conj
in
  fun get_goal s = first (can (find_term (can (match_term (Term [QUOTE s]))))) ind_goals
  fun compile_correct_tm () = ind_thm |> concl |> rand
  fun the_ind_thm () = ind_thm
end

Theorem compile_Skip:
  ^(get_goal "wheatLang$Skip") ∧
  ^(get_goal "wheatLang$Fail") ∧
  ^(get_goal "wheatLang$Tick")
Proof
  fs [syntax_ok_def,comp_no_loop_def,evaluate_def]
  \\ rw [] \\ fs []
  \\ fs [state_rel_def,call_env_def,dec_clock_def]
  \\ rveq \\ fs [state_component_equality]
  \\ rw [] \\ res_tac
QED

Theorem compile_Continue:
  ^(get_goal "wheatLang$Continue") ∧
  ^(get_goal "wheatLang$Break")
Proof
  fs [syntax_ok_def,comp_no_loop_def,evaluate_def]
  \\ rw [] \\ fs []
  \\ asm_exists_tac \\ fs []
QED

Theorem evaluate_break_ok:
  evaluate (qq,t1) = (res,r') ∧ break_ok qq ⇒ res ≠ NONE
Proof
  Cases_on ‘qq’ \\ fs [break_ok_def] \\ rw [] \\ fs []
  \\ fs [evaluate_def] \\ rveq \\ fs []
  \\ Cases_on ‘o1’ \\ fs [break_ok_def]
  \\ fs [CaseEq"option",pair_case_eq,CaseEq"bool"]
  \\ rveq \\ fs []
QED

Theorem compile_Mark:
  ^(get_goal "syntax_ok (Mark _)")
Proof
  simp_tac std_ss [evaluate_def,syntax_ok_def]
  \\ full_simp_tac std_ss [no_Loop_def,every_prog_def]
  \\ full_simp_tac std_ss [GSYM no_Loop_def,comp_with_loop_def]
  \\ rw [] \\ fs []
  \\ first_x_assum drule
  \\ disch_then drule \\ strip_tac
  \\ asm_exists_tac \\ fs []
  \\ Cases_on ‘res’ \\ fs [evaluate_def,comp_no_loop_def]
  \\ Cases_on ‘x’ \\ fs [evaluate_def,comp_no_loop_def]
  \\ Cases_on ‘p'’ \\ fs []
  \\ rename [‘_ = evaluate (qq,_)’]
  \\ fs [breaks_ok_def]
  \\ Cases_on ‘evaluate (qq,t1)’ \\ fs [] \\ rw []
  \\ imp_res_tac evaluate_break_ok \\ fs []
QED

Theorem compile_Return:
  ^(get_goal "wheatLang$Return") ∧
  ^(get_goal "wheatLang$Raise")
Proof
  fs [syntax_ok_def,comp_no_loop_def,evaluate_def]
  \\ rw [] \\ fs [CaseEq"option"] \\ rveq \\ fs []
  \\ fs [state_rel_def,call_env_def,state_component_equality]
  \\ metis_tac []
QED

Theorem comp_with_loop_has_code:
  ∀p prog cont s0 q s1 code.
     comp_with_loop p prog cont s0 = (q,s1) ∧ has_code s1 code ⇒ has_code s0 code
Proof
  ho_match_mp_tac comp_with_loop_ind \\ rpt strip_tac
  \\ fs [comp_with_loop_def] \\ fs []
  \\ rpt (pairarg_tac \\ fs []) \\ rveq \\ fs []
  \\ res_tac \\ fs []
  \\ res_tac \\ fs []
  \\ Cases_on ‘s0’
  \\ fs [store_cont_def]
  \\ rveq \\ fs [] \\ fs [has_code_def]
  \\ fs [CaseEq"option",pair_case_eq]
  \\ rveq \\ fs []
  \\ fs [has_code_def]
  \\ pairarg_tac \\ fs []
QED

Theorem compile_Loop:
  ^(get_goal "wheatLang$Loop")
Proof
  cheat
QED

Theorem compile_Call:
  ^(get_goal "syntax_ok (wheatLang$Call _ _ _ _ _)")
Proof
  cheat
QED

Theorem compile_If:
  ^(get_goal "wheatLang$If")
Proof
  cheat
QED

Theorem compile_Seq:
  ^(get_goal "syntax_ok (wheatLang$Seq _ _)")
Proof
  reverse (rpt strip_tac)
  THEN1
   (fs [comp_no_loop_def,no_Loop_def,every_prog_def]
    \\ fs [GSYM no_Loop_def]
    \\ qpat_x_assum ‘evaluate _ = _’ mp_tac
    \\ simp [Once evaluate_def]
    \\ pairarg_tac \\ fs []
    \\ reverse IF_CASES_TAC
    THEN1
     (strip_tac \\ fs [] \\ rveq \\ fs []
      \\ first_x_assum drule
      \\ disch_then drule
      \\ strip_tac \\ asm_exists_tac \\ fs []
      \\ Cases_on ‘res’ \\ fs []
      \\ Cases_on ‘x’ \\ fs [evaluate_def]
      \\ Cases_on ‘p’ \\ fs []
      \\ rename [‘_ = evaluate (qq,_)’]
      \\ fs [breaks_ok_def]
      \\ Cases_on ‘evaluate (qq,t1)’ \\ fs [] \\ rw []
      \\ imp_res_tac evaluate_break_ok \\ fs [])
    \\ rveq \\ fs [] \\ strip_tac \\ fs []
    \\ first_x_assum drule
    \\ disch_then drule \\ strip_tac
    \\ first_x_assum drule
    \\ disch_then drule \\ strip_tac
    \\ asm_exists_tac \\ fs []
    \\ Cases_on ‘res’ \\ fs [evaluate_def])
  \\ fs [syntax_ok_def]
  \\ qpat_x_assum ‘evaluate _ = _’ mp_tac
  \\ simp [Once evaluate_def]
  \\ pairarg_tac \\ fs []
  \\ reverse IF_CASES_TAC
  THEN1
   (strip_tac \\ fs [] \\ rveq \\ fs []
    \\ first_x_assum drule
    \\ disch_then drule
    \\ strip_tac \\ pop_assum kall_tac
    \\ fs [comp_with_loop_def]
    \\ pairarg_tac \\ fs []
    \\ first_x_assum drule \\ fs []
    \\ strip_tac
    \\ asm_exists_tac \\ fs []
    \\ Cases_on ‘res’ \\ fs [])
  \\ rveq \\ fs [] \\ strip_tac \\ fs []
  \\ fs [comp_with_loop_def]
  \\ pairarg_tac \\ fs []
  \\ first_x_assum drule
  \\ disch_then drule
  \\ strip_tac \\ pop_assum kall_tac
  \\ first_x_assum drule \\ simp []
  \\ strip_tac
  \\ first_x_assum drule
  \\ disch_then drule
  \\ strip_tac \\ pop_assum kall_tac
  \\ first_x_assum drule
  \\ imp_res_tac comp_with_loop_has_code \\ fs []
QED

Theorem compile_Assign:
  ^(get_goal "wheatLang$Assign") ∧
  ^(get_goal "wheatLang$LocValue")
Proof
  cheat
QED

Theorem compile_Store:
  ^(get_goal "wheatLang$Store") ∧
  ^(get_goal "wheatLang$LoadByte")
Proof
  cheat
QED

Theorem compile_StoreGlob:
  ^(get_goal "wheatLang$StoreGlob") ∧
  ^(get_goal "wheatLang$LoadGlob")
Proof
  cheat
QED

Theorem compile_FFI:
  ^(get_goal "wheatLang$FFI")
Proof
  cheat
QED

Theorem compile_correct:
  ^(compile_correct_tm())
Proof
  match_mp_tac (the_ind_thm())
  \\ EVERY (map strip_assume_tac [compile_Skip, compile_Continue,
       compile_Mark, compile_Return, compile_Assign, compile_Store,
       compile_StoreGlob, compile_Call, compile_Seq, compile_If,
       compile_FFI, compile_Loop])
  \\ asm_rewrite_tac [] \\ rw [] \\ rpt (pop_assum kall_tac)
QED

val _ = export_theory();
