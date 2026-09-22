%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = N_DELINQUENT_DAYS;
%let num_tol = 0.0005;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACT_&tgt);
    %let act_out  = ACT_&tgt MATCH;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.delq(keep=AC_CODE DELQ_DAYS);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL    (keep=PROC_DTE AC_CODE DELQ_DAYS)
        LBFRS9.T_MTH_FRS9_CC_DTL    (keep=PROC_DTE AC_CODE DELQ_DAYS)
        LBFRS9.T_MTH_FRS9_OD_DTL    (keep=PROC_DTE AC_CODE DELQ_DAYS)
        LBFRS9.T_MTH_FRS9_INVMT_DTL (keep=PROC_DTE AC_CODE DELQ_DAY
                                     rename=(DELQ_DAY=DELQ_DAYS));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER DELQ_DAYS
                            N_DELINQUENT_DAYS &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER DELQ_DAYS N_DELINQUENT_DAYS &act_out;
    length AC_CODE $50;
    format DELQ_DAYS N_DELINQUENT_DAYS 6.;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash d(dataset:"WORK.delq");
        d.definekey("AC_CODE");
        d.definedata("DELQ_DAYS");
        d.definedone();
    end;

    call missing(DELQ_DAYS);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = d.find();

    N_DELINQUENT_DAYS = DELQ_DAYS;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if abs(&tgt - ACT_&tgt) <= &num_tol    then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete delq;
quit;
