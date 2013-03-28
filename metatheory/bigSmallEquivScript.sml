open preamble;
open MiniMLTheory;
open evaluateEquationsTheory;

val _ = new_theory "bigSmallEquiv";

(* ------------------------ Big step/small step equivalence ----------------- *)

val small_eval_prefix = Q.prove (
`∀menv cenv s env e c cenv' s' env' e' c' r.
  e_step_reln^* (menv,cenv,s,env,Exp e,c) (menv,cenv,s',env',Exp e',c') ∧
  small_eval menv cenv s' env' e' c' r
  ⇒
  small_eval menv cenv s env e c r`,
rw [] >>
PairCases_on `r` >>
cases_on `r1` >>
fs [small_eval_def] >-
metis_tac [transitive_RTC, transitive_def] >>
cases_on `e''` >>
fs [small_eval_def] >>
metis_tac [transitive_RTC, transitive_def])

val e_single_step_add_ctxt = Q.prove (
`!menv cenv s env e c menv' cenv' s' env' e' c' c''.
  (e_step (menv,cenv,s,env,e,c) = Estep (menv',cenv',s',env',e',c'))
  ⇒
  (e_step (menv,cenv,s,env,e,c++c'') = Estep (menv',cenv',s',env',e',c'++c''))`,
rw [e_step_def] >>
cases_on `e` >>
fs [push_def, return_def, emp_def] >>
rw [] >>
fs [] >>
rw [] >|
[ntac 3
     (full_case_tac >> fs [] >> rw []) >>
     every_case_tac >>
     fs [] >>
     rw [],
 fs [continue_def] >>
     cases_on `c` >>
     fs [] >>
     cases_on `h` >>
     fs [] >>
     cases_on `q` >>
     fs [] >>
     every_case_tac >>
     fs [push_def, return_def] >>
     rw []]);

val e_single_error_add_ctxt = Q.prove (
`!menv cenv s env e c c'.
  (e_step (menv,cenv,s,env,e,c) = Etype_error)
  ⇒
  (e_step (menv,cenv,s,env,e,c++c') = Etype_error)`,
rw [e_step_def] >>
cases_on `e` >>
fs [push_def, return_def, emp_def] >>
rw [] >>
fs [] >>
rw [] >>
every_case_tac >>
fs [] >>
rw [] >>
fs [continue_def] >>
cases_on `c` >>
fs [] >>
cases_on `h` >>
fs [] >>
cases_on `q` >>
fs [] >>
every_case_tac >>
fs [push_def, return_def] >>
rw []);

val e_step_add_ctxt_help = Q.prove (
`!st1 st2. e_step_reln^* st1 st2 ⇒
  !menv1 cenv1 s1 env1 e1 c1 menv2 cenv2 s2 env2 e2 c2 c'.
    (st1 = (menv1,cenv1,s1,env1,e1,c1)) ∧ (st2 = (menv2,cenv2,s2,env2,e2,c2))
    ⇒
    e_step_reln^* (menv1,cenv1,s1,env1,e1,c1++c') (menv2,cenv2,s2,env2,e2,c2++c')`,
HO_MATCH_MP_TAC RTC_INDUCT >>
rw [e_step_reln_def] >-
metis_tac [RTC_REFL] >>
PairCases_on `st1'` >>
fs [] >>
imp_res_tac e_single_step_add_ctxt >>
fs [] >>
rw [Once RTC_CASES1] >>
metis_tac [e_step_reln_def]);

val e_step_add_ctxt = Q.prove (
`!menv1 cenv1 s1 env1 e1 c1 menv2 cenv2 s2 env2 e2 c2 c'.
   e_step_reln^* (menv1,cenv1,s1,env1,e1,c1) (menv2,cenv2,s2,env2,e2,c2)
   ⇒
   e_step_reln^* (menv1,cenv1,s1,env1,e1,c1++c') (menv2,cenv2,s2,env2,e2,c2++c')`,
metis_tac [e_step_add_ctxt_help]);

val e_step_raise = Q.prove (
`!menv cenv s env err c.
  EVERY (\c. ¬?n e env. c = (Chandle () n e, env)) c
  ⇒
  e_step_reln^* (menv,cenv,s,env,Exp (Raise err),c) (menv,cenv,s,env,Exp (Raise err),[])`,
induct_on `c` >>
rw [] >>
rw [Once RTC_CASES1] >>
qexists_tac `(menv,cenv,s,env,Exp (Raise err),c)` >>
rw [e_step_reln_def, e_step_def] >>
every_case_tac >>
fs [] >>
cases_on `o'` >>
fs []);

