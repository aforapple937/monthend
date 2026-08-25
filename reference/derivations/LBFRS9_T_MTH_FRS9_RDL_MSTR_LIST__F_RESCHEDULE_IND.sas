%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.resch(keep=AC_CODE RESCHEDULE_FLG);
    length AC_CODE $50 RESCHEDULE_FLG $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE RESCHEDULE_FLG)
        LBFRS9.T_MTH_FRS9_CC_DTL(keep=PROC_DTE AC_CODE RESCHEDULE_FLG)
        LBFRS9.T_MTH_FRS9_OD_DTL(keep=PROC_DTE AC_CODE RESCHEDULED_FLG
                                 rename=(RESCHEDULED_FLG=RESCHEDULE_FLG));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER RESCHEDULE_FLG
                            F_RESCHEDULE_IND);
    retain PROC_DTE V_ACCOUNT_NUMBER RESCHEDULE_FLG F_RESCHEDULE_IND;
    length AC_CODE $50 RESCHEDULE_FLG $1 F_RESCHEDULE_IND $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash r(dataset:"WORK.resch");
        r.definekey("AC_CODE");
        r.definedata("RESCHEDULE_FLG");
        r.definedone();
    end;

    call missing(RESCHEDULE_FLG);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = r.find();

    F_RESCHEDULE_IND = RESCHEDULE_FLG;
run;

proc datasets library=WORK nolist;
    delete resch;
quit;
