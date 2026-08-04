*ProcessBody;

libname sasfiles "C:/Users/FNLNJE/Documents/My SAS Files";

%let rpt_dt  = %sysfunc(inputn(&proc_dte, date9.));
%let yymm    = %sysfunc(putn(&rpt_dt, yymmn4.));
%let rpt_lbl = %sysfunc(putn(&rpt_dt, date9.));
%let tol     = 0.000000001;

%let rpt_dtm = "&rpt_lbl:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

libname mth "C:/Users/FNLNJE/Documents/My SAS Files/&yymm";

%macro sora_verify;

%if not %sysfunc(exist(mth.frs9_ln_dtl_patch_sora))
 or not %sysfunc(exist(mth.frs9_rt_dtl_patch_sora)) %then %do;
    %put ERROR: Patch tables not found in the &yymm folder - run the SORA;
    %put ERROR- Rate Patch stored process for &rpt_lbl first.;
    %return;
%end;

proc sort data=mth.frs9_ln_dtl_patch_sora
          out=work.ln_want(keep=AC_CODE BASE_RT_PREV BASE_RT_PATCH PRM_RT_NO);
    by AC_CODE;
run;

proc sort data=LBFRS9.T_MTH_FRS9_LN_DTL
              (keep=PROC_DTE AC_CODE BASE_RT
               where=(PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm))
          out=work.ln_now(rename=(BASE_RT=BASE_RT_NOW) drop=PROC_DTE);
    by AC_CODE;
run;

data work.ln_chk;
    merge work.ln_want(in=w) work.ln_now(in=n);
    by AC_CODE;
    if not w then delete;
    length STATUS $20;

    if      not n                                    then STATUS = "Gone from LN_DTL";
    else if abs(BASE_RT_NOW - BASE_RT_PATCH) <= &tol then STATUS = "Patched";
    else if abs(BASE_RT_NOW - BASE_RT_PREV)  <= &tol then STATUS = "Not patched";
    else                                                  STATUS = "Unexpected value";

    format BASE_RT_PREV BASE_RT_PATCH BASE_RT_NOW 20.9;
    label AC_CODE       = "Account"
          PRM_RT_NO     = "Peg code"
          BASE_RT_PREV  = "Before"
          BASE_RT_PATCH = "Asked for"
          BASE_RT_NOW   = "Now"
          STATUS        = "Status";
run;

proc sort data=mth.frs9_rt_dtl_patch_sora
          out=work.rt_want(keep=AC_CODE RT_EFF_DTE PRM_RT_NO VAR_RT
                                BASE_RT_PREV BASE_RT_PATCH
                                TIER_INT_RT_PREV TIER_INT_RT_PATCH);
    by AC_CODE RT_EFF_DTE;
run;

data work.rt_now;
    set LBFRS9.T_MTH_FRS9_RT_DTL
        (keep=PROC_DTE AC_CODE RT_EFF_DTE BASE_RT TIER_INT_RT
         where=(PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm));
    RT_EFF_DTE = datepart(RT_EFF_DTE);
    rename BASE_RT = BASE_RT_NOW  TIER_INT_RT = TIER_INT_RT_NOW;
    drop PROC_DTE;
run;

proc sort data=work.rt_now;  by AC_CODE RT_EFF_DTE;  run;

data work.rt_dup;
    set work.rt_now;
    by AC_CODE RT_EFF_DTE;
    if not (first.RT_EFF_DTE and last.RT_EFF_DTE);
run;

proc sql noprint;
    select count(*) into :n_dup trimmed from work.rt_dup;
quit;

%if &n_dup > 0 %then %do;
    %put ERROR: &n_dup RT_DTL row(s) share an account and effective date -;
    %put ERROR- the key is not unique, so the comparison cannot be trusted.;
    title "RT_DTL rows sharing an account and effective date";
    proc print data=work.rt_dup(obs=50) noobs;  run;
    title;
    %return;
%end;

