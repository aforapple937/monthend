*ProcessBody;

libname sasfiles "C:/Users/FNLNJE/Documents/My SAS Files";

%let rpt_dt  = %sysfunc(inputn(&proc_dte, date9.));
%let yymm    = %sysfunc(putn(&rpt_dt, yymmn4.));

%let rpt_dtm = "&proc_dte:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;
%let tb_dir  = C:/Users/FNLNJE/Documents/My SAS Files/PRETB;

%let detail  = Y;
%let tol     = 1;

options dlcreatedir;
libname mth "C:/Users/FNLNJE/Documents/My SAS Files/&yymm";

data work.tbmap(keep=K PRODUCT_TYPE RECON_GRP);
    set sasfiles.tb_mapping;
    length K $16;
    if ISLAMIC in ("N", "Y") then do;
        K = catx("|", POSTING_ACCOUNT, ISLAMIC);
        output;
    end;
    else do;
        K = catx("|", POSTING_ACCOUNT, "N");  output;
        K = catx("|", POSTING_ACCOUNT, "Y");  output;
    end;
run;

proc sort data=work.tbmap nodupkey;  by K;  run;

proc sql noprint;
    select count(*) into :n_map trimmed from work.tbmap;
quit;

%macro bal_recon;
%if &n_map = 0 %then %do;
    %put ERROR: SASFILES.TB_MAPPING is empty - run the setup first.;
    %return;
%end;

data work.tb_sum(keep=ENTITY PRODUCT_TYPE RECON_GRP YTD_NET_ACCOUNTED);
    length LEDGER_ID 8 PERIOD $10 ACCOUNT_NAME $100 ACCOUNTS $60
           CURRENCY $3 ACC_PROD $13 ENTITY $3 PRODUCT_TYPE $10
           RECON_GRP $20 K $16 _dlm $1;
    retain _dlm ",";
    infile "&tb_dir/*.txt" dsd truncover dlm=_dlm;

    if _n_ = 1 then do;
        declare hash m(dataset:"work.tbmap");
        m.definekey("K");
        m.definedata("PRODUCT_TYPE", "RECON_GRP");
        m.definedone();
    end;

    input @;
    if _infile_ = " " then delete;
    if _infile_ =: "LEDGER_ID" then delete;

    if      index(_infile_, "09"x) then _dlm = "09"x;
    else if index(_infile_, ",")   then _dlm = ",";
    else do;
        put "ERROR: Unrecognised delimiter - " _infile_;
        stop;
    end;

    input LEDGER_ID PERIOD $ EFFECTIVE_DATE : anydtdte10. ACCOUNT_NAME $
          ACCOUNTS $ CURRENCY $ PTD_NET_ENTERED PTD_NET_ACCOUNTED
          YTD_NET_ENTERED YTD_NET_ACCOUNTED ACC_PROD $;

    ENTITY = scan(ACCOUNTS, 1, "-");
    K = catx("|", ACC_PROD,
             ifc(strip(scan(ACCOUNTS, 7, "-")) = "8999", "Y", "N"));

    call missing(PRODUCT_TYPE, RECON_GRP);
    if m.find() ne 0 then delete;

    if RECON_GRP = "" then RECON_GRP = catx(" ", ACC_PROD, "(no group)");
run;

proc means data=work.tb_sum noprint nway;
    class ENTITY PRODUCT_TYPE;
    var YTD_NET_ACCOUNTED;
    output out=work.tb_bal(drop=_type_ _freq_) sum=TB_BAL;
run;

proc means data=work.tb_sum noprint nway;
    class ENTITY PRODUCT_TYPE RECON_GRP;
    var YTD_NET_ACCOUNTED;
    output out=work.tb_grp(drop=_type_ _freq_) sum=TB_BAL;
run;

