%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = V_SEGMENT_TYPE;

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

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_NAME V_SEGMENT_TYPE &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_NAME V_SEGMENT_TYPE &act_out;
    length V_SEGMENT_TYPE $60;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_SEGMENT_NAME &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    select (strip(V_SEGMENT_NAME));
        when ('SG_Bank','SG_IRRS','SG_Non-Retail','SG_ProjectFinance','SG_Sovereign')
            V_SEGMENT_TYPE = 'NON RETAIL';
        when ('SG_CreditCard','SG_EquityTermLoan','SG_HirePurchase','SG_Housing')
            V_SEGMENT_TYPE = 'RETAIL';
        when ('SG_RSME')
            V_SEGMENT_TYPE = 'RSME';
        otherwise
            call missing(V_SEGMENT_TYPE);
    end;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;
