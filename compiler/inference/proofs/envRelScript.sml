open preamble;
open libTheory namespacePropsTheory typeSystemTheory astTheory
semanticPrimitivesTheory terminationTheory inferTheory unifyTheory inferPropsTheory;
open astPropsTheory typeSysPropsTheory;

val _ = new_theory "envRel";

(* ---------- Converting infer types and envs to type system ones ---------- *)

val convert_t_def = tDefine "convert_t" `
(convert_t (Infer_Tvar_db n) = Tvar_db n) ∧
(convert_t (Infer_Tapp ts tc) = Tapp (MAP convert_t ts) tc)`
(WF_REL_TAC `measure infer_t_size` >>
 rw [] >>
 induct_on `ts` >>
 rw [infer_tTheory.infer_t_size_def] >>
 res_tac >>
 decide_tac);

val convert_env_def = Define `
convert_env s env = MAP (\(x,t). (x, convert_t (t_walkstar s t))) env`;

val convert_decls_def = Define `
convert_decls idecls =
  <| defined_mods := set idecls.inf_defined_mods;
     defined_types :=  set idecls.inf_defined_types;
     defined_exns := set idecls.inf_defined_exns|>`;

val convert_append_decls = Q.store_thm ("convert_append_decls",
`!decls1 decls2. convert_decls (append_decls decls1 decls2) = union_decls (convert_decls decls1) (convert_decls decls2)`,
 rw [convert_decls_def, append_decls_def, union_decls_def]);

val check_convert_freevars = Q.store_thm ("check_convert_freevars",
`(!tvs uvs t. check_t tvs uvs t ⇒ (uvs = {}) ⇒ check_freevars tvs [] (convert_t t))`,
ho_match_mp_tac check_t_ind >>
rw [check_freevars_def, check_t_def, convert_t_def] >>
fs [EVERY_MEM, MEM_MAP] >>
metis_tac []);

val check_t_to_check_freevars = Q.store_thm ("check_t_to_check_freevars",
`!tvs (n:num set) t. check_t tvs {} t ⇒ check_freevars tvs [] (convert_t t)`,
ho_match_mp_tac check_t_ind >>
rw [check_t_def, check_freevars_def, convert_t_def, EVERY_MAP] >>
fs [EVERY_MEM]);

val convert_inc = Q.store_thm ("convert_inc",
`!t tvs tvs'.
  check_t tvs' {} t
  ⇒
  (convert_t (infer_deBruijn_inc tvs t) = deBruijn_inc 0 tvs (convert_t t))`,
ho_match_mp_tac (fetch "-" "convert_t_ind") >>
rw [check_t_def, convert_t_def, infer_deBruijn_inc_def, deBruijn_inc_def] >>
induct_on `ts` >>
fs [] >>
metis_tac []);

val infer_t_induction = infer_tTheory.infer_t_induction;

val db_subst_infer_subst_swap = Q.store_thm ("db_subst_infer_subst_swap",
`(!t s tvs uvar n.
  t_wfs s ∧
  count (uvar + tvs) ⊆ FDOM s ∧
  (!uv. uv ∈ FDOM s ⇒ check_t n {} (t_walkstar s (Infer_Tuvar uv))) ∧
  check_t tvs (FDOM s) t
  ⇒
  (convert_t
    (t_walkstar s
       (infer_deBruijn_subst
          (MAP (λn. Infer_Tuvar (uvar + n)) (COUNT_LIST tvs))
          t)) =
   deBruijn_subst 0
    (MAP (convert_t o t_walkstar s)
       (MAP (λn. Infer_Tuvar (uvar + n)) (COUNT_LIST tvs)))
    (convert_t (t_walkstar (infer_deBruijn_inc tvs o_f s) t)))) ∧
 (!ts s tvs uvar n.
  t_wfs s ∧
  count (uvar + tvs) ⊆ FDOM s ∧
  (!uv. uv ∈ FDOM s ⇒ check_t n {} (t_walkstar s (Infer_Tuvar uv))) ∧
  EVERY (\t. check_t tvs (FDOM s) t) ts ⇒
  (MAP (convert_t o
       t_walkstar s o
       infer_deBruijn_subst (MAP (λn. Infer_Tuvar (uvar + n)) (COUNT_LIST tvs)))
      ts =
   MAP (deBruijn_subst 0 (MAP (convert_t o t_walkstar s) (MAP (λn. Infer_Tuvar (uvar + n)) (COUNT_LIST tvs))) o
       convert_t o
       t_walkstar (infer_deBruijn_inc tvs o_f s))
      ts))`,
ho_match_mp_tac infer_t_induction >>
rw [convert_t_def, deBruijn_subst_def, EL_MAP, t_walkstar_eqn1,
    infer_deBruijn_subst_def, MAP_MAP_o, combinTheory.o_DEF, check_t_def,
    LENGTH_COUNT_LIST] >|
[`t_wfs (infer_deBruijn_inc tvs o_f s)` by metis_tac [inc_wfs] >>
     fs [t_walkstar_eqn1, convert_t_def, deBruijn_subst_def,
         LENGTH_COUNT_LIST] >>
     fs [LENGTH_MAP, el_map_count, EL_COUNT_LIST],
 `t_wfs (infer_deBruijn_inc tvs o_f s)` by metis_tac [inc_wfs] >>
     fs [t_walkstar_eqn1, convert_t_def, deBruijn_subst_def, MAP_MAP_o,
         combinTheory.o_DEF] >>
     metis_tac [],
 res_tac >>
     imp_res_tac convert_inc >>
     rw [walkstar_inc2] >>
     metis_tac [subst_inc_cancel, arithmeticTheory.ADD,
                deBruijn_inc0,
                LENGTH_COUNT_LIST, LENGTH_MAP],
 metis_tac [],
 metis_tac []]);

