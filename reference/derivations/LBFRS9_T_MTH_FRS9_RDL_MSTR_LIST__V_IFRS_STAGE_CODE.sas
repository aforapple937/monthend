%let rpt_mth = 30JUN2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.prd_hier(keep=V_PROD_CODE LEVEL_3);
    length V_PROD_CODE $50 LEVEL_3 $20;
    set LBFRS9.T_FRS9_PRD_MSTR(rename=(PRODUCT_HIERARCHY_CD=V_PROD_CODE));
run;

data WORK.invmt_flags(keep=AC_CODE CMA_FLAG CNTRL_BY_TREASURY_FLAG);
    length AC_CODE $50 CMA_FLAG $1 CNTRL_BY_TREASURY_FLAG $1;
    set LBFRS9.T_MTH_FRS9_INVMT_DTL(keep=PROC_DTE AC_CODE CMA_FLAG CNTRL_BY_TREASURY_FLAG);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_TYPE V_PROD_CODE
                            LEVEL_3 N_DELINQUENT_DAYS F_AKPK_FLAG
                            ORIG_RATING CURR_RATING CMA_FLAG
                            F_SMA_FLAG F_RATING_OUTLOOK_WATCH
                            PROD_LV4 N_MONTH_IN_ARREARS
                            F_EXPOSURE_DEFAULT_STATUS_FLAG IMPAIRED_FLAG
                            CNTRL_BY_TREASURY_FLAG
                            CUSTOMER_ID
                            N_OUTSTANDING_AMT N_UNDRAWN_AMOUNT_RCY
                            V_IFRS_STAGE_CODE);
    retain PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_TYPE V_PROD_CODE
           LEVEL_3 N_DELINQUENT_DAYS F_AKPK_FLAG
           ORIG_RATING CURR_RATING CMA_FLAG
           F_SMA_FLAG F_RATING_OUTLOOK_WATCH
           PROD_LV4 N_MONTH_IN_ARREARS
           F_EXPOSURE_DEFAULT_STATUS_FLAG IMPAIRED_FLAG
           CNTRL_BY_TREASURY_FLAG
           CUSTOMER_ID
           N_OUTSTANDING_AMT N_UNDRAWN_AMOUNT_RCY
           V_IFRS_STAGE_CODE;
    length V_IFRS_STAGE_CODE $10 LEVEL_3 $20 AC_CODE $50 CMA_FLAG $1 CNTRL_BY_TREASURY_FLAG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_SEGMENT_TYPE V_PROD_CODE N_DELINQUENT_DAYS
                                             F_AKPK_FLAG ORIG_RATING CURR_RATING
                                             F_SMA_FLAG F_RATING_OUTLOOK_WATCH
                                             PROD_LV4 N_MONTH_IN_ARREARS
                                             F_EXPOSURE_DEFAULT_STATUS_FLAG IMPAIRED_FLAG
                                             CUSTOMER_ID
                                             N_OUTSTANDING_AMT N_UNDRAWN_AMOUNT_RCY);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash h(dataset:"WORK.prd_hier");
        h.definekey("V_PROD_CODE");
        h.definedata("LEVEL_3");
        h.definedone();

        declare hash c(dataset:"WORK.invmt_flags");
        c.definekey("AC_CODE");
        c.definedata("CMA_FLAG","CNTRL_BY_TREASURY_FLAG");
        c.definedone();
    end;

    call missing(LEVEL_3, CMA_FLAG, CNTRL_BY_TREASURY_FLAG);
    rc = h.find();
    AC_CODE = V_ACCOUNT_NUMBER;
    rc2 = c.find();

    V_IFRS_STAGE_CODE = 'STAGE1';

    if V_SEGMENT_TYPE in ('NON RETAIL','RSME')
       and LEVEL_3 not in ('Interbank Placement','Investments')
       and N_DELINQUENT_DAYS > 30
    then V_IFRS_STAGE_CODE = 'STAGE2';

    if V_SEGMENT_TYPE = 'RETAIL' and F_AKPK_FLAG = 'Y'
    then V_IFRS_STAGE_CODE = 'STAGE2';

    orig_num = .;
    curr_num = .;
    if lengthn(strip(ORIG_RATING)) >= 2 and upcase(substr(strip(ORIG_RATING),1,1)) = 'R' then
        orig_num = input(substr(strip(ORIG_RATING),2), ?? 8.);
    if lengthn(strip(CURR_RATING)) >= 2 and upcase(substr(strip(CURR_RATING),1,1)) = 'R' then
        curr_num = input(substr(strip(CURR_RATING),2), ?? 8.);

    if not missing(orig_num) and not missing(curr_num) then notches = curr_num - orig_num;
    else notches = .;

    if V_SEGMENT_TYPE in ('RETAIL','RSME') and not missing(notches) then do;
        if      orig_num in (1,2)     and notches >= 4 then V_IFRS_STAGE_CODE = 'STAGE2';
        else if orig_num in (3,4,5)   and notches >= 3 then V_IFRS_STAGE_CODE = 'STAGE2';
        else if orig_num in (6,7,8)   and notches >= 2 then V_IFRS_STAGE_CODE = 'STAGE2';
        else if orig_num in (9,10,11) and notches >= 1 then V_IFRS_STAGE_CODE = 'STAGE2';
    end;

    if ORIG_RATING = 'UNRATED' and CURR_RATING ne 'UNRATED'
    then V_IFRS_STAGE_CODE = 'STAGE2';

    if CMA_FLAG = 'Y' and LEVEL_3 in ('Interbank Placement','Investments')
    then V_IFRS_STAGE_CODE = 'STAGE2';

    if V_SEGMENT_TYPE in ('NON RETAIL','RSME')
       and (F_SMA_FLAG = 'Y' or F_RATING_OUTLOOK_WATCH = 'Y')
    then V_IFRS_STAGE_CODE = 'STAGE2';

    if V_SEGMENT_TYPE = 'RETAIL'
       and ( (PROD_LV4 = 'Term Loans'            and N_MONTH_IN_ARREARS >= 1)
          or (PROD_LV4 in ('Auto','OD','Cards')  and N_DELINQUENT_DAYS  > 30) )
    then V_IFRS_STAGE_CODE = 'STAGE2';

    if F_EXPOSURE_DEFAULT_STATUS_FLAG = 'Y' or IMPAIRED_FLAG = 'Y'
    then V_IFRS_STAGE_CODE = 'STAGE3';

    if CNTRL_BY_TREASURY_FLAG = 'Y' then V_IFRS_STAGE_CODE = 'STAGE1';
