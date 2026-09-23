%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = CHECK;
%let tgt     = F_DISBURSED_IND;

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

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_NAME
                            V_RELEASE_TYPE_CD N_EXPOSURE_LIMIT F_DISBURSED_IND &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER V_SEGMENT_NAME
           V_RELEASE_TYPE_CD N_EXPOSURE_LIMIT F_DISBURSED_IND &act_out;
    length F_DISBURSED_IND $1;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_SEGMENT_NAME V_RELEASE_TYPE_CD
                                             N_EXPOSURE_LIMIT &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    call missing(F_DISBURSED_IND);

    if strip(V_SEGMENT_NAME) in ('SG_Housing','SG_EquityTermLoan','SG_RSME') then do;
        if      strip(V_RELEASE_TYPE_CD) = 'F' then F_DISBURSED_IND = 'F';
        else if strip(V_RELEASE_TYPE_CD) = 'P' then F_DISBURSED_IND = 'P';
        else if missing(V_RELEASE_TYPE_CD)     then do;
            if N_EXPOSURE_LIMIT <= 0 then F_DISBURSED_IND = 'F';
            else                          F_DISBURSED_IND = 'P';
        end;
    end;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ACT_&tgt) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ACT_&tgt) then MATCH = 'N';
        else if strip(&tgt) = strip(ACT_&tgt)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
