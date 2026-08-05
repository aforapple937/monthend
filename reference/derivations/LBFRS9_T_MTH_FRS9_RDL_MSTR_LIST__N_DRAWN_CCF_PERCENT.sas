%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.prd_hier(keep=V_PROD_CODE LEVEL_2);
    length V_PROD_CODE $50 LEVEL_2 $20;
    set LBFRS9.T_FRS9_PRD_MSTR(keep=PRODUCT_HIERARCHY_CD LEVEL_2
                               rename=(PRODUCT_HIERARCHY_CD=V_PROD_CODE));
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_TYPE V_PROD_CODE
                            LEVEL_2 CE_TYPE N_DRAWN_CCF_PERCENT);
    retain PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_TYPE V_PROD_CODE
           LEVEL_2 CE_TYPE N_DRAWN_CCF_PERCENT;
    length LEVEL_2 $20;
    format N_DRAWN_CCF_PERCENT 17.11;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_SEGMENT_TYPE V_PROD_CODE CE_TYPE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash h(dataset:"WORK.prd_hier");
        h.definekey("V_PROD_CODE");
        h.definedata("LEVEL_2");
        h.definedone();
    end;

    call missing(LEVEL_2, N_DRAWN_CCF_PERCENT);
    rc = h.find();

    if strip(V_SEGMENT_TYPE) = 'NON RETAIL' and strip(LEVEL_2) = 'Trade' then
    select (strip(CE_TYPE));
        when ('230') N_DRAWN_CCF_PERCENT = 0.5;
        when ('232') N_DRAWN_CCF_PERCENT = 1;
        when ('238') N_DRAWN_CCF_PERCENT = 0.2;
        otherwise;
    end;
run;

proc datasets library=WORK nolist;
    delete prd_hier;
quit;
