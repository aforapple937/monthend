*ProcessBody;

%let rpt_dt     = %sysfunc(inputn(&PROC_DTE, date9.));
%let prv_dt     = %sysfunc(intnx(month, &rpt_dt, -1, e));
%let rpt_lit    = "%sysfunc(putn(&rpt_dt, date9.)):00:00:00"dt;
%let prv_lit    = "%sysfunc(putn(&prv_dt, date9.)):00:00:00"dt;
%let curr_yymm  = %sysfunc(putn(&rpt_dt, yymmn4.));
%let prev_yymm  = %sysfunc(putn(&prv_dt, yymmn4.));
%let rpt_lbl    = %sysfunc(putn(&rpt_dt, date9.));
%let remark     = Fut repricing %sysfunc(putn(&rpt_dt, monyy5.));
%let rev_remark = ER - Fut repricing %sysfunc(putn(&prv_dt, monyy5.));

libname FUTREP "C:/Users/FNLNJE/Documents/My SAS Files/futrep";

options dlcreatedir;
libname OUT  "C:/Users/FNLNJE/Documents/My SAS Files/&curr_yymm";
libname GLTE "C:/Users/FNLNJE/Documents/My SAS Files/&curr_yymm/glte";
options nodlcreatedir;

%macro fut_repricing;

    %if not %sysfunc(exist(FUTREP.FUT_REPRICING_&prev_yymm)) %then %do;
        %put ERROR: FUTREP.FUT_REPRICING_&prev_yymm not found - load the prior month schedule before running.;
        %return;
    %end;

    %if %sysfunc(exist(FUTREP.FUT_REPRICING_&curr_yymm)) %then %do;
        %put ERROR: FUTREP.FUT_REPRICING_&curr_yymm already exists - &rpt_lbl has already been built.;
        %put ERROR- Rerunning after RDL has been patched collapses the movement to nil and empties the schedule.;
        %put ERROR- Delete the dataset only if you are certain RDL has not yet been patched for &rpt_lbl..;
        %return;
    %end;

    proc sql noprint;
        create table WORK.TARGET_ACCOUNTS as
        select  PROC_DTE
              , AC_CODE
              , PRD_CODE
              , REPRICE_DATE
              , BIZ_UNIT_CODE
              , FINANCING_CODE
              , LEGAL_ENTITY_CODE
        from LBFRS9.T_MTH_FRS9_LN_DTL
        where PROC_DTE = &rpt_lit
          and REPRICE_DATE > PROC_DTE
          and PRD_CODE in ('SG_HDBHL', 'SG_HL', 'SG_ISLMHL', 'SG_STFHL')
        ;

        select count(*) into :n_nonmsl trimmed
        from WORK.TARGET_ACCOUNTS
        where upcase(strip(LEGAL_ENTITY_CODE)) ne 'MSL'
        ;
    quit;

    %if &n_nonmsl > 0 %then %do;
        %put ERROR: &n_nonmsl account(s) in the population are not MSL - posting file has no entity field, cannot continue.;
        %return;
    %end;

    proc sql noprint;
        create table WORK.EIR_RAW as
        select  a.PROC_DTE
              , a.AC_CODE
              , a.PRD_CODE
              , a.REPRICE_DATE
              , a.BIZ_UNIT_CODE
              , a.FINANCING_CODE
              , cur.LCY_EIR_ADJ_AMT  as CURR_RAW
              , prv.LCY_EIR_ADJ_AMT  as PREV_RAW
        from        WORK.TARGET_ACCOUNTS            as a
        left join   LBFRS9.T_MTH_FRS9_RDL_AC_DTL    as cur
            on  a.AC_CODE     = cur.UNIQUE_ID_NO
            and cur.PROC_DTE  = &rpt_lit
        left join   LBFRS9.T_MTH_FRS9_RDL_AC_DTL    as prv
            on  a.AC_CODE     = prv.UNIQUE_ID_NO
            and prv.PROC_DTE  = &prv_lit
        ;

        select count(*) into :n_no_curr trimmed
        from WORK.EIR_RAW where CURR_RAW is missing;

        select count(*) into :n_no_prev trimmed
        from WORK.EIR_RAW where PREV_RAW is missing;
    quit;

    proc sql noprint;
        create table FUTREP.FUT_REPRICING_&curr_yymm as
        select * from
        (
            select  PROC_DTE
                  , AC_CODE
                  , PRD_CODE
                  , REPRICE_DATE
                  , BIZ_UNIT_CODE
                  , FINANCING_CODE
                  , coalesce(CURR_RAW, 0)                    as CURR_MTH_EIR
                  , coalesce(PREV_RAW, 0)                    as PREV_MTH_EIR
                  , coalesce(CURR_RAW, 0) - coalesce(PREV_RAW, 0)
                                                             as EIR_DIFF
            from WORK.EIR_RAW
        )
        where round(EIR_DIFF, 0.01) ne 0
        ;
    quit;

    data OUT.FRS9_EIR;
        retain PROC_DTE UNIQUE_ID_NO LCY_EIR_ADJ_AMT LEGAL_ENTITY;
        length PROC_DTE        $9
               UNIQUE_ID_NO    $50
               LCY_EIR_ADJ_AMT 8
               LEGAL_ENTITY    $3;
        set WORK.EIR_RAW(rename=(PROC_DTE = _PROC_DTM)
                         where=(CURR_RAW is not missing));

        _d = datepart(_PROC_DTM);

        PROC_DTE        = cats(put(day(_d), z2.), "-",
                               propcase(put(_d, monname3.)), "-",
                               put(mod(year(_d), 100), z2.));
        UNIQUE_ID_NO    = AC_CODE;
        LCY_EIR_ADJ_AMT = coalesce(PREV_RAW, 0);
        LEGAL_ENTITY    = "003";

        if round(CURR_RAW - LCY_EIR_ADJ_AMT, 0.01) = 0 then delete;

        format LCY_EIR_ADJ_AMT 24.3;
        keep PROC_DTE UNIQUE_ID_NO LCY_EIR_ADJ_AMT LEGAL_ENTITY;
    run;

    proc sql noprint;
        create table WORK.AGG_CURR as
        select  BIZ_UNIT_CODE
              , FINANCING_CODE
              , round(sum(EIR_DIFF), 0.01)  as TOTAL_EIR_DIFF
        from FUTREP.FUT_REPRICING_&curr_yymm
        group by BIZ_UNIT_CODE, FINANCING_CODE
        having calculated TOTAL_EIR_DIFF ne 0
        ;

        create table WORK.AGG_PREV as
        select  BIZ_UNIT_CODE
              , FINANCING_CODE
              , round(sum(EIR_DIFF), 0.01)  as TOTAL_EIR_DIFF
        from FUTREP.FUT_REPRICING_&prev_yymm
        group by BIZ_UNIT_CODE, FINANCING_CODE
        having calculated TOTAL_EIR_DIFF ne 0
        ;
    quit;

    data WORK.PREV_ENTRIES;
        retain _ENTRY_ORDER CCY COST_CENTRE ACCOUNT PRODUCT INTERCO
               FUTURE1 SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS;
        length _ENTRY_ORDER 3      CCY $3          COST_CENTRE $20
               ACCOUNT $10         PRODUCT $5      INTERCO $3
               FUTURE1 $5          SUB_ACCOUNT $4  FUTURE3 $4
               DEBIT 8             CREDIT 8        REMARKS $30;
        set WORK.AGG_PREV;

        _ENTRY_ORDER = 1;
        CCY          = "SGD";
        COST_CENTRE  = BIZ_UNIT_CODE;
        PRODUCT      = "00000";
        INTERCO      = "000";
        FUTURE1      = "00000";
        FUTURE3      = "0000";

        SUB_ACCOUNT  = ifc(upcase(strip(FINANCING_CODE)) = "I", "8999", "0000");
        REMARKS      = "&rev_remark";

        abs_amt = abs(TOTAL_EIR_DIFF);

        if TOTAL_EIR_DIFF < 0 then do;
            ACCOUNT = "7101701";  DEBIT = abs_amt;  CREDIT = 0;        output;
            ACCOUNT = "1207001";  DEBIT = 0;        CREDIT = abs_amt;  output;
        end;
        else do;
            ACCOUNT = "1207001";  DEBIT = abs_amt;  CREDIT = 0;        output;
            ACCOUNT = "7101701";  DEBIT = 0;        CREDIT = abs_amt;  output;
        end;

        format DEBIT CREDIT 15.2;
        keep _ENTRY_ORDER CCY COST_CENTRE ACCOUNT PRODUCT INTERCO
             FUTURE1 SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS;
    run;

    data WORK.CURR_ENTRIES;
        retain _ENTRY_ORDER CCY COST_CENTRE ACCOUNT PRODUCT INTERCO
               FUTURE1 SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS;
        length _ENTRY_ORDER 3      CCY $3          COST_CENTRE $20
               ACCOUNT $10         PRODUCT $5      INTERCO $3
               FUTURE1 $5          SUB_ACCOUNT $4  FUTURE3 $4
               DEBIT 8             CREDIT 8        REMARKS $30;
        set WORK.AGG_CURR;

        _ENTRY_ORDER = 2;
        CCY          = "SGD";
        COST_CENTRE  = BIZ_UNIT_CODE;
        PRODUCT      = "00000";
        INTERCO      = "000";
        FUTURE1      = "00000";
        FUTURE3      = "0000";
        SUB_ACCOUNT  = ifc(upcase(strip(FINANCING_CODE)) = "I", "8999", "0000");
        REMARKS      = "&remark";

        abs_amt = abs(TOTAL_EIR_DIFF);

        if TOTAL_EIR_DIFF < 0 then do;
            ACCOUNT = "1207001";  DEBIT = abs_amt;  CREDIT = 0;        output;
            ACCOUNT = "7101701";  DEBIT = 0;        CREDIT = abs_amt;  output;
        end;
        else do;
            ACCOUNT = "7101701";  DEBIT = abs_amt;  CREDIT = 0;        output;
            ACCOUNT = "1207001";  DEBIT = 0;        CREDIT = abs_amt;  output;
        end;

        format DEBIT CREDIT 15.2;
        keep _ENTRY_ORDER CCY COST_CENTRE ACCOUNT PRODUCT INTERCO
             FUTURE1 SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS;
    run;

    data WORK.GL_COMBINED;
        set WORK.PREV_ENTRIES
            WORK.CURR_ENTRIES;
    run;

    proc sort data=WORK.GL_COMBINED
              out=GLTE.FUT_REPRICING_ENTRIES(drop=_ENTRY_ORDER);
        by _ENTRY_ORDER ACCOUNT COST_CENTRE SUB_ACCOUNT;
    run;

    %put NOTE: Accounts with no current-month RDL row: &n_no_curr..;
    %put NOTE: Accounts with no prior-month RDL row: &n_no_prev..;

    proc sql;
        title "Future Repricing EIR - &rpt_lbl";

        select  "&prev_yymm"            as PERIOD          length=6
              , sum(TOTAL_EIR_DIFF)     as TOTAL_EIR_DIFF  format=comma18.2
        from WORK.AGG_PREV
        union all
        select  "&curr_yymm"
              , sum(TOTAL_EIR_DIFF)
        from WORK.AGG_CURR
        order by 1
        ;

        title;
    quit;

    proc datasets library=WORK nolist;
        delete TARGET_ACCOUNTS
               EIR_RAW
               AGG_CURR
               AGG_PREV
               PREV_ENTRIES
               CURR_ENTRIES
               GL_COMBINED
               ;
    quit;

%mend fut_repricing;

%fut_repricing
