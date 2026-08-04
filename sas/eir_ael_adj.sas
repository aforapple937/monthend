*ProcessBody;

%let TARGET_MONTH    = %sysfunc(inputn(&PROC_DTE, date9.));
%let PREV_MONTH      = %sysfunc(intnx(month, &TARGET_MONTH, -1, end));

%let TGT_LO          = "%sysfunc(putn(&TARGET_MONTH, date9.)):00:00:00"dt;
%let TGT_HI          = "%sysfunc(putn(%eval(&TARGET_MONTH + 1), date9.)):00:00:00"dt;
%let PRV_LO          = "%sysfunc(putn(&PREV_MONTH, date9.)):00:00:00"dt;
%let PRV_HI          = "%sysfunc(putn(%eval(&PREV_MONTH + 1), date9.)):00:00:00"dt;
%let REMARK_VAL      = AEL - %sysfunc(putn(&TARGET_MONTH, monyy5.));
%let REV_REMARK_VAL  = ER AEL - %sysfunc(putn(&PREV_MONTH, monyy5.));
%let YYMM_TAG        = %sysfunc(putn(&TARGET_MONTH, yymmn4.));

libname BASE "C:\Users\FNLNJE\Documents\My SAS Files";

options dlcreatedir;
libname OUT  "C:\Users\FNLNJE\Documents\My SAS Files\&YYMM_TAG";
libname GLTE "C:\Users\FNLNJE\Documents\My SAS Files\&YYMM_TAG\glte";
options nodlcreatedir;

proc sql noprint;
    delete from BASE.EIR_ADJ_SCH
    where PROC_DTE = &TARGET_MONTH
    ;
quit;

proc sql noprint;
    create table WORK.PREV_MONTH_ACCTS as
    select  ACCOUNT_NUMBER
          , BS
          , ACCT_STATUS_CODE
    from BASE.EIR_ADJ_SCH
    where PROC_DTE = &PREV_MONTH
    ;

    create table WORK.CURRENT_STATUS as
    select distinct
            AC_CODE
          , ACCT_STATUS_CODE
          , BIZ_UNIT_CODE
          , FINANCING_CODE
    from LBFRS9.T_MTH_FRS9_LN_DTL
    where PROC_DTE >= &TGT_LO and PROC_DTE < &TGT_HI
    ;
quit;

proc sql noprint;
    create table WORK.CALCULATED_ADJ as
    select  &TARGET_MONTH                                  as PROC_DTE format=date9.
          , a.ACCOUNT_NUMBER
          , case when b.ACCT_STATUS_CODE = 'Active'
                 then a.BS else 0 end                      as BS
          , case when (b.ACCT_STATUS_CODE = 'Closed'
                       or b.AC_CODE is missing)
                 then a.BS else 0 end                      as PL
          , case when b.AC_CODE is missing
                 then 'Closed'
                 else b.ACCT_STATUS_CODE end               as ACCT_STATUS_CODE
          , b.BIZ_UNIT_CODE
          , case when b.FINANCING_CODE = 'I' then '8999'
                 else '0000' end                           as SUB_ACCOUNT
    from        WORK.PREV_MONTH_ACCTS(where=(ACCT_STATUS_CODE='Active')) as a
    left join   WORK.CURRENT_STATUS                                      as b
        on a.ACCOUNT_NUMBER = b.AC_CODE
    ;
quit;

proc append base=BASE.EIR_ADJ_SCH data=WORK.CALCULATED_ADJ force;
run;

title "EIR Adjustment Summary - %sysfunc(putn(&TARGET_MONTH, monyy7.))";

proc sql;
    select  &TARGET_MONTH       as PROC_DTE format=date9.
          , sum(BS)             as TOTAL_BS  format=comma18.2
          , sum(PL)             as TOTAL_PL  format=comma18.2
    from WORK.CALCULATED_ADJ
    ;
quit;

title;

proc sql noprint;
    create table WORK.GL_SUM_CURR_PREP as
    select  "SGD"                       as CCY
          , BIZ_UNIT_CODE               as COST_CENTRE
          , SUB_ACCOUNT
          , "&REMARK_VAL"               as REMARKS
          , round(sum(BS), 0.01)        as NET_BS
    from WORK.CALCULATED_ADJ
    group by BIZ_UNIT_CODE, SUB_ACCOUNT
    having calculated NET_BS ne 0
    ;