val small_eval_err_add_ctxt = Q.prove (
`!menv cenv s env e c err c' s'.
  EVERY (\c. ¬?n e env. c = (Chandle () n e, env)) c'
  ⇒
  small_eval menv cenv s env e c (s', Rerr err) ⇒ small_eval menv cenv s env e (c++c') (s', Rerr err)`,
cases_on `err` >>
rw [small_eval_def] >|
[`e_step_reln^* (menv,cenv,s,env,Exp e,c++c') (menv,cenv,s',env',e',c''++c')`
       by metis_tac [e_step_add_ctxt] >>
     metis_tac [e_single_error_add_ctxt],
 `e_step_reln^* (menv,cenv,s,env,Exp e',c++c') (menv,cenv,s',env',Exp (Raise e),c')`
       by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step_reln^* (menv,cenv,s',env',Exp (Raise e),c') (menv,cenv,s',env',Exp (Raise e),[])`
            by (match_mp_tac e_step_raise >>
                rw []) >>
     metis_tac [transitive_RTC, transitive_def]]);

val small_eval_err_add_ctxt =
SIMP_RULE (srw_ss ()) 
   [METIS_PROVE [] ``!x y z. x ⇒ y ⇒ z = x ∧ y ⇒ z``]
   small_eval_err_add_ctxt;

val small_eval_step_tac =
rw [do_con_check_def] >>
every_case_tac >>
fs [] >>
PairCases_on `r` >>
cases_on `r1` >|
[all_tac,
 cases_on `e`] >>
rw [small_eval_def] >>
EQ_TAC >>
rw [] >|
[pop_assum (ASSUME_TAC o SIMP_RULE (srw_ss()) [Once RTC_CASES1]) >>
     fs [return_def, e_step_reln_def, e_step_def, push_def, do_con_check_def] >>
     every_case_tac >>
     fs [] >>
     metis_tac [],
 rw [return_def, Once RTC_CASES1, e_step_reln_def, e_step_def, push_def,
     do_con_check_def] >>
     metis_tac [],
 qpat_assum `e_step_reln^* spat1 spat2`
             (ASSUME_TAC o
              SIMP_RULE (srw_ss()) [Once RTC_CASES1,e_step_reln_def,
                                    e_step_def, push_def]) >>
     fs [] >>
     every_case_tac >>
     fs [return_def, do_con_check_def] >>
     rw [] >-
     (fs [e_step_def, push_def] >>
      pop_assum MP_TAC >>
      rw [return_def, do_con_check_def]) >>
     metis_tac [],
 rw [return_def, Once RTC_CASES1, e_step_reln_def, Once e_step_def, push_def,
     do_con_check_def] >>
     metis_tac [],
 pop_assum (ASSUME_TAC o SIMP_RULE (srw_ss()) [Once RTC_CASES1]) >>
     fs [e_step_reln_def, e_step_def, push_def, return_def, do_con_check_def] >>
     every_case_tac >>
     fs [] >>
     metis_tac [],
 rw [return_def, Once RTC_CASES1, e_step_reln_def, Once e_step_def, push_def,
     do_con_check_def] >>
     metis_tac []];

val small_eval_handle = Q.prove (
`!menv cenv s env cn e1 var e2 c r.
  small_eval menv cenv s env (Handle e1 var e2) c r =
  small_eval menv cenv s env e1 ((Chandle () var e2,env)::c) r`,
small_eval_step_tac);

val small_eval_con = Q.prove (
`!menv cenv s env cn e1 es ns c r.
  do_con_check cenv cn (LENGTH (e1::es))
  ⇒
  (small_eval menv cenv s env (Con cn (e1::es)) c r =
   small_eval menv cenv s env e1 ((Ccon cn [] () es,env)::c) r)`,
rw [do_con_check_def] >>
every_case_tac >>
fs [] >>
small_eval_step_tac);

val small_eval_app = Q.prove (
`!menv cenv s env op e1 e2 c r.
  small_eval menv cenv s env (App op e1 e2) c r =
  small_eval menv cenv s env e1 ((Capp1 op () e2,env)::c) r`,
small_eval_step_tac);

val small_eval_uapp = Q.prove (
`!menv cenv s env uop e1 c r.
  small_eval menv cenv s env (Uapp uop e1) c r =
  small_eval menv cenv s env e1 ((Cuapp uop (),env)::c) r`,
small_eval_step_tac);

val small_eval_log = Q.prove (
`!menv cenv s env op e1 e2 c r.
  small_eval menv cenv s env (Log op e1 e2) c r =
  small_eval menv cenv s env e1 ((Clog op () e2,env)::c) r`,
small_eval_step_tac);

val small_eval_if = Q.prove (
`!menv cenv s env e1 e2 e3 c r.
  small_eval menv cenv s env (If e1 e2 e3) c r =
  small_eval menv cenv s env e1 ((Cif () e2 e3,env)::c) r`,
small_eval_step_tac);

val small_eval_match = Q.prove (
`!menv cenv s env e1 pes c r.
  small_eval menv cenv s env (Mat e1 pes) c r =
  small_eval menv cenv s env e1 ((Cmat () pes,env)::c) r`,
small_eval_step_tac);

val small_eval_let = Q.prove (
`!menv cenv s env n e1 e2 c r tvs.
  small_eval menv cenv s env (Let n tvs e1 e2) c r =
  small_eval menv cenv s env e1 ((Clet n tvs () e2,env)::c) r`,
small_eval_step_tac);

val small_eval_letrec = Q.prove (
`!menv cenv s env funs e1 c r.
  ALL_DISTINCT (MAP (λ(x,y,z). x) funs) ⇒
  (small_eval menv cenv s env (Letrec funs e1) c r =
   small_eval menv cenv s (build_rec_env funs env env) e1 c r)`,
small_eval_step_tac);

val (small_eval_list_rules, small_eval_list_ind, small_eval_list_cases) = Hol_reln `
(!menv cenv s env. small_eval_list menv cenv s env [] (s, Rval [])) ∧
(!menv cenv s1 env e es v vs s2 s3 env'.
  e_step_reln^* (menv,cenv,s1,env,Exp e,[]) (menv,cenv,s2,env',Val v,[]) ∧
  small_eval_list menv cenv s2 env es (s3, Rval vs)
  ⇒
  small_eval_list menv cenv s1 env (e::es) (s3, Rval (v::vs))) ∧
(!menv cenv s1 env e es err env' s2 s3 v.
  e_step_reln^* (menv,cenv,s1,env,Exp e,[]) (menv,cenv,s3,env',Exp (Raise err),[]) ∨
  (e_step_reln^* (menv,cenv,s1,env,Exp e,[]) (menv,cenv,s2,env',Val v,[]) ∧
   small_eval_list menv cenv s2 env es (s3, Rerr (Rraise err)))
  ⇒
  (small_eval_list menv cenv s1 env (e::es) (s3, Rerr (Rraise err)))) ∧
(!menv cenv s1 env e es e' c' env' s2 v s3.
  (e_step_reln^* (menv,cenv,s1,env,Exp e,[]) (menv,cenv,s3,env',e',c') ∧
   (e_step (menv,cenv,s3,env',e',c') = Etype_error)) ∨
  (e_step_reln^* (menv,cenv,s1,env,Exp e,[]) (menv,cenv,s2,env',Val v,[]) ∧
   small_eval_list menv cenv s2 env es (s3, Rerr Rtype_error))
  ⇒
  (small_eval_list menv cenv s1 env (e::es) (s3, Rerr Rtype_error)))`;

val small_eval_list_length = Q.prove (
`!menv cenv s1 env es r. small_eval_list menv cenv s1 env es r ⇒
  !vs s2. (r = (s2, Rval vs)) ⇒ (LENGTH es = LENGTH vs)`,
HO_MATCH_MP_TAC small_eval_list_ind >>
rw [] >>
rw []);

val small_eval_list_step = Q.prove (
`!menv cenv s2 env es r. small_eval_list menv cenv s2 env es r ⇒
  (!e v vs cn vs' env' s1 s3.
     do_con_check cenv cn (LENGTH vs' + 1 + LENGTH vs) ∧
     (r = (s3, Rval vs)) ∧ e_step_reln^* (menv,cenv,s1,env,Exp e,[]) (menv,cenv,s2,env',Val v,[]) ⇒
     e_step_reln^* (menv,cenv,s1,env,Exp e,[(Ccon cn vs' () es,env)])
                   (menv,cenv,s3,env,Val (Conv cn (REVERSE vs'++[v]++vs)),[]))`,
HO_MATCH_MP_TAC (fetch "-" "small_eval_list_strongind") >>
rw [] >|
[`e_step_reln^* (menv,cenv,s1,env,Exp e,[(Ccon cn vs' () [],env)])
                (menv,cenv,s2,env',Val v,[(Ccon cn vs' () [],env)])`
             by metis_tac [e_step_add_ctxt,APPEND] >>
     `e_step_reln (menv,cenv,s2,env',Val v,[(Ccon cn vs' () [],env)])
                  (menv,cenv,s2,env,Val (Conv cn (REVERSE vs' ++ [v] ++ [])),[])`
             by rw [return_def, continue_def, e_step_reln_def, e_step_def] >>
     fs [] >>
     metis_tac [transitive_RTC, transitive_def, RTC_SINGLE, APPEND],
 `LENGTH (v'::vs'') + 1 + LENGTH vs = LENGTH vs'' + 1 + SUC (LENGTH vs)`
              by (fs [] >>
                  DECIDE_TAC) >>
     `e_step_reln^* (menv,cenv,s2,env,Exp e,[(Ccon cn (v'::vs'') () es,env)])
                (menv,cenv,s3,env,Val (Conv cn (REVERSE vs'' ++ [v'] ++ [v] ++ vs)),[])`
             by metis_tac [REVERSE_DEF] >>
     `e_step_reln^* (menv,cenv,s1,env,Exp e',[(Ccon cn vs'' () (e::es),env)])
                    (menv,cenv,s2,env'',Val v',[(Ccon cn vs'' () (e::es),env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step_reln (menv,cenv,s2,env'',Val v',[(Ccon cn vs'' () (e::es),env)])
                  (menv,cenv,s2,env,Exp e,[(Ccon cn (v'::vs'') () es,env)])`
             by rw [push_def,continue_def, e_step_reln_def, e_step_def] >>
     fs [] >>
     `LENGTH es = LENGTH vs` by metis_tac [small_eval_list_length] >>
     `LENGTH vs'' + 1 + 1 + LENGTH es = LENGTH vs'' + 1 + SUC (LENGTH es)`
                by DECIDE_TAC >>
     `e_step_reln^* (menv,cenv,s1,env,Exp e',[(Ccon cn vs'' () (e::es),env)])
                    (menv,cenv,s3,env,Val (Conv cn (REVERSE vs'' ++ [v'] ++ [v] ++ vs)),[])`
                by metis_tac [RTC_SINGLE, transitive_RTC, transitive_def] >>
     metis_tac [APPEND_ASSOC, APPEND]]);

val small_eval_list_err = Q.prove (
`!menv cenv s2 env es r. small_eval_list menv cenv s2 env es r ⇒
  (!e v err cn vs' env' s1 s3.
     do_con_check cenv cn (LENGTH vs' + 1 + LENGTH es) ∧
     (r = (s3, Rerr (Rraise err))) ∧
     e_step_reln^* (menv,cenv,s1,env,e,[]) (menv,cenv,s2,env',Val v,[]) ⇒
     ?env''. e_step_reln^* (menv,cenv,s1,env,e,[(Ccon cn vs' () es,env)])
                              (menv,cenv,s3,env'',Exp (Raise err),[]))`,
HO_MATCH_MP_TAC small_eval_list_ind >>
rw [] >>
`e_step_reln^* (menv,cenv,s1,env,e',[(Ccon cn vs' () (e::es),env)])
               (menv,cenv,s2,env'',Val v',[(Ccon cn vs' () (e::es),env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
`e_step_reln (menv,cenv,s2,env'',Val v',[(Ccon cn vs' () (e::es),env)])
             (menv,cenv,s2,env,Exp e,[(Ccon cn (v'::vs') () es,env)])`
        by rw [push_def,continue_def, e_step_reln_def, e_step_def] >>
`LENGTH vs' + 1 + 1 + LENGTH es = LENGTH vs' + 1 + SUC (LENGTH es)`
                by DECIDE_TAC >>
fs [] >|
[`e_step_reln^* (menv,cenv,s2,env,Exp e,[(Ccon cn (v'::vs') () es,env)])
                (menv,cenv,s3,env',Exp (Raise err),[(Ccon cn (v'::vs') () es,env)])`
             by metis_tac [e_step_add_ctxt,APPEND] >>
     `e_step_reln^* (menv,cenv,s3,env',Exp (Raise err),[(Ccon cn (v'::vs') () es,env)])
                    (menv,cenv,s3,env',Exp (Raise err),[])`
             by (match_mp_tac e_step_raise >>
                 rw []) >>
     metis_tac [RTC_SINGLE, transitive_RTC, transitive_def],
 `LENGTH (v'::vs') + 1 + LENGTH es = LENGTH vs' + 1 + SUC (LENGTH es)`
              by (fs [] >>
                  DECIDE_TAC) >>
     `?env''. e_step_reln^* (menv,cenv,s2,env,Exp e,[(Ccon cn (v'::vs') () es,env)])
                               (menv,cenv,s3,env'',Exp (Raise err), [])`
             by metis_tac [] >>
     metis_tac [RTC_SINGLE, transitive_RTC, transitive_def]]);

