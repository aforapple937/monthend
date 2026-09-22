%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = F_REPACKAGING_IND;

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

data WORK.rpk(keep=AC_CODE REPACKAGING_IND);
    length AC_CODE $50 REPACKAGING_IND $1;
    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE REPACKAGING_IND)
        LBFRS9.T_MTH_FRS9_OD_DTL(keep=PROC_DTE AC_CODE REPACKAGING_IND);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER REPACKAGING_IND
                            F_REPACKAGING_IND &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER REPACKAGING_IND F_REPACKAGING_IND &act_out;
    length AC_CODE $50 REPACKAGING_IND $1 F_REPACKAGING_IND $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash r(dataset:"WORK.rpk");
        r.definekey("AC_CODE");
        r.definedata("REPACKAGING_IND");
        r.definedone();
    end;

    call missing(REPACKAGING_IND);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = r.find();

    F_REPACKAGING_IND = REPACKAGING_IND;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete rpk;
quit;
