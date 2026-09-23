%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = V_SEGMENT_NAME;

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

data WORK.proxy_seg(keep=N_PRODUCT_DISPLAY_CODE V_ATTRIBUTE_ASSIGN_VALUE);
    set WORK.stg_products_attr_intf_SG;
    where strip(V_ATTRIBUTE_VARCHAR_LABEL) = 'Proxy Segment';
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER
                            F_RSME_INCLUSION_IND CURR_RATING RS_INCLUSION
                            CORPORATE_SCORECARD V_SECTOR_CATEGORY MKT_SUB_SEGMENT
                            V_PROD_CODE N_PRODUCT_DISPLAY_CODE V_ATTRIBUTE_ASSIGN_VALUE
                            V_SEGMENT_NAME &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER
           F_RSME_INCLUSION_IND CURR_RATING RS_INCLUSION
           CORPORATE_SCORECARD V_SECTOR_CATEGORY MKT_SUB_SEGMENT
           V_PROD_CODE N_PRODUCT_DISPLAY_CODE V_ATTRIBUTE_ASSIGN_VALUE
           V_SEGMENT_NAME &act_out;
    length V_SEGMENT_NAME $20;

    if 0 then set WORK.prod_disp WORK.proxy_seg;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             F_RSME_INCLUSION_IND CURR_RATING RS_INCLUSION
                                             CORPORATE_SCORECARD V_SECTOR_CATEGORY
                                             MKT_SUB_SEGMENT V_PROD_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash d(dataset:"WORK.prod_disp");
        d.definekey("V_PROD_CODE");
        d.definedata("N_PRODUCT_DISPLAY_CODE");
        d.definedone();

        declare hash x(dataset:"WORK.proxy_seg");
        x.definekey("N_PRODUCT_DISPLAY_CODE");
        x.definedata("V_ATTRIBUTE_ASSIGN_VALUE");
        x.definedone();
    end;

    call missing(V_SEGMENT_NAME, N_PRODUCT_DISPLAY_CODE, V_ATTRIBUTE_ASSIGN_VALUE);

    if F_RSME_INCLUSION_IND = 'Y' then V_SEGMENT_NAME = 'SG_RSME';

    if missing(V_SEGMENT_NAME) and CURR_RATING ne 'UNRATED' then
    select (strip(RS_INCLUSION));
        when ('S01') V_SEGMENT_NAME = 'SG_Housing';
        when ('S03') V_SEGMENT_NAME = 'SG_HirePurchase';
        when ('S04') V_SEGMENT_NAME = 'SG_CreditCard';
        when ('S05') V_SEGMENT_NAME = 'SG_EquityTermLoan';
        otherwise;
    end;

    if missing(V_SEGMENT_NAME) and CURR_RATING ne 'UNRATED' then
    select (strip(CORPORATE_SCORECARD));
        when ('IS') V_SEGMENT_NAME = 'SG_IRRS';
        when ('MD','OH','PI','IH','LG','MI','NB','CN','MP','PD','DI','SM',
              'BC','BJ','BG','BM','BN','BP','BI','FR','IR','IV','OV','ZP',
              'RT','ZR','SA','XX','RE','BK','FM')
                    V_SEGMENT_NAME = 'SG_Non-Retail';
        when ('BD','BE') V_SEGMENT_NAME = 'SG_Bank';
        when ('PF') V_SEGMENT_NAME = 'SG_ProjectFinance';
        otherwise;
    end;

    if missing(V_SEGMENT_NAME) then
    select (strip(V_SECTOR_CATEGORY));
        when ('05')                          V_SEGMENT_NAME = 'SG_Bank';
        when ('01','02')                     V_SEGMENT_NAME = 'SG_Sovereign';
        when ('03','06','07','08','10','11') V_SEGMENT_NAME = 'SG_Non-Retail';
        otherwise;
    end;

    if missing(V_SEGMENT_NAME) then
    select (strip(MKT_SUB_SEGMENT));
        when ('BUSINESS BANKING','COMMERCIAL BANKING',
              'GWB-CORPORATE BANK','GWB-GLOBAL MARKET')
                    V_SEGMENT_NAME = 'SG_Non-Retail';
        otherwise;
    end;

    if missing(V_SEGMENT_NAME) then do;
        rc_d = d.find();
        rc_x = x.find();
        select (strip(V_ATTRIBUTE_ASSIGN_VALUE));
            when ('SG_Credit Cards')     V_SEGMENT_NAME = 'SG_CreditCard';
            when ('SG_Equity Term Loan') V_SEGMENT_NAME = 'SG_EquityTermLoan';
            when ('SG_Hire Purchase')    V_SEGMENT_NAME = 'SG_HirePurchase';
            when ('SG_Housing Loan')     V_SEGMENT_NAME = 'SG_Housing';
            when ('SG_Non-Retail')       V_SEGMENT_NAME = 'SG_Non-Retail';
            when ('SG_RSME')             V_SEGMENT_NAME = 'SG_RSME';
            otherwise;
        end;
    end;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete prod_disp proxy_seg;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
