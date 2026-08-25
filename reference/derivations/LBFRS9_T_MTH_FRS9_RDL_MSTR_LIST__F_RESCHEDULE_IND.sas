%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.acd(keep=UNIQUE_ID_NO RESCHEDULE_FLG);
    length UNIQUE_ID_NO $50 RESCHEDULE_FLG $1;
    set LBFRS9.T_MTH_FRS9_RDL_AC_DTL(keep=PROC_DTE UNIQUE_ID_NO RESCHEDULE_FLG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.prd(keep=AC_CODE PRD_RESCHEDULE_FLG);
    length AC_CODE $50 PRD_RESCHEDULE_FLG $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE RESCHEDULE_FLG)
        LBFRS9.T_MTH_FRS9_CC_DTL(keep=PROC_DTE AC_CODE RESCHEDULE_FLG)
        LBFRS9.T_MTH_FRS9_OD_DTL(keep=PROC_DTE AC_CODE RESCHEDULED_FLG
                                 rename=(RESCHEDULED_FLG=RESCHEDULE_FLG));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
    PRD_RESCHEDULE_FLG = RESCHEDULE_FLG;
    drop RESCHEDULE_FLG;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER RESCHEDULE_FLG
                            PRD_RESCHEDULE_FLG F_RESCHEDULE_IND);
    retain PROC_DTE V_ACCOUNT_NUMBER RESCHEDULE_FLG PRD_RESCHEDULE_FLG
           F_RESCHEDULE_IND;
    length UNIQUE_ID_NO $50 AC_CODE $50 RESCHEDULE_FLG $1
           PRD_RESCHEDULE_FLG $1 F_RESCHEDULE_IND $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash a(dataset:"WORK.acd");
        a.definekey("UNIQUE_ID_NO");
        a.definedata("RESCHEDULE_FLG");
        a.definedone();

        declare hash p(dataset:"WORK.prd");
        p.definekey("AC_CODE");
        p.definedata("PRD_RESCHEDULE_FLG");
        p.definedone();
    end;

    call missing(RESCHEDULE_FLG, PRD_RESCHEDULE_FLG);
    UNIQUE_ID_NO = V_ACCOUNT_NUMBER;
    AC_CODE      = V_ACCOUNT_NUMBER;
    rc = a.find();
    rc = p.find();

    F_RESCHEDULE_IND = RESCHEDULE_FLG;
run;

proc datasets library=WORK nolist;
    delete acd prd;
quit;
