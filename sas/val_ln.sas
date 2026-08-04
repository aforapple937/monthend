*ProcessBody;

libname sasfiles "C:/Users/FNLNJE/Documents/My SAS Files";

%let rpt_dt   = %sysfunc(inputn(&proc_dte, date9.));
%let prv_dt   = %sysfunc(intnx(month, &rpt_dt, -1, e));
%let yymm     = %sysfunc(putn(&rpt_dt, yymmn4.));
%let prv_yymm = %sysfunc(putn(&prv_dt, yymmn4.));
%let tbl      = LN_DTL;
%let shift    = 5;

%let derived  = CREDIT_CLASSIFICATION;

%let ccflags  = DEFAULT_FLG SM_FLG RATING_OUTLOOK_WATCH;

%let enums    = FINANCING_CODE IFRS9_CLASS_CODE LEGAL_ENTITY_CODE;

%let dchk     = MULTI_TIER_INT_FLG RSME_FLG SHORTFALL_FLAG
                UNCOND_CANCELLED_EXP_IND FINANCING_CODE IFRS9_CLASS_CODE
                LEGAL_ENTITY_CODE;

options dlcreatedir;
libname mth "C:/Users/FNLNJE/Documents/My SAS Files/&yymm";

proc sql noprint;
    select distinct COLNAME into :vlist separated by " "
      from sasfiles.valid_values
     where TBL = "&tbl" and COLNAME ne "&derived";
    select count(distinct COLNAME) into :n_col trimmed
      from sasfiles.valid_values where TBL = "&tbl";
quit;

proc sql;
    create table work.allowed as
    select catx("|", v.COLNAME, v.VALUE) as K length=240,
           case when t.NV = 1 then "Y" else "N" end as ONEVAL length=1
      from sasfiles.valid_values as v
      join (select COLNAME, count(*) as NV
              from sasfiles.valid_values
             where TBL = "&tbl" group by COLNAME) as t
        on v.COLNAME = t.COLNAME
     where v.TBL = "&tbl";
quit;

data work.closed_bal(keep=AC_CODE ACCT_STATUS_CODE LEDGER_BALANCE_AMT);
    set LBFRS9.T_MTH_FRS9_&tbl
        (keep=PROC_DTE AC_CODE ACCT_STATUS_CODE LEDGER_BALANCE_AMT
         where=(datepart(PROC_DTE) = &rpt_dt));

    if upcase(strip(ACCT_STATUS_CODE)) ne "ACTIVE"
       and round(LEDGER_BALANCE_AMT, 0.01) ne 0;
run;

proc sql noprint;
    select count(*) into :n_cbal trimmed from work.closed_bal;
quit;

%macro tall(dt=, out=);
    data work.&out(keep=COLNAME VALUE);
        set LBFRS9.T_MTH_FRS9_&tbl
            (keep=&vlist ACCT_STATUS_CODE PROC_DTE
             where=(datepart(PROC_DTE) = &dt
                    and upcase(strip(ACCT_STATUS_CODE)) = "ACTIVE"));

        array c{*} $ _character_;
        array n{*}   _numeric_;
        length COLNAME $32 VALUE $200 CREDIT_CLASSIFICATION $10;

        do i = 1 to dim(c);
            COLNAME = vname(c{i});
            if COLNAME = "ACCT_STATUS_CODE"
               and indexw("&vlist", "ACCT_STATUS_CODE") = 0 then continue;
            VALUE = ifc(missing(c{i}), "(blank)", strip(c{i}));
            output;
        end;
        do i = 1 to dim(n);
            COLNAME = vname(n{i});
            if COLNAME = "PROC_DTE" then continue;
            VALUE = ifc(missing(n{i}), "(blank)",
                        strip(putn(n{i}, "best12.")));
            output;
        end;

        if      upcase(strip(DEFAULT_FLG))          = "Y"
            then CREDIT_CLASSIFICATION = "IMP";
        else if upcase(strip(SM_FLG))               = "Y"
            then CREDIT_CLASSIFICATION = "SMA";
        else if upcase(strip(RATING_OUTLOOK_WATCH)) = "Y"
            then CREDIT_CLASSIFICATION = "WLS";
        else     CREDIT_CLASSIFICATION = "NML/EWS";

        COLNAME = "&derived";
        VALUE   = CREDIT_CLASSIFICATION;
        output;
    run;

    proc freq data=work.&out noprint;
        tables COLNAME * VALUE / out=work.&out._f(drop=percent);
    run;

    proc sql;
        create table work.&out._s as
        select f.COLNAME, f.VALUE, f.COUNT,
               f.COUNT / t.TOT * 100 as PCT
          from work.&out._f as f
          join (select COLNAME, sum(COUNT) as TOT
                  from work.&out._f group by COLNAME) as t
            on f.COLNAME = t.COLNAME;
    quit;
