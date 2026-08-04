*ProcessBody;

options validvarname=any;

libname sasfiles "C:/Users/FNLNJE/Documents/My SAS Files";

%let rpt_dt   = %sysfunc(inputn(&proc_dte, date9.));
%let yymm     = %sysfunc(putn(&rpt_dt, yymmn4.));
%let rpt_lbl  = %sysfunc(putn(&rpt_dt, date9.));
%let per_exp  = %upcase(%sysfunc(putn(&rpt_dt, monyy5.)));
%let tb_dir   = C:/Users/FNLNJE/Documents/My SAS Files/posttb;

options dlcreatedir;
libname mth "C:/Users/FNLNJE/Documents/My SAS Files/&yymm";

data work.egl_map;
    set sasfiles.egl_mapping;
    length K $60;
    K = catx("|", upcase(strip(LEVEL_3)), upcase(strip(SEC_CLS_CD)),
                  upcase(strip(F_SHORT_TERM_IND)),
                  upcase(strip(F_SHORT_TERM_INCEP_IND)));
    keep K ECL_OPENING ECL_CHARGE ECL_WRITEBACK ECL_WRITEOFF
         UWI_OPENING UWI_CHARGE UWI_WRITEBACK UWI_WRITEOFF
         EIR_BS FVOCI_BS;
run;

data work.gl_lbl_raw(keep=GL_NO COMPONENT);
    set work.egl_map;
    length GL_NO $10 COMPONENT $14;
    array g{10} $ ECL_OPENING ECL_CHARGE ECL_WRITEBACK ECL_WRITEOFF
                  UWI_OPENING UWI_CHARGE UWI_WRITEBACK UWI_WRITEOFF
                  EIR_BS FVOCI_BS;
    array n{10} $14 _temporary_
                ("ECL opening" "ECL charge" "ECL writeback" "ECL write-off"
                 "UWI opening" "UWI charge" "UWI writeback" "UWI write-off"
                 "EIR" "FVOCI");
    do i = 1 to 10;
        if not missing(g{i}) then do;
            GL_NO = g{i};  COMPONENT = n{i};  output;
        end;
    end;
run;

proc sort data=work.gl_lbl_raw nodupkey;  by GL_NO COMPONENT;  run;

data work.gl_lbl(keep=GL_NO COMPONENT);
    set work.gl_lbl_raw(rename=(COMPONENT=_c));
    by GL_NO;
    length COMPONENT $40;
    retain COMPONENT;
    if first.GL_NO then COMPONENT = "";
    COMPONENT = catx(" + ", COMPONENT, _c);
    if last.GL_NO then output;
run;

data work.fmt_bsgl(keep=fmtname type start label hlo);
    length fmtname $8 type $1 start $10 label $1 hlo $1;
    retain fmtname "BSGL" type "C";
    set work.egl_map end=eof;

    array g{*} $ ECL_OPENING ECL_CHARGE ECL_WRITEBACK ECL_WRITEOFF
                 UWI_OPENING UWI_CHARGE UWI_WRITEBACK UWI_WRITEOFF
                 EIR_BS FVOCI_BS;
    do i = 1 to dim(g);
        if not missing(g{i}) then do;
            start = g{i};  label = "Y";  hlo = "";  output;
        end;
    end;
    if eof then do;
        start = "";  label = "N";  hlo = "O";  output;
    end;
run;

proc sort data=work.fmt_bsgl nodupkey;  by start hlo;  run;
proc format cntlin=work.fmt_bsgl;       run;

data work.fmt_excl(keep=fmtname type start label hlo);
    length fmtname $8 type $1 start $10 label $1 hlo $1;
    retain fmtname "EXCLDTL" type "C";
    set work.egl_map end=eof;
    array g{*} $ ECL_OPENING UWI_OPENING EIR_BS;
    do i = 1 to dim(g);
        if not missing(g{i}) then do;
            start = g{i};  label = "Y";  hlo = "";  output;
        end;
    end;
    if eof then do;
        start = "";  label = "N";  hlo = "O";  output;
    end;
run;

proc sort data=work.fmt_excl nodupkey;  by start hlo;  run;
proc format cntlin=work.fmt_excl;       run;

proc sort data=LBFRS9.T_FRS9_PRD_MSTR(keep=PRODUCT_HIERARCHY_CD LEVEL_3)
          out=work.prd nodupkey;
    by PRODUCT_HIERARCHY_CD;
run;

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
                   V_CUSTOMER_PARENT_GROUP_NAME $30 V_FINANCING_CODE $1;
            stop;
        run;
    %end;
