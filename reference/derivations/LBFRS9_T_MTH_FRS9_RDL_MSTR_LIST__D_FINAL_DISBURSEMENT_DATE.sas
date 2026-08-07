%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.disb(keep=AC_CODE FINAL_DISB_DTE);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE FINAL_DISB_DTE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER FINAL_DISB_DTE
                            D_FINAL_DISBURSEMENT_DATE);
    retain PROC_DTE V_ACCOUNT_NUMBER FINAL_DISB_DTE
           D_FINAL_DISBURSEMENT_DATE;
    length AC_CODE $50;
    format FINAL_DISB_DTE D_FINAL_DISBURSEMENT_DATE datetime20.;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash d(dataset:"WORK.disb");
        d.definekey("AC_CODE");
        d.definedata("FINAL_DISB_DTE");
        d.definedone();
    end;

    call missing(FINAL_DISB_DTE);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = d.find();

    D_FINAL_DISBURSEMENT_DATE = FINAL_DISB_DTE;
run;

proc datasets library=WORK nolist;
    delete disb;
quit;