data work.rt_chk;
    merge work.rt_want(in=w) work.rt_now(in=n);
    by AC_CODE RT_EFF_DTE;
    if not w then delete;
    length STATUS $20;

    if not n then STATUS = "Gone from RT_DTL";
    else if abs(BASE_RT_NOW     - BASE_RT_PATCH)     <= &tol
        and abs(TIER_INT_RT_NOW - TIER_INT_RT_PATCH) <= &tol
                                                  then STATUS = "Patched";
    else if abs(BASE_RT_NOW     - BASE_RT_PREV)      <= &tol
        and abs(TIER_INT_RT_NOW - TIER_INT_RT_PREV)  <= &tol
                                                  then STATUS = "Not patched";

    else if abs(BASE_RT_NOW - BASE_RT_PATCH) <= &tol
                                                  then STATUS = "Base only";
    else                                               STATUS = "Unexpected value";

    format RT_EFF_DTE date11.
           BASE_RT_PREV BASE_RT_PATCH BASE_RT_NOW
           TIER_INT_RT_PREV TIER_INT_RT_PATCH TIER_INT_RT_NOW 20.9;
    label AC_CODE           = "Account"
          RT_EFF_DTE        = "Effective from"
          PRM_RT_NO         = "Peg code"
          VAR_RT            = "Spread"
          BASE_RT_PREV      = "Base before"
          BASE_RT_PATCH     = "Base asked for"
          BASE_RT_NOW       = "Base now"
          TIER_INT_RT_PREV  = "Tier before"
          TIER_INT_RT_PATCH = "Tier asked for"
          TIER_INT_RT_NOW   = "Tier now"
          STATUS            = "Status";
run;

proc freq data=work.ln_chk noprint;
    tables STATUS / out=work.ln_summ(drop=percent);
run;

proc freq data=work.rt_chk noprint;
    tables STATUS / out=work.rt_summ(drop=percent);
run;

title "SORA Patch Verification &yymm - LN_DTL";
proc print data=work.ln_summ noobs label;
    var STATUS COUNT;
    format COUNT comma12.;
    label STATUS = "Status"  COUNT = "Accounts";
run;
title;

title "SORA Patch Verification &yymm - RT_DTL";
proc print data=work.rt_summ noobs label;
    var STATUS COUNT;
    format COUNT comma12.;
    label STATUS = "Status"  COUNT = "Tiers";
run;
title;

proc sql noprint;
    select count(*) into :n_ln_bad trimmed
      from work.ln_chk where STATUS ne "Patched";
    select count(*) into :n_rt_bad trimmed
      from work.rt_chk where STATUS ne "Patched";
quit;

%if &n_ln_bad > 0 %then %do;
    title "LN_DTL exceptions &yymm - &n_ln_bad";
    proc print data=work.ln_chk(obs=200) noobs label;
        where STATUS ne "Patched";
        var AC_CODE PRM_RT_NO BASE_RT_PREV BASE_RT_PATCH BASE_RT_NOW STATUS;
    run;
    title;
%end;

%if &n_rt_bad > 0 %then %do;
    title "RT_DTL exceptions &yymm - &n_rt_bad";
    proc print data=work.rt_chk(obs=200) noobs label;
        where STATUS ne "Patched";
        var AC_CODE RT_EFF_DTE PRM_RT_NO
            BASE_RT_PREV BASE_RT_PATCH BASE_RT_NOW
            TIER_INT_RT_PREV TIER_INT_RT_PATCH TIER_INT_RT_NOW STATUS;
    run;
    title;
%end;

%if &n_ln_bad = 0 and &n_rt_bad = 0 %then %do;
    data work.ok;
        length Result $90;
        Result = "Every row in both patch files now holds the value asked for";
    run;
    title "SORA Patch Verification &yymm";
    proc print data=work.ok noobs label;  label Result = "Result";  run;
    title;
%end;
%mend;
%sora_verify

proc datasets library=work nolist;
    delete ln_want ln_now ln_chk rt_want rt_now rt_dup rt_chk
           ln_summ rt_summ ok;
quit;