run;

proc sql;
    create table WORK.cust_outstanding as
    select CUSTOMER_ID, sum(N_OUTSTANDING_AMT) as CUST_OUTSTANDING
    from   WORK.mstr_derived
    where  V_SEGMENT_TYPE = 'NON RETAIL'
    group by CUSTOMER_ID;
quit;

%let thr_ccy = MYR;
proc sql noprint;
    select EXCHG_RT into :fx_myr trimmed
    from LBDWH.T_MTH_CURCY_EXCHG
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and CURCY_CODE = "&thr_ccy";
quit;

proc sql;
    create table WORK.mstr_derived as
    select t1.*, t2.CUST_OUTSTANDING
    from       WORK.mstr_derived     as t1
    left join  WORK.cust_outstanding as t2 on t1.CUSTOMER_ID = t2.CUSTOMER_ID;
quit;

data WORK.cross_staging;
    set WORK.mstr_derived;
    where (N_OUTSTANDING_AMT > 0 or N_UNDRAWN_AMOUNT_RCY > 0)
      and V_SEGMENT_TYPE = 'NON RETAIL';
    N_OUT_MYR   = N_OUTSTANDING_AMT / &fx_myr;
    CUST_OS_MYR = CUST_OUTSTANDING  / &fx_myr;
    if (N_DELINQUENT_DAYS > 30 or N_MONTH_IN_ARREARS > 1 or V_IFRS_STAGE_CODE = 'STAGE3')
       and N_OUT_MYR < min(CUST_OS_MYR*0.05, 1000000)
    then EXEMPTED = 'Y';
    else EXEMPTED = 'N';
run;

proc sql;
    create table WORK.max_stage as
    select CUSTOMER_ID, max(V_IFRS_STAGE_CODE) as MAX_STAGE length=10
    from   WORK.cross_staging
    where  EXEMPTED = 'N'
    group by CUSTOMER_ID;
quit;

proc sql;
    create table WORK.mstr_derived as
    select t1.*, t2.EXEMPTED, t2.N_OUT_MYR, t2.CUST_OS_MYR, t3.MAX_STAGE
    from       WORK.mstr_derived  as t1
    left join  WORK.cross_staging as t2 on t1.V_ACCOUNT_NUMBER = t2.V_ACCOUNT_NUMBER
    left join  WORK.max_stage     as t3 on t1.CUSTOMER_ID      = t3.CUSTOMER_ID;
quit;

data WORK.mstr_derived;
    retain PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_TYPE V_PROD_CODE
           LEVEL_3 N_DELINQUENT_DAYS F_AKPK_FLAG
           ORIG_RATING CURR_RATING CMA_FLAG
           F_SMA_FLAG F_RATING_OUTLOOK_WATCH
           PROD_LV4 N_MONTH_IN_ARREARS
           F_EXPOSURE_DEFAULT_STATUS_FLAG IMPAIRED_FLAG
           CNTRL_BY_TREASURY_FLAG
           CUSTOMER_ID
           N_OUTSTANDING_AMT N_UNDRAWN_AMOUNT_RCY
           CUST_OUTSTANDING N_OUT_MYR CUST_OS_MYR EXEMPTED MAX_STAGE
           V_IFRS_STAGE_CODE;
    set WORK.mstr_derived;
    if EXEMPTED = 'N' and MAX_STAGE = 'STAGE2' and V_IFRS_STAGE_CODE = 'STAGE1'
    then V_IFRS_STAGE_CODE = 'STAGE2';
    else if EXEMPTED = 'N' and MAX_STAGE = 'STAGE3'
         and V_IFRS_STAGE_CODE in ('STAGE1','STAGE2')
    then V_IFRS_STAGE_CODE = 'STAGE3';
run;

proc datasets library=WORK nolist;
    delete prd_hier invmt_flags cust_outstanding cross_staging max_stage;
quit;
