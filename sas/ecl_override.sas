*ProcessBody;

libname sasfiles "C:/Users/FNLNJE/Documents/My SAS Files";

%let rpt_dt  = %sysfunc(inputn(&proc_dte, date9.));
%let prv_dt  = %sysfunc(intnx(month, &rpt_dt, -1, e));
%let yymm    = %sysfunc(putn(&rpt_dt, yymmn4.));
%let rpt_lbl = %sysfunc(putn(&rpt_dt, date9.));
%let mon_lbl = %upcase(%sysfunc(putn(&rpt_dt, monyy5.)));

%let prd_scope = SG_MSTRGD;

options dlcreatedir;
libname mth  "C:/Users/FNLNJE/Documents/My SAS Files/&yymm";
libname glte "C:/Users/FNLNJE/Documents/My SAS Files/&yymm/glte";
options nodlcreatedir;

%macro cif_count;
    %if %symexist(cif_list_count) %then %do;
        %if %datatyp(&cif_list_count) = NUMERIC %then &cif_list_count;
        %else 0;
    %end;
    %else 0;
%mend;

%let cif_n = %cif_count;

data work.cif_in;
    length CIF_NO $50 _raw $32767;
    keep CIF_NO;
    %if &cif_n > 0 %then %do;
        do _v = 1 to &cif_n;
            _raw = symget(cats("cif_list", _v));
            link split;
        end;
    %end;
    %else %do;
        _raw = symget("cif_list");
        link split;
    %end;
    return;

split:
    do _i = 1 to countw(_raw, " ,;");
        CIF_NO = strip(scan(_raw, _i, " ,;"));
        if CIF_NO ne "" then output;
    end;
    return;
run;

proc sort data=work.cif_in nodupkey;  by CIF_NO;  run;

%macro guard_cif_list;
    %local n;
    proc sql noprint;
        select count(*) into :n trimmed from work.cif_in;
    quit;
    %if &n = 0 %then %do;
        %put ERROR: No CIF values parsed from the prompt.;
        %abort cancel;
    %end;
    %put NOTE: &n CIF(s) requested.;
%mend;
%guard_cif_list

proc sql noprint;
    select distinct quote(strip(CIF_NO)) into :cif_sql separated by ","
      from work.cif_in;
quit;

proc sql;
    create table work.pop as
    select a.CIF_NO,
           a.LEGAL_ENTITY,
           a.UNIQUE_ID_NO,
           a.CURCY_CODE,
           a.SRC_PROD_TYPE_CD,
           a.SEC_CLS_CD,
           a.GL_AC_ID,
           a.AC_MGR_UNIT_CODE,
           a.LCY_LEDGER_BAL,
           a.LCY_ECL_CLOSING_FY,
           a.LCY_INT_UNWIND_CLOSING_FY,
           a.RCY_ECL_CLOSING_FY,
           a.RCY_ECL_OPENING_BAL,
           a.RCY_ECL_CHARGE_FY,
           a.RCY_ECL_WRITEBACK_FY,
           a.RCY_ECL_WRITE_OFF_FY,
           a.RCY_ECL_CHARGE_FTM,
           a.RCY_ECL_WRITEBACK_FTM,
           a.RCY_ECL_WRITE_OFF_FTM
      from LBFRS9.T_MTH_FRS9_RDL_AC_DTL as a
     where datepart(a.PROC_DTE) = &rpt_dt
       and a.CIF_NO in (&cif_sql)
       and a.SRC_PROD_TYPE_CD = "&prd_scope";
quit;

proc sort data=work.pop;  by UNIQUE_ID_NO;  run;

%macro guard_population;
    %local n n_miss;
    proc sql noprint;
        select count(*) into :n trimmed from work.pop;

        create table work.cif_miss as
        select c.CIF_NO
          from work.cif_in as c
          left join (select distinct CIF_NO from work.pop) as p
                 on p.CIF_NO = c.CIF_NO
         where p.CIF_NO is null;

        select count(*) into :n_miss trimmed from work.cif_miss;
    quit;
    %if &n = 0 %then %do;
        %put ERROR: No &prd_scope rows for the listed CIFs at &rpt_lbl..;
        %abort cancel;
    %end;

    %if &n_miss > 0 %then %do;
        title "ECL Override &yymm - &n_miss requested CIF(s) with no &prd_scope rows";
        proc print data=work.cif_miss noobs label;
            label CIF_NO = "CIF";
        run;
        title;
        %put WARNING: &n_miss requested CIF(s) returned no &prd_scope rows at &rpt_lbl..;
    %end;