val inc_convert_t = Q.store_thm ("inc_convert_t",
`(!t tvs' tvs. check_t tvs' {} t ⇒ (deBruijn_inc tvs' tvs (convert_t t) = convert_t t)) ∧
 (!ts tvs' tvs. EVERY (check_t tvs' {}) ts ⇒ (MAP (deBruijn_inc tvs' tvs o convert_t) ts = MAP convert_t ts))`,
ho_match_mp_tac infer_t_induction >>
rw [check_t_def, convert_t_def, deBruijn_inc_def] >>
metis_tac [MAP_MAP_o]);

val convert_t_subst = Q.store_thm ("convert_t_subst",
`(!t tvs ts'.
    (LENGTH tvs = LENGTH ts') ∧
    check_freevars 0 tvs t ⇒
    convert_t (infer_type_subst (ZIP (tvs,ts')) t) =
    type_subst (alist_to_fmap (ZIP (tvs, MAP convert_t ts'))) t) ∧
 (!ts tvs ts'.
    (LENGTH tvs = LENGTH ts') ∧
    EVERY (check_freevars 0 tvs) ts ⇒
    MAP convert_t (MAP (infer_type_subst (ZIP (tvs,ts'))) ts) =
    MAP (type_subst (alist_to_fmap (ZIP (tvs, MAP convert_t ts')))) ts)`,
ho_match_mp_tac t_induction >>
rw [check_freevars_def, convert_t_def, type_subst_def, infer_type_subst_def] >|
[full_case_tac >>
     full_case_tac >>
     fs [ALOOKUP_FAILS] >>
     imp_res_tac ALOOKUP_MEM >>
     REPEAT (pop_assum mp_tac) >>
     rw [MAP_ZIP] >>
     REPEAT (pop_assum mp_tac) >>
     Q.SPEC_TAC (`tvs`,`tvs`) >>
     induct_on `ts'` >>
     rw [] >>
     cases_on `tvs` >>
     fs [] >>
     metis_tac [optionTheory.SOME_11],
 metis_tac []]);

val unconvert_t_def = tDefine "unconvert_t" `
(unconvert_t (Tvar_db n) = Infer_Tvar_db n) ∧
(unconvert_t (Tapp ts tc) = Infer_Tapp (MAP unconvert_t ts) tc)`
(wf_rel_tac `measure t_size` >>
 rw [] >>
 induct_on `ts` >>
 rw [t_size_def] >>
 full_simp_tac (srw_ss()++ARITH_ss) []);

val unconvert_t_ind = theorem"unconvert_t_ind"

val unconvert_t_Tword = Q.store_thm("unconvert_t_Tword[simp]",
  `unconvert_t (Tword wz) = Infer_Tapp [] (TC_word wz)`,
  EVAL_TAC);

val check_freevars_empty_convert_unconvert_id = store_thm("check_freevars_empty_convert_unconvert_id",
``!t. check_freevars n [] t ⇒ convert_t (unconvert_t t) = t``,
  ho_match_mp_tac unconvert_t_ind>>
  rw[]>>fs[unconvert_t_def,convert_t_def,check_freevars_def]>>
  fs[MAP_MAP_o,MAP_EQ_ID,EVERY_MEM])

val check_t_empty_unconvert_convert_id = store_thm("check_t_empty_unconvert_convert_id",
``!t n. check_t n {} t ⇒
  unconvert_t (convert_t t) = t``,
  ho_match_mp_tac (fetch "-" "convert_t_ind") >>
  rw[]>>
  fs[unconvert_t_def,convert_t_def,check_t_def]>>
  fs[MAP_MAP_o,MAP_EQ_ID,EVERY_MEM] >>
  metis_tac []);

val check_freevars_to_check_t = store_thm("check_freevars_to_check_t",
``!t z. check_freevars n [] t ⇒ check_t n {} (unconvert_t t)``,
  ho_match_mp_tac unconvert_t_ind>>rw[]>>
  fs[unconvert_t_def,check_freevars_def,check_t_def]>>
  fs[EVERY_MAP,EVERY_MEM])

