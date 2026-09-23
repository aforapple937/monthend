%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode    = DERIVE;
%let tgt     = V_PD_TERM_STRUCTURE_ID;

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

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER ECL_METHOD V_SEGMENT_NAME
                            V_PD_TERM_STRUCTURE_ID &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER ECL_METHOD V_SEGMENT_NAME
           V_PD_TERM_STRUCTURE_ID &act_out;
    length V_PD_TERM_STRUCTURE_ID $40;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS
                                             ECL_METHOD V_SEGMENT_NAME &act_keep &act_ren);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    call missing(V_PD_TERM_STRUCTURE_ID);

    if strip(ECL_METHOD) = 'PD LGD Method'
       and strip(V_SEGMENT_NAME) in ('SG_Bank', 'SG_CreditCard',
                                     'SG_EquityTermLoan', 'SG_HirePurchase',
                                     'SG_Housing', 'SG_IRRS', 'SG_Non-Retail',
                                     'SG_ProjectFinance', 'SG_RSME',
                                     'SG_Sovereign') then do;

        /* CLARIFY: every segment takes the term structure of the same name,
           but SG_Sovereign is mapped to SG_Non-Retail. */
        if strip(V_SEGMENT_NAME) = 'SG_Sovereign' then
            V_PD_TERM_STRUCTURE_ID = 'SG_Non-Retail';
        else V_PD_TERM_STRUCTURE_ID = strip(V_SEGMENT_NAME);
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