%mend;
%guard_population

%let dt_lo = "&rpt_lbl:00:00:00"dt;
%let dt_hi = "&rpt_lbl:23:59:59"dt;

%let ml_found = 0;

proc sql noprint;
    select case when count(*) > 0 then 1 else 0 end
      into :ml_found trimmed
      from LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST
     where PROC_DTE between &dt_lo and &dt_hi;
quit;

%macro get_mstr;
    %if &ml_found = 1 %then %do;
        %put NOTE: Master listing taken from LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST.;
        proc sort data=LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST
                      (keep=PROC_DTE V_ACCOUNT_NUMBER F_SHORT_TERM_IND
                            F_SHORT_TERM_INCEP_IND
                            V_CUSTOMER_PARENT_GROUP_NAME V_FINANCING_CODE
                       where=(datepart(PROC_DTE) = &rpt_dt))
                  out=work.mstr(rename=(V_ACCOUNT_NUMBER=UNIQUE_ID_NO)
                                drop=PROC_DTE);
            by V_ACCOUNT_NUMBER;
        run;
    %end;
    %else %if %sysfunc(exist(mth.masterlisting_&yymm)) %then %do;
        %put WARNING: RDL_MSTR_LIST not loaded for &rpt_lbl - using MTH.MASTERLISTING_&yymm..;
        proc sort data=mth.masterlisting_&yymm
                      (keep=V_ACCOUNT_NUMBER F_SHORT_TERM_IND
                            F_SHORT_TERM_INCEP_IND
                            V_CUSTOMER_PARENT_GROUP_NAME V_FINANCING_CODE)
                  out=work.mstr(rename=(V_ACCOUNT_NUMBER=UNIQUE_ID_NO));
            by V_ACCOUNT_NUMBER;
        run;
    %end;
    %else %do;
        %put ERROR: No master listing for &rpt_lbl - RDL_MSTR_LIST is empty and MTH.MASTERLISTING_&yymm does not exist.;
        data work.mstr;
            length UNIQUE_ID_NO $50 F_SHORT_TERM_IND $1
                   F_SHORT_TERM_INCEP_IND $1
                   V_CUSTOMER_PARENT_GROUP_NAME $255 V_FINANCING_CODE $1;
            stop;
        run;
    %end;
%mend;
%get_mstr

data work.pop_m;
    merge work.pop(in=a) work.mstr;
    by UNIQUE_ID_NO;
    if not a then delete;
run;

proc sort data=LBFRS9.T_FRS9_PRD_MSTR(keep=PRODUCT_HIERARCHY_CD LEVEL_3)
          out=work.prd nodupkey;
    by PRODUCT_HIERARCHY_CD;
run;

data work.fx(keep=CURCY_CODE EXCHG_RT);
    set LBDWH.T_MTH_CURCY_EXCHG(keep=PROC_DTE CURCY_CODE EXCHG_RT);
    where datepart(PROC_DTE) = &rpt_dt;
run;

proc sort data=work.fx nodupkey;  by CURCY_CODE;  run;

data work.party(keep=CIF_NO CIF_NAME);
    set LBDWH.V_T_CIF_MSTR(keep=CIF_NO CIF_NAME);
run;

proc sort data=work.party nodupkey;  by CIF_NO;  run;

data work.prv(keep=UNIQUE_ID_NO PRV_CLOSING_FY);
    set LBFRS9.T_MTH_FRS9_RDL_AC_DTL(keep=PROC_DTE UNIQUE_ID_NO RCY_ECL_CLOSING_FY
             rename=(RCY_ECL_CLOSING_FY = PRV_CLOSING_FY));
    where datepart(PROC_DTE) = &prv_dt;
run;

proc sort data=work.prv nodupkey;  by UNIQUE_ID_NO;  run;