val infer_type_subst_nil = store_thm("infer_type_subst_nil",
  ``(∀t. check_freevars n [] t ⇒ infer_type_subst [] t = unconvert_t t) ∧
    (∀ts. EVERY (check_freevars n []) ts ⇒ MAP (infer_type_subst []) ts = MAP unconvert_t ts)``,
  ho_match_mp_tac(TypeBase.induction_of(``:t``)) >>
  rw[infer_type_subst_def,convert_t_def,unconvert_t_def,check_freevars_def] >>
  fsrw_tac[boolSimps.ETA_ss][]);

(* ---------- relating inference and type system environments ---------- *)


(* We want tscheme_approx max_tvs s (tvs, t) (tvs', t') to hold iff (tvs', t') is
 * more general than (tvs, t) under substitution s constraining unification
 * variables.
 *
 * In general, there are 4 classes of variables that can appear in ts and ts':
 * - de Bruijn variables less than tvs, and hence bound by the type scheme,
 * - de Bruijn variables ≥ tvs that are bound in the enclosing context which
 *     binds max_tvs variables, appearing in t as tvs to tvs + max_tvs,
 * - unification variables constrained by s, and
 * - other unification variables.
 *
 * We assume that s only mentions de Bruijn variables bound in the context, but
 * unlike in t, they appear as 0 to max_tvs (since the substitution is not under
 * the typescheme binder).
 *
 * We'd like to instantiate the bound de Bruijn variables in t' so that it
 * matches t. To do so, we must apply s to both t and t', since they may contain
 * different bound unification variables that are constrained to be the same by
 * s. However, since s may contain de Bruijn type variables, we have to either
 * shift it by tvs/tvs' to avoid capture, or first instantiate both type schemes.
 * Since we have to instantiate one anyway, we choose the latter option.
 *
 * The main question is how to instantiate t. Crucially, we don't want to
 * over-specialise t, so that a less general t' can be matched to t. One
 * approach would be to instantiate t with fresh variables of some sort;
 * however, that does not work well with our general setup which requires all
 * type variables to be explicitly bound somewhere. Instead, we require that t'
 * be able to match the result of any instantiation of t. In fact, we can
 * restrict to variable free substitutions, because for each type parameter to
 * t, there are at least two different types (e.g., int and bool) that can be
 * used to instantiate it, and t' can only match in both cases if it is at least
 * as general at t. Compared to allowing bound type variables and unification
 * variables in the instantiation of t's type parameters, this choice makes
 * tscheme_approx monotone is max_tvs and s (under the SUBMAP relation).
 *
 * Once we instantiate t, we just need tobe able to instantiate t' and then
 * apply the substitution. We directly require that the instantiation of t' not contain
 * free de Bruijn or unification variables to make things work smoothly, the
 * relevant parts of the instantiation won't contain any as neither t, nor its
 * instantion do. In the definition below, the restriction to (FDOM s) is
 * slightly more restrictive, since t could contain unification variables not
 * constrained by s. However, in our use of this definition so far, s is always
 * a sub_completion, and hence FDOM s contains every allocated unification
 * variable.
 *
 * *)

val tscheme_approx_def = Define `
  tscheme_approx max_tvs s (tvs,t) (tvs',t') ⇔
    !subst.
      LENGTH subst = tvs ∧
      EVERY (check_t 0 {}) subst
      ⇒
      ?subst'.
        LENGTH subst' = tvs' ∧
        EVERY (check_t max_tvs (FDOM s)) subst' ∧
        t_walkstar s (infer_deBruijn_subst subst t) =
        t_walkstar s (infer_deBruijn_subst subst' t')`;

val env_rel_sound_def = Define `
  env_rel_sound s ienv tenv tenvE ⇔
    ienv.inf_t = tenv.t ∧
    ienv.inf_c = tenv.c ∧
    !x ts.
      nsLookup ienv.inf_v x = SOME ts
      ⇒
      ?tvs' t'.
        check_freevars (tvs' + num_tvs tenvE) [] t' ∧
        lookup_var x tenvE tenv = SOME (tvs', t') ∧
        tscheme_approx (num_tvs tenvE) s ts (tvs', unconvert_t t')`;

val env_rel_sound_lookup_some = Q.store_thm ("env_rel_sound_lookup_some",
  `!id ts s ienv tenv tenvE.
    nsLookup ienv.inf_v id = SOME ts ∧ env_rel_sound s ienv tenv tenvE
    ⇒
    ?tvs' t'.
      check_freevars (tvs' + num_tvs tenvE) [] t' ∧
      lookup_var id tenvE tenv = SOME (tvs',t') ∧
      tscheme_approx (num_tvs tenvE) s ts (tvs', unconvert_t t')`,
 rw [env_rel_sound_def]);

