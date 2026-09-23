%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = BASE_RT;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACT_&tgt);
    %let act_out  = ACT_&tgt DIFF;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.ac_ref(keep=DWH_AC_CODE DWH_BASE_RT);
    length DWH_AC_CODE $50;
    set LBDWH.V_T_MTH_AC_DTL(keep=PROC_DTE AC_CODE BASE_RT
                             rename=(AC_CODE=DWH_AC_CODE BASE_RT=DWH_BASE_RT));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.rt_raw(keep=DWH_AC_CODE RT_EFF_DTE PRM_RT_NO);
    length DWH_AC_CODE $50;
    set LBFRS9.T_FRS_RT_INTF(keep=PROC_DTE AC_CODE RT_EFF_DTE PRM_RT_NO
                             rename=(AC_CODE=DWH_AC_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

proc sort data=WORK.rt_raw out=WORK.rt_sorted;
    by DWH_AC_CODE descending RT_EFF_DTE;
run;

data WORK.rt_intf(keep=DWH_AC_CODE PRM_RT_NO);
    set WORK.rt_sorted;
    by DWH_AC_CODE;
    if first.DWH_AC_CODE;
run;

proc sort data=LBFRS9.T_RT_TYP_MSTR(keep=RT_TYP_CODE UPDT_DTE CURR_RT)
          out=WORK.typ_sorted;
    by RT_TYP_CODE descending UPDT_DTE;
run;

data WORK.rt_typ(keep=RT_TYP_CODE CURR_RT);
    set WORK.typ_sorted;
    by RT_TYP_CODE;
    if first.RT_TYP_CODE;
run;

data WORK.ln_derived(keep=PROC_DTE AC_CODE PRM_RT_NO RT_TYP_CODE CURR_RT
                          DWH_BASE_RT BASE_RT &act_out);
    retain PROC_DTE AC_CODE PRM_RT_NO RT_TYP_CODE CURR_RT DWH_BASE_RT BASE_RT &act_out;
    length DWH_AC_CODE $50 RT_TYP_CODE $7;
    format PRM_RT_NO 4. CURR_RT 14.9 DWH_BASE_RT 20.9 BASE_RT 17.9;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE ORIGINAL_ACCOUNT_NUMBER
                                      ACCT_STATUS_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash a(dataset:"WORK.ac_ref");
        a.definekey("DWH_AC_CODE");
        a.definedata("DWH_BASE_RT");
        a.definedone();

        declare hash i(dataset:"WORK.rt_intf");
        i.definekey("DWH_AC_CODE");
        i.definedata("PRM_RT_NO");
        i.definedone();

        declare hash t(dataset:"WORK.rt_typ");
        t.definekey("RT_TYP_CODE");
        t.definedata("CURR_RT");
        t.definedone();
    end;

    call missing(DWH_BASE_RT, PRM_RT_NO, RT_TYP_CODE, CURR_RT);
    DWH_AC_CODE = ORIGINAL_ACCOUNT_NUMBER;
    rc_a = a.find();
    rc_i = i.find();

    if not missing(PRM_RT_NO) and PRM_RT_NO ne 0 then do;
        RT_TYP_CODE = put(PRM_RT_NO, z3.);
        rc_t = t.find();
        BASE_RT = CURR_RT * 100;
    end;
    else BASE_RT = DWH_BASE_RT * 100;

    %if %upcase(&mode) = CHECK %then %do;
        DIFF = &tgt - ACT_&tgt;
    %end;
run;

proc datasets library=WORK nolist;
    delete ac_ref rt_raw rt_sorted rt_intf typ_sorted rt_typ;
quit;

%if %upcase(&mode) = CHECK %then %do;
data WORK.chk_var(keep=ABS_DIFF);
    set WORK.ln_derived;
    ABS_DIFF = abs(DIFF);
run;

proc means data=WORK.chk_var n nmiss max maxdec=12;
    var ABS_DIFF;
    title "&tgt - CHECK &rpt_mth - maximum absolute variance";
    label ABS_DIFF = "Absolute variance";
run;
title;

proc datasets library=WORK nolist;
    delete chk_var;
quit;
%end;
