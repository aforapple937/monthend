*ProcessBody;

libname sasfiles "C:/Users/FNLNJE/Documents/My SAS Files";

%let rpt_dt  = %sysfunc(inputn(&proc_dte, date9.));
%let prv_dt  = %sysfunc(intnx(month, &rpt_dt, -1, e));
%let yymm    = %sysfunc(putn(&rpt_dt, yymmn4.));
%let rpt_lbl = %sysfunc(putn(&rpt_dt, date9.));
%let prv_lbl = %sysfunc(putn(&prv_dt, date9.));

options dlcreatedir;
libname mth "C:/Users/FNLNJE/Documents/My SAS Files/&yymm";

%macro stack_ccy(dt=, out=);
    %local i tbl;
    %let tbl = LN_DTL CC_DTL OD_DTL INVMT_DTL GUARANTEE_DTL;

    data work.&out._raw(keep=AC_CODE CURCY_CODE ENTITY SRC);
        length ENTITY $3 SRC $14;
        set
        %do i = 1 %to 5;
            LBFRS9.T_MTH_FRS9_%scan(&tbl, &i)
                (keep=PROC_DTE AC_CODE CURCY_CODE LEGAL_ENTITY_CODE in=in&i)
        %end;
        ;
        where datepart(PROC_DTE) = &dt;

        %do i = 1 %to 5;
            %if &i = 1 %then if; %else else if;
            in&i then SRC = "%scan(&tbl, &i)";
        %end;

        select (upcase(strip(LEGAL_ENTITY_CODE)));
            when ("MBB-SG") ENTITY = "128";
            when ("MSL")    ENTITY = "252";
            otherwise       ENTITY = "???";
        end;
    run;

    proc sort data=work.&out._raw out=work.&out;
        by AC_CODE;
    run;
%mend;

%stack_ccy(dt=&rpt_dt, out=cur)
%stack_ccy(dt=&prv_dt, out=prv)

data mth.ccy_change_&yymm;
    merge work.prv(in=p rename=(CURCY_CODE=PRIOR_CCY SRC=PRIOR_SRC
                                ENTITY=PRIOR_ENTITY))
          work.cur(in=c rename=(CURCY_CODE=CURR_CCY  SRC=CURR_SRC));
    by AC_CODE;
    length ENTITY_NAME $3;

    if not (p and c) then delete;
    if PRIOR_CCY = CURR_CCY then delete;

    select (ENTITY);
        when ("128") ENTITY_NAME = "MBS";
        when ("252") ENTITY_NAME = "MSL";
        otherwise    ENTITY_NAME = "???";
    end;

    keep AC_CODE ENTITY ENTITY_NAME PRIOR_CCY CURR_CCY PRIOR_SRC CURR_SRC;
run;

proc sql noprint;
    select count(*) into :n_chg trimmed from mth.ccy_change_&yymm;
quit;

%macro show_ccy;
    %if &n_chg = 0 %then %do;
        data work.no_chg;
            length Result $70;
            Result = "No currency changes between &prv_lbl and &rpt_lbl";
        run;
        title "Currency Change Check &yymm";
        proc print data=work.no_chg noobs label;
            label Result = "Result";
        run;
        title;
    %end;
    %else %do;
        title "Currency Change Check &yymm - &n_chg account(s), &prv_lbl to &rpt_lbl";
        proc print data=mth.ccy_change_&yymm noobs label;
            var AC_CODE ENTITY_NAME PRIOR_CCY CURR_CCY PRIOR_SRC CURR_SRC;
            label AC_CODE   = "Account"      ENTITY_NAME = "Entity"
                  PRIOR_CCY = "Prior ccy"    CURR_CCY    = "New ccy"
                  PRIOR_SRC = "Prior file"   CURR_SRC    = "Current file";
        run;
        title;
    %end;
%mend;
%show_ccy

proc datasets library=work nolist;
    delete cur cur_raw prv prv_raw no_chg;
quit;
