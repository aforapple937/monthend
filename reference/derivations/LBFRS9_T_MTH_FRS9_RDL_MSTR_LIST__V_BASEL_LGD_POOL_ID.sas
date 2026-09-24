%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = V_BASEL_LGD_POOL_ID;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACTUAL);
    %let act_out  = ACTUAL MATCH;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.bas(keep=AC_CODE BASEL_LGD_CLS);
    length AC_CODE $50 BASEL_LGD_CLS $20;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE BASEL_LGD_CLS)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE BASEL_LGD_CLS)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE BASEL_LGD_CLS)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE BASEL_LGD_CLS)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE BASEL_LGD_CLS);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_TYPE ECL_METHOD
                            BASEL_LGD_CLS V_BASEL_LGD_POOL_ID &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_TYPE ECL_METHOD
           BASEL_LGD_CLS V_BASEL_LGD_POOL_ID &act_out;
    length AC_CODE $50 BASEL_LGD_CLS $20 V_BASEL_LGD_POOL_ID $20;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS
                                             V_SEGMENT_TYPE ECL_METHOD &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash b(dataset:"WORK.bas");
        b.definekey("AC_CODE");
        b.definedata("BASEL_LGD_CLS");
        b.definedone();
    end;

    call missing(BASEL_LGD_CLS);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = b.find();

    if missing(BASEL_LGD_CLS)
       and strip(V_SEGMENT_TYPE) = 'RETAIL'
       and strip(ECL_METHOD) = 'Specific Provision Methodology'
        then V_BASEL_LGD_POOL_ID = 'S3';
    else V_BASEL_LGD_POOL_ID = BASEL_LGD_CLS;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACTUAL) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACTUAL) then MATCH = 'N';
        else if strip(&tgt) = strip(ACTUAL)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete bas;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
