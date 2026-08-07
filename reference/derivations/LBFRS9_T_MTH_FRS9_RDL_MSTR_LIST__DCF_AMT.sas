%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.fx(keep=CURCY_CODE EXCHG_RT);
    set LBDWH.T_MTH_CURCY_EXCHG(keep=PROC_DTE CURCY_CODE EXCHG_RT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.cf_raw(keep=CUSTOMER_ID CF_LCY);
    length CUSTOMER_ID $50;
    set LBFRS9.T_MTH_FRS9_TASC_PARTY_FEED(keep=PROC_DTE CIF_NO CURCY_CODE
                                               RCY_EXP_CF_AMT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;

    if _n_ = 1 then do;
        declare hash f(dataset:"WORK.fx");
        f.definekey("CURCY_CODE");
        f.definedata("EXCHG_RT");
        f.definedone();
    end;

    call missing(EXCHG_RT);
    rc = f.find();

    CUSTOMER_ID = cats('SG', CIF_NO);
    CF_LCY = RCY_EXP_CF_AMT * EXCHG_RT;
run;

proc summary data=LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST
                  (keep=PROC_DTE V_D_ACCOUNT_STATUS CUSTOMER_ID N_LEDGER_BALANCE_AMT
                   where=(PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
                          and V_D_ACCOUNT_STATUS = "Active"))
             nway missing;
    class CUSTOMER_ID;
    var N_LEDGER_BALANCE_AMT;
    output out=WORK.tot(drop=_type_ _freq_) sum=TOT_LEDGER;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID IMPAIRED_FLAG
                            N_LEDGER_BALANCE_AMT TOT_LEDGER CF_LCY DCF_AMT);
    retain PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID IMPAIRED_FLAG
           N_LEDGER_BALANCE_AMT TOT_LEDGER CF_LCY DCF_AMT;
    format DCF_AMT 24.3;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             CUSTOMER_ID IMPAIRED_FLAG
                                             N_LEDGER_BALANCE_AMT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash c(dataset:"WORK.cf_raw");
        c.definekey("CUSTOMER_ID");
        c.definedata("CF_LCY");
        c.definedone();

        declare hash t(dataset:"WORK.tot");
        t.definekey("CUSTOMER_ID");
        t.definedata("TOT_LEDGER");
        t.definedone();
    end;

    call missing(CF_LCY, TOT_LEDGER, DCF_AMT);
    rc_c = c.find();
    rc_t = t.find();

    if not missing(CF_LCY) then do;
        if      strip(IMPAIRED_FLAG) ne 'Y'          then DCF_AMT = 0;
        else if missing(TOT_LEDGER) or TOT_LEDGER = 0 then DCF_AMT = 0;
        else DCF_AMT = CF_LCY * coalesce(N_LEDGER_BALANCE_AMT, 0) / TOT_LEDGER;
    end;
run;

proc datasets library=WORK nolist;
    delete fx cf_raw tot;
quit;