val db_subst_infer_subst_swap3 = Q.store_thm ("db_subst_infer_subst_swap3",
  `!t tvs s subst.
    t_wfs s ∧
    check_freevars tvs [] t
    ⇒
    convert_t (t_walkstar s (infer_deBruijn_subst subst (unconvert_t t)))
    =
    deBruijn_subst 0 (MAP (convert_t o t_walkstar s) subst) t`,
 ho_match_mp_tac unconvert_t_ind
 >> rw [unconvert_t_def, infer_deBruijn_subst_def, deBruijn_subst_def,
        check_freevars_def, convert_t_def, t_walkstar_eqn1]
 >- rw [EL_MAP]
 >> rw [MAP_MAP_o, combinTheory.o_DEF]
 >> rw [MAP_EQ_f]
 >> first_x_assum drule
 >> fs [EVERY_MEM]
 >> metis_tac []);

val tscheme_approx_weakening = Q.store_thm ("tscheme_approx_weakening",
  `!tvs s1 s2 ts1 ts2.
    tscheme_approx tvs s1 ts1 ts2 ∧
    t_wfs s2 ∧
    s1 SUBMAP s2
    ⇒
    tscheme_approx tvs s2 ts1 ts2`,
 rw []
 >> Cases_on `ts1`
 >> Cases_on `ts2`
 >> fs [tscheme_approx_def]
 >> rw []
 >> first_x_assum (qspec_then `subst` mp_tac)
 >> rw []
 >> qexists_tac `subst'`
 >> rw []
 >- metis_tac [SUBMAP_DEF, check_t_more5, SUBSET_DEF]
 >> metis_tac [t_walkstar_idempotent, t_walkstar_SUBMAP]);

val tscheme_approx0 = Q.store_thm ("tscheme_approx0",
  `!tvs s t. t_wfs s ⇒ tscheme_approx tvs s (0, t) (0, t_walkstar s t)`,
 rw [tscheme_approx_def, LENGTH_NIL, infer_deBruijn_subst_id, t_walkstar_idempotent]);

val env_rel_sound_extend0 = Q.store_thm ("env_rel_sound_extend0",
  `!s x t ienv tenv tenvE.
    env_rel_sound s ienv tenv tenvE ∧
    t_wfs s ∧
    check_t (num_tvs tenvE) (FDOM s) t ∧
    (∀uv. uv ∈ FDOM s ⇒ check_t (num_tvs tenvE) ∅ (t_walkstar s (Infer_Tuvar uv)))
    ⇒
    env_rel_sound s (ienv with inf_v := nsBind x (0,t) ienv.inf_v)
      tenv (Bind_name x 0 (convert_t (t_walkstar s t)) tenvE)`,
 rw [env_rel_sound_def]
 >> Cases_on `Short x = x'`
 >> rw []
 >> simp [lookup_var_def, lookup_varE_def, tveLookup_def, deBruijn_inc0]
 >- (
   `check_t (num_tvs tenvE) {} (t_walkstar s t)`
     by (
       irule (CONJUNCT1 check_t_walkstar)
       >> simp [])
   >> drule check_t_empty_unconvert_convert_id
   >> rw [check_t_to_check_freevars]
   >> fs []
   >> rw []
   >> metis_tac [tscheme_approx0])
 >- (
   fs []
   >> first_x_assum drule
   >> rw []
   >> every_case_tac
   >> fs [lookup_var_def, lookup_varE_def]));

val env_rel_sound_merge0 = Q.store_thm ("env_rel_sound_merge0",
  `!s ienv bindings tenv tenvE.
    t_wfs s ∧
    (∀uv. uv ∈ FDOM s ⇒ check_t (num_tvs tenvE) ∅ (t_walkstar s (Infer_Tuvar uv))) ∧
    EVERY (λ(x,t). check_t 0 (FDOM s) t) bindings ∧
    env_rel_sound s ienv tenv tenvE
    ⇒
    env_rel_sound s
       (ienv with inf_v := nsAppend (alist_to_ns (MAP (λ(n,t). (n,0,t)) bindings)) ienv.inf_v)
       tenv
       (bind_var_list 0 (convert_env s bindings) tenvE)`,
 rw [env_rel_sound_def]
 >> fs [nsLookup_nsAppend_some, nsLookup_alist_to_ns_some, nsLookup_alist_to_ns_none]
 >- (
   rw [lookup_var_def, lookup_varE_def, tveLookup_bvl, convert_env_def, deBruijn_inc0]
   >> fs [ALOOKUP_MAP]
   >> rw []
   >- (
     irule check_t_to_check_freevars
     >> irule (CONJUNCT1 check_t_walkstar)
     >> rw []
     >> fs [EVERY_MEM]
     >> imp_res_tac ALOOKUP_MEM
     >> first_x_assum drule
     >> fs []
     >> metis_tac [check_t_more2, DECIDE ``x + 0n = x``])
   >- (
     rw [tscheme_approx_def]
     >> qexists_tac `subst`
     >> fs [LENGTH_NIL]
     >> rw []
     >> simp [infer_deBruijn_subst_id]
     >> fs []
     >> `check_t (num_tvs tenvE) {} (t_walkstar s t)`
       by (
         irule (CONJUNCT1 check_t_walkstar)
         >> simp []
         >> imp_res_tac ALOOKUP_MEM
         >> fs [EVERY_MEM]
         >> first_x_assum drule
         >> rw []
         >> metis_tac [check_t_more2, DECIDE ``z + 0n = z``])
     >> drule check_t_empty_unconvert_convert_id
     >> rw []
     >> fs [t_walkstar_idempotent]))
 >- (
   first_x_assum drule
   >> rw [lookup_var_def, lookup_varE_def]
   >> CASE_TAC
   >> fs [tveLookup_bvl]
   >> every_case_tac
   >> fs [deBruijn_inc0, ALOOKUP_MAP, convert_env_def]
   >> fs []));