data work.derived;
    length LEVEL_3 $50 CIF_NAME $80;

    if _n_ = 1 then do;
        declare hash h_prd(dataset:"work.prd");
          h_prd.definekey("PRODUCT_HIERARCHY_CD");  h_prd.definedata("LEVEL_3");   h_prd.definedone();
        declare hash h_fx(dataset:"work.fx");
          h_fx.definekey("CURCY_CODE");             h_fx.definedata("EXCHG_RT");   h_fx.definedone();
        declare hash h_cif(dataset:"work.party");
          h_cif.definekey("CIF_NO");                h_cif.definedata("CIF_NAME");  h_cif.definedone();
        declare hash h_prv(dataset:"work.prv");
          h_prv.definekey("UNIQUE_ID_NO");
          h_prv.definedata("PRV_CLOSING_FY");  h_prv.definedone();
        call missing(LEVEL_3, CIF_NAME, EXCHG_RT, PRV_CLOSING_FY);
    end;

    set work.pop_m;

    length PRODUCT_HIERARCHY_CD $50;
    PRODUCT_HIERARCHY_CD = SRC_PROD_TYPE_CD;
    if h_prd.find() ne 0 then call missing(LEVEL_3);
    if h_fx.find()  ne 0 then call missing(EXCHG_RT);
    if h_cif.find() ne 0 then call missing(CIF_NAME);
    if h_prv.find() ne 0 then call missing(PRV_CLOSING_FY);

    if LEVEL_3 in ('Bank Guarantee','Letter Of Credit','Shipping Guarantee')
        then LEVEL_3 = 'Off Balance Sheet';
    if SRC_PROD_TYPE_CD in ('SG_REVRPO','SG_ISLMREVRPO')
        then LEVEL_3 = 'Rev Repo';

    array _amt{*} LCY_LEDGER_BAL
                  LCY_ECL_CLOSING_FY LCY_INT_UNWIND_CLOSING_FY
                  RCY_ECL_CLOSING_FY RCY_ECL_OPENING_BAL
                  RCY_ECL_CHARGE_FY RCY_ECL_WRITEBACK_FY RCY_ECL_WRITE_OFF_FY
                  RCY_ECL_CHARGE_FTM RCY_ECL_WRITEBACK_FTM RCY_ECL_WRITE_OFF_FTM
                  PRV_CLOSING_FY;
    do _j = 1 to dim(_amt);
        if _amt{_j} = . then _amt{_j} = 0;
    end;

    FX_MISSING = (EXCHG_RT = . or EXCHG_RT = 0);
    if not FX_MISSING then RCY_TARGET = round(LCY_LEDGER_BAL / EXCHG_RT, 0.01);
    else RCY_TARGET = .;

    LCY_TARGET = round(LCY_LEDGER_BAL, 0.01);
    LCY_TOPUP  = round(LCY_TARGET - LCY_ECL_CLOSING_FY, 0.01);
    RCY_TOPUP  = round(RCY_TARGET - RCY_ECL_CLOSING_FY, 0.01);

    ID_RESIDUAL = round( (RCY_ECL_OPENING_BAL + RCY_ECL_CHARGE_FY
                          - RCY_ECL_WRITEBACK_FY - RCY_ECL_WRITE_OFF_FY)
                         - RCY_ECL_CLOSING_FY, 0.01);

    NET_REQ_FY = round(RCY_TARGET - RCY_ECL_OPENING_BAL
                       + RCY_ECL_WRITE_OFF_FY, 0.01);
    P_RCY_ECL_CLOSING_FY    = RCY_TARGET;
    P_RCY_ECL_CHARGE_FY     = max(NET_REQ_FY, 0);
    P_RCY_ECL_WRITEBACK_FY  = max(-NET_REQ_FY, 0);

    D_CHARGE_FY    = round(P_RCY_ECL_CHARGE_FY    - RCY_ECL_CHARGE_FY,    0.01);
    D_WRITEBACK_FY = round(P_RCY_ECL_WRITEBACK_FY - RCY_ECL_WRITEBACK_FY, 0.01);

    NET_REQ_FTM = round(RCY_TARGET - PRV_CLOSING_FY
                        + RCY_ECL_WRITE_OFF_FTM, 0.01);
    P_RCY_ECL_CHARGE_FTM    = max(NET_REQ_FTM, 0);
    P_RCY_ECL_WRITEBACK_FTM = max(-NET_REQ_FTM, 0);

    D_CHARGE_FTM    = round(P_RCY_ECL_CHARGE_FTM    - RCY_ECL_CHARGE_FTM,    0.01);
    D_WRITEBACK_FTM = round(P_RCY_ECL_WRITEBACK_FTM - RCY_ECL_WRITEBACK_FTM, 0.01);

    PATCH_LCY = (round(LCY_TOPUP, 0.01) ne 0);
    PATCH_RCY = (round(RCY_TOPUP, 0.01) ne 0
                 or round(D_CHARGE_FY, 0.01)     ne 0
                 or round(D_WRITEBACK_FY, 0.01)  ne 0
                 or round(D_CHARGE_FTM, 0.01)    ne 0
                 or round(D_WRITEBACK_FTM, 0.01) ne 0);

    CHK_TOPUP = round((D_CHARGE_FY - D_WRITEBACK_FY) - RCY_TOPUP, 0.01);
    CHK_IDENT = round((RCY_ECL_OPENING_BAL + P_RCY_ECL_CHARGE_FY
                       - P_RCY_ECL_WRITEBACK_FY - RCY_ECL_WRITE_OFF_FY)
                      - P_RCY_ECL_CLOSING_FY, 0.01);

    drop _j PRODUCT_HIERARCHY_CD;