quit;

proc sql noprint;
    create table WORK.PREV_MONTH_DETAILS as
    select distinct
            AC_CODE
          , BIZ_UNIT_CODE
          , FINANCING_CODE
    from LBFRS9.T_MTH_FRS9_LN_DTL
    where PROC_DTE >= &PRV_LO and PROC_DTE < &PRV_HI
    ;

    create table WORK.GL_SUM_REV_PREP as
    select  "SGD"                                          as CCY
          , b.BIZ_UNIT_CODE                                as COST_CENTRE
          , case when b.FINANCING_CODE = 'I' then '8999'
                 else '0000' end                           as SUB_ACCOUNT
          , "&REV_REMARK_VAL"                              as REMARKS
          , round(sum(a.BS), 0.01)                         as NET_BS
    from        WORK.PREV_MONTH_ACCTS    as a
    left join   WORK.PREV_MONTH_DETAILS  as b
        on a.ACCOUNT_NUMBER = b.AC_CODE
    group by b.BIZ_UNIT_CODE, calculated SUB_ACCOUNT
    having calculated NET_BS ne 0
    ;
quit;

data WORK.CURR_ENTRIES;
    retain CCY COST_CENTRE ACCOUNT PRODUCT INTERCO FUTURE1
           SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS;
    length CCY $3   COST_CENTRE $10 ACCOUNT $7 PRODUCT $5
           INTERCO $3 FUTURE1 $5    SUB_ACCOUNT $4 FUTURE3 $4
           DEBIT 8  CREDIT 8        REMARKS $50;
    set WORK.GL_SUM_CURR_PREP;

    PRODUCT = "00000";
    INTERCO = "000";
    FUTURE1 = "00000";
    FUTURE3 = "0000";

    ACCOUNT = "1207001";
    if NET_BS > 0 then do; DEBIT = NET_BS;       CREDIT = 0;             end;
    else               do; DEBIT = 0;            CREDIT = abs(NET_BS);   end;
    output;

    ACCOUNT = "7101701";
    if NET_BS > 0 then do; DEBIT = 0;            CREDIT = NET_BS;        end;
    else               do; DEBIT = abs(NET_BS);  CREDIT = 0;             end;
    output;

    format DEBIT CREDIT 18.2;
    drop NET_BS;
run;

data WORK.REV_ENTRIES;
    retain CCY COST_CENTRE ACCOUNT PRODUCT INTERCO FUTURE1
           SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS;
    length CCY $3   COST_CENTRE $10 ACCOUNT $7 PRODUCT $5
           INTERCO $3 FUTURE1 $5    SUB_ACCOUNT $4 FUTURE3 $4
           DEBIT 8  CREDIT 8        REMARKS $50;
    set WORK.GL_SUM_REV_PREP;

    PRODUCT = "00000";
    INTERCO = "000";
    FUTURE1 = "00000";
    FUTURE3 = "0000";

    ACCOUNT = "1207001";
    if NET_BS > 0 then do; DEBIT = 0;            CREDIT = NET_BS;        end;
    else               do; DEBIT = abs(NET_BS);  CREDIT = 0;             end;
    output;

    ACCOUNT = "7101701";
    if NET_BS > 0 then do; DEBIT = NET_BS;       CREDIT = 0;             end;
    else               do; DEBIT = 0;            CREDIT = abs(NET_BS);   end;
    output;

    format DEBIT CREDIT 18.2;
    drop NET_BS;
run;

data GLTE.EIR_AEL_ENTRIES;
    retain CCY COST_CENTRE ACCOUNT PRODUCT INTERCO FUTURE1
           SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS;
    set WORK.CURR_ENTRIES
        WORK.REV_ENTRIES;
run;

proc datasets library=WORK nolist;
    delete PREV_MONTH_ACCTS
           CURRENT_STATUS
           CALCULATED_ADJ
           GL_SUM_CURR_PREP
           PREV_MONTH_DETAILS
           GL_SUM_REV_PREP
           CURR_ENTRIES
           REV_ENTRIES
           ;
quit;

proc sql noprint;
    delete from LBDSFAU.EIR_ADJ_SCH;
quit;

proc append base=LBDSFAU.EIR_ADJ_SCH data=BASE.EIR_ADJ_SCH force;
run;