val env_rel_e_sound_letrec_merge0 = Q.store_thm ("env_rel_e_sound_letrec_merge0",
`!funs ienv tenv tenvE s uvs.
  t_wfs s ∧
  (∀uv. uv ∈ FDOM s ⇒ check_t (num_tvs tenvE) ∅ (t_walkstar s (Infer_Tuvar uv))) ∧
  count (uvs + LENGTH funs) ⊆ FDOM s ∧
  env_rel_sound s ienv tenv tenvE
  ⇒
  env_rel_sound s
    (ienv with inf_v :=
      nsAppend
        (alist_to_ns
          (MAP2 (λ(f,x,e) uvar. (f,0,uvar))
            funs
            (MAP (λn. Infer_Tuvar (uvs + n)) (COUNT_LIST (LENGTH funs)))))
        ienv.inf_v)
    tenv
    (bind_var_list 0 (MAP2 (λ(f,x,e) t. (f,t))
                       funs
                       (MAP (λn. convert_t (t_walkstar s (Infer_Tuvar (uvs + n))))
                         (COUNT_LIST (LENGTH funs)))) tenvE)`,
  induct_on `funs` >>
  srw_tac[] [COUNT_LIST_def, bind_var_list_def] >>
  PairCases_on `h` >>
  srw_tac[] [bind_var_list_def] >>
  last_x_assum drule >>
  disch_then drule >>
  full_simp_tac (bool_ss) [DECIDE ``x+SUC y=SUC x + y``] >>
  disch_then drule >>
  disch_then drule >>
  rw [] >>
  drule env_rel_sound_extend0 >>
  simp [MAP_MAP_o, combinTheory.o_DEF] >>
  disch_then (qspecl_then [`h0`, `Infer_Tuvar uvs`] mp_tac) >>
  simp [check_t_def] >>
  fs [SUBSET_DEF] >>
  simp_tac (srw_ss()++ARITH_ss) [ADD1]
  >> rw []
  >> ONCE_REWRITE_TAC [DECIDE ``n + (x + 1) = x + (n + 1n)``]
  >> metis_tac []);

val env_rel_complete_def = Define `
  env_rel_complete s ienv tenv tenvE ⇔
    ienv.inf_t = tenv.t ∧
    ienv.inf_c = tenv.c ∧
    !x tvs t.
      lookup_var x tenvE tenv = SOME (tvs, t)
      ⇒
      ?tvs' t'.
        nsLookup ienv.inf_v x = SOME (tvs', t') ∧
        check_t (tvs' + num_tvs tenvE) {} t' ∧
        tscheme_approx (num_tvs tenvE) s (tvs, unconvert_t t) (tvs', t')`;

val env_rel_e_sound_empty_to = Q.store_thm ("env_rel_e_sound_empty_to",
`!s ienv tenv tenvE.
  t_wfs s ∧ ienv_ok {} ienv ∧ env_rel_sound FEMPTY ienv tenv tenvE
  ⇒
  env_rel_sound s ienv tenv tenvE`,
 rw [env_rel_sound_def]
 >> first_x_assum drule
 >> rw []
 >> rename1 `lookup_var _ _ _ = SOME (tvs', t')`
 >> qexists_tac `tvs'`
 >> qexists_tac `t'`
 >> simp []
 >> irule tscheme_approx_weakening
 >> simp []
 >> qexists_tac `FEMPTY`
 >> simp [SUBMAP_FEMPTY]);

(*
val env_rel_e_sound_extend = Q.store_thm ("env_rel_e_sound_extend",
`!s x tvs t env t' tenv.
  t_wfs s ∧
  env_rel_e_sound s env tenv
  ⇒
  env_rel_e_sound s ((x,tvs,t)::env) (bind_tenv x tvs (convert_t (t_walkstar (infer_deBruijn_inc tvs o_f s) t)) tenv)`,
rw [env_rel_e_sound_def] >>
every_case_tac >>
rw [] >>
rw [lookup_tenv_def, bind_tenv_def, deBruijn_inc0] >>
imp_res_tac inc_wfs>>
fs[t_walkstar_no_vars]
metis_tac []);
*)