%macro stack_products;
    %local i tbl typ;
    %let tbl = LN_DTL CC_DTL OD_DTL INVMT_DTL GUARANTEE_DTL;
    %let typ = Loan Loan Loan Investment Guarantee;

    data work.prod_all(keep=ENTITY PRD_CODE PRODUCT_TYPE
                            LEDGER_BALANCE_AMT);
        length ENTITY $3 PRODUCT_TYPE $10;
        set
        %do i = 1 %to 5;
            LBFRS9.T_MTH_FRS9_%scan(&tbl, &i)
                (keep=PROC_DTE LEGAL_ENTITY_CODE PRD_CODE
                      LEDGER_BALANCE_AMT in=in&i)
        %end;
        ;
        where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;

        %do i = 1 %to 5;
            %if &i = 1 %then if; %else else if;
            in&i then PRODUCT_TYPE = "%scan(&typ, &i)";
        %end;

        select (upcase(strip(LEGAL_ENTITY_CODE)));
            when ("MBB-SG") ENTITY = "128";
            when ("MSL")    ENTITY = "252";
            otherwise       ENTITY = "???";
        end;
    run;
%mend;
%stack_products

proc means data=work.prod_all noprint nway;
    class ENTITY PRODUCT_TYPE;
    var LEDGER_BALANCE_AMT;
    output out=work.prod_bal(drop=_type_ _freq_) sum=PROD_BAL;
run;

proc sort data=work.prod_all;  by PRD_CODE;  run;

proc sort data=sasfiles.prd_group out=work.pg nodupkey dupout=work.pg_dup;
    by PRD_CODE;
run;

data _null_;
    if 0 then set work.pg_dup nobs=n;
    if n > 0 then put "WARNING: " n
        "duplicate product code(s) in PRD_GROUP - first kept, rest ignored.";
    stop;
run;

data work.prod_grp;
    merge work.prod_all(in=p) work.pg(in=g);
    by PRD_CODE;
    if not p then delete;
    if not g or RECON_GRP = ""
        then RECON_GRP = catx(" ", strip(PRD_CODE), "(no group)");
run;

proc means data=work.prod_grp noprint nway;
    class ENTITY PRODUCT_TYPE RECON_GRP;
    var LEDGER_BALANCE_AMT;
    output out=work.prod_gbal(drop=_type_ _freq_) sum=PROD_BAL;
run;

data work.prod_gbal;
    set work.prod_gbal;
    if index(RECON_GRP, "(no group)") > 0
       and round(PROD_BAL, 0.01) = 0 then delete;
run;

%let fifo_dir  = C:/Users/FNLNJE/Documents/My SAS Files/fifo;
%let fifo_file = &fifo_dir/FIFO_SGSG%sysfunc(putn(&rpt_dt, yymmddn8.)).xlsx;

%macro read_fifo;
    %global fifo_bal;
    %local savevv postype;
    %let fifo_bal = 0;

    %if %sysfunc(fileexist(&fifo_file)) = 0 %then %do;
        %put ERROR: FIFO file not found - &fifo_file;
        %return;
    %end;

    %let savevv = %sysfunc(getoption(validvarname));
    options validvarname=v7;

    proc import datafile="&fifo_file" out=work.fifo_raw dbms=xlsx replace;
        range="FIFOGLOBAL_I1$A4:CZ200000";
        getnames=yes;
    run;

    options validvarname=&savevv;

    proc sql noprint;
        select type into :postype trimmed
          from dictionary.columns
         where libname = "WORK" and memname = "FIFO_RAW"
           and upcase(name) = "POSITION";
    quit;

    %if &postype ne num %then %do;
        %put ERROR: FIFO Position is &postype, not numeric - check for text cells.;
        %return;
    %end;

    data work.fifo_in;
        set work.fifo_raw;
        where upcase(strip(BalanceType)) = "ON BALANCE"
          and upcase(strip(Currency))    = "SGD"
          and Position < 0
          and index(upcase(Security_Name), "EMMC") = 0;
    run;

    proc sql noprint;
        select coalesce(sum(Position), 0) format=32.2
          into :fifo_bal trimmed
          from work.fifo_in;
    quit;

    %put NOTE: FIFO total = &fifo_bal;
%mend;
%read_fifo

proc sort data=work.prod_bal;  by ENTITY PRODUCT_TYPE;  run;
proc sort data=work.tb_bal;    by ENTITY PRODUCT_TYPE;  run;

