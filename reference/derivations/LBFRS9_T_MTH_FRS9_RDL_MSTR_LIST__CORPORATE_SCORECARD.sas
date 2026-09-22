%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = CORPORATE_SCORECARD;

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

data WORK.credit_src(keep=AC_CODE CREDIT_SCORE_SOURCE ORGL_EXT_CREDIT_SCORE_SOURCE);
    length CREDIT_SCORE_SOURCE $10 ORGL_EXT_CREDIT_SCORE_SOURCE $40;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE CREDIT_SCORE_SOURCE)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE CREDIT_SCORE_SOURCE)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE CREDIT_SCORE_SOURCE)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE CREDIT_SCORE_SOURCE)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE ORGL_EXT_CREDIT_SCORE_SOURCE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CREDIT_SCORE_SOURCE
                            ORGL_EXT_CREDIT_SCORE_SOURCE CORPORATE_SCORECARD &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER CREDIT_SCORE_SOURCE
           ORGL_EXT_CREDIT_SCORE_SOURCE CORPORATE_SCORECARD &act_out;
    length CORPORATE_SCORECARD $20 AC_CODE $50
           CREDIT_SCORE_SOURCE $10 ORGL_EXT_CREDIT_SCORE_SOURCE $40;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash s(dataset:"WORK.credit_src");
        s.definekey("AC_CODE");
        s.definedata("CREDIT_SCORE_SOURCE","ORGL_EXT_CREDIT_SCORE_SOURCE");
        s.definedone();
    end;

    call missing(CREDIT_SCORE_SOURCE, ORGL_EXT_CREDIT_SCORE_SOURCE);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = s.find();
    CORPORATE_SCORECARD = coalescec(CREDIT_SCORE_SOURCE, ORGL_EXT_CREDIT_SCORE_SOURCE);

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete credit_src;
quit;
