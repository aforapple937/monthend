%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = N_CUST_UTILISATION_LEVEL;

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

/* CLARIFY: N_CUST_UTILISATION_LEVEL on RDL_MSTR_LIST comes through all blank,
   even though CUST_UTILISATION on the FRS9 product tables is populated. */

data WORK.util(keep=AC_CODE CUST_UTILISATION);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE CUST_UTILISATION)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE CUST_UTILISATION)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE CUST_UTILISATION);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CUST_UTILISATION
                            N_CUST_UTILISATION_LEVEL &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER CUST_UTILISATION
           N_CUST_UTILISATION_LEVEL &act_out;
    length AC_CODE $50;
    format N_CUST_UTILISATION_LEVEL 24.3;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash u(dataset:"WORK.util");
        u.definekey("AC_CODE");
        u.definedata("CUST_UTILISATION");
        u.definedone();
    end;

    call missing(CUST_UTILISATION);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = u.find();

    N_CUST_UTILISATION_LEVEL = CUST_UTILISATION;

    %if %upcase(&mode) = CHECK %then %do;
        DIFF = &tgt - ACT_&tgt;
    %end;
run;

proc datasets library=WORK nolist;
    delete util;
quit;

%if %upcase(&mode) = CHECK %then %do;
data WORK.chk_var(keep=ABS_DIFF);
    set WORK.mstr_derived;
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