run;

%macro fx_checks;
    %local n_fx;
    proc sql noprint;
        select sum(FX_MISSING) into :n_fx trimmed from work.derived;
    quit;

    %local n_fgn;
    proc sql noprint;
        select sum(CURCY_CODE ne "SGD") into :n_fgn trimmed from work.derived;
    quit;
    %if &n_fgn > 0 %then %do;
        title "ECL Override &yymm - &n_fgn non-SGD account(s)";
        proc print data=work.derived noobs label;
            where CURCY_CODE ne "SGD";
            var CIF_NO UNIQUE_ID_NO CURCY_CODE EXCHG_RT LCY_LEDGER_BAL RCY_TARGET;
            format LCY_LEDGER_BAL RCY_TARGET comma20.2  EXCHG_RT 20.10;
            label CIF_NO = "CIF"  UNIQUE_ID_NO = "Account"  CURCY_CODE = "Ccy"
                  EXCHG_RT = "Rate"  LCY_LEDGER_BAL = "Ledger balance (SGD)"
                  RCY_TARGET = "Target (account ccy)";
        run;
        title;
        %put WARNING: &n_fgn non-SGD account(s) - check the code is not a variant.;
    %end;

    %if &n_fx > 0 %then %do;
        title "ECL Override &yymm - &n_fx account(s) with no exchange rate";
        proc print data=work.derived noobs label;
            where FX_MISSING;
            var CIF_NO UNIQUE_ID_NO CURCY_CODE LCY_LEDGER_BAL;
            label CIF_NO = "CIF"  UNIQUE_ID_NO = "Account"
                  CURCY_CODE = "Ccy"  LCY_LEDGER_BAL = "LCY ledger balance";
        run;
        title;
        %put ERROR: &n_fx account(s) have no rate in T_MTH_CURCY_EXCHG at &rpt_lbl..;
        %abort cancel;
    %end;
%mend;
%fx_checks

