*ProcessBody;

options validvarname=any;

libname sasfiles "C:/Users/FNLNJE/Documents/My SAS Files";

%let rpt_dt  = %sysfunc(inputn(&proc_dte, date9.));
%let yymm    = %sysfunc(putn(&rpt_dt, yymmn4.));
%let rpt_lbl = %sysfunc(putn(&rpt_dt, date9.));
%let egl_dir = C:/Users/FNLNJE/Documents/My SAS Files/eglfile;

%let rpt_dtm = "%sysfunc(putn(&rpt_dt, date9.)):00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

options dlcreatedir;
libname mth "C:/Users/FNLNJE/Documents/My SAS Files/&yymm";

data work.egl_map;
    set sasfiles.egl_mapping;
    length K $60;
    K = catx("|", upcase(strip(LEVEL_3)), upcase(strip(SEC_CLS_CD)),
                  upcase(strip(F_SHORT_TERM_IND)),
                  upcase(strip(F_SHORT_TERM_INCEP_IND)));
    keep K ECL_OPENING ECL_CHARGE ECL_WRITEBACK ECL_WRITEOFF
         ECL_PNL_CHARGE ECL_PNL_WRITEBACK ECL_PNL_WRITEOFF
         UWI_OPENING UWI_CHARGE UWI_WRITEBACK UWI_WRITEOFF
         UWI_PNL_CHARGE UWI_PNL_WRITEBACK UWI_PNL_WRITEOFF
         EIR_BS EIR_PNL FVOCI_BS FVOCI_OCI;
run;

data work.prd(keep=PRODUCT_HIERARCHY_CD LEVEL_3);
    set LBFRS9.T_FRS9_PRD_MSTR(keep=PRODUCT_HIERARCHY_CD LEVEL_3);
run;

%let ml_found = 0;

proc sql noprint;
    select case when count(*) > 0 then 1 else 0 end
      into :ml_found trimmed
      from LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST
     where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
quit;

%macro get_mstr;
    %if &ml_found = 1 %then %do;
        %put NOTE: Master listing taken from LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST.;
        proc sort data=LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST
                      (keep=PROC_DTE V_ACCOUNT_NUMBER F_SHORT_TERM_IND
                            F_SHORT_TERM_INCEP_IND
                            V_CUSTOMER_PARENT_GROUP_NAME V_FINANCING_CODE
                       where=(PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm))
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
                    RCY_ECL_CHARGE_FY RCY_ECL_WRITEBACK_FY
                    RCY_ECL_WRITE_OFF_FY RCY_INT_UNWIND_CHARGE_FY
                    RCY_INT_UNWIND_WRITEBACK_FY RCY_INT_UNWIND_WRITE_OFF_FY
                    LCY_EIR_ADJ_AMT
               where=(PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm))
          out=work.acdtl(drop=PROC_DTE);
    by UNIQUE_ID_NO;
run;