val small_eval_list_terr = Q.prove (
`!menv cenv s2 env es r. small_eval_list menv cenv s2 env es r ⇒
  (!e v err cn vs' env' s1 s3.
     do_con_check cenv cn (LENGTH vs' + 1 + LENGTH es) ∧
     (r = (s3, Rerr Rtype_error)) ∧
     e_step_reln^* (menv,cenv,s1,env,e,[]) (menv,cenv,s2,env',Val v,[]) ⇒
     ?env'' e' c'. e_step_reln^* (menv,cenv,s1,env,e,[(Ccon cn vs' () es,env)])
                                    (menv,cenv,s3,env'',e',c') ∧
                   (e_step (menv,cenv,s3,env'',e',c') = Etype_error))`,
HO_MATCH_MP_TAC small_eval_list_ind >>
rw [] >>
`e_step_reln^* (menv,cenv,s1,env,e'',[(Ccon cn vs' () (e::es),env)])
               (menv,cenv,s2,env'',Val v',[(Ccon cn vs' () (e::es),env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
`e_step_reln (menv,cenv,s2,env'',Val v',[(Ccon cn vs' () (e::es),env)])
             (menv,cenv,s2,env,Exp e,[(Ccon cn (v'::vs') () es,env)])`
        by rw [push_def,continue_def, e_step_reln_def, e_step_def] >>
`LENGTH vs' + 1 + 1 + LENGTH es = LENGTH vs' + 1 + SUC (LENGTH es)`
                by DECIDE_TAC >>
fs [] >|
[`e_step_reln^* (menv,cenv,s2,env,Exp e,[(Ccon cn (v'::vs') () es,env)])
                (menv,cenv,s3,env',e',c'++[(Ccon cn (v'::vs') () es,env)])`
             by metis_tac [e_step_add_ctxt,APPEND] >>
     `e_step (menv,cenv,s3,env',e',c'++[(Ccon cn (v'::vs') () es,env)]) = Etype_error`
             by metis_tac [e_single_error_add_ctxt] >>
     metis_tac [RTC_SINGLE, transitive_RTC, transitive_def],
 `LENGTH (v'::vs') + 1 + LENGTH es = LENGTH vs' + 1 + SUC (LENGTH es)`
              by (fs [] >>
                  DECIDE_TAC) >>
     `?env'' e' c'. e_step_reln^* (menv,cenv,s2,env,Exp e,[(Ccon cn (v'::vs') () es,env)])
                              (menv,cenv,s3,env'',e',c') ∧
                (e_step (menv,cenv,s3,env'',e',c') = Etype_error)`
             by metis_tac [] >>
     metis_tac [RTC_SINGLE, transitive_RTC, transitive_def]]);

