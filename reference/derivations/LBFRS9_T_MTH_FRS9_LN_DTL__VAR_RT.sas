%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = VAR_RT;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACTUAL);
    %let act_out  = ACTUAL DIFF;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.ac_ref(keep=DWH_AC_CODE DWH_VAR_RT);
    length DWH_AC_CODE $50;
    set LBDWH.V_T_MTH_AC_DTL(keep=PROC_DTE AC_CODE VAR_RT
                             rename=(AC_CODE=DWH_AC_CODE VAR_RT=DWH_VAR_RT));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.rt_raw(keep=DWH_AC_CODE RT_EFF_DTE PRM_RT_NO PRM_VAR PRM_VAR_CODE);
    length DWH_AC_CODE $50;
    set LBFRS9.T_FRS_RT_INTF(keep=PROC_DTE AC_CODE RT_EFF_DTE PRM_RT_NO
                                  PRM_VAR PRM_VAR_CODE
                             rename=(AC_CODE=DWH_AC_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

proc sort data=WORK.rt_raw out=WORK.rt_sorted;
    by DWH_AC_CODE descending RT_EFF_DTE;
run;

data WORK.rt_intf(keep=DWH_AC_CODE PRM_RT_NO PRM_VAR PRM_VAR_CODE);
    set WORK.rt_sorted;
    by DWH_AC_CODE;
    if first.DWH_AC_CODE;
run;

data WORK.ln_derived(keep=PROC_DTE AC_CODE PRM_RT_NO PRM_VAR PRM_VAR_CODE
                          DWH_VAR_RT VAR_RT &act_out);
    retain PROC_DTE AC_CODE PRM_RT_NO PRM_VAR PRM_VAR_CODE DWH_VAR_RT VAR_RT
           &act_out;
    length DWH_AC_CODE $50 PRM_VAR_CODE $2;
    format PRM_RT_NO 4. PRM_VAR 13.9 DWH_VAR_RT 20.9 VAR_RT 17.9;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE ORIGINAL_ACCOUNT_NUMBER
                                      ACCT_STATUS_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash a(dataset:"WORK.ac_ref");
        a.definekey("DWH_AC_CODE");
        a.definedata("DWH_VAR_RT");
        a.definedone();

        declare hash i(dataset:"WORK.rt_intf");
        i.definekey("DWH_AC_CODE");
        i.definedata("PRM_RT_NO", "PRM_VAR", "PRM_VAR_CODE");
        i.definedone();
    end;

    call missing(DWH_VAR_RT, PRM_RT_NO, PRM_VAR, PRM_VAR_CODE);
    DWH_AC_CODE = ORIGINAL_ACCOUNT_NUMBER;
    rc_a = a.find();
    rc_i = i.find();

    if not missing(PRM_RT_NO) and PRM_RT_NO ne 0 then do;
        if strip(PRM_VAR_CODE) = '-' then VAR_RT = PRM_VAR * -100;
        else VAR_RT = PRM_VAR * 100;
    end;
    else VAR_RT = DWH_VAR_RT * 100;

    %if %upcase(&mode) = CHECK %then %do;
        DIFF = &tgt - ACTUAL;
    %end;
run;

proc datasets library=WORK nolist;
    delete ac_ref rt_raw rt_sorted rt_intf;
quit;

%if %upcase(&mode) = CHECK %then %do;
data WORK.chk_var(keep=ABS_DIFF);
    set WORK.ln_derived;
    if missing(&tgt) and missing(ACTUAL) then delete;
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
