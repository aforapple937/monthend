%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.prd_hier(keep=V_PROD_CODE LEVEL_3 LEVEL_4 LEVEL_5);
    length V_PROD_CODE $50 LEVEL_3 $20 LEVEL_4 $100 LEVEL_5 $100;
    set LBFRS9.T_FRS9_PRD_MSTR(keep=PRODUCT_HIERARCHY_CD LEVEL_3 LEVEL_4 LEVEL_5
                               rename=(PRODUCT_HIERARCHY_CD=V_PROD_CODE));
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE
                            LEVEL_3 LEVEL_4 LEVEL_5 F_EXP_REVOLVING_FLAG);
    retain PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE
           LEVEL_3 LEVEL_4 LEVEL_5 F_EXP_REVOLVING_FLAG;
    length F_EXP_REVOLVING_FLAG $1 LEVEL_3 $20 LEVEL_4 $100 LEVEL_5 $100;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_PROD_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash h(dataset:"WORK.prd_hier");
        h.definekey("V_PROD_CODE");
        h.definedata("LEVEL_3", "LEVEL_4", "LEVEL_5");
        h.definedone();
    end;

    call missing(LEVEL_3, LEVEL_4, LEVEL_5);
    rc = h.find();

    if strip(LEVEL_4) = 'Term Loans'
       or strip(LEVEL_5) = 'Hire Purchase'
       or strip(LEVEL_3) in ('Interbank Placement','Investments')
        then F_EXP_REVOLVING_FLAG = 'N';
    else F_EXP_REVOLVING_FLAG = 'Y';
run;

proc datasets library=WORK nolist;
    delete prd_hier;
quit;
