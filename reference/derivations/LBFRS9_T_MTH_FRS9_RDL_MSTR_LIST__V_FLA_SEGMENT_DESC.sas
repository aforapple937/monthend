%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

data WORK.fla(keep=V_NAICS_CODE V_FLA_SEGMENT_DESC);
    length V_NAICS_CODE $50;
    set WORK.FLA_SEGMENTATION;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_NAICS_CODE
                            V_FLA_SEGMENT_DESC);
    retain PROC_DTE V_ACCOUNT_NUMBER V_NAICS_CODE V_FLA_SEGMENT_DESC;

    if 0 then set WORK.fla;

    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS V_NAICS_CODE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash f(dataset:"WORK.fla");
        f.definekey("V_NAICS_CODE");
        f.definedata("V_FLA_SEGMENT_DESC");
        f.definedone();
    end;

    call missing(V_FLA_SEGMENT_DESC);
    rc = f.find();
run;

proc datasets library=WORK nolist;
    delete fla;
quit;
