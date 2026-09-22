%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = N_CCF_PERCENT;
%let num_tol = 0.0005;

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

/* CLARIFY: open queries on the FSD, raised against this derivation:

   1. The FSD does not mention Bank and Sovereign applying CCF 0. Why is it not
      left blank like Housing and ETL? If blank, it would be treated as 1 when
      calculating EAD.

   2. The FSD said for RSME only revolvers read from account detail. Why did
      non-revolvers also end up reading from account detail? Noted that for
      non-revolvers the CCF is all 1. The FSD also said this reading from
      account detail is for performing accounts - why did NPL also end up
      reading from it?

   3. The FSD said for Housing and ETL the CCF is 0 if the disbursed flag is F
      and 1 if P. Why did all Housing and ETL end up with a blank CCF? Is it
      because the FSD also said this applies only to MBBSG and did not include
      MSL? No issue for P, because a blank CCF ends up treated as 1 when
      calculating EAD, but there is an impact for F, where 0 should be applied.
      Also noted that F have undrawn.

   4. If CUST_UTILISATION is blank the CCF is blank. Is that intended? A blank
      CUST_UTILISATION should arguably be treated as 0, because a blank CCF
      actually ends up treated as 1 when calculating EAD. */

data WORK.ccf(keep=AC_CODE CCF CUST_UTILISATION);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE CCF CUST_UTILISATION)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE CCF CUST_UTILISATION)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE CCF CUST_UTILISATION)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE CCF)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE CCF);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER F_UNCOND_CANCELLED_EXP_IND
                            V_SEGMENT_NAME
                            F_EXPOSURE_DEFAULT_STATUS_FLAG IMPAIRED_FLAG
                            F_NEW_ACCT_FLG CUST_UTILISATION
                            CE_TYPE PROD_LV4 CURR_RATING N_ORIGINAL_MATURITY
                            CCF N_CCF_PERCENT &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER F_UNCOND_CANCELLED_EXP_IND
           V_SEGMENT_NAME
           F_EXPOSURE_DEFAULT_STATUS_FLAG IMPAIRED_FLAG
           F_NEW_ACCT_FLG CUST_UTILISATION
           CE_TYPE PROD_LV4 CURR_RATING N_ORIGINAL_MATURITY
           CCF N_CCF_PERCENT &act_out;
    length AC_CODE $50;
    format N_CCF_PERCENT 17.11;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             F_UNCOND_CANCELLED_EXP_IND V_SEGMENT_NAME
                                             F_EXPOSURE_DEFAULT_STATUS_FLAG IMPAIRED_FLAG
                                             F_NEW_ACCT_FLG
                                             CE_TYPE PROD_LV4 CURR_RATING
                                             N_ORIGINAL_MATURITY &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash c(dataset:"WORK.ccf");
        c.definekey("AC_CODE");
        c.definedata("CCF", "CUST_UTILISATION");
        c.definedone();
    end;

    call missing(CCF, CUST_UTILISATION, N_CCF_PERCENT);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = c.find();

    if      strip(F_UNCOND_CANCELLED_EXP_IND) = 'Y'   then N_CCF_PERCENT = 0;
    else if strip(V_SEGMENT_NAME) = 'SG_RSME'         then N_CCF_PERCENT = CCF;
    else if strip(V_SEGMENT_NAME) = 'SG_HirePurchase' then N_CCF_PERCENT = 0;
    else if strip(V_SEGMENT_NAME) in ('SG_Bank','SG_Sovereign') then N_CCF_PERCENT = 0;
    else if strip(V_SEGMENT_NAME) = 'SG_CreditCard'   then do;
        if strip(F_EXPOSURE_DEFAULT_STATUS_FLAG) = 'Y' or strip(IMPAIRED_FLAG) = 'Y' then
            N_CCF_PERCENT = 1;
        else if strip(F_NEW_ACCT_FLG) = 'Y' then do;
            if not missing(CUST_UTILISATION) then
                N_CCF_PERCENT = 0.6691 + min(1, max(0, CUST_UTILISATION)) * -0.6677;
        end;
        else N_CCF_PERCENT = CCF;
    end;
    else if strip(V_SEGMENT_NAME) in ('SG_IRRS','SG_Non-Retail','SG_ProjectFinance') then
    select (strip(CE_TYPE));
        when ('100') do;
            if      strip(PROD_LV4)    = 'Term Loans' then N_CCF_PERCENT = 1;
            else if strip(CURR_RATING) ne 'UNRATED'   then N_CCF_PERCENT = 0.75;
            else if N_ORIGINAL_MATURITY > 1           then N_CCF_PERCENT = 0.5;
            else                                           N_CCF_PERCENT = 0.2;
        end;
        when ('230') do;
            if      strip(CURR_RATING) ne 'UNRATED'   then N_CCF_PERCENT = 0.5;
            else if N_ORIGINAL_MATURITY > 1           then N_CCF_PERCENT = 0.5;
            else                                           N_CCF_PERCENT = 0.2;
        end;
        when ('232') do;
            if      strip(CURR_RATING) ne 'UNRATED'   then N_CCF_PERCENT = 0.75;
            else if N_ORIGINAL_MATURITY > 1           then N_CCF_PERCENT = 0.5;
            else                                           N_CCF_PERCENT = 0.2;
        end;
        when ('238') N_CCF_PERCENT = 0.2;
        otherwise;
    end;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if abs(&tgt - ACT_&tgt) <= &num_tol    then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete ccf;
quit;
