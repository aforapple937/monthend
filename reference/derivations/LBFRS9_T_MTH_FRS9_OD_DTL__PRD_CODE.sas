%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.v_ref(keep=DWH_AC_CODE V_SYS_CODE V_PRD_CODE V_BIZ_PRD_CODE);
    length DWH_AC_CODE $50;
    set LBDWH.V_T_MTH_AC_DTL(keep=PROC_DTE AC_CODE SYS_CODE PRD_CODE
                                  BIZ_PRD_CODE
                             rename=(AC_CODE       = DWH_AC_CODE
                                     SYS_CODE     = V_SYS_CODE
                                     PRD_CODE     = V_PRD_CODE
                                     BIZ_PRD_CODE = V_BIZ_PRD_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.od_derived(keep=PROC_DTE AC_CODE V_SYS_CODE V_PRD_CODE V_BIZ_PRD_CODE
                          PRD_CODE);
    retain PROC_DTE AC_CODE V_SYS_CODE V_PRD_CODE V_BIZ_PRD_CODE PRD_CODE;
    length DWH_AC_CODE $50 PRD_CODE $50;

    if 0 then set WORK.v_ref;

    set LBFRS9.T_MTH_FRS9_OD_DTL(keep=PROC_DTE AC_CODE ORIGINAL_ACCOUNT_NUMBER
                                      ACCT_STATUS_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash v(dataset:"WORK.v_ref");
        v.definekey("DWH_AC_CODE");
        v.definedata("V_SYS_CODE", "V_PRD_CODE", "V_BIZ_PRD_CODE");
        v.definedone();
    end;

    call missing(V_SYS_CODE, V_PRD_CODE, V_BIZ_PRD_CODE);
    DWH_AC_CODE = ORIGINAL_ACCOUNT_NUMBER;
    rc = v.find();

    if      strip(V_SYS_CODE) = 'RB' and strip(V_PRD_CODE) = 'CE' then
        PRD_CODE = 'SG_CBIZ';
    else if strip(V_SYS_CODE) = 'RB' and strip(V_BIZ_PRD_CODE) = 'CRABLE' then
        PRD_CODE = 'SG_CABL';
    else
        PRD_CODE = 'SG_' || strip(V_BIZ_PRD_CODE);
run;

proc datasets library=WORK nolist;
    delete v_ref;
quit;
