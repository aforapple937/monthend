%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = MTH_ARREARS;
%let num_tol = 0.0005;

%if %upcase(&mode) = CHECK %then %do;
    %let act_keep = &tgt;
    %let act_ren  = rename=(&tgt = ACT_&tgt);
    %let act_out  = ACT_&tgt DIFF MATCH;
%end;
%else %do;
    %let act_keep = ;
    %let act_ren  = ;
    %let act_out  = ;
%end;

data WORK.v_ref(keep=DWH_AC_CODE ARREAR_NO SYS_CODE CIF_TYP_CODE CR_STS_CODE);
    length DWH_AC_CODE $50;
    set LBDWH.V_T_MTH_AC_DTL(keep=PROC_DTE AC_CODE ARREAR_NO SYS_CODE
                                  CIF_TYP_CODE CR_STS_CODE
                             rename=(AC_CODE=DWH_AC_CODE));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.term_ln(keep=PRD_CODE);
    length PRD_CODE $50;
    set LBFRS9.T_FRS9_PRD_MSTR(keep=PRODUCT_HIERARCHY_CD LEVEL_4
                               rename=(PRODUCT_HIERARCHY_CD=PRD_CODE));
    where strip(LEVEL_4) = 'Term Loans';
run;

data WORK.ln_derived(keep=PROC_DTE AC_CODE PRD_CODE SYS_CODE CIF_TYP_CODE
                          CR_STS_CODE ARREAR_NO MTH_ARREARS &act_out);
    retain PROC_DTE AC_CODE PRD_CODE SYS_CODE CIF_TYP_CODE CR_STS_CODE
           ARREAR_NO MTH_ARREARS &act_out;
    length DWH_AC_CODE $50;
    format ARREAR_NO MTH_ARREARS 6.;

    if 0 then set WORK.v_ref;

    set LBFRS9.T_MTH_FRS9_LN_DTL(keep=PROC_DTE AC_CODE ORIGINAL_ACCOUNT_NUMBER
                                      ACCT_STATUS_CODE PRD_CODE &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash v(dataset:"WORK.v_ref");
        v.definekey("DWH_AC_CODE");
        v.definedata("ARREAR_NO", "SYS_CODE", "CIF_TYP_CODE", "CR_STS_CODE");
        v.definedone();

        declare hash t(dataset:"WORK.term_ln");
        t.definekey("PRD_CODE");
        t.definedone();
    end;

    call missing(ARREAR_NO, SYS_CODE, CIF_TYP_CODE, CR_STS_CODE);
    DWH_AC_CODE = ORIGINAL_ACCOUNT_NUMBER;
    rc = v.find();

    _is_term = (t.check() = 0);

    if strip(SYS_CODE) = 'TS'
       and strip(CIF_TYP_CODE) in ('INDV', 'STAFF')
       and strip(CR_STS_CODE) = '2'
       and _is_term
        then MTH_ARREARS = 2;
    else MTH_ARREARS = coalesce(ARREAR_NO, 0);

    drop _is_term;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        DIFF = &tgt - ACT_&tgt;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if abs(&tgt - ACT_&tgt) <= &num_tol    then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete v_ref term_ln;
quit;