%mend;

%tall(dt=&rpt_dt, out=cur)
%tall(dt=&prv_dt, out=prv)

proc sort data=work.cur_s;  by COLNAME VALUE;  run;
proc sort data=work.prv_s;  by COLNAME VALUE;  run;

data mth.valchk_&yymm;
    merge work.cur_s(in=c rename=(COUNT=ROWS_NOW PCT=PCT_NOW))
          work.prv_s(in=p rename=(COUNT=ROWS_PRV PCT=PCT_PRV));
    by COLNAME VALUE;
    length ALLOWED $1 ONEVAL $1 ISSUE $40 K $240 SORTKEY 8;

    if _n_ = 1 then do;
        declare hash A(dataset:"work.allowed");
        A.definekey("K");
        A.definedata("ONEVAL");
        A.definedone();
    end;

    if ROWS_NOW = . then do; ROWS_NOW = 0; PCT_NOW = 0; end;
    if ROWS_PRV = . then do; ROWS_PRV = 0; PCT_PRV = 0; end;

    K = catx("|", COLNAME, VALUE);
    call missing(ONEVAL);

    if COLNAME = "&derived" then ALLOWED = "Y";
    else ALLOWED = ifc(A.find() = 0, "Y", "N");

    PCT_MOVE = PCT_NOW - PCT_PRV;

    if      ALLOWED = "N"          then ISSUE = "Unexpected value";
    else if ONEVAL = "Y"           then ISSUE = "";
    else if not p                  then ISSUE = "New this month";
    else if not c                  then ISSUE = "Gone this month";
    else if abs(PCT_MOVE) > &shift then ISSUE = "Share shift";
    else                                ISSUE = "";

    if COLNAME = "&derived" then
        select (strip(VALUE));
            when ("NML/EWS") SORTKEY = 1;
            when ("WLS")     SORTKEY = 2;
            when ("SMA")     SORTKEY = 3;
            when ("IMP")     SORTKEY = 4;
            otherwise        SORTKEY = 9;
        end;
    else if indexw("&enums", strip(COLNAME)) > 0 then SORTKEY = 1;
    else if upcase(strip(VALUE)) = "Y"           then SORTKEY = 1;
    else if upcase(strip(VALUE)) = "N"           then SORTKEY = 2;
    else                                              SORTKEY = 3;

    ABS_MOVE = abs(PCT_MOVE);
    format PCT_NOW PCT_PRV PCT_MOVE 8.2;
    drop K;
run;

proc sort data=mth.valchk_&yymm;
    by COLNAME SORTKEY VALUE;
run;

proc sql noprint;
    select count(*) into :n_bad trimmed
      from mth.valchk_&yymm where ISSUE = "Unexpected value";
quit;

%macro prv_ren;
    %local i c;
    %do i = 1 %to %sysfunc(countw(&dchk));
        %let c = %scan(&dchk, &i);
        &c=P_&c
    %end;
%mend;

%macro prv_list;
    %local i;
    %do i = 1 %to %sysfunc(countw(&dchk));
        P_%scan(&dchk, &i)
    %end;
%mend;

proc sort data=LBFRS9.T_MTH_FRS9_&tbl
              (keep=PROC_DTE AC_CODE ACCT_STATUS_CODE &dchk
               where=(datepart(PROC_DTE) = &rpt_dt
                      and upcase(strip(ACCT_STATUS_CODE)) = "ACTIVE"))
          out=work.d_cur(drop=PROC_DTE ACCT_STATUS_CODE);
    by AC_CODE;
run;