data work.exp_lines(keep=UNIQUE_ID_NO ACCT SEG_CCY DRCR AMOUNT
                         COMPONENT SIGNED_AMT)
     work.exp_excep(keep=UNIQUE_ID_NO LEVEL_3 SEC_CLS_CD COMPONENT AMOUNT REASON);
    merge work.acdtl(in=a) work.mstr;
    by UNIQUE_ID_NO;
    if not a then delete;

    length LEVEL_3 $20 K $60 GLDR GLCR $10 ACCT $60 SEG_CCY $3 DRCR $1
           COMPONENT $14 REASON $40
           S_ENT $3 S_RC $10 S_PRD $10 S_IC $10 S_ISL $4
           ECL_CHARGE ECL_WRITEBACK ECL_WRITEOFF
           ECL_PNL_CHARGE ECL_PNL_WRITEBACK ECL_PNL_WRITEOFF
           UWI_CHARGE UWI_WRITEBACK UWI_WRITEOFF
           UWI_PNL_CHARGE UWI_PNL_WRITEBACK UWI_PNL_WRITEOFF
           EIR_BS EIR_PNL $10;

    if _n_ = 1 then do;
        declare hash p(dataset:"work.prd");
        p.definekey("PRODUCT_HIERARCHY_CD");
        p.definedata("LEVEL_3");
        p.definedone();

        declare hash m(dataset:"work.egl_map");
        m.definekey("K");
        m.definedata("ECL_CHARGE", "ECL_WRITEBACK", "ECL_WRITEOFF",
                     "ECL_PNL_CHARGE", "ECL_PNL_WRITEBACK", "ECL_PNL_WRITEOFF",
                     "UWI_CHARGE", "UWI_WRITEBACK", "UWI_WRITEOFF",
                     "UWI_PNL_CHARGE", "UWI_PNL_WRITEBACK", "UWI_PNL_WRITEOFF",
                     "EIR_BS", "EIR_PNL");
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
        call missing(ECL_CHARGE, ECL_WRITEBACK, ECL_WRITEOFF,
                     ECL_PNL_CHARGE, ECL_PNL_WRITEBACK, ECL_PNL_WRITEOFF,
                     UWI_CHARGE, UWI_WRITEBACK, UWI_WRITEOFF,
                     UWI_PNL_CHARGE, UWI_PNL_WRITEBACK, UWI_PNL_WRITEOFF,
                     EIR_BS, EIR_PNL);

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

    array camt{7} RCY_ECL_CHARGE_FY RCY_ECL_WRITEBACK_FY RCY_ECL_WRITE_OFF_FY
                  RCY_INT_UNWIND_CHARGE_FY RCY_INT_UNWIND_WRITEBACK_FY
                  RCY_INT_UNWIND_WRITE_OFF_FY LCY_EIR_ADJ_AMT;
    array cdr{7}  ECL_PNL_CHARGE ECL_WRITEBACK ECL_WRITEOFF
                  UWI_PNL_CHARGE UWI_WRITEBACK UWI_WRITEOFF EIR_BS;
    array ccr{7}  ECL_CHARGE ECL_PNL_WRITEBACK ECL_PNL_WRITEOFF
                  UWI_CHARGE UWI_PNL_WRITEBACK UWI_PNL_WRITEOFF EIR_PNL;
    array cnm{7}  $14 _temporary_
                  ("ECL charge" "ECL writeback" "ECL write-off"
                   "UWI charge" "UWI writeback" "UWI write-off" "EIR");

    do i = 1 to 7;

        if missing(camt{i}) or round(camt{i}, 0.01) = 0 then continue;
        COMPONENT = cnm{i};
        AMOUNT    = camt{i};

        if missing(cdr{i}) or missing(ccr{i}) then do;
            REASON = ifc(missing(LEVEL_3), "No LEVEL_3 for this product",
                                           "No GL in EGL mapping");
            output work.exp_excep;
            continue;
        end;

        SEG_CCY = ifc(i = 7, "SGD", strip(CURCY_CODE));

        DRCR = "D";  GLDR = cdr{i};
        ACCT = catx("-", S_ENT, S_RC, GLDR, S_PRD, S_IC, "00000", S_ISL, "0000");
        SIGNED_AMT = AMOUNT;
        output work.exp_lines;

        DRCR = "C";  GLCR = ccr{i};
        ACCT = catx("-", S_ENT, S_RC, GLCR, S_PRD, S_IC, "00000", S_ISL, "0000");
        SIGNED_AMT = -AMOUNT;
        output work.exp_lines;
    end;
run;

data mth.postdtl;
    retain UNIQUE_ID_NO ACCT SEG_CCY DRCR AMOUNT COMPONENT;
    set work.exp_lines;
    keep UNIQUE_ID_NO ACCT SEG_CCY DRCR AMOUNT COMPONENT;
    label UNIQUE_ID_NO = "Account number"  ACCT      = "Account"
          SEG_CCY      = "Currency"        DRCR      = "Dr/Cr"
          AMOUNT       = "Amount"          COMPONENT = "Component";
    format AMOUNT comma20.2;
run;

proc means data=work.exp_lines noprint nway;
    class ACCT SEG_CCY;
    var SIGNED_AMT;
    output out=work.exp_net(drop=_type_ _freq_) sum=EXPECTED;
run;

