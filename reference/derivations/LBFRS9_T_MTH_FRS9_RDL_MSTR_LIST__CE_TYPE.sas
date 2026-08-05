%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.prod_disp(keep=V_PROD_CODE N_PRODUCT_DISPLAY_CODE);
    length V_PROD_CODE $50;
    set WORK.stg_products_b_intf_SG;
run;

data WORK.ce_attr(keep=N_PRODUCT_DISPLAY_CODE V_ATTRIBUTE_ASSIGN_VALUE);
    set WORK.stg_products_attr_intf_SG;
    where strip(V_ATTRIBUTE_VARCHAR_LABEL) = 'CE_PRODUCT_TYPE';
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE
                            N_PRODUCT_DISPLAY_CODE V_ATTRIBUTE_ASSIGN_VALUE CE_TYPE);
    retain PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE
           N_PRODUCT_DISPLAY_CODE V_ATTRIBUTE_ASSIGN_VALUE CE_TYPE;
    length CE_TYPE $20;

    if 0 then set WORK.prod_disp WORK.ce_attr;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_PROD_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash d(dataset:"WORK.prod_disp");
        d.definekey("V_PROD_CODE");
        d.definedata("N_PRODUCT_DISPLAY_CODE");
        d.definedone();

        declare hash a(dataset:"WORK.ce_attr");
        a.definekey("N_PRODUCT_DISPLAY_CODE");
        a.definedata("V_ATTRIBUTE_ASSIGN_VALUE");
        a.definedone();
    end;

    call missing(CE_TYPE, N_PRODUCT_DISPLAY_CODE, V_ATTRIBUTE_ASSIGN_VALUE);

    rc_d = d.find();
    rc_a = a.find();

    CE_TYPE = V_ATTRIBUTE_ASSIGN_VALUE;
run;

proc datasets library=WORK nolist;
    delete prod_disp ce_attr;
quit;