%mend;
%get_mstr

proc sort data=LBFRS9.T_MTH_FRS9_RDL_AC_DTL
              (keep=PROC_DTE UNIQUE_ID_NO CURCY_CODE LEGAL_ENTITY SEC_CLS_CD
                    SRC_PROD_TYPE_CD AC_MGR_UNIT_CODE GL_AC_ID
                    RCY_ECL_OPENING_BAL RCY_ECL_CHARGE_FY
                    RCY_ECL_WRITEBACK_FY RCY_ECL_WRITE_OFF_FY
                    RCY_INT_UNWIND_OPENING_FY RCY_INT_UNWIND_CHARGE_FY
                    RCY_INT_UNWIND_WRITEBACK_FY RCY_INT_UNWIND_WRITE_OFF_FY
                    LCY_EIR_ADJ_AMT RCY_FAIR_VALUE
               where=(datepart(PROC_DTE) = &rpt_dt))
          out=work.acdtl(drop=PROC_DTE);
    by UNIQUE_ID_NO;
run;

data work.exp_lines(keep=UNIQUE_ID_NO ACCT SEG_CCY SIGNED_AMT COMPONENT)
     work.exp_excep(keep=UNIQUE_ID_NO LEVEL_3 SEC_CLS_CD COMPONENT AMOUNT REASON);
    merge work.acdtl(in=a) work.mstr;
    by UNIQUE_ID_NO;
    if not a then delete;

    length LEVEL_3 $20 K $60 ACCT $60 SEG_CCY $3 COMPONENT $14 REASON $40
           S_ENT $3 S_RC $10 S_PRD $10 S_IC $10 S_ISL $4
           ECL_OPENING ECL_CHARGE ECL_WRITEBACK ECL_WRITEOFF
           UWI_OPENING UWI_CHARGE UWI_WRITEBACK UWI_WRITEOFF
           EIR_BS FVOCI_BS $10;

    if _n_ = 1 then do;
        declare hash p(dataset:"work.prd");
        p.definekey("PRODUCT_HIERARCHY_CD");
        p.definedata("LEVEL_3");
        p.definedone();

        declare hash m(dataset:"work.egl_map");
        m.definekey("K");
        m.definedata("ECL_OPENING", "ECL_CHARGE", "ECL_WRITEBACK",
                     "ECL_WRITEOFF", "UWI_OPENING", "UWI_CHARGE",
                     "UWI_WRITEBACK", "UWI_WRITEOFF", "EIR_BS", "FVOCI_BS");
        m.definedone();
    end;

    length PRODUCT_HIERARCHY_CD $20;
    PRODUCT_HIERARCHY_CD = SRC_PROD_TYPE_CD;
    call missing(LEVEL_3);
    if p.find() ne 0 then LEVEL_3 = "";

    if upcase(strip(LEVEL_3)) in ("BANK GUARANTEE", "LETTER OF CREDIT",
                                  "SHIPPING GUARANTEE")
        then LEVEL_3 = "Off Balance Sheet";
    if upcase(strip(SRC_PROD_TYPE_CD)) in ("SG_REVRPO", "SG_ISLMREVRPO")
        then LEVEL_3 = "Rev Repo";

    K = catx("|", upcase(strip(LEVEL_3)), upcase(strip(SEC_CLS_CD)),
                  upcase(strip(F_SHORT_TERM_IND)),
                  upcase(strip(F_SHORT_TERM_INCEP_IND)));
    if m.find() ne 0 then
        call missing(ECL_OPENING, ECL_CHARGE, ECL_WRITEBACK, ECL_WRITEOFF,
                     UWI_OPENING, UWI_CHARGE, UWI_WRITEBACK, UWI_WRITEOFF,
                     EIR_BS, FVOCI_BS);

    select (strip(LEGAL_ENTITY));
        when ("001") S_ENT = "128";
        when ("003") S_ENT = "252";
        otherwise    S_ENT = "???";
    end;
    S_RC  = strip(AC_MGR_UNIT_CODE);
    S_PRD = strip(GL_AC_ID);
    S_IC  = ifc(missing(V_CUSTOMER_PARENT_GROUP_NAME), "000",
                strip(V_CUSTOMER_PARENT_GROUP_NAME));
    S_ISL = ifc(upcase(strip(V_FINANCING_CODE)) = "I", "8999", "0000");

    array camt{10} RCY_ECL_OPENING_BAL RCY_ECL_CHARGE_FY
                   RCY_ECL_WRITEBACK_FY RCY_ECL_WRITE_OFF_FY
                   RCY_INT_UNWIND_OPENING_FY RCY_INT_UNWIND_CHARGE_FY
                   RCY_INT_UNWIND_WRITEBACK_FY RCY_INT_UNWIND_WRITE_OFF_FY
                   LCY_EIR_ADJ_AMT RCY_FAIR_VALUE;
    array cgl{10}  ECL_OPENING ECL_CHARGE ECL_WRITEBACK ECL_WRITEOFF
                   UWI_OPENING UWI_CHARGE UWI_WRITEBACK UWI_WRITEOFF
                   EIR_BS FVOCI_BS;
    array csg{10}  _temporary_ (-1 -1 1 1 -1 -1 1 1 1 1);
    array cnm{10}  $14 _temporary_
                   ("ECL opening" "ECL charge" "ECL writeback"
                    "ECL write-off" "UWI opening" "UWI charge"
                    "UWI writeback" "UWI write-off" "EIR" "FVOCI");

    do i = 1 to 10;
        if missing(camt{i}) or round(camt{i}, 0.01) = 0 then continue;
        COMPONENT = cnm{i};
        AMOUNT    = camt{i};

        if missing(cgl{i}) then do;
            REASON = ifc(missing(LEVEL_3), "No LEVEL_3 for this product",
                                           "No GL in EGL mapping");
            output work.exp_excep;
            continue;
        end;

        SEG_CCY = ifc(i = 9, "SGD", strip(CURCY_CODE));

        if i = 10 then
            ACCT = catx("-", S_ENT, "82101", cgl{i},
                             "00000", "000", "00000", "0000", "0000");
        else
            ACCT = catx("-", S_ENT, S_RC, cgl{i}, S_PRD, S_IC,
                             "00000", S_ISL, "0000");

        SIGNED_AMT = csg{i} * AMOUNT;
        output work.exp_lines;
    end;