data work.act_raw(keep=ACCT SEG_CCY SIGNED_AMT);
    length fn $300 base $64 F_CODE $2 F_DTE $6
           f1 f2 $20 DRCR $1 f5 $20
           s1 $3 s2 $10 s3 $10 s4 $10 s5 $10 s6 $10 s7 $10 s8 $10
           f14-f20 $20 RPT_DATE $20 SEG_CCY $3 f25 $20 DESCR $60
           ACCT $60;
    infile "&egl_dir/*.csv" dsd dlm="|" truncover filename=fn;

    input @;
    base   = scan(fn, -1, "\/");
    F_CODE = substr(base, 10, 2);
    F_DTE  = substr(base, 12, 6);

    if not (input(F_DTE, ddmmyy6.) = &rpt_dt and F_CODE ne "11") then delete;
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

proc means data=work.act_raw noprint nway;
    class ACCT SEG_CCY;
    var SIGNED_AMT;
    output out=work.act_net(drop=_type_ _freq_) sum=ACTUAL;
run;

proc sort data=work.exp_net; by ACCT SEG_CCY; run;
proc sort data=work.act_net; by ACCT SEG_CCY; run;

data mth.postchk;
    merge work.exp_net(in=e) work.act_net(in=a);
    by ACCT SEG_CCY;
    length ENTITY $3 ENTITY_NAME $3 GL_NO $10 STATUS $22;

    if EXPECTED = . then EXPECTED = 0;
    if ACTUAL   = . then ACTUAL   = 0;
    DIFF = round(ACTUAL - EXPECTED, 0.01);

    if      DIFF = 0        then STATUS = "Match";
    else if not a           then STATUS = "Missing from posting";
    else if not e           then STATUS = "Not expected";
    else                         STATUS = "Amount differs";

    ENTITY = scan(ACCT, 1, "-");
    GL_NO  = scan(ACCT, 3, "-");
    select (ENTITY);
        when ("128") ENTITY_NAME = "MBS";
        when ("252") ENTITY_NAME = "MSL";
        otherwise    ENTITY_NAME = "???";
    end;
run;

proc sql noprint;
    select count(*) into :n_exc  trimmed
      from mth.postchk where STATUS ne "Match";
    select count(*) into :n_bad  trimmed from work.exp_excep;
quit;

%macro show_post;
    %if &n_bad > 0 %then %do;
        title "GL mapping - &n_bad account(s) with amounts but no GL";
        proc print data=work.exp_excep noobs label;
            var UNIQUE_ID_NO LEVEL_3 SEC_CLS_CD COMPONENT AMOUNT REASON;
            format AMOUNT comma20.2;
        run;
        title;
    %end;
    %else %do;
        data work.no_bad;
            length Result $80;
            Result = "All accounts with amounts found a GL in the EGL mapping";
        run;
        title "GL mapping &yymm";
        proc print data=work.no_bad noobs label;
            label Result = "Result";
        run;
        title;
    %end;

    %if &n_exc = 0 %then %do;
        data work.no_exc;
            length Result $80;
            Result = "Posting file agrees with RDL for &rpt_lbl";
        run;
        title "Posting Check &yymm";
        proc print data=work.no_exc noobs label;
            label Result = "Result";
        run;
        title;
    %end;
    %else %do;
        title "Posting Check &yymm - &n_exc exception(s)";
        proc print data=mth.postchk noobs label;
            where STATUS ne "Match";
            var ENTITY_NAME GL_NO ACCT SEG_CCY EXPECTED ACTUAL DIFF STATUS;
            format EXPECTED ACTUAL DIFF comma20.2;
            label ENTITY_NAME = "Entity"    GL_NO    = "GL"
                  ACCT        = "Account"   SEG_CCY  = "Ccy"
                  EXPECTED    = "Expected (RDL)"
                  ACTUAL      = "Actual (HO file)"
                  DIFF        = "Difference" STATUS  = "Status";
        run;
        title;
    %end;
%mend;
%show_post

proc datasets library=work nolist;
    delete egl_map prd mstr acdtl exp_lines exp_net act_raw act_net
           exp_excep no_bad no_exc;
quit;
