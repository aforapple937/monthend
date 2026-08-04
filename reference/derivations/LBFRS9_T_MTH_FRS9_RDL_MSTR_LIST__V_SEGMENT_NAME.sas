%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

/* V_SEGMENT_NAME is a priority cascade; each step applies only if no name has
   been assigned yet:
     1. F_RSME_INCLUSION_IND = Y
     2. Rated + RS_INCLUSION code (retail scorecard)
     3. Rated + CORPORATE_SCORECARD code
     4. V_SECTOR_CATEGORY code
     5. MKT_SUB_SEGMENT
     6. Proxy Segment from the product-attribute CSVs
   Unmapped values at any step are left blank. */

/* Step 6 lookups. Proxy segment is reached in two hops from V_PROD_CODE:
   V_PROD_CODE -> N_PRODUCT_DISPLAY_CODE (stg_products_b_intf_SG)
               -> V_ATTRIBUTE_ASSIGN_VALUE (stg_products_attr_intf_SG, where the
                  attribute label is Proxy Segment). */
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
                            V_SEGMENT_NAME);
    retain PROC_DTE V_ACCOUNT_NUMBER
           F_RSME_INCLUSION_IND CURR_RATING RS_INCLUSION
           CORPORATE_SCORECARD V_SECTOR_CATEGORY MKT_SUB_SEGMENT
           V_PROD_CODE N_PRODUCT_DISPLAY_CODE V_ATTRIBUTE_ASSIGN_VALUE
           V_SEGMENT_NAME;
    length V_SEGMENT_NAME $20;

    /* Types and lengths for the two hash lookup variables, taken from the lookup
       datasets. Neither is defined anywhere else in the step, so without this
       both are created numeric by the RETAIN above and definedone() fails on the
       character one. After the RETAIN so column order is unchanged. */
    if 0 then set WORK.prod_disp WORK.proxy_seg;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             F_RSME_INCLUSION_IND CURR_RATING RS_INCLUSION
                                             CORPORATE_SCORECARD V_SECTOR_CATEGORY
                                             MKT_SUB_SEGMENT V_PROD_CODE);
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

    /* 1. RSME inclusion */
    if F_RSME_INCLUSION_IND = 'Y' then V_SEGMENT_NAME = 'SG_RSME';

    /* 2. rated - retail scorecard */
    if missing(V_SEGMENT_NAME) and CURR_RATING ne 'UNRATED' then
    select (strip(RS_INCLUSION));
        when ('S01') V_SEGMENT_NAME = 'SG_Housing';
        when ('S03') V_SEGMENT_NAME = 'SG_HirePurchase';
        when ('S04') V_SEGMENT_NAME = 'SG_CreditCard';
        when ('S05') V_SEGMENT_NAME = 'SG_EquityTermLoan';
        otherwise;
    end;

    /* 3. rated - corporate scorecard */
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

    /* 4. sector category */
    if missing(V_SEGMENT_NAME) then
    select (strip(V_SECTOR_CATEGORY));
        when ('05')                          V_SEGMENT_NAME = 'SG_Bank';
        when ('01','02')                     V_SEGMENT_NAME = 'SG_Sovereign';
        when ('03','06','07','08','10','11') V_SEGMENT_NAME = 'SG_Non-Retail';
        otherwise;
    end;

    /* 5. market sub-segment */
    if missing(V_SEGMENT_NAME) then
    select (strip(MKT_SUB_SEGMENT));
        when ('BUSINESS BANKING','COMMERCIAL BANKING',
              'GWB-CORPORATE BANK','GWB-GLOBAL MARKET')
                    V_SEGMENT_NAME = 'SG_Non-Retail';
        otherwise;
    end;

    /* 6. proxy segment from the product-attribute CSVs */
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
run;

proc datasets library=WORK nolist;
    delete prod_disp proxy_seg;
quit;