run;

data mth.postrecondtl;
    retain UNIQUE_ID_NO ACCT SEG_CCY AMOUNT COMPONENT;
    set work.exp_lines(rename=(SIGNED_AMT=AMOUNT));
    keep UNIQUE_ID_NO ACCT SEG_CCY AMOUNT COMPONENT;
    label UNIQUE_ID_NO = "Account number"  ACCT      = "Account"
          SEG_CCY      = "Currency"        AMOUNT    = "Amount"
          COMPONENT    = "Component";
    format AMOUNT comma20.2;
run;

proc means data=work.exp_lines noprint nway;
    class ACCT SEG_CCY;
    var SIGNED_AMT;
    output out=work.exp_net(drop=_type_ _freq_) sum=RDL_AMT;
run;

data work.tb_all;
    length LEDGER_ID 8 PERIOD $10 ACCOUNT_NAME $100 ACCOUNTS $60
           CURRENCY $3 ACC_PROD $20 GL_NO $10 _dlm $1;
    retain _dlm ",";
    infile "&tb_dir/*.txt" dsd truncover dlm=_dlm;

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

    GL_NO = scan(ACCOUNTS, 3, "-");
run;

proc sql noprint;
    select count(distinct scan(ACCOUNTS, 1, "-")) into :n_ent trimmed
      from work.tb_all;
    select sum(compress(upcase(PERIOD), "-") ne "&per_exp") into :n_bad_per trimmed
      from work.tb_all;
quit;