data mth.balrecon;
    merge work.prod_bal(in=p) work.tb_bal(in=t);
    by ENTITY PRODUCT_TYPE;
    length ENTITY_NAME $3 MATCH_FLG $1;

    select (ENTITY);
        when ("128") ENTITY_NAME = "MBS";
        when ("252") ENTITY_NAME = "MSL";
        otherwise    ENTITY_NAME = "???";
    end;

    if not p then PROD_BAL = 0;
    if not t then TB_BAL   = 0;

    FIFO_BAL = 0;
    if ENTITY = "128" and PRODUCT_TYPE = "Investment" then FIFO_BAL = &fifo_bal;

    TOTAL_PROD = PROD_BAL + FIFO_BAL;
    DIFF       = TOTAL_PROD - TB_BAL;
    MATCH_FLG  = ifc(round(DIFF, 0.01) = 0, "Y", "N");
run;

proc sql noprint;
    select count(*) into :n_diff trimmed
      from mth.balrecon where MATCH_FLG = "N";
quit;

title "Balance Recon &yymm";
proc print data=mth.balrecon noobs label;
    var ENTITY_NAME PRODUCT_TYPE PROD_BAL FIFO_BAL TOTAL_PROD
        TB_BAL DIFF;
    format PROD_BAL FIFO_BAL TOTAL_PROD TB_BAL DIFF comma20.2;
    label ENTITY_NAME  = "Entity"        PRODUCT_TYPE = "Product type"
          PROD_BAL     = "Product files" FIFO_BAL     = "FIFO"
          TOTAL_PROD   = "Total product" TB_BAL       = "Trial balance"
          DIFF         = "Difference";
run;
title;

%if %upcase(&detail) ne Y %then %return;

proc sort data=work.prod_gbal;  by ENTITY PRODUCT_TYPE RECON_GRP;  run;
proc sort data=work.tb_grp;     by ENTITY PRODUCT_TYPE RECON_GRP;  run;

data mth.baldetail;
    merge work.prod_gbal(in=p) work.tb_grp(in=t);
    by ENTITY PRODUCT_TYPE RECON_GRP;
    length ENTITY_NAME $3 STATUS $26;

    select (ENTITY);
        when ("128") ENTITY_NAME = "MBS";
        when ("252") ENTITY_NAME = "MSL";
        otherwise    ENTITY_NAME = "???";
    end;

    if PROD_BAL = . then PROD_BAL = 0;
    if TB_BAL   = . then TB_BAL   = 0;

    FIFO_BAL = 0;
    if ENTITY = "128" and RECON_GRP = "SECURITIES" then FIFO_BAL = &fifo_bal;

    TOTAL_PROD = PROD_BAL + FIFO_BAL;
    DIFF       = round(TOTAL_PROD - TB_BAL, 0.01);

    if      index(RECON_GRP, "(no group)") > 0 then STATUS = "No group";
    else if abs(DIFF) <= &tol                  then STATUS = "Match";
    else if not t                              then STATUS = "Missing from TB";
    else if not p                              then STATUS = "Not in product file";
    else                                            STATUS = "Amount differs";
run;

title "Balance Recon detail &yymm";
proc report data=mth.baldetail nowd spanrows;
    column ENTITY_NAME PRODUCT_TYPE RECON_GRP PROD_BAL FIFO_BAL
           TOTAL_PROD TB_BAL DIFF;
    define ENTITY_NAME  / order        "Entity";
    define PRODUCT_TYPE / order        "Product type";
    define RECON_GRP    / display      "Group";
    define PROD_BAL     / analysis sum "Product files" format=comma20.2;
    define FIFO_BAL     / analysis sum "FIFO"          format=comma20.2;
    define TOTAL_PROD   / analysis sum "Total product" format=comma20.2;
    define TB_BAL       / analysis sum "Trial balance" format=comma20.2;
    define DIFF         / analysis sum "Difference"    format=comma20.2;

    compute after PRODUCT_TYPE;
        RECON_GRP    = "Total";
        PRODUCT_TYPE = "";
        ENTITY_NAME  = "";
    endcomp;

    break after PRODUCT_TYPE / summarize style={font_weight=bold};
run;
title;

%mend;
%bal_recon

proc datasets library=work nolist;
    delete tbmap tb_sum tb_bal tb_grp prod_all prod_bal pg pg_dup
           prod_grp prod_gbal fifo_raw fifo_in;
quit;
