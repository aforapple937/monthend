%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = N_CUST_UTILISATION_LEVEL;
%let num_tol = 0.0005;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACT_&tgt);
    %let act_out  = ACT_&tgt DIFF MATCH;
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
        length MATCH $1;
        DIFF = &tgt - ACT_&tgt;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if abs(&tgt - ACT_&tgt) <= &num_tol    then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete util;
quit;
