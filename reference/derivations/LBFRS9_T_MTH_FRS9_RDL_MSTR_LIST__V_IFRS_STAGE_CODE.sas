%let rpt_mth = 30JUN2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));

/* V_IFRS_STAGE_CODE defaults to STAGE1 and is promoted to STAGE2 under the
   staging rules below, then to STAGE3 if any STAGE3 rule applies. STAGE3 rules
   are evaluated after all STAGE2 rules so they overwrite STAGE2 (STAGE3 takes
   precedence). A final override forces STAGE1 for treasury-controlled accounts,
   applied last so it overrides every stage. A cross-staging pass then applies a
   customer-level override to NON RETAIL accounts, elaborated below. */

/* Product-hierarchy lookup: PRODUCT_HIERARCHY_CD -> LEVEL_3. */
data WORK.prd_hier(keep=V_PROD_CODE LEVEL_3);
    length V_PROD_CODE $50 LEVEL_3 $20;
    set LBFRS9.T_FRS9_PRD_MSTR(rename=(PRODUCT_HIERARCHY_CD=V_PROD_CODE));
run;

/* Flags not on the master list, sourced from INVMT_DTL for the reporting
   month: CMA_FLAG and CNTRL_BY_TREASURY_FLAG. */
data WORK.invmt_flags(keep=AC_CODE CMA_FLAG CNTRL_BY_TREASURY_FLAG);
    length AC_CODE $50 CMA_FLAG $1 CNTRL_BY_TREASURY_FLAG $1;
    set LBFRS9.T_MTH_FRS9_INVMT_DTL(keep=PROC_DTE AC_CODE CMA_FLAG CNTRL_BY_TREASURY_FLAG);
    where datepart(PROC_DTE) = &rpt_dt;
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
    where datepart(PROC_DTE) = &rpt_dt and V_D_ACCOUNT_STATUS = "Active";

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

    /* default */
    V_IFRS_STAGE_CODE = 'STAGE1';

    /* STAGE2 rule 1 - NON RETAIL/RSME non-interbank/investment delinquency */
    if V_SEGMENT_TYPE in ('NON RETAIL','RSME')
       and LEVEL_3 not in ('Interbank Placement','Investments')
       and N_DELINQUENT_DAYS > 30
    then V_IFRS_STAGE_CODE = 'STAGE2';

    /* STAGE2 rule 2 - RETAIL with AKPK flag */
    if V_SEGMENT_TYPE = 'RETAIL' and F_AKPK_FLAG = 'Y'
    then V_IFRS_STAGE_CODE = 'STAGE2';

    /* Rating notch rule (rule 3): CURR_RATING and ORIG_RATING are held as
       "Rx" (R + grade number, higher number = worse). Both are parsed to a
       numeric grade; a downgrade is curr grade - orig grade. The rule only
       applies when BOTH ratings parse as Rx - any non-Rx value (UNRATED, blank,
       other) leaves the grade missing and the rule is skipped for that row. */

    orig_num = .;
    curr_num = .;
    if lengthn(strip(ORIG_RATING)) >= 2 and upcase(substr(strip(ORIG_RATING),1,1)) = 'R' then
        orig_num = input(substr(strip(ORIG_RATING),2), ?? 8.);
    if lengthn(strip(CURR_RATING)) >= 2 and upcase(substr(strip(CURR_RATING),1,1)) = 'R' then
        curr_num = input(substr(strip(CURR_RATING),2), ?? 8.);

    if not missing(orig_num) and not missing(curr_num) then notches = curr_num - orig_num;
    else notches = .;

    /* STAGE2 rule 3 - RETAIL/RSME notch downgrade */
    if V_SEGMENT_TYPE in ('RETAIL','RSME') and not missing(notches) then do;
        if      orig_num in (1,2)     and notches >= 4 then V_IFRS_STAGE_CODE = 'STAGE2';
        else if orig_num in (3,4,5)   and notches >= 3 then V_IFRS_STAGE_CODE = 'STAGE2';
        else if orig_num in (6,7,8)   and notches >= 2 then V_IFRS_STAGE_CODE = 'STAGE2';
        else if orig_num in (9,10,11) and notches >= 1 then V_IFRS_STAGE_CODE = 'STAGE2';
    end;

    /* STAGE2 rule 4 - origination rating UNRATED but current rating rated */
    if ORIG_RATING = 'UNRATED' and CURR_RATING ne 'UNRATED'
    then V_IFRS_STAGE_CODE = 'STAGE2';

    /* STAGE2 rule 5 - CMA flag on interbank/investment products */
    if CMA_FLAG = 'Y' and LEVEL_3 in ('Interbank Placement','Investments')
    then V_IFRS_STAGE_CODE = 'STAGE2';

    /* STAGE2 rule 6 - NON RETAIL/RSME on SMA or WL */
    if V_SEGMENT_TYPE in ('NON RETAIL','RSME')
       and (F_SMA_FLAG = 'Y' or F_RATING_OUTLOOK_WATCH = 'Y')
    then V_IFRS_STAGE_CODE = 'STAGE2';

    /* STAGE2 rule 7 - RETAIL arrears/delinquency */
    if V_SEGMENT_TYPE = 'RETAIL'
       and ( (PROD_LV4 = 'Term Loans'            and N_MONTH_IN_ARREARS >= 1)
          or (PROD_LV4 in ('Auto','OD','Cards')  and N_DELINQUENT_DAYS  > 30) )
    then V_IFRS_STAGE_CODE = 'STAGE2';

    /* STAGE3 rules - evaluated last so they take precedence over STAGE2 */

    /* STAGE3 rule 1 - default status or impaired */
    if F_EXPOSURE_DEFAULT_STATUS_FLAG = 'Y' or IMPAIRED_FLAG = 'Y'
    then V_IFRS_STAGE_CODE = 'STAGE3';

    /* Final override - treasury-controlled forced to STAGE1 (overrides all) */
    if CNTRL_BY_TREASURY_FLAG = 'Y' then V_IFRS_STAGE_CODE = 'STAGE1';