(*
val env_rel_e_sound_extend_tvar_empty_subst = Q.store_thm ("env_rel_e_sound_extend_tvar_empty_subst",
`!env tvs tenv.
  check_env {} env ∧ env_rel_e_sound FEMPTY env tenv ⇒ env_rel_e_sound FEMPTY env (bind_tvar tvs tenv)`,
  induct_on `env` >>
  fs [env_rel_e_sound_def] >>
  rw [] >>
  PairCases_on `h` >>
  rw [bind_tvar_def, lookup_tenv_val_def] >>
  fs [t_walkstar_FEMPTY] >>
  res_tac >>
  imp_res_tac lookup_tenv_val_inc >>
  fs[]>>
  reverse (Cases_on`h0=x`)>>fs[]
  >-
    (IF_CASES_TAC>>fs[deBruijn_inc0,num_tvs_def]
    >-
      (fs[nil_deBruijn_inc]>>
      metis_tac[])
    >>
    (fs[check_env_def,deBruijn_inc_def,EVERY_MEM]>>
    `MEM (x,0,t) env` by metis_tac[ALOOKUP_MEM]>>
    res_tac>>fs[]>>
    metis_tac[]))
  >>
    fs[check_env_def]>>rfs[nil_deBruijn_inc,num_tvs_def]>>
    metis_tac[])

val env_rel_e_sound_merge = Q.store_thm ("env_rel_e_sound_merge",
`!s x uv env env' tenv.
  t_wfs s ∧
  env_rel_e_sound s env tenv
  ⇒
  env_rel_e_sound s (MAP (λ(n,t). (n,0,t)) env' ++ env) (bind_var_list 0 (convert_env s env') tenv)`,
  induct_on `env'` >>
  rw [convert_env_def, bind_var_list_def] >>
  res_tac >>
  fs [env_rel_e_sound_def] >>
  rw [] >>
  PairCases_on `h` >>
  fs [] >>
  cases_on `h0 = x` >>
  fs [] >>
  rw [bind_var_list_def, lookup_tenv_val_def,
      deBruijn_inc0, infer_deBruijn_inc0_id, o_f_id]
  >-
    metis_tac[t_walkstar_no_vars,check_t_to_check_freevars]
  >-
    (qexists_tac`[]`>>fs[deBruijn_subst_def]>>
    imp_res_tac check_t_to_check_freevars>>
    imp_res_tac deBruijn_subst_id>>
    fs[COUNT_LIST_def]>>
    metis_tac[t_walkstar_no_vars])
  >>
    res_tac>>
    fs[convert_env_def,num_tvs_def])
    *)

(*
val env_rel_e_sound_merge2 = Q.store_thm ("env_rel_e_sound_merge2",
`!env tenv env'' s tvs.
  env_rel_e_sound FEMPTY env tenv
  ⇒
  env_rel_e_sound FEMPTY
    (MAP (λx. (FST x,tvs,t_walkstar s (SND x))) env'' ++ env)
    (bind_var_list2 (MAP (λx. (FST x,tvs, convert_t (t_walkstar s (SND x)))) env'') tenv)`,
induct_on `env''` >>
rw [bind_var_list2_def] >>
PairCases_on `h` >>
rw [bind_var_list2_def] >>
res_tac >>
fs [env_rel_e_sound_def, bind_tenv_def, lookup_tenv_def] >>
rw [deBruijn_inc0, t_walkstar_FEMPTY] >>
metis_tac [t_walkstar_FEMPTY]);

val env_rel_e_sound_merge3 = Q.store_thm ("env_rel_e_sound_merge3",
`!l l' env tenv s tvs.
(LENGTH l = LENGTH l') ∧
env_rel_e_sound FEMPTY env tenv
⇒
env_rel_e_sound FEMPTY
     (MAP2 (λ(f,x,e) t. (f,tvs,t)) l
        (MAP (λx. t_walkstar s (Infer_Tuvar x))
           l') ++ env)
  (bind_var_list2
     (MAP (λ(x,tvs,t). (x,tvs,convert_t t))
        (MAP2 (λ(f,x,e) t. (f,tvs,t)) l
           (MAP (λx. t_walkstar s (Infer_Tuvar x))
              l'))) tenv)`,
induct_on `l` >>
rw [] >>
cases_on `l'` >>
rw [bind_var_list2_def] >>
fs [] >>
PairCases_on `h` >>
fs [bind_var_list2_def] >>
fs [env_rel_e_sound_def, bind_tenv_def, lookup_tenv_def] >>
rw [deBruijn_inc0, t_walkstar_FEMPTY] >>
fs [t_walkstar_FEMPTY] >>
res_tac >>
metis_tac []);
*)