data mth.ecl_override;
    retain PROC_DTE CIF_NO CIF_NAME LEGAL_ENTITY UNIQUE_ID_NO CURCY_CODE
           SRC_PROD_TYPE_CD LEVEL_3 SEC_CLS_CD
           LCY_LEDGER_BAL LCY_ECL_CLOSING_FY LCY_TOPUP
           EXCHG_RT RCY_TARGET
           RCY_ECL_CLOSING_FY RCY_TOPUP
           RCY_ECL_OPENING_BAL RCY_ECL_CHARGE_FY RCY_ECL_WRITEBACK_FY
           RCY_ECL_WRITE_OFF_FY ID_RESIDUAL
           PRV_CLOSING_FY
           NET_REQ_FY D_CHARGE_FY D_WRITEBACK_FY
           NET_REQ_FTM D_CHARGE_FTM D_WRITEBACK_FTM
           CHK_TOPUP CHK_IDENT PATCH_LCY PATCH_RCY
           P_RCY_ECL_CLOSING_FY P_RCY_ECL_CHARGE_FY P_RCY_ECL_WRITEBACK_FY
           P_RCY_ECL_CHARGE_FTM P_RCY_ECL_WRITEBACK_FTM
           LCY_INT_UNWIND_CLOSING_FY;
    set work.derived;
    PROC_DTE = dhms(&rpt_dt, 0, 0, 0);
    format PROC_DTE datetime20.
           LCY_LEDGER_BAL LCY_ECL_CLOSING_FY LCY_TOPUP
           RCY_TARGET RCY_ECL_CLOSING_FY RCY_TOPUP
           RCY_ECL_OPENING_BAL RCY_ECL_CHARGE_FY RCY_ECL_WRITEBACK_FY
           RCY_ECL_WRITE_OFF_FY ID_RESIDUAL PRV_CLOSING_FY
           NET_REQ_FY D_CHARGE_FY D_WRITEBACK_FY
           NET_REQ_FTM D_CHARGE_FTM D_WRITEBACK_FTM
           CHK_TOPUP CHK_IDENT
           P_RCY_ECL_CLOSING_FY P_RCY_ECL_CHARGE_FY P_RCY_ECL_WRITEBACK_FY
           P_RCY_ECL_CHARGE_FTM P_RCY_ECL_WRITEBACK_FTM
           LCY_INT_UNWIND_CLOSING_FY  24.2
           EXCHG_RT 20.10;
    keep PROC_DTE CIF_NO CIF_NAME LEGAL_ENTITY UNIQUE_ID_NO CURCY_CODE
         SRC_PROD_TYPE_CD LEVEL_3 SEC_CLS_CD
         LCY_LEDGER_BAL LCY_ECL_CLOSING_FY LCY_TOPUP
         EXCHG_RT RCY_TARGET
         RCY_ECL_CLOSING_FY RCY_TOPUP
         RCY_ECL_OPENING_BAL RCY_ECL_CHARGE_FY RCY_ECL_WRITEBACK_FY
         RCY_ECL_WRITE_OFF_FY ID_RESIDUAL PRV_CLOSING_FY
         NET_REQ_FY D_CHARGE_FY D_WRITEBACK_FY
         NET_REQ_FTM D_CHARGE_FTM D_WRITEBACK_FTM
         CHK_TOPUP CHK_IDENT PATCH_LCY PATCH_RCY
         P_RCY_ECL_CLOSING_FY P_RCY_ECL_CHARGE_FY P_RCY_ECL_WRITEBACK_FY
         P_RCY_ECL_CHARGE_FTM P_RCY_ECL_WRITEBACK_FTM
         LCY_INT_UNWIND_CLOSING_FY;
run;

data work.egl_map;
    set sasfiles.egl_mapping;
    length K $60;
    K = catx("|", upcase(strip(LEVEL_3)), upcase(strip(SEC_CLS_CD)),
                  upcase(strip(F_SHORT_TERM_IND)),
                  upcase(strip(F_SHORT_TERM_INCEP_IND)));
    keep K ECL_CHARGE ECL_PNL_CHARGE ECL_WRITEBACK ECL_PNL_WRITEBACK;
run;

proc sort data=work.egl_map nodupkey;  by K;  run;

