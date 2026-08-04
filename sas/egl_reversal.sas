*ProcessBody;

%let rpt_dt  = %sysfunc(inputn(&proc_dte, date9.));
%let prv_dt  = %sysfunc(intnx(month, &rpt_dt, -1, e));
%let yymm    = %sysfunc(putn(&rpt_dt, yymmn4.));
%let rpt_lbl = %sysfunc(putn(&rpt_dt, date9.));
%let prv_lbl = %sysfunc(putn(&prv_dt, date9.));
%let egl_dir = C:/Users/FNLNJE/Documents/My SAS Files/eglfile;

options dlcreatedir;
libname mth "C:/Users/FNLNJE/Documents/My SAS Files/&yymm";

data work.egl_raw(keep=ROLE F_ENT F_CODE ACCT SEG_CCY SIGNED_AMT DESCR);
    length fn $300 base $64 F_ENT $3 F_CODE $2 F_DTE $6 ROLE $10
           f1 f2 $20 DRCR $1 f5 $20
           s1 $3 s2 $10 s3 $10 s4 $10 s5 $10 s6 $10 s7 $10 s8 $10
           f14-f20 $20 RPT_DATE $20 SEG_CCY $3 f25 $20 DESCR $60
           ACCT $60;
    infile "&egl_dir/*.csv" dsd dlm="|" truncover filename=fn;

    input @;

    base   = scan(fn, -1, "\/");
    F_ENT  = substr(base, 1, 3);
    F_CODE = substr(base, 10, 2);
    F_DTE  = substr(base, 12, 6);

    if      input(F_DTE, ddmmyy6.) = &prv_dt and F_CODE ne "11" then ROLE = "PRIORPOST";
    else if input(F_DTE, ddmmyy6.) = &rpt_dt and F_CODE  = "11" then ROLE = "CURRREV";
    else delete;

    if index(_infile_, '"BH"') = 1 then delete;

    input f1 $ f2 $ f3 DRCR $ f5 $
          s1 $ s2 $ s3 $ s4 $ s5 $ s6 $ s7 $ s8 $
          f14 $ f15 $ f16 $ f17 $ f18 $ f19 $ f20 $
          RPT_DATE $ AMOUNT SEG_CCY $ f24 f25 $ f26 f27 DESCR $;

    ACCT = catx("-", s1, s2, s3, s4, s5, s6, s7, s8);

    if      upcase(DRCR) = "D" then SIGNED_AMT =  AMOUNT;
    else if upcase(DRCR) = "C" then SIGNED_AMT = -AMOUNT;
    else do;
        put "ERROR: Unexpected DR/CR indicator - " DRCR= base=;
        stop;
    end;
run;

proc sql noprint;
    select count(distinct F_ENT) into :n_prior trimmed
      from work.egl_raw where ROLE = "PRIORPOST";
    select count(distinct F_ENT) into :n_rev trimmed
      from work.egl_raw where ROLE = "CURRREV";
    select count(*) into :n_ambig trimmed
      from (select F_ENT from work.egl_raw where ROLE = "PRIORPOST"
             group by F_ENT having count(distinct F_CODE) > 1);
quit;

%macro egl_reversal;
    %if &n_prior ne 2 %then %do;
        %put ERROR: Expected 2 prior posting files for &prv_lbl, found &n_prior..;
        %return;
    %end;
    %if &n_rev ne 2 %then %do;
        %put ERROR: Expected 2 reversal files for &rpt_lbl, found &n_rev..;
        %return;
    %end;
    %if &n_ambig ne 0 %then %do;
        %put ERROR: More than one posting code for an entity - cannot tell which file to use.;
        %return;
    %end;

    proc means data=work.egl_raw noprint nway;
        class ROLE ACCT SEG_CCY;
        var SIGNED_AMT;
        output out=work.netted(drop=_type_ _freq_) sum=NET;
    run;

    proc sort data=work.netted;
        by ACCT SEG_CCY ROLE;
    run;

    proc transpose data=work.netted out=work.paired(drop=_name_) prefix=NET_;
        by ACCT SEG_CCY;
        id ROLE;
        var NET;
    run;

    data mth.eglrev;
        set work.paired;
        length ENTITY $3 ENTITY_NAME $3 STATUS $24;

        if NET_PRIORPOST = . then NET_PRIORPOST = 0;
        if NET_CURRREV   = . then NET_CURRREV   = 0;

        RESIDUAL = round(NET_PRIORPOST + NET_CURRREV, 0.01);

        if      RESIDUAL = 0      then STATUS = "Reversed";
        else if NET_CURRREV   = 0 then STATUS = "Not reversed";
        else if NET_PRIORPOST = 0 then STATUS = "Reversal without posting";
        else                           STATUS = "Amount differs";

        ENTITY = scan(ACCT, 1, "-");
        select (ENTITY);
            when ("128") ENTITY_NAME = "MBS";
            when ("252") ENTITY_NAME = "MSL";
            otherwise    ENTITY_NAME = "???";
        end;
    run;

    proc sql noprint;
        select count(*) into :n_exc trimmed
          from mth.eglrev where STATUS ne "Reversed";
    quit;

    %if &n_exc = 0 %then %do;
        data work.no_exc;
            length Result $80;
            Result = "All &rpt_lbl reversals match the &prv_lbl postings";
        run;
        title "EGL Reversal Check &yymm";
        proc print data=work.no_exc noobs label;
            label Result = "Result";
        run;
        title;
    %end;
    %else %do;
        title "EGL Reversal Check &yymm - &n_exc exception(s)";
        proc print data=mth.eglrev noobs label;
            where STATUS ne "Reversed";
            var ENTITY_NAME ACCT SEG_CCY NET_PRIORPOST NET_CURRREV
                RESIDUAL STATUS;
            format NET_PRIORPOST NET_CURRREV RESIDUAL comma20.2;
            label ENTITY_NAME   = "Entity"        ACCT     = "Account"
                  SEG_CCY       = "Ccy"
                  NET_PRIORPOST = "&prv_lbl posting"
                  NET_CURRREV   = "&rpt_lbl reversal"
                  RESIDUAL      = "Residual"      STATUS   = "Status";
        run;
        title;
    %end;
%mend;
%egl_reversal

proc datasets library=work nolist;
    delete egl_raw netted paired no_exc;
quit;