(*
val env_rel_e_sound_convert_env2 = Q.store_thm ("env_rel_e_sound_convert_env2",
`∀env. check_env {} env ⇒
 env_rel_e_sound FEMPTY env (bind_var_list2 (convert_env2 env) Empty)`,
  Induct >>
  rw [convert_env2_def, bind_var_list2_def, env_rel_e_sound_def] >>
  PairCases_on `h` >>
  Cases_on`h0=x`>>fs[lookup_tenv_val_def,bind_var_list2_def,check_env_def]>>
  fs[deBruijn_inc0]
  >-
    (fs[check_t_to_check_freevars]>>
    qexists_tac`MAP (Tvar_db) (COUNT_LIST tvs)` >>
    fs[LENGTH_COUNT_LIST]>>
    CONJ_TAC
    >-
      fs[EVERY_MAP,COUNT_LIST_GENLIST,EVERY_GENLIST,check_freevars_def]
    >>
    match_mp_tac (deBruijn_subst_id |> CONJUNCT1)>>
    fs[check_t_to_check_freevars])
  >>
  fs[env_rel_e_sound_def]>>
  res_tac>>
  Cases_on`check_t tvs {} t` >> fs[convert_env2_def])
  *)

(*
val tenv_invC_def = Define `
  tenv_invC s tenv tenvE =
  (∀x tvs t.
    lookup_tenv_val x 0 tenvE = SOME (tvs, t)
    ⇒
    (∃n. check_freevars n [] t) ∧
    (*Need a condition like this, not sure exactly what yet*)
    ∃tvs' t'.
    ALOOKUP tenv x = SOME(tvs',t') ∧
    (*Case split on whether we are inside an expression or not
      i.e. whether we have inferencer stuff in the types*)
    if check_t tvs' {} t'
    then
      (*Has no uvars*)
      ∃subst.
        LENGTH subst = tvs' ∧
        EVERY (check_t tvs {}) subst ∧
        infer_deBruijn_subst subst t' = unconvert_t t
    else
      tvs' = 0 ∧ tvs = 0 ∧
      unconvert_t t = t_walkstar s t')`

val tenv_alpha_def = Define`
  tenv_alpha tenv tenvE =
    (tenv_inv FEMPTY tenv tenvE ∧
    tenv_invC FEMPTY tenv tenvE)`
    *)
    (*
val tenv_invC_convert_env2 = Q.store_thm ("tenv_invC_convert_env2",
`!env. check_env {} env ⇒ tenv_invC FEMPTY env (bind_var_list2 (convert_env2 env) Empty)`,
  Induct >>
  rw [convert_env2_def, bind_var_list2_def, tenv_invC_def] >>
  fs[lookup_tenv_val_def]>>
  PairCases_on `h` >>
  Cases_on`h0=x`>>fs[lookup_tenv_val_def,bind_var_list2_def,check_env_def]>>
  fs[deBruijn_inc0]
  >-
    metis_tac[check_t_to_check_freevars]
  >-
    (fs[tenv_invC_def,convert_env2_def]>>
    metis_tac[])
  >-
    (fs[check_t_to_check_freevars]>>
    qexists_tac`GENLIST Infer_Tvar_db tvs` >>
    fs[LENGTH_COUNT_LIST]>>
    CONJ_TAC
    >-
      fs[EVERY_MAP,COUNT_LIST_GENLIST,EVERY_GENLIST,check_t_def]
    >>
    qpat_x_assum `A=t` (SUBST_ALL_TAC o SYM)>>
    imp_res_tac check_t_empty_unconvert_convert_id>>
    fs[]>>
    match_mp_tac (infer_deBruijn_subst_id2 |> CONJUNCT1)>>
    fs[check_t_to_check_freevars])
  >>
  fs[tenv_invC_def,convert_env2_def])

  *)

  (*
val menv_alpha_def = Define`
  menv_alpha = fmap_rel (λitenv tenv. tenv_alpha itenv (bind_var_list2 tenv Empty))`
  *)

  (*
val tenv_alpha_empty = store_thm("tenv_alpha_empty",``
  tenv_alpha [] (bind_var_list2 [] Empty)``,
  fs[tenv_alpha_def,bind_var_list2_def,env_rel_e_sound_def,tenv_invC_def,lookup_tenv_val_def])

val tenv_alpha_convert = store_thm("tenv_alpha_convert",
  ``check_env ∅ tenv ⇒
    tenv_alpha tenv (bind_var_list2 (convert_env2 tenv) Empty) ``,
  rw[tenv_alpha_def,env_rel_e_sound_convert_env2,tenv_invC_convert_env2])

val menv_alpha_convert = store_thm("menv_alpha_convert",
  ``check_menv menv ⇒ menv_alpha menv (convert_menv menv)``,
  rw[menv_alpha_def,convert_menv_def,fmap_rel_OPTREL_FLOOKUP,optionTheory.OPTREL_def,FLOOKUP_o_f] >>
  CASE_TAC >>
  fs[check_menv_def,FEVERY_ALL_FLOOKUP] >>
  res_tac >> fs[GSYM check_env_def] >>
  rw[GSYM convert_env2_def, tenv_alpha_convert])

val env_rel_e_sound_bind_var_list2 = prove(``
  env_rel_e_sound FEMPTY itenv (bind_var_list2 tenv Empty) ∧
  env_rel_e_sound FEMPTY itenv' (bind_var_list2 tenv' Empty) ∧
  set (MAP FST itenv) = set (MAP FST tenv)
  ⇒
  env_rel_e_sound FEMPTY (itenv++itenv') (bind_var_list2 (tenv++tenv') Empty)``,
  rw[env_rel_e_sound_def]>>
  fs[GSYM bvl2_lookup]>>
  fs[ALOOKUP_APPEND]>>
  Cases_on`ALOOKUP itenv x`>>fs[]
  >-
    (`ALOOKUP tenv x = NONE` by metis_tac[ALOOKUP_NONE,EXTENSION]>>
    fs[])
  >>
    qpat_x_assum`x'=A` SUBST_ALL_TAC>>
    res_tac>>
    fs[])

