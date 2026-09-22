%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = CE_TYPE;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACT_&tgt);
    %let act_out  = ACT_&tgt MATCH;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.prod_disp(keep=V_PROD_CODE N_PRODUCT_DISPLAY_CODE);
    length V_PROD_CODE $50;
    set WORK.stg_products_b_intf_SG;
run;

data WORK.ce_attr(keep=N_PRODUCT_DISPLAY_CODE V_ATTRIBUTE_ASSIGN_VALUE);
    set WORK.stg_products_attr_intf_SG;
    where strip(V_ATTRIBUTE_VARCHAR_LABEL) = 'CE_PRODUCT_TYPE';
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE
                            N_PRODUCT_DISPLAY_CODE V_ATTRIBUTE_ASSIGN_VALUE CE_TYPE &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE
           N_PRODUCT_DISPLAY_CODE V_ATTRIBUTE_ASSIGN_VALUE CE_TYPE &act_out;
    length CE_TYPE $20;

    if 0 then set WORK.prod_disp WORK.ce_attr;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_PROD_CODE &act_keep &act_ren);
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

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete prod_disp ce_attr;
quit;