val (small_eval_match_rules, small_eval_match_ind, small_eval_match_cases) = Hol_reln `
(!menv cenv s env v. small_eval_match menv cenv s env v [] (s, Rerr (Rraise Bind_error))) ∧
(!menv cenv s env p e pes r env' v.
  ALL_DISTINCT (pat_bindings p []) ∧
  (pmatch cenv s p v env = Match env') ∧
  small_eval menv cenv s env' e [] r
  ⇒
  small_eval_match menv cenv s env v ((p,e)::pes) r) ∧
(!menv cenv s env e p pes r v.
  ALL_DISTINCT (pat_bindings p []) ∧
  (pmatch cenv s p v env = No_match) ∧
  small_eval_match menv cenv s env v pes r
  ⇒
  small_eval_match menv cenv s env v ((p,e)::pes) r) ∧
(!menv cenv s env p e pes v.
  ¬(ALL_DISTINCT (pat_bindings p []))
  ⇒
  small_eval_match menv cenv s env v ((p,e)::pes) (s, Rerr (Rtype_error))) ∧
(!menv cenv s env p e pes v.
  (pmatch cenv s p v env = Match_type_error)
  ⇒
  small_eval_match menv cenv s env v ((p,e)::pes) (s, Rerr (Rtype_error)))`;

val alt_small_eval_def = Define `
(alt_small_eval menv cenv s1 env e c (s2, Rval v) =
    ∃env'. e_step_reln^* (menv,cenv,s1,env,e,c) (menv,cenv,s2,env',Val v,[])) ∧
(alt_small_eval menv cenv s1 env e c (s2, Rerr (Rraise err)) ⇔
    ∃env'.
      e_step_reln^* (menv,cenv,s1,env,e,c) (menv,cenv,s2,env',Exp (Raise err),[])) ∧
(alt_small_eval menv cenv s env e c (s2, Rerr Rtype_error) ⇔
    ∃env' e' c'.
      e_step_reln^* (menv,cenv,s1,env,e,c) (menv,cenv,s2,env',e',c') ∧
      (e_step (menv,cenv,s2,env',e',c') = Etype_error))`;

val small_eval_match_thm = Q.prove (
`!menv cenv s env v pes r. small_eval_match menv cenv s env v pes r ⇒
 !env2. alt_small_eval menv cenv s env2 (Val v) [(Cmat () pes,env)] r`,
HO_MATCH_MP_TAC small_eval_match_ind >>
rw [alt_small_eval_def] >|
[qexists_tac `env` >>
     match_mp_tac RTC_SINGLE >>
     rw [e_step_reln_def, e_step_def, continue_def],
 PairCases_on `r` >>
     cases_on `r1` >|
     [all_tac,
      cases_on `e'`] >>
     fs [alt_small_eval_def, small_eval_def] >|
     [qexists_tac `env''` >>
          rw [Once RTC_CASES1, e_step_reln_def] >>
          rw [e_step_def, continue_def],
      qexists_tac `env''` >>
          rw [Once RTC_CASES1, e_step_reln_def] >>
          qexists_tac `e'` >>
          qexists_tac `c'` >>
          rw [] >>
          rw [e_step_def, continue_def],
      qexists_tac `env''` >>
          rw [Once RTC_CASES1, e_step_reln_def] >>
          rw [e_step_def, continue_def]],
 PairCases_on `r` >>
     cases_on `r1` >|
     [all_tac,
      cases_on `e'`] >>
     fs [alt_small_eval_def] >>
     rw [Once RTC_CASES1, e_step_reln_def] >|
     [rw [e_step_def, push_def, continue_def],
      pop_assum (ASSUME_TAC o Q.SPEC `env`) >>
          fs [] >>
          qexists_tac `env'` >>
          qexists_tac `e'` >>
          qexists_tac `c'` >>
          rw [] >>
          rw [e_step_def, push_def, continue_def],
      rw [e_step_def, push_def, continue_def]],
 qexists_tac `env2` >>
     qexists_tac `Val v` >>
     qexists_tac `[(Cmat () ((p,e)::pes),env)]` >>
     rw [RTC_REFL] >>
     rw [e_step_def, continue_def],
 qexists_tac `env2` >>
     qexists_tac `Val v` >>
     qexists_tac `[(Cmat () ((p,e)::pes),env)]` >>
     rw [RTC_REFL] >>
     rw [e_step_def, continue_def]]);