val tenv_invC_bind_var_list2 = prove(``
  tenv_invC FEMPTY itenv (bind_var_list2 tenv Empty) ∧
  tenv_invC FEMPTY itenv' (bind_var_list2 tenv' Empty) ∧
  set (MAP FST itenv) = set (MAP FST tenv)
  ⇒
  tenv_invC FEMPTY (itenv++itenv') (bind_var_list2 (tenv++tenv') Empty)``,
  rw[tenv_invC_def]>>
  fs[GSYM bvl2_lookup]>>
  fs[ALOOKUP_APPEND]>>
  Cases_on `ALOOKUP tenv x`>>fs[]
  >-
    metis_tac[]
  >-
    metis_tac[]
  >-
    (`ALOOKUP itenv x = NONE` by metis_tac[ALOOKUP_NONE,EXTENSION]>>
    fs[])
  >>
    qpat_x_assum`x'=A` SUBST_ALL_TAC>>
    res_tac>>
    fs[])

val tenv_alpha_bind_var_list2 = store_thm("tenv_alpha_bind_var_list2",``
  tenv_alpha itenv (bind_var_list2 tenv Empty) ∧
  set (MAP FST itenv) = set (MAP FST tenv) ∧
  tenv_alpha itenv' (bind_var_list2 tenv' Empty)
  ⇒
  tenv_alpha (itenv++itenv') (bind_var_list2 (tenv++tenv') Empty)``,
  fs[tenv_alpha_def]>>
  metis_tac[env_rel_e_sound_bind_var_list2,env_rel_e_soundC_bind_var_list2])

val check_weakE_EVERY = store_thm("check_weakE_EVERY",
  ``∀env_impl env_spec st.
      (∃st'. check_weakE env_impl env_spec st = (Success (),st')) ⇔
      EVERY (λ(n,tvs_spec,t_spec).
           case ALOOKUP env_impl n of
           | NONE => F
           | SOME (tvs_impl,t_impl) =>
               let t = infer_deBruijn_subst (GENLIST Infer_Tuvar tvs_impl) t_impl in
               IS_SOME (t_unify FEMPTY t_spec t)) env_spec``,
  ho_match_mp_tac check_weakE_ind >>
  conj_tac >- rw[check_weakE_def,success_eqns] >>
  rw[check_weakE_def] >>
  Cases_on`ALOOKUP env_impl n`>>simp[failwith_def] >>
  Cases_on`x`>>simp[success_eqns,init_state_def] >> fs[] >>
  simp[markerTheory.Abbrev_def] >>
  simp[init_infer_state_def] >>
  simp[COUNT_LIST_GENLIST,MAP_GENLIST,ETA_AX] >>
  simp[IS_SOME_EXISTS,PULL_EXISTS] >>
  rw[EQ_IMP_THM] >> rw[] >- (
    fs[LET_THM,IS_SOME_EXISTS] >>
    metis_tac[] ) >>
  simp[markerTheory.Abbrev_def,IS_SOME_EXISTS] )

val convert_env2_anub = store_thm("convert_env2_anub",
  ``∀ls ac. convert_env2 (anub ls ac) = anub (convert_env2 ls) ac``,
  Induct >> fs[anub_def,convert_env2_def] >>
  fs[UNCURRY] >>
  Cases >> fs[anub_def,UNCURRY] >> rw[] >>
  Cases_on`r`>>fs[])

val tenv_bvl_def = Define`
  tenv_bvl venv ⇔  ∃tenv_v. venv = bind_var_list2 tenv_v Empty`

  *)

(*Environment relation at infer_d and above*)
val env_rel_def = Define`
 env_rel tenv ienv ⇔
  ienv_ok {} ienv ∧
  tenv_ok tenv ∧
  env_rel_sound FEMPTY ienv tenv Empty ∧
  env_rel_complete FEMPTY ienv tenv Empty`;

val _ = export_theory ();
