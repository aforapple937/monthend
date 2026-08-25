%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

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
                            N_DELINQUENT_DAYS);
    retain PROC_DTE V_ACCOUNT_NUMBER DELQ_DAYS N_DELINQUENT_DAYS;
    length AC_CODE $50;
    format DELQ_DAYS N_DELINQUENT_DAYS 6.;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
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
run;

proc datasets library=WORK nolist;
    delete delq;
quit;
