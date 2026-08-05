%let rpt_mth = 30JUN2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.party(keep=CUSTOMER_ID MKT_SUB_SEG);
    length CUSTOMER_ID $50 MKT_SUB_SEG $15;
    set LBFRS9.T_MTH_FRS9_PARTY_MSTR(keep=PROC_DTE CIF_NO MKT_SUB_SEG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
    CUSTOMER_ID = cats('SG', CIF_NO);
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID MKT_SUB_SEG V_CUST_MKT_SUB_SEG);
    retain PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID MKT_SUB_SEG V_CUST_MKT_SUB_SEG;
    length V_CUST_MKT_SUB_SEG $60 MKT_SUB_SEG $15;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             CUSTOMER_ID);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash p(dataset:"WORK.party");
        p.definekey("CUSTOMER_ID");
        p.definedata("MKT_SUB_SEG");
        p.definedone();
    end;

    call missing(MKT_SUB_SEG);
    rc = p.find();

    V_CUST_MKT_SUB_SEG = MKT_SUB_SEG;
run;

proc datasets library=WORK nolist;
    delete party;
quit;
