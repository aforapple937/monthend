%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = RS_INCLUSION;

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

data WORK.cls(keep=AC_CODE CREDIT_CLS_TYP_CODE);
    length AC_CODE $50 CREDIT_CLS_TYP_CODE $20;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE
                                              CREDIT_CLS_TYP_CODE)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE
                                              CREDIT_CLASS_TYP_CODE
                                         rename=(CREDIT_CLASS_TYP_CODE=CREDIT_CLS_TYP_CODE))
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE
                                              CREDIT_CLASS_TYP_CODE
                                         rename=(CREDIT_CLASS_TYP_CODE=CREDIT_CLS_TYP_CODE))
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE
                                              CREDIT_CLASS_TYP_CODE
                                         rename=(CREDIT_CLASS_TYP_CODE=CREDIT_CLS_TYP_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER CREDIT_CLS_TYP_CODE
                            RS_INCLUSION &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER CREDIT_CLS_TYP_CODE RS_INCLUSION &act_out;
    length AC_CODE $50 CREDIT_CLS_TYP_CODE $20 RS_INCLUSION $20;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash c(dataset:"WORK.cls");
        c.definekey("AC_CODE");
        c.definedata("CREDIT_CLS_TYP_CODE");
        c.definedone();
    end;

    call missing(CREDIT_CLS_TYP_CODE);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = c.find();

    RS_INCLUSION = CREDIT_CLS_TYP_CODE;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete cls;
quit;