data work.legs work.nomap;
    length K $60 ECL_CHARGE ECL_PNL_CHARGE ECL_WRITEBACK ECL_PNL_WRITEBACK $20
           ENTITY_CODE $3 CCY $3 COST_CENTRE $10 ACCOUNT $20 PRODUCT $20
           INTERCO $30 FUTURE1 $5 SUB_ACCOUNT $4 FUTURE3 $4 REMARKS $60;

    if _n_ = 1 then do;
        declare hash h_map(dataset:"work.egl_map");
          h_map.definekey("K");
          h_map.definedata("ECL_CHARGE","ECL_PNL_CHARGE","ECL_WRITEBACK","ECL_PNL_WRITEBACK");
          h_map.definedone();
    end;

    set work.derived;
    if round(D_CHARGE_FY, 0.01) = 0 and round(D_WRITEBACK_FY, 0.01) = 0
        then return;

    K = catx("|", upcase(strip(LEVEL_3)), upcase(strip(SEC_CLS_CD)),
                  upcase(strip(F_SHORT_TERM_IND)),
                  upcase(strip(F_SHORT_TERM_INCEP_IND)));
    if h_map.find() ne 0 then do;
        output work.nomap;
        return;
    end;

    select (strip(LEGAL_ENTITY));
        when ("001") ENTITY_CODE = "128";
        when ("003") ENTITY_CODE = "252";
        otherwise    ENTITY_CODE = "???";
    end;

    CCY         = CURCY_CODE;
    COST_CENTRE = AC_MGR_UNIT_CODE;
    PRODUCT     = GL_AC_ID;
    INTERCO     = ifc(missing(V_CUSTOMER_PARENT_GROUP_NAME), "000",
                      strip(V_CUSTOMER_PARENT_GROUP_NAME));
    FUTURE1     = "00000";
    SUB_ACCOUNT = ifc(upcase(strip(V_FINANCING_CODE)) = "I", "8999", "0000");
    FUTURE3     = "0000";
    REMARKS     = "&mon_lbl ECL OVERRIDE";

    if round(D_CHARGE_FY, 0.01) > 0 then do;
        ACCOUNT = ECL_PNL_CHARGE;  DEBIT = D_CHARGE_FY;  CREDIT = .;  output work.legs;
        ACCOUNT = ECL_CHARGE;      DEBIT = .;  CREDIT = D_CHARGE_FY;  output work.legs;
    end;
    else if round(D_CHARGE_FY, 0.01) < 0 then do;
        ACCOUNT = ECL_CHARGE;      DEBIT = -D_CHARGE_FY;  CREDIT = .;  output work.legs;
        ACCOUNT = ECL_PNL_CHARGE;  DEBIT = .;  CREDIT = -D_CHARGE_FY;  output work.legs;
    end;

    if round(D_WRITEBACK_FY, 0.01) > 0 then do;
        ACCOUNT = ECL_WRITEBACK;      DEBIT = D_WRITEBACK_FY;  CREDIT = .;  output work.legs;
        ACCOUNT = ECL_PNL_WRITEBACK;  DEBIT = .;  CREDIT = D_WRITEBACK_FY;  output work.legs;
    end;
    else if round(D_WRITEBACK_FY, 0.01) < 0 then do;
        ACCOUNT = ECL_PNL_WRITEBACK;  DEBIT = -D_WRITEBACK_FY;  CREDIT = .;  output work.legs;
        ACCOUNT = ECL_WRITEBACK;      DEBIT = .;  CREDIT = -D_WRITEBACK_FY;  output work.legs;
    end;

    keep ENTITY_CODE CCY COST_CENTRE ACCOUNT PRODUCT INTERCO FUTURE1
         SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS
         CIF_NO UNIQUE_ID_NO LEVEL_3 SEC_CLS_CD RCY_TOPUP;
run;

%macro guard_mapping;
    %local n;
    proc sql noprint;
        select count(*) into :n trimmed from work.nomap;
    quit;
    %if &n > 0 %then %do;
        title "ECL Override &yymm - &n account(s) with no EGL mapping";
        proc print data=work.nomap noobs label;
            var CIF_NO UNIQUE_ID_NO LEVEL_3 SEC_CLS_CD RCY_TOPUP;
            label CIF_NO = "CIF"  UNIQUE_ID_NO = "Account"
                  LEVEL_3 = "Level 3"  SEC_CLS_CD = "Sec class"
                  RCY_TOPUP = "RCY top-up";
        run;
        title;
        %put ERROR: &n account(s) have no EGL mapping row - entries would be incomplete.;
        %abort cancel;
    %end;
%mend;
%guard_mapping

proc means data=work.legs noprint nway;
    class ENTITY_CODE CCY COST_CENTRE ACCOUNT PRODUCT INTERCO FUTURE1
          SUB_ACCOUNT FUTURE3 REMARKS;
    var DEBIT CREDIT;
    output out=work.agg(drop=_type_ _freq_) sum=DEBIT CREDIT;
run;

data glte.ecl_override_entries;
    retain ENTITY_CODE CCY COST_CENTRE ACCOUNT PRODUCT INTERCO FUTURE1
           SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS;
    set work.agg;
    if DEBIT  = . then DEBIT  = 0;
    if CREDIT = . then CREDIT = 0;
    if round(DEBIT, 0.01) = 0 and round(CREDIT, 0.01) = 0 then delete;
    format DEBIT CREDIT 24.2;
    keep ENTITY_CODE CCY COST_CENTRE ACCOUNT PRODUCT INTERCO FUTURE1
         SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS;
