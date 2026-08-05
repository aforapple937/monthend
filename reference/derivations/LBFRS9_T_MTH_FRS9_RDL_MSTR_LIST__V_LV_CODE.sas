%let rpt_mth = 30JUN2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.legal_ent(keep=AC_CODE LEGAL_ENTITY_CODE);
    length LEGAL_ENTITY_CODE $20;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE LEGAL_ENTITY_CODE)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE LEGAL_ENTITY_CODE)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE LEGAL_ENTITY_CODE)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE LEGAL_ENTITY_CODE)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE LEGAL_ENTITY_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER LEGAL_ENTITY_CODE V_LV_CODE);
    retain PROC_DTE V_ACCOUNT_NUMBER LEGAL_ENTITY_CODE V_LV_CODE;
    length V_LV_CODE $20 AC_CODE $50 LEGAL_ENTITY_CODE $20;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash s(dataset:"WORK.legal_ent");
        s.definekey("AC_CODE");
        s.definedata("LEGAL_ENTITY_CODE");
        s.definedone();
    end;

    call missing(LEGAL_ENTITY_CODE);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = s.find();
    V_LV_CODE = LEGAL_ENTITY_CODE;
run;

proc datasets library=WORK nolist;
    delete legal_ent;
quit;