proc sort data=LBFRS9.T_MTH_FRS9_&tbl
              (keep=PROC_DTE AC_CODE ACCT_STATUS_CODE &dchk
               where=(datepart(PROC_DTE) = &prv_dt
                      and upcase(strip(ACCT_STATUS_CODE)) = "ACTIVE"))
          out=work.d_prv(drop=PROC_DTE ACCT_STATUS_CODE
                         rename=(%prv_ren));
    by AC_CODE;
run;

data work.d_chg(keep=AC_CODE COLNAME VAL_PRV VAL_NOW);
    merge work.d_cur(in=c) work.d_prv(in=p);
    by AC_CODE;
    if not (c and p) then delete;

    length COLNAME $32 VAL_PRV VAL_NOW $200;
    array now{*} $ &dchk;
    array bef{*} $ %prv_list;

    do i = 1 to dim(now);
        if strip(now{i}) ne strip(bef{i}) then do;
            COLNAME = vname(now{i});
            VAL_PRV = ifc(missing(bef{i}), "(blank)", strip(bef{i}));
            VAL_NOW = ifc(missing(now{i}), "(blank)", strip(now{i}));
            output;
        end;
    end;
run;

proc freq data=work.d_chg noprint;
    tables COLNAME / out=work.d_summ(drop=percent rename=(COUNT=ACCTS_CHG));
run;

proc sort data=work.d_summ;
    by descending ACCTS_CHG;
run;

proc sql noprint;
    select count(*) into :n_dchg trimmed from work.d_summ;
    select count(*) into :n_both trimmed
      from work.d_cur as c, work.d_prv as p where c.AC_CODE = p.AC_CODE;
quit;

%macro show_valchk;

    %if &n_cbal = 0 %then %do;
        data work.ok1;
            length Result $90;
            Result = "All non-active accounts carry a nil ledger balance";
        run;
        title "A. Closed accounts with a balance &yymm";
        proc print data=work.ok1 noobs label;  label Result = "Result";  run;
        title;
    %end;
    %else %do;
        title "A. Closed accounts with a balance &yymm";
        proc print data=work.closed_bal(obs=200) noobs label;
            var AC_CODE ACCT_STATUS_CODE LEDGER_BALANCE_AMT;
            format LEDGER_BALANCE_AMT comma20.2;
            label AC_CODE = "Account"  ACCT_STATUS_CODE = "Status"
                  LEDGER_BALANCE_AMT = "Ledger balance";
        run;
        title;
    %end;

    %if &n_bad = 0 %then %do;
        data work.ok2;
            length Result $90;
            Result = "&tbl active accounts - all &n_col checked column(s) hold only allowed values";
        run;
        title "B. Allowed values &yymm";
        proc print data=work.ok2 noobs label;  label Result = "Result";  run;
        title;
    %end;
    %else %do;
        title "B. Allowed values &yymm";
        proc print data=mth.valchk_&yymm noobs label;
            where ISSUE = "Unexpected value";
            var COLNAME VALUE ROWS_NOW PCT_NOW;
            format ROWS_NOW comma12.;
            label COLNAME = "Column"  VALUE   = "Value"
                  ROWS_NOW = "Rows"   PCT_NOW = "% of rows";
        run;
        title;
    %end;

    title "C. Share of rows &yymm against &prv_yymm";
    proc print data=mth.valchk_&yymm noobs label;
        where ONEVAL ne "Y" and indexw("&ccflags", strip(COLNAME)) = 0;
        var COLNAME VALUE ROWS_PRV PCT_PRV ROWS_NOW PCT_NOW
            PCT_MOVE ISSUE;
        format ROWS_PRV ROWS_NOW comma12.;
        label COLNAME  = "Column"     VALUE   = "Value"
              ROWS_PRV = "Rows prior" PCT_PRV = "% prior"
              ROWS_NOW = "Rows now"   PCT_NOW = "% now"
              PCT_MOVE = "Move (pts)" ISSUE   = "Issue";
    run;
    title;

%mend;
%show_valchk

proc datasets library=work nolist;
    delete allowed cur cur_f cur_s prv prv_f prv_s closed_bal
           d_cur d_prv d_chg d_summ ok1 ok2 ok4;
quit;