%macro post_recon;
    %if &n_ent ne 2 %then %do;
        %put ERROR: Expected 2 entities in &tb_dir, found &n_ent..;
        %return;
    %end;
    %if &n_bad_per ne 0 %then %do;
        %put ERROR: &n_bad_per line(s) are not period &per_exp - stale TB.;
        %return;
    %end;

    proc means data=work.tb_all noprint nway;
        where put(GL_NO, $bsgl.) = "Y";
        class ACCOUNTS CURRENCY;
        var YTD_NET_ENTERED;
        output out=work.tb_net(drop=_type_ _freq_
                               rename=(ACCOUNTS=ACCT CURRENCY=SEG_CCY))
               sum=TB_AMT;
    run;

    proc sort data=work.exp_net;  by ACCT SEG_CCY;  run;
    proc sort data=work.tb_net;   by ACCT SEG_CCY;  run;

    data mth.postrecon;
        merge work.exp_net(in=r) work.tb_net(in=t);
        by ACCT SEG_CCY;
        length ENTITY $3 ENTITY_NAME $3 GL_NO $10 STATUS $22
               COMPONENT $40 EXCL_FLG $1;

        if _n_ = 1 then do;
            declare hash L(dataset:"work.gl_lbl");
            L.definekey("GL_NO");
            L.definedata("COMPONENT");
            L.definedone();
        end;

        if RDL_AMT = . then RDL_AMT = 0;
        if TB_AMT  = . then TB_AMT  = 0;
        DIFF = round(TB_AMT - RDL_AMT, 0.01);

        if      DIFF = 0  then STATUS = "Match";
        else if not t     then STATUS = "Missing from TB";
        else if not r     then STATUS = "Not in RDL";
        else                   STATUS = "Amount differs";

        ENTITY = scan(ACCT, 1, "-");
        GL_NO  = scan(ACCT, 3, "-");

        call missing(COMPONENT);
        if L.find() ne 0 then COMPONENT = "";

        select (ENTITY);
            when ("128") ENTITY_NAME = "MBS";
            when ("252") ENTITY_NAME = "MSL";
            otherwise    ENTITY_NAME = "???";
        end;

        EXCL_FLG = put(GL_NO, $excldtl.);
    run;

    proc means data=mth.postrecon noprint nway;
        where EXCL_FLG = "Y";
        class ENTITY_NAME COMPONENT GL_NO SEG_CCY;
        var DIFF;
        output out=work.summ(drop=_type_ _freq_) sum=TOT_DIFF;
    run;

    data work.summ;
        set work.summ;
        if round(TOT_DIFF, 0.01) ne 0;
        ABS_DIFF = abs(TOT_DIFF);
    run;

    proc sort data=work.summ;
        by descending ABS_DIFF;
    run;

    proc sql noprint;
        select count(*) into :n_sum trimmed from work.summ;
        select count(*) into :n_exc trimmed
          from mth.postrecon
         where STATUS ne "Match" and EXCL_FLG ne "Y";
        select count(*) into :n_map trimmed from work.exp_excep;
    quit;

    %if &n_map > 0 %then %do;
        title "GL mapping - &n_map account(s) with amounts but no GL";
        proc print data=work.exp_excep noobs label;
            var UNIQUE_ID_NO LEVEL_3 SEC_CLS_CD COMPONENT AMOUNT REASON;
            format AMOUNT comma20.2;
        run;
        title;
    %end;
    %else %do;
        data work.no_map;
            length Result $80;
            Result = "All accounts with amounts found a GL in the EGL mapping";
        run;
        title "GL mapping &yymm";
        proc print data=work.no_map noobs label;  label Result = "Result";  run;
        title;
    %end;

    %if &n_sum = 0 %then %do;
        data work.no_sum;
            length Result $80;
            Result = "Opening and EIR net to zero at GL and currency level";
        run;
        title "Opening and EIR summary &yymm";
        proc print data=work.no_sum noobs label;  label Result = "Result";  run;
        title;
    %end;
    %else %do;
        title "Opening and EIR summary &yymm - &n_sum with net difference";
        proc print data=work.summ noobs label;
            var ENTITY_NAME COMPONENT GL_NO SEG_CCY TOT_DIFF;
            format TOT_DIFF comma20.2;
            label ENTITY_NAME = "Entity"  COMPONENT = "Component"
                  GL_NO       = "GL"      SEG_CCY   = "Ccy"
                  TOT_DIFF    = "Difference";
        run;
        title;
    %end;

    %if &n_exc = 0 %then %do;
        data work.no_exc;
            length Result $80;
            Result = "No account-level differences for &rpt_lbl (BS, excl opening and EIR)";
        run;
        title "Post-Posting TB Recon &yymm";
        proc print data=work.no_exc noobs label;  label Result = "Result";  run;
        title;
    %end;
    %else %do;
        title "Post-Posting TB Recon &yymm - &n_exc exception(s), excl opening and EIR";
        proc print data=mth.postrecon noobs label;
            where STATUS ne "Match" and EXCL_FLG ne "Y";
            var ENTITY_NAME GL_NO COMPONENT ACCT SEG_CCY
                RDL_AMT TB_AMT DIFF STATUS;
            format RDL_AMT TB_AMT DIFF comma20.2;
            label ENTITY_NAME = "Entity"   GL_NO     = "GL"
                  COMPONENT   = "Component"
                  ACCT        = "Account"  SEG_CCY   = "Ccy"
                  RDL_AMT     = "RDL"      TB_AMT    = "Trial balance"
                  DIFF        = "Difference"  STATUS = "Status";
        run;
        title;
    %end;
%mend;
%post_recon

proc datasets library=work nolist;
    delete egl_map gl_lbl_raw gl_lbl fmt_bsgl fmt_excl prd mstr acdtl
           exp_lines exp_net exp_excep tb_all tb_net summ no_map no_sum no_exc;
quit;
