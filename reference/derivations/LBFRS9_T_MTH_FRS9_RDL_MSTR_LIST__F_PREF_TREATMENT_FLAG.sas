%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = F_PREF_TREATMENT_FLAG;

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

data WORK.prd_hier(keep=V_PROD_CODE LEVEL_3);
    length V_PROD_CODE $50 LEVEL_3 $20;
    set LBFRS9.T_FRS9_PRD_MSTR(keep=PRODUCT_HIERARCHY_CD LEVEL_3
                               rename=(PRODUCT_HIERARCHY_CD=V_PROD_CODE));
run;

data WORK.invmt(keep=AC_CODE APP_GUAR_CENTRAL_GOVT QUALIFYING_INS_FLAG GUAR_TYP);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_INVMT_DTL(keep=PROC_DTE AC_CODE APP_GUAR_CENTRAL_GOVT
                                         QUALIFYING_INS_FLAG GUAR_TYP);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE LEVEL_3
                            APP_GUAR_CENTRAL_GOVT QUALIFYING_INS_FLAG GUAR_TYP
                            F_PREF_TREATMENT_FLAG &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_PROD_CODE LEVEL_3
           APP_GUAR_CENTRAL_GOVT QUALIFYING_INS_FLAG GUAR_TYP
           F_PREF_TREATMENT_FLAG &act_out;
    length AC_CODE $50 LEVEL_3 $20 APP_GUAR_CENTRAL_GOVT $1
           QUALIFYING_INS_FLAG $1 GUAR_TYP $50 F_PREF_TREATMENT_FLAG $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS V_PROD_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash h(dataset:"WORK.prd_hier");
        h.definekey("V_PROD_CODE");
        h.definedata("LEVEL_3");
        h.definedone();

        declare hash i(dataset:"WORK.invmt");
        i.definekey("AC_CODE");
        i.definedata("APP_GUAR_CENTRAL_GOVT", "QUALIFYING_INS_FLAG", "GUAR_TYP");
        i.definedone();
    end;

    call missing(LEVEL_3, APP_GUAR_CENTRAL_GOVT, QUALIFYING_INS_FLAG, GUAR_TYP,
                 F_PREF_TREATMENT_FLAG);
    rc = h.find();

    AC_CODE = V_ACCOUNT_NUMBER;
    if i.find() = 0 then do;
        if (strip(LEVEL_3) = 'Investments'
            and strip(APP_GUAR_CENTRAL_GOVT) = 'Y')
           or (strip(LEVEL_3) = 'Interbank Placement'
               and strip(QUALIFYING_INS_FLAG) = 'Y')
           or (strip(LEVEL_3) = 'Investments'
               and strip(GUAR_TYP) = 'FEDERAL')
            then F_PREF_TREATMENT_FLAG = 'Y';
        else F_PREF_TREATMENT_FLAG = 'N';
    end;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACTUAL) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACTUAL) then MATCH = 'N';
        else if strip(&tgt) = strip(ACTUAL)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete prd_hier invmt;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