val big_exp_to_small_exp = Q.prove (
`(∀(menv : envM) cenv s env e r.
   evaluate menv cenv s env e r ⇒
   small_eval menv cenv s env e [] r) ∧
 (∀(menv : envM) cenv s env es r.
   evaluate_list menv cenv s env es r ⇒
   small_eval_list menv cenv s env es r) ∧
 (∀(menv : envM) cenv s env v pes r.
   evaluate_match menv cenv s env v pes r ⇒
   small_eval_match menv cenv s env v pes r)`,
HO_MATCH_MP_TAC evaluate_ind >>
rw [small_eval_app, small_eval_log, small_eval_if, small_eval_match,
    small_eval_handle, small_eval_let, small_eval_letrec,small_eval_uapp] >|
[rw [return_def, small_eval_def, Once RTC_CASES1, e_step_reln_def, e_step_def] >>
     metis_tac [RTC_REFL],
 rw [return_def, small_eval_def, Once RTC_CASES1, e_step_reln_def, e_step_def] >>
     metis_tac [RTC_REFL],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Chandle () var e2,env)]) (menv,cenv,s2,env',Val v,[(Chandle () var e2,env)])`
                 by metis_tac [APPEND,e_step_add_ctxt] >>
     `e_step_reln (menv,cenv,s2,env',Val v,[(Chandle () var e2,env)]) (menv,cenv,s2,env,Val v,[])`
                 by (rw [e_step_reln_def, e_step_def, continue_def, return_def]) >>
     metis_tac [transitive_def, transitive_RTC, RTC_SINGLE],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Chandle () var e',env)]) (menv,cenv,s',env',Exp (Raise (Int_error n)),[(Chandle () var e',env)])`
                 by metis_tac [APPEND,e_step_add_ctxt] >>
     `e_step_reln (menv,cenv,s',env',Exp (Raise (Int_error n)),[(Chandle () var e',env)]) 
                  (menv,cenv,s',(bind var (Litv (IntLit n)) env),Exp e',[])`
                 by (rw [e_step_reln_def, e_step_def, continue_def, return_def]) >>
     metis_tac [RTC_SINGLE, small_eval_prefix],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Chandle () var e2,env)]) (menv,cenv,s2,env',e',c'++[(Chandle () var e2,env)])` 
                by metis_tac [APPEND,e_step_add_ctxt] >>
      metis_tac [APPEND, e_step_add_ctxt, transitive_RTC,
                 transitive_def, e_single_error_add_ctxt],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Chandle () var e2,env)]) (menv,cenv,s2,env',Exp (Raise Bind_error),[(Chandle () var e2,env)])` 
                by metis_tac [APPEND,e_step_add_ctxt] >>
     `e_step_reln (menv,cenv,s2,env',Exp (Raise Bind_error),[(Chandle () var e2,env)]) (menv,cenv,s2,env',Exp (Raise Bind_error),[])`
                 by (rw [e_step_reln_def, e_step_def, continue_def, return_def]) >>
     metis_tac [transitive_def, transitive_RTC, RTC_SINGLE],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Chandle () var e2,env)]) (menv,cenv,s2,env',Exp (Raise Div_error),[(Chandle () var e2,env)])` 
                by metis_tac [APPEND,e_step_add_ctxt] >>
     `e_step_reln (menv,cenv,s2,env',Exp (Raise Div_error),[(Chandle () var e2,env)]) (menv,cenv,s2,env',Exp (Raise Div_error),[])`
                 by (rw [e_step_reln_def, e_step_def, continue_def, return_def]) >>
     metis_tac [transitive_def, transitive_RTC, RTC_SINGLE],
 cases_on `es` >>
     fs [LENGTH] >>
     rw [small_eval_con] >|
     [rw [small_eval_def] >>
          fs [Once small_eval_list_cases] >>
          rw [return_def, small_eval_def, Once RTC_CASES1, e_step_reln_def, e_step_def] >>
          metis_tac [RTC_REFL],
      fs [Once small_eval_list_cases] >>
          rw [small_eval_def] >>
          `SUC (LENGTH t) = LENGTH ([]:v list) + 1 + LENGTH t` by
                  (fs [] >>
                   DECIDE_TAC) >>
          `do_con_check cenv cn (LENGTH ([]:v list) + 1 + LENGTH vs')`
                      by metis_tac [small_eval_list_length] >>
          `e_step_reln^* (menv,cenv,s,env,Exp h,[(Ccon cn [] () t,env)])
                         (menv,cenv,s',env,Val (Conv cn (REVERSE ([]:v list)++[v]++vs')),[])`
                    by metis_tac [small_eval_list_step] >>
          fs [] >>
          metis_tac []],
 rw [small_eval_def, e_step_def] >>
     qexists_tac `env` >>
     qexists_tac `Exp (Con cn es)` >>
     rw [] >>
     metis_tac [RTC_REFL],
 cases_on `es` >>
     rw [small_eval_con] >>
     fs [Once small_eval_list_cases] >>
     rw [small_eval_def] >|
     [`e_step_reln^* (menv,cenv,s',env',Exp (Raise err'),[(Ccon cn [] () t,env)]) 
                     (menv,cenv,s',env',Exp (Raise err'),[])`
                by (match_mp_tac e_step_raise >>
                    rw []) >>
          metis_tac [APPEND,e_step_add_ctxt, transitive_RTC, transitive_def],
      `LENGTH ([]:v list) + 1 + LENGTH t = SUC (LENGTH t)` by
                 (fs [] >>
                  DECIDE_TAC) >>
          metis_tac [small_eval_list_err],
      metis_tac [APPEND, e_step_add_ctxt, transitive_RTC,
                 transitive_def, e_single_error_add_ctxt],
      `LENGTH ([]:v list) + 1 + LENGTH t = SUC (LENGTH t)` by
                 (fs [] >>
                  DECIDE_TAC) >>
          metis_tac [small_eval_list_terr]],
 rw [small_eval_def] >>
     qexists_tac `env` >>
     rw [Once RTC_CASES1, e_step_reln_def, return_def, e_step_def],
 rw [small_eval_def, e_step_def] >>
     qexists_tac `env` >>
     qexists_tac `Exp (Var n)` >>
     rw [] >>
     metis_tac [RTC_REFL],
 rw [small_eval_def] >>
     qexists_tac `env` >>
     rw [Once RTC_CASES1, e_step_reln_def, return_def, e_step_def],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Cuapp uop (),env)])
                    (menv,cenv,s2,env',Val v,[(Cuapp uop (),env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step_reln (menv,cenv,s2,env',Val v,[(Cuapp uop (),env)])
                  (menv,cenv,s3,env,Val v',[])`
             by rw [e_step_def, e_step_reln_def, continue_def, return_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Cuapp uop (),env)])
                    (menv,cenv,s3,env,Val v',[])`
              by metis_tac [transitive_RTC, RTC_SINGLE, transitive_def] >>
     metis_tac [small_eval_prefix],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Cuapp uop (),env)])
                    (menv,cenv,s2,env',Val v,[(Cuapp uop (),env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step (menv,cenv,s2,env',Val v,[(Cuapp uop (),env)]) = Etype_error`
             by rw [e_step_def, e_step_reln_def, continue_def, push_def] >>
     metis_tac [transitive_RTC, RTC_SINGLE, transitive_def],
 `small_eval menv cenv s env e ([] ++ [(Cuapp uop (),env)]) (s', Rerr err)`
           by (match_mp_tac small_eval_err_add_ctxt >>
               rw []) >>
     fs [],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Capp1 op () e',env)])
                    (menv,cenv,s',env'',Val v1,[(Capp1 op () e',env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step_reln (menv,cenv,s',env'',Val v1,[(Capp1 op () e',env)])
                  (menv,cenv,s',env,Exp e',[(Capp2 op v1 (),env)])`
             by rw [e_step_def, e_step_reln_def, continue_def, push_def] >>
     `e_step_reln^* (menv,cenv,s',env,Exp e',[(Capp2 op v1 (),env)])
                    (menv,cenv,s3,env''',Val v2,[(Capp2 op v1 (),env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step_reln (menv,cenv,s3,env''',Val v2,[(Capp2 op v1 (),env)])
                  (menv,cenv,s'',env',Exp e'',[])`
             by rw [e_step_def, e_step_reln_def, continue_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Capp1 op () e',env)])
                    (menv,cenv,s'',env',Exp e'',[])`
              by metis_tac [transitive_RTC, RTC_SINGLE, transitive_def] >>
     metis_tac [small_eval_prefix],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Capp1 op () e',env)])
                    (menv,cenv,s',env',Val v1,[(Capp1 op () e',env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step_reln (menv,cenv,s',env',Val v1,[(Capp1 op () e',env)])
                  (menv,cenv,s',env,Exp e',[(Capp2 op v1 (),env)])`
             by rw [e_step_def, e_step_reln_def, continue_def, push_def] >>
     `e_step_reln^* (menv,cenv,s',env,Exp e',[(Capp2 op v1 (),env)])
                    (menv,cenv,s3,env'',Val v2,[(Capp2 op v1 (),env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step (menv,cenv,s3,env'',Val v2,[(Capp2 op v1 (),env)]) = Etype_error`
             by rw [e_step_def, e_step_reln_def, continue_def, push_def] >>
     metis_tac [transitive_RTC, RTC_SINGLE, transitive_def],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Capp1 op () e',env)])
                    (menv,cenv,s',env',Val v1,[(Capp1 op () e',env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step_reln (menv,cenv,s',env',Val v1,[(Capp1 op () e',env)])
                  (menv,cenv,s',env,Exp e',[(Capp2 op v1 (),env)])`
             by rw [e_step_def, e_step_reln_def, continue_def, push_def] >>
     `small_eval menv cenv s' env e' ([]++[(Capp2 op v1 (),env)]) (s3, Rerr err)`
             by (match_mp_tac small_eval_err_add_ctxt >>
                 rw []) >>
     fs [] >>
     fs [] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Capp1 op () e',env)])
                    (menv,cenv,s',env,Exp e',[(Capp2 op v1 (),env)])`
             by metis_tac [transitive_RTC, RTC_SINGLE, transitive_def] >>
     metis_tac [small_eval_prefix],
 `small_eval menv cenv s env e ([] ++ [(Capp1 op () e2,env)]) (s', Rerr err)`
             by (match_mp_tac small_eval_err_add_ctxt >>
                 rw []) >>
     fs [],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Clog op () e2,env)])
                    (menv,cenv,s',env',Val v,[(Clog op () e2,env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step_reln (menv,cenv,s',env',Val v,[(Clog op () e2,env)])
                  (menv,cenv,s',env,Exp e',[])`
             by rw [e_step_def, e_step_reln_def, continue_def, push_def] >>
     metis_tac [transitive_RTC, RTC_SINGLE, transitive_def, small_eval_prefix],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Clog op () e2,env)])
                    (menv,cenv,s2,env',Val v,[(Clog op () e2,env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step (menv,cenv,s2,env',Val v,[(Clog op () e2,env)]) = Etype_error`
             by rw [e_step_def, e_step_reln_def, continue_def, push_def] >>
     metis_tac [transitive_RTC, RTC_SINGLE, transitive_def],
 `small_eval menv cenv s env e ([] ++ [(Clog op () e2,env)]) (s', Rerr err)`
             by (match_mp_tac small_eval_err_add_ctxt >>
                 rw []) >>
     fs [],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Cif () e2 e3,env)])
                    (menv,cenv,s',env',Val v,[(Cif () e2 e3,env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step_reln (menv,cenv,s',env',Val v,[(Cif () e2 e3,env)])
                  (menv,cenv,s',env,Exp e',[])`
             by rw [e_step_def, e_step_reln_def, continue_def, push_def] >>
     metis_tac [transitive_RTC, RTC_SINGLE, transitive_def,
                small_eval_prefix],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Cif () e2 e3,env)])
                    (menv,cenv,s2,env',Val v,[(Cif () e2 e3,env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step (menv,cenv,s2,env',Val v,[(Cif () e2 e3,env)]) = Etype_error`
             by rw [e_step_def, e_step_reln_def, continue_def, push_def] >>
     metis_tac [transitive_RTC, RTC_SINGLE, transitive_def],
 `small_eval menv cenv s env e ([] ++ [(Cif () e2 e3,env)]) (s', Rerr err)`
             by (match_mp_tac small_eval_err_add_ctxt >>
                 rw []) >>
     fs [],
 fs [small_eval_def] >>
     imp_res_tac small_eval_match_thm >>
     PairCases_on `r` >>
     cases_on `r1` >|
     [all_tac,
      cases_on `e'`] >>
     rw [] >>
     fs [small_eval_def, alt_small_eval_def] >>
     metis_tac [transitive_def, transitive_RTC, e_step_add_ctxt, APPEND],
 `small_eval menv cenv s env e ([] ++ [(Cmat () pes,env)]) (s', Rerr err)`
             by (match_mp_tac small_eval_err_add_ctxt >>
                 rw []) >>
     fs [],
 fs [small_eval_def] >>
     `e_step_reln^* (menv,cenv,s,env,Exp e,[(Clet tvs n () e',env)])
                    (menv,cenv,s',env',Val v,[(Clet tvs n () e',env)])`
             by metis_tac [e_step_add_ctxt, APPEND] >>
     `e_step_reln (menv,cenv,s',env',Val v,[(Clet tvs n () e',env)])
                  (menv,cenv,s',bind n v env,Exp e',[])`
             by rw [e_step_def, e_step_reln_def, continue_def, push_def] >>
     match_mp_tac small_eval_prefix >>
     metis_tac [transitive_RTC, RTC_SINGLE, transitive_def],
 `small_eval menv cenv s env e ([] ++ [(Clet tvs n () e2,env)]) (s', Rerr err)`
             by (match_mp_tac small_eval_err_add_ctxt >>
                 rw []) >>
     fs [],
 rw [small_eval_def] >>
     qexists_tac `env` >>
     qexists_tac `Exp (Letrec funs e)` >>
     qexists_tac `[]` >>
     rw [RTC_REFL, e_step_def],
 fs [small_eval_def] >>
     metis_tac [APPEND,e_step_add_ctxt, small_eval_list_rules],
 fs [small_eval_def] >>
     metis_tac [APPEND,e_step_add_ctxt, small_eval_list_rules],
 cases_on `err` >>
     fs [small_eval_def] >>
     metis_tac [APPEND,e_step_add_ctxt, small_eval_list_rules],
 cases_on `err` >>
     fs [small_eval_def] >>
     metis_tac [APPEND,e_step_add_ctxt, small_eval_list_rules],
 metis_tac [small_eval_match_rules],
 metis_tac [small_eval_match_rules],
 metis_tac [small_eval_match_rules],
 metis_tac [small_eval_match_rules],
 metis_tac [small_eval_match_rules]]);

val evaluate_ctxts_cons = Q.prove (
`!menv cenv s1 f cs res1 bv.
  evaluate_ctxts menv cenv s1 (f::cs) res1 bv =
  (?c s2 env v' res2 v.
     (res1 = Rval v) ∧
     (f = (c,env)) ∧
     evaluate_ctxt menv cenv s1 env c v (s2, res2) ∧
     evaluate_ctxts menv cenv s2 cs res2 bv) ∨
  (?c env err.
     (res1 = Rerr err) ∧
     (f = (c,env)) ∧
     ((∀i e'. c ≠ Chandle () i e') ∨ ∀i. err ≠ Rraise (Int_error i)) ∧
     evaluate_ctxts menv cenv s1 cs res1 bv) ∨
  (?var e' s2 env v' res2 v i.
     (res1 = Rerr (Rraise (Int_error i))) ∧
     (f = (Chandle () var e',env)) ∧
     evaluate menv cenv s1 (bind var (Litv (IntLit i)) env) e' (s2, res2) ∧
     evaluate_ctxts menv cenv s2 cs res2 bv)`,
rw [] >>
rw [Once evaluate_ctxts_cases] >>
EQ_TAC >>
rw [] >>
metis_tac []);

val evaluate_raise = Q.prove (
`!menv cenv s env err bv.
  (evaluate menv cenv s env (Raise err) bv = (bv = (s, Rerr (Rraise err))))`,
rw [Once evaluate_cases]);

val tac1 =
fs [evaluate_state_cases] >>
ONCE_REWRITE_TAC [evaluate_ctxts_cases] >>
rw [] >>
metis_tac [oneTheory.one]

val tac3 =
fs [evaluate_state_cases] >>
ONCE_REWRITE_TAC [evaluate_cases] >>
rw [] >>
fs [evaluate_ctxts_cons, evaluate_ctxt_cases] >>
ONCE_REWRITE_TAC [hd (tl (CONJUNCTS evaluate_cases))] >>
rw [] >>
fs [evaluate_ctxts_cons, evaluate_ctxt_cases] >>
metis_tac [DECIDE ``SUC x = x + 1``]

val one_step_backward = Q.prove (
`!menv cenv s env e c menv' cenv' s' env' e' c' bv.
  (e_step (menv,cenv,s,env,e,c) = Estep (menv',cenv',s',env',e',c')) ∧
  evaluate_state (menv',cenv',s',env',e',c') bv
  ⇒
  evaluate_state (menv,cenv,s,env,e,c) bv`,
rw [e_step_def] >>
cases_on `e` >>
fs [] >|
[cases_on `e''` >>
     fs [push_def, return_def] >>
     rw [] >|
     [cases_on `c` >>
          fs [] >>
          PairCases_on `h` >>
          cases_on `h0` >>
          fs [] >>
          rw [] >-
          (every_case_tac >>
               fs [] >>
               rw [] >>
               tac1) >>
          tac1,
      fs [evaluate_state_cases] >>
          ONCE_REWRITE_TAC [evaluate_cases] >>
          rw [] >>
          fs [evaluate_ctxts_cons, evaluate_ctxt_cases] >>
          rw [] >|
          [metis_tac [],
           cases_on `err` >>
               fs [] >-
               metis_tac [] >>
               cases_on `e'` >>
               fs [] >>
               metis_tac [],
           metis_tac []],
      fs [evaluate_state_cases],
      every_case_tac >>
          fs [] >>
          rw [] >>
          tac3,
      every_case_tac >>
          fs [] >>
          rw [] >>
          tac3,
      tac1,
      tac3,
      tac3,
      tac3,
      tac3,
      tac3,
      tac3,
      every_case_tac >>
          fs [] >>
          rw [] >>
          tac3],
  fs [continue_def] >>
     cases_on `c` >>
     fs [] >>
     cases_on `h` >>
     fs [] >>
     cases_on `q` >>
     fs [] >>
     every_case_tac >>
     fs [push_def, return_def] >>
     rw [] >>
     fs [evaluate_state_cases, evaluate_ctxts_cons, evaluate_ctxt_cases, oneTheory.one,
         evaluate_ctxts_cons, evaluate_ctxt_cases, evaluate_raise, do_con_check_def] >|
     [metis_tac [],
      metis_tac [],
      metis_tac [],
      metis_tac [],
      metis_tac [],
      metis_tac [],
      ONCE_REWRITE_TAC [evaluate_cases] >>
          rw [],
      ONCE_REWRITE_TAC [evaluate_cases] >>
          rw [] >>
          metis_tac [],
      ONCE_REWRITE_TAC [evaluate_cases] >>
          rw [] >>
          metis_tac [],
      metis_tac [],
      ONCE_REWRITE_TAC [evaluate_cases] >>
          rw [] >>
          metis_tac [],
      every_case_tac >>
          full_simp_tac (srw_ss()++ARITH_ss) [],
      every_case_tac >>
          full_simp_tac (srw_ss()++ARITH_ss) [],
      every_case_tac >>
          full_simp_tac (srw_ss()++ARITH_ss) [],
      every_case_tac >>
          full_simp_tac (srw_ss()++ARITH_ss) [],
      every_case_tac >>
          full_simp_tac (srw_ss()++ARITH_ss) [] >>
          ONCE_REWRITE_TAC [evaluate_cases] >>
          rw [] >>
          metis_tac [APPEND_ASSOC, APPEND],
      every_case_tac >>
          full_simp_tac (srw_ss()++ARITH_ss) [],
      every_case_tac >>
          full_simp_tac (srw_ss()++ARITH_ss) [] >>
          ONCE_REWRITE_TAC [evaluate_cases] >>
          rw [] >>
          metis_tac [APPEND_ASSOC, APPEND],
      every_case_tac >>
          full_simp_tac (srw_ss()++ARITH_ss) [] >>
          ONCE_REWRITE_TAC [evaluate_cases] >>
          rw [] >>
          metis_tac [APPEND_ASSOC, APPEND]]]);

val evaluate_ctxts_type_error = Q.prove (
`!menv cenv s env c. evaluate_ctxts menv cenv s c (Rerr Rtype_error) (s,Rerr Rtype_error)`,
induct_on `c` >>
rw [] >>
rw [Once evaluate_ctxts_cases] >>
PairCases_on `h` >>
rw []);

val one_step_backward_type_error = Q.prove (
`!menv cenv s env e c.
  (e_step (menv,cenv,s,env,e,c) = Etype_error)
  ⇒
  evaluate_state (menv,cenv,s,env,e,c) (s, Rerr Rtype_error)`,
rw [e_step_def] >>
cases_on `e` >>
fs [] >|
[cases_on `e'` >>
     fs [push_def, return_def] >>
     every_case_tac >>
     rw [evaluate_state_cases] >>
     rw [Once evaluate_cases] >>
     fs [] >>
     rw [] >>
      metis_tac [evaluate_ctxts_type_error],
 fs [continue_def] >>
     cases_on `c` >>
     fs [] >>
     cases_on `h` >>
     fs [] >>
     cases_on `q` >>
     fs [] >>
     every_case_tac >>
     fs [evaluate_state_cases, push_def, return_def] >>
     rw [evaluate_ctxts_cons, evaluate_ctxt_cases] >>
     rw [Once evaluate_cases] >>
     full_simp_tac (srw_ss() ++ ARITH_ss) [arithmeticTheory.ADD1] >>
     rw [Once evaluate_cases] >>
     metis_tac [oneTheory.one, evaluate_ctxts_type_error]]);

val small_exp_to_big_exp = Q.prove (
`!st st'. e_step_reln^* st st' ⇒
  !r.
    evaluate_state st' r
    ⇒
    evaluate_state st r`,
HO_MATCH_MP_TAC RTC_INDUCT_RIGHT1 >>
rw [e_step_reln_def] >>
PairCases_on `st` >>
PairCases_on `st'` >>
PairCases_on `st''` >>
rw [] >>
metis_tac [one_step_backward]);

val evaluate_state_no_ctxt = Q.prove (
`!menv cenv s env e r. evaluate_state (menv,cenv,s,env,Exp e,[]) r = evaluate menv cenv s env e r`,
rw [evaluate_state_cases, Once evaluate_ctxts_cases] >>
cases_on `r` >>
rw []);

val evaluate_state_val_no_ctxt = Q.prove (
`!menv cenv s env e. evaluate_state (menv,cenv,s,env,Val e,[]) r = (r = (s, Rval e))`,
rw [evaluate_state_cases, Once evaluate_ctxts_cases] >>
rw [evaluate_state_cases, Once evaluate_ctxts_cases]);

val small_big_exp_equiv = Q.store_thm ("small_big_exp_equiv",
`!menv cenv s env e r. small_eval menv cenv s env e [] r = evaluate menv cenv s env e r`,
rw [] >>
cases_on `r` >>
cases_on `r'` >|
[all_tac,
 cases_on `e'`] >>
rw [small_eval_def] >>
EQ_TAC >>
rw [] >>
metis_tac [small_exp_to_big_exp, big_exp_to_small_exp,
           evaluate_state_no_ctxt, small_eval_def, evaluate_raise,
           one_step_backward_type_error, evaluate_state_val_no_ctxt]);

val _ = export_theory ();