run;

data mth.frs9_closing_bal;
    retain PROC_DTE UNIQUE_ID_NO LCY_INT_UNWIND_CLOSING_FY
           LCY_ECL_CLOSING_FY LEGAL_ENTITY;
    length PROC_DTE $9;
    set work.derived(rename=(LCY_TARGET=LCY_ECL_TARGET));
    where PATCH_LCY;
    PROC_DTE = catx("-", put(day(&rpt_dt), z2.),
                         propcase(put(&rpt_dt, monname3.)),
                         put(mod(year(&rpt_dt), 100), z2.));
    LCY_ECL_CLOSING_FY = LCY_ECL_TARGET;
    format LCY_INT_UNWIND_CLOSING_FY LCY_ECL_CLOSING_FY 24.2;
    label PROC_DTE                  = "PROC_DTE"
          UNIQUE_ID_NO              = "UNIQUE_ID_NO"
          LCY_INT_UNWIND_CLOSING_FY = "LCY_INT_UNWIND_CLOSING_FY"
          LCY_ECL_CLOSING_FY        = "LCY_ECL_CLOSING_FY"
          LEGAL_ENTITY              = "LEGAL_ENTITY";
    keep PROC_DTE UNIQUE_ID_NO LCY_INT_UNWIND_CLOSING_FY
         LCY_ECL_CLOSING_FY LEGAL_ENTITY;
run;

data mth.rcy_to_patch;
    retain PROC_DTE UNIQUE_ID_NO RCY_ECL_CHARGE_FY RCY_ECL_WRITEBACK_FY
           RCY_ECL_CLOSING_FY RCY_ECL_CHARGE_FTM RCY_ECL_WRITEBACK_FTM;
    length PROC_DTE $9;
    set work.derived;
    where PATCH_RCY;
    PROC_DTE = catx("-", put(day(&rpt_dt), z2.),
                         propcase(put(&rpt_dt, monname3.)),
                         put(mod(year(&rpt_dt), 100), z2.));

    RCY_ECL_CLOSING_FY    = P_RCY_ECL_CLOSING_FY;
    RCY_ECL_CHARGE_FY     = P_RCY_ECL_CHARGE_FY;
    RCY_ECL_WRITEBACK_FY  = P_RCY_ECL_WRITEBACK_FY;
    RCY_ECL_CHARGE_FTM    = P_RCY_ECL_CHARGE_FTM;
    RCY_ECL_WRITEBACK_FTM = P_RCY_ECL_WRITEBACK_FTM;

    format RCY_ECL_CHARGE_FY RCY_ECL_WRITEBACK_FY RCY_ECL_CLOSING_FY
           RCY_ECL_CHARGE_FTM RCY_ECL_WRITEBACK_FTM 24.2;

    label PROC_DTE              = "PROC_DTE"
          UNIQUE_ID_NO          = "UNIQUE_ID_NO"
          RCY_ECL_CHARGE_FY     = "RCY_ECL_CHARGE_FY"
          RCY_ECL_WRITEBACK_FY  = "RCY_ECL_WRITEBACK_FY"
          RCY_ECL_CLOSING_FY    = "RCY_ECL_CLOSING_FY"
          RCY_ECL_CHARGE_FTM    = "RCY_ECL_CHARGE_FTM"
          RCY_ECL_WRITEBACK_FTM = "RCY_ECL_WRITEBACK_FTM";

    keep PROC_DTE UNIQUE_ID_NO RCY_ECL_CHARGE_FY RCY_ECL_WRITEBACK_FY
         RCY_ECL_CLOSING_FY RCY_ECL_CHARGE_FTM RCY_ECL_WRITEBACK_FTM;
run;

%macro patch_counts;
    %local n_lcy n_rcy;
    proc sql noprint;
        select count(*) into :n_lcy trimmed from mth.frs9_closing_bal;
        select count(*) into :n_rcy trimmed from mth.rcy_to_patch;
    quit;
    %put NOTE: FRS9_CLOSING_BAL &n_lcy row(s), RCY_TO_PATCH &n_rcy row(s).;
%mend;
%patch_counts

proc datasets library=work nolist;
    delete cif_in cif_miss pop pop_m mstr prd fx party prv derived egl_map legs nomap agg;
quit;
