%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.prd_hier(keep=V_PROD_CODE LEVEL_4);
    length V_PROD_CODE $50 LEVEL_4 $100;
    set LBFRS9.T_FRS9_PRD_MSTR(keep=PRODUCT_HIERARCHY_CD LEVEL_4
                               rename=(PRODUCT_HIERARCHY_CD=V_PROD_CODE));
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE LEVEL_4 PROD_LV4);
    retain PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE LEVEL_4 PROD_LV4;
    length PROD_LV4 $150 LEVEL_4 $100;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_PROD_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash h(dataset:"WORK.prd_hier");
        h.definekey("V_PROD_CODE");
        h.definedata("LEVEL_4");
        h.definedone();
    end;

    call missing(LEVEL_4);
    rc = h.find();

    PROD_LV4 = LEVEL_4;
    /* NOTE: T_FRS9_PRD_MSTR holds "STD with Other Bank and FI", but the engine
       output carries the spelt-out value - the MFRS9 engine's product level
       derivation is sourced from HO REDW, not T_FRS9_PRD_MSTR. Remap to
       match. */
    if PROD_LV4 = "STD with Other Bank and FI" then
        PROD_LV4 = "Short Term Deposit with Other Bank and FI";
run;

proc datasets library=WORK nolist;
    delete prd_hier;
quit;
