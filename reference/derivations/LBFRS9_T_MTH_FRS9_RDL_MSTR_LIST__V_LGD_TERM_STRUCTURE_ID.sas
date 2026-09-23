%let rpt_mth = 31AUG2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let mode = DERIVE;
%let tgt  = V_LGD_TERM_STRUCTURE_ID;

%if %upcase(&mode) = CHECK %then %do;
    %let act_out = MATCH;
%end;
%else %do;
    %let act_out = ;
%end;

data WORK.prd(keep=AC_CODE LGD_PROD_TYPE);
    length AC_CODE $50 LGD_PROD_TYPE $7;
    set LBFRS9.T_MTH_FRS9_LN_DTL        (keep=PROC_DTE AC_CODE LGD_PROD_TYPE)
        LBFRS9.T_MTH_FRS9_CC_DTL        (keep=PROC_DTE AC_CODE LGD_PROD_TYPE)
        LBFRS9.T_MTH_FRS9_INVMT_DTL     (keep=PROC_DTE AC_CODE LGD_PROD_TYPE)
        LBFRS9.T_MTH_FRS9_GUARANTEE_DTL (keep=PROC_DTE AC_CODE LGD_PROD_TYPE)
        LBFRS9.T_MTH_FRS9_OD_DTL        (keep=PROC_DTE AC_CODE LGD_PROD_TYPE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER ECL_METHOD V_SEGMENT_NAME
                            MKT_SUB_SEGMENT LGD_PROD_TYPE ENG_LGD_TS
                            V_LGD_TERM_STRUCTURE_ID &act_out);
    retain PROC_DTE V_ACCOUNT_NUMBER ECL_METHOD V_SEGMENT_NAME
           MKT_SUB_SEGMENT LGD_PROD_TYPE ENG_LGD_TS
           V_LGD_TERM_STRUCTURE_ID &act_out;
    length AC_CODE $50 LGD_PROD_TYPE $7 V_LGD_TERM_STRUCTURE_ID $40
           _pfx $20 _x $10 _y $20;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS ECL_METHOD
                                             V_SEGMENT_NAME MKT_SUB_SEGMENT
                                             V_LGD_TERM_STRUCTURE_ID
                                        rename=(V_LGD_TERM_STRUCTURE_ID=ENG_LGD_TS));
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash p(dataset:"WORK.prd");
        p.definekey("AC_CODE");
        p.definedata("LGD_PROD_TYPE");
        p.definedone();
    end;

    call missing(LGD_PROD_TYPE, V_LGD_TERM_STRUCTURE_ID, _pfx, _x, _y);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = p.find();

    if strip(ECL_METHOD) in ('PD LGD Method', 'Specific Provision Methodology')
    then do;

        if strip(V_SEGMENT_NAME) in ('SG_CreditCard', 'SG_EquityTermLoan',
                                     'SG_HirePurchase', 'SG_Housing', 'SG_RSME')
            then V_LGD_TERM_STRUCTURE_ID = strip(V_SEGMENT_NAME);

        else if strip(V_SEGMENT_NAME) in ('SG_Non-Retail', 'SG_ProjectFinance',
                                          'SG_Sovereign', 'SG_Bank',
                                          'SG_IRRS') then do;

            if strip(V_SEGMENT_NAME) = 'SG_IRRS' then _pfx = 'SG_IRRS';
            else _pfx = 'SG_Non-Retail';

            select (strip(MKT_SUB_SEGMENT));
                when ('BUSINESS BANKING')   _x = 'BB';
                when ('COMMERCIAL BANKING') _x = 'CMB';
                when ('GWB-CORPORATE BANK') _x = 'GB';
                when ('GWB-GLOBAL MARKET')  _x = 'GGM';
                otherwise;
            end;

            if not missing(_x) and strip(LGD_PROD_TYPE) = 'ESG' then
                _x = cats(_x, 'ESG');

            /* CLARIFY:
               1. Y is the collateralisation status, but how it is derived is
                  not known, so it is lifted from the engine's own
                  V_LGD_TERM_STRUCTURE_ID rather than built.
               2. Specific Provision Methodology is supposed to give Y = S3,
                  but GWB-CORPORATE BANK does not follow that, and the FSD
                  leaves the rule out for GWB-CORPORATE BANK. */
            _y = scan(ENG_LGD_TS, -1, '_');

            if not missing(_x) and not missing(_y) then
                V_LGD_TERM_STRUCTURE_ID = catx('_', _pfx, _x, _y);
        end;
    end;

    drop _pfx _x _y;

    %if %upcase(&mode) = CHECK %then %do;
        length MATCH $1;
        if      missing(&tgt) and missing(ENG_LGD_TS) then MATCH = 'Y';
        else if missing(&tgt) or  missing(ENG_LGD_TS) then MATCH = 'N';
        else if strip(&tgt) = strip(ENG_LGD_TS)       then MATCH = 'Y';
        else MATCH = 'N';
    %end;
run;

proc datasets library=WORK nolist;
    delete prd;
quit;

%if %upcase(&mode) = CHECK %then %do;
proc freq data=WORK.mstr_derived;
    tables MATCH / nocum missing;
    title "&tgt - CHECK &rpt_mth";
run;
title;
%end;
