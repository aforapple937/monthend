%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.party(keep=CUSTOMER_ID SECTOR_CAT);
    length CUSTOMER_ID $50 SECTOR_CAT $6;
    set LBFRS9.T_MTH_FRS9_PARTY_MSTR(keep=PROC_DTE CIF_NO SECTOR_CAT);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
    CUSTOMER_ID = cats('SG', CIF_NO);
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID SECTOR_CAT V_SECTOR_CATEGORY);
    retain PROC_DTE V_ACCOUNT_NUMBER CUSTOMER_ID SECTOR_CAT V_SECTOR_CATEGORY;
    length V_SECTOR_CATEGORY $20 SECTOR_CAT $6;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             CUSTOMER_ID);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash p(dataset:"WORK.party");
        p.definekey("CUSTOMER_ID");
        p.definedata("SECTOR_CAT");
        p.definedone();
    end;

    call missing(SECTOR_CAT);
    rc = p.find();

    V_SECTOR_CATEGORY = SECTOR_CAT;
run;

proc datasets library=WORK nolist;
    delete party;
quit;
