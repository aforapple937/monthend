%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.party(keep=CIF_NO MKT_SUB_SEG_DESC);
    length CIF_NO $50 MKT_SUB_SEG_DESC $60;
    set LBFRS9.T_MTH_FRS9_PARTY_MSTR(keep=PROC_DTE CIF_NO MKT_SUB_SEG_DESC);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.invmt_derived(keep=PROC_DTE AC_CODE PRD_CODE CIF_NO MKT_SUB_SEG_DESC
                             RSME_FLG);
    retain PROC_DTE AC_CODE PRD_CODE CIF_NO MKT_SUB_SEG_DESC RSME_FLG;
    length MKT_SUB_SEG_DESC $60 RSME_FLG $1;
    set LBFRS9.T_MTH_FRS9_INVMT_DTL(keep=PROC_DTE AC_CODE CIF_NO PRD_CODE
                                         ACCT_STATUS_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and ACCT_STATUS_CODE = "Active";

    if _n_ = 1 then do;
        declare hash p(dataset:"WORK.party");
        p.definekey("CIF_NO");
        p.definedata("MKT_SUB_SEG_DESC");
        p.definedone();
    end;

    call missing(MKT_SUB_SEG_DESC, RSME_FLG);
    rc = p.find();

    if strip(PRD_CODE) ne 'SG_NOSTRO' then do;
        if strip(MKT_SUB_SEG_DESC) = 'CFS-SME' then RSME_FLG = 'Y';
        else RSME_FLG = 'N';
    end;
run;

proc datasets library=WORK nolist;
    delete party;
quit;
