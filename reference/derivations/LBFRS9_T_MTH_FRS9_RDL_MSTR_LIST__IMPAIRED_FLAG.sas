%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.imp(keep=CUSTOMER_ID IMPAIRMENT_FLG);
    length CUSTOMER_ID $50 IMPAIRMENT_FLG $1;
    set LBFRS9.T_MTH_FRS9_TASC_PARTY_FEED(keep=PROC_DTE CIF_NO EXPOSURE_ID
                                               IMPAIRMENT_FLG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and EXPOSURE_ID ne "Securities";
    CUSTOMER_ID = cats('SG', CIF_NO);
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID
                            IMPAIRMENT_FLG IMPAIRED_FLAG);
    retain PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID IMPAIRMENT_FLG IMPAIRED_FLAG;
    length IMPAIRMENT_FLG $1 IMPAIRED_FLAG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS CUSTOMER_ID);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash i(dataset:"WORK.imp");
        i.definekey("CUSTOMER_ID");
        i.definedata("IMPAIRMENT_FLG");
        i.definedone();
    end;

    call missing(IMPAIRMENT_FLG);
    rc = i.find();

    IMPAIRED_FLAG = IMPAIRMENT_FLG;
run;

proc datasets library=WORK nolist;
    delete imp;
quit;