run;

/*==========================================================================
  CROSS STAGING - NON RETAIL only
  Every material account of a customer inherits the worst stage held by any
  of that customer's material accounts. An account that is both distressed
  and immaterial is EXEMPTED: it neither sets the customer benchmark nor
  receives the override. The override only ever worsens a stage.
==========================================================================*/

/* Customer total outstanding (NON RETAIL) - general pool denominator. */
proc sql;
    create table WORK.cust_outstanding as
    select CUSTOMER_ID, sum(N_OUTSTANDING_AMT) as CUST_OUTSTANDING
    from   WORK.mstr_derived
    where  V_SEGMENT_TYPE = 'NON RETAIL'
    group by CUSTOMER_ID;
quit;

/* MYR rate for the RM1,000,000 materiality cap. */
%let thr_ccy = MYR;
proc sql noprint;
    select EXCHG_RT into :fx_myr trimmed
    from LBDWH.T_MTH_CURCY_EXCHG
    where datepart(PROC_DTE) = &rpt_dt and CURCY_CODE = "&thr_ccy";
quit;

/* Attach customer total. */
proc sql;
    create table WORK.mstr_derived as
    select t1.*, t2.CUST_OUTSTANDING
    from       WORK.mstr_derived     as t1
    left join  WORK.cust_outstanding as t2 on t1.CUSTOMER_ID = t2.CUSTOMER_ID;
quit;

/* Exemption test on NON RETAIL accounts with a positive balance:
   distressed (DPD>30, arrears>1 month, or already STAGE3) AND immaterial. */
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

/* Worst stage per customer over material (non-exempt) accounts only.
   STAGE1<STAGE2<STAGE3 sort in severity order, so max() = worst stage. */
proc sql;
    create table WORK.max_stage as
    select CUSTOMER_ID, max(V_IFRS_STAGE_CODE) as MAX_STAGE length=10
    from   WORK.cross_staging
    where  EXEMPTED = 'N'
    group by CUSTOMER_ID;
quit;

/* Attach account-level EXEMPTED and customer-level MAX_STAGE. */
proc sql;
    create table WORK.mstr_derived as
    select t1.*, t2.EXEMPTED, t2.N_OUT_MYR, t2.CUST_OS_MYR, t3.MAX_STAGE
    from       WORK.mstr_derived  as t1
    left join  WORK.cross_staging as t2 on t1.V_ACCOUNT_NUMBER = t2.V_ACCOUNT_NUMBER
    left join  WORK.max_stage     as t3 on t1.CUSTOMER_ID      = t3.CUSTOMER_ID;
quit;

/* Apply the override - bump a non-exempt account up to the customer's worst
   material stage. */
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
