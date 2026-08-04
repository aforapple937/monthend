*ProcessBody;

libname sasfiles "C:/Users/FNLNJE/Documents/My SAS Files";

%let rpt_dt  = %sysfunc(inputn(&proc_dte, date9.));
%let prv_dt  = %sysfunc(intnx(month, &rpt_dt, -1, e));
%let yymm    = %sysfunc(putn(&rpt_dt, yymmn4.));
%let rpt_lbl = %sysfunc(putn(&rpt_dt, date9.));
%let prv_lbl = %sysfunc(putn(&prv_dt, date9.));

%let rpt_lo  = "&rpt_lbl:00:00:00"dt;
%let rpt_hi  = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;
%let prv_lo  = "&prv_lbl:00:00:00"dt;
%let prv_hi  = "%sysfunc(putn(%eval(&prv_dt + 1), date9.)):00:00:00"dt;

%let rpt_win = %sysfunc(intnx(month, &rpt_dt, -11, b));

%let remark  = %sysfunc(putn(&rpt_dt, monyy5.)) MTM - LOANS FVOCI;
%let rev_rmk = ER %sysfunc(putn(&prv_dt, monyy5.)) MTM - LOANS FVOCI;

%let entity  = MBB-SG;
%let prods   = 'SG_ISLMBIZTERMLN','SG_ISLMTERMLN','SG_ISLMVSLN','SG_PROJFIN','SG_SYNDRCL','SG_SYNDTL','SG_TERMLN','SG_VSLN';

options dlcreatedir;
libname mth  "C:/Users/FNLNJE/Documents/My SAS Files/&yymm";
libname glte "C:/Users/FNLNJE/Documents/My SAS Files/&yymm/glte";
options nodlcreatedir;

proc sort data=LBDWH.T_DAL_CURCY_EXCHG
              (keep=PROC_DTE CURCY_CODE EXCHG_RT
               where=(PROC_DTE >= &rpt_lo and PROC_DTE < &rpt_hi))
          out=work.fx(drop=PROC_DTE) nodupkey;
    by CURCY_CODE;
run;

data work.ln_cur;
    set LBFRS9.T_MTH_FRS9_LN_DTL
        (keep=PROC_DTE AC_CODE CIF_NO CURCY_CODE LEGAL_ENTITY_CODE
              IFRS9_CLASS_CODE PRD_CODE CURR_INT_RT BASE_RT
              RCY_END_PERIOD_BAL RCY_ACCRUED_INT RPYM_TYP INT_PYM_FREQ
              INT_PYM_FREQ_UNIT DEFAULT_FLG MATURITY_DTE VALUE_DTE
              AA_FAC_REF RT_TYP_DESC ACCT_STATUS_CODE
         where=(PROC_DTE >= &rpt_lo and PROC_DTE < &rpt_hi
                and upcase(strip(ACCT_STATUS_CODE)) = "ACTIVE"));
run;

proc sql noprint;
    create table work.wpop as
    select  l.PROC_DTE
          , l.AC_CODE
          , l.CIF_NO
          , l.LEGAL_ENTITY_CODE
          , l.PRD_CODE
          , l.ACCT_STATUS_CODE
          , l.VALUE_DTE
          , l.CURCY_CODE
          , l.RT_TYP_DESC
          , l.CURR_INT_RT
          , l.RCY_END_PERIOD_BAL
          , l.RCY_ACCRUED_INT
          , f.EXCHG_RT
          , (l.RCY_END_PERIOD_BAL - l.RCY_ACCRUED_INT) * f.EXCHG_RT  as LCY_NET
          , calculated LCY_NET * (l.CURR_INT_RT / 100)               as INT_COMP
    from      work.ln_cur as l
    left join work.fx     as f
      on l.CURCY_CODE = f.CURCY_CODE
    where upcase(strip(l.LEGAL_ENTITY_CODE)) = "&entity"
      and upcase(strip(l.PRD_CODE)) in (&prods)
      and datepart(l.VALUE_DTE) between &rpt_win and &rpt_dt
    ;

    select sum(INT_COMP) / sum(LCY_NET) format=best32.
      into :avg_wair trimmed
    from work.wpop;

    create table work.wair as
    select  RT_TYP_DESC
          , CURCY_CODE
          , sum(INT_COMP) / sum(LCY_NET) as WAIR format=best32.
    from work.wpop
    group by RT_TYP_DESC, CURCY_CODE
    ;
quit;

proc sql noprint;
    create table work.prv_mark as
    select  UNIQUE_ID_NO   as AC_CODE
          , LCY_FAIR_VALUE as PREV_MTM_GAINLOSS
    from LBFRS9.T_MTH_FRS9_RDL_AC_DTL
         (keep=PROC_DTE UNIQUE_ID_NO SEC_CLS_CD LCY_FAIR_VALUE)
    where PROC_DTE >= &prv_lo and PROC_DTE < &prv_hi
      and upcase(strip(SEC_CLS_CD)) = "FVOCI"
    ;
quit;

proc sql noprint;
    create table work.fv_prep as
    select  l.PROC_DTE
          , l.AC_CODE
          , l.CIF_NO
          , l.CURCY_CODE
          , l.LEGAL_ENTITY_CODE
          , l.IFRS9_CLASS_CODE
          , l.PRD_CODE
          , l.CURR_INT_RT
          , l.BASE_RT
          , l.RCY_END_PERIOD_BAL
          , l.RCY_ACCRUED_INT
          , l.RPYM_TYP
          , l.INT_PYM_FREQ
          , l.INT_PYM_FREQ_UNIT
          , l.DEFAULT_FLG
          , l.MATURITY_DTE
          , l.AA_FAC_REF
          , l.RT_TYP_DESC
          , f.EXCHG_RT
          , coalesce(w.WAIR, &avg_wair)   as WAIR
          , p.PREV_MTM_GAINLOSS
    from      work.ln_cur   as l
    left join work.fx       as f  on l.CURCY_CODE  = f.CURCY_CODE
    left join work.wair     as w  on l.RT_TYP_DESC = w.RT_TYP_DESC
                                 and l.CURCY_CODE  = w.CURCY_CODE
    left join work.prv_mark as p  on l.AC_CODE     = p.AC_CODE
    where upcase(strip(l.IFRS9_CLASS_CODE)) = "FVOCI"
    order by l.AC_CODE
    ;
quit;

%macro gl_legs(in=, out=, sign=, remark=);
    data work.&out
        (keep=CCY COST_CENTRE ACCOUNT PRODUCT INTERCO FUTURE1
              SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS);
        retain CCY COST_CENTRE ACCOUNT PRODUCT INTERCO FUTURE1
               SUB_ACCOUNT FUTURE3 DEBIT CREDIT REMARKS;
        length CCY $3   COST_CENTRE $10 ACCOUNT $7  PRODUCT $5
               INTERCO $3 FUTURE1 $5    SUB_ACCOUNT $4 FUTURE3 $4
               DEBIT 8  CREDIT 8        REMARKS $50;
        set work.&in;

        COST_CENTRE = "82101";
        PRODUCT     = "00000";
        INTERCO     = "000";
        FUTURE1     = "00000";
        SUB_ACCOUNT = "0000";
        FUTURE3     = "0000";
        REMARKS     = "&remark";

        _amt = (&sign) * AMT;

        ACCOUNT = "1220001";
        if _amt > 0 then do;  DEBIT = _amt;       CREDIT = 0;           end;
        else             do;  DEBIT = 0;          CREDIT = abs(_amt);   end;
        output;

        ACCOUNT = "4121514";
        if _amt > 0 then do;  DEBIT = 0;          CREDIT = _amt;        end;
        else             do;  DEBIT = abs(_amt);  CREDIT = 0;           end;
        output;

        format DEBIT CREDIT 18.2;
    run;
%mend;

proc sql noprint;
    select count(*) into :n_fv trimmed
      from work.fv_prep;
    select count(*) into :n_norate trimmed
      from work.fv_prep where EXCHG_RT is missing;
quit;

%macro fvoci_mtm;

    %if &n_fv = 0 %then %do;
        %put ERROR: No active FVOCI loan accounts at &rpt_lbl - nothing to mark.;
        %return;
    %end;
    %if &avg_wair = . %then %do;
        %put ERROR: No qualifying new business between %sysfunc(putn(&rpt_win, date9.)) and &rpt_lbl - no WAIR to discount at.;
        %return;
    %end;
    %if &n_norate ne 0 %then %do;
        %put ERROR: &n_norate FVOCI account(s) have no &rpt_lbl exchange rate - balances would convert to missing.;
        %return;
    %end;

    data mth.fvocimtm
        (keep=PROC_DTE AC_CODE CIF_NO CIF_NAME CURCY_CODE LEGAL_ENTITY_CODE
              IFRS9_CLASS_CODE PRD_CODE CURR_INT_RT BASE_RT VAR_RT
              RCY_END_PERIOD_BAL RCY_ACCRUED_INT EXCHG_RT
              LCY_END_PERIOD_BAL LCY_ACCRUED_INT
              RPYM_TYP INT_PYM_FREQ INT_PYM_FREQ_UNIT DEFAULT_FLG
              MATURITY_DTE AA_FAC_REF RT_TYP_DESC
              MOB LT_6_MONTHS RESIDUAL_MTH WAIR PERIODIC_PAYT
              MKT_VALUE_PERIODIC MKT_VALUE_FINAL MKT_VALUE_TOTAL
              LCY_MKT_VALUE_CHG RCY_MKT_VALUE_CHG PREV_MTM_GAINLOSS VARIANCE);

        retain PROC_DTE AC_CODE CIF_NO CIF_NAME CURCY_CODE LEGAL_ENTITY_CODE
               IFRS9_CLASS_CODE PRD_CODE CURR_INT_RT BASE_RT VAR_RT
               RCY_END_PERIOD_BAL RCY_ACCRUED_INT EXCHG_RT
               LCY_END_PERIOD_BAL LCY_ACCRUED_INT
               RPYM_TYP INT_PYM_FREQ INT_PYM_FREQ_UNIT DEFAULT_FLG
               MATURITY_DTE AA_FAC_REF RT_TYP_DESC
               MOB LT_6_MONTHS RESIDUAL_MTH WAIR PERIODIC_PAYT
               MKT_VALUE_PERIODIC MKT_VALUE_FINAL MKT_VALUE_TOTAL
               LCY_MKT_VALUE_CHG RCY_MKT_VALUE_CHG PREV_MTM_GAINLOSS VARIANCE;
        length CIF_NAME $255 LT_6_MONTHS $1;
        set work.fv_prep;

        if _n_ = 1 then do;

            declare hash C(dataset:"LBDWH.V_T_CIF_MSTR(keep=CIF_NO CIF_NAME)");
            C.definekey("CIF_NO");
            C.definedata("CIF_NAME");
            C.definedone();
        end;
        call missing(CIF_NAME);
        if C.find() ne 0 then call missing(CIF_NAME);

        VAR_RT             = CURR_INT_RT - BASE_RT;
        LCY_END_PERIOD_BAL = RCY_END_PERIOD_BAL * EXCHG_RT;
        LCY_ACCRUED_INT    = RCY_ACCRUED_INT    * EXCHG_RT;
        _bal_net           = LCY_END_PERIOD_BAL - LCY_ACCRUED_INT;

        RESIDUAL_MTH = abs(yrdif(datepart(PROC_DTE), datepart(MATURITY_DTE),
                                 '30/360')) * 12;

        MOB = (year(datepart(PROC_DTE))  - input(substr(AA_FAC_REF, 2, 4), 4.)) * 12
            + (month(datepart(PROC_DTE)) - input(substr(AA_FAC_REF, 6, 2), 2.));

        if MOB < 6 then LT_6_MONTHS = "Y";
        else            LT_6_MONTHS = "N";

        if RPYM_TYP = '100' and INT_PYM_FREQ = 3 and INT_PYM_FREQ_UNIT = 'M' then
            PERIODIC_PAYT = (CURR_INT_RT/100/4*_bal_net)
                            / (1 - (1 + CURR_INT_RT/100/4)**(-RESIDUAL_MTH/12*4));
        else if RPYM_TYP = '100' and INT_PYM_FREQ = 1 and INT_PYM_FREQ_UNIT = 'M' then
            PERIODIC_PAYT = (CURR_INT_RT/100/12*_bal_net)
                            / (1 - (1 + CURR_INT_RT/100/12)**(-RESIDUAL_MTH));
        else if RPYM_TYP = '100' and INT_PYM_FREQ_UNIT = 'D' then
            PERIODIC_PAYT = (CURR_INT_RT/100/(365/INT_PYM_FREQ)*_bal_net)
                            / (1 - (1 + CURR_INT_RT/100/(365/INT_PYM_FREQ))
                                   **(-RESIDUAL_MTH/12*365/INT_PYM_FREQ));
        else if INT_PYM_FREQ_UNIT = 'M' then
            PERIODIC_PAYT = _bal_net*CURR_INT_RT/100/12*INT_PYM_FREQ;
        else if INT_PYM_FREQ_UNIT = 'D' then
            PERIODIC_PAYT = _bal_net*CURR_INT_RT/100/365*INT_PYM_FREQ;
        else PERIODIC_PAYT = .;

        if INT_PYM_FREQ_UNIT = 'M' then
            MKT_VALUE_PERIODIC =
                (PERIODIC_PAYT * ((1 - (1 + (WAIR/(12/INT_PYM_FREQ)))
                                       **(-RESIDUAL_MTH/INT_PYM_FREQ))
                                  / (WAIR/(12/INT_PYM_FREQ)))) + LCY_ACCRUED_INT;
        else if INT_PYM_FREQ_UNIT = 'D' then
            MKT_VALUE_PERIODIC =
                (PERIODIC_PAYT * ((1 - (1 + (WAIR/(365/INT_PYM_FREQ)))
                                       **(-RESIDUAL_MTH/12*365/INT_PYM_FREQ))
                                  / (WAIR/(365/INT_PYM_FREQ)))) + LCY_ACCRUED_INT;
        else MKT_VALUE_PERIODIC = .;

        if RPYM_TYP ne '100' then
            MKT_VALUE_FINAL = _bal_net / (1 + WAIR/12)**RESIDUAL_MTH;
        else MKT_VALUE_FINAL = 0;

        if RESIDUAL_MTH <= 12 or DEFAULT_FLG = 'Y' or LT_6_MONTHS = 'Y' then
            MKT_VALUE_TOTAL = LCY_END_PERIOD_BAL;
        else MKT_VALUE_TOTAL = MKT_VALUE_PERIODIC + MKT_VALUE_FINAL;

        LCY_MKT_VALUE_CHG = MKT_VALUE_TOTAL - LCY_END_PERIOD_BAL;
        RCY_MKT_VALUE_CHG = LCY_MKT_VALUE_CHG / EXCHG_RT;

        VARIANCE = LCY_MKT_VALUE_CHG - coalesce(PREV_MTM_GAINLOSS, 0);

        format LCY_END_PERIOD_BAL LCY_ACCRUED_INT PERIODIC_PAYT
               MKT_VALUE_PERIODIC MKT_VALUE_FINAL MKT_VALUE_TOTAL
               LCY_MKT_VALUE_CHG RCY_MKT_VALUE_CHG PREV_MTM_GAINLOSS
               VARIANCE comma20.2
               WAIR 12.9;
    run;

    proc sql;
        create table mth.fvociwair as
        select  p.PROC_DTE
              , p.AC_CODE
              , p.CIF_NO
              , p.LEGAL_ENTITY_CODE
              , p.PRD_CODE
              , p.ACCT_STATUS_CODE
              , p.VALUE_DTE
              , p.CURCY_CODE
              , p.RT_TYP_DESC
              , p.CURR_INT_RT
              , p.RCY_END_PERIOD_BAL format=comma20.2
              , p.RCY_ACCRUED_INT    format=comma20.2
              , p.EXCHG_RT
              , p.LCY_NET            format=comma20.2
              , p.INT_COMP           format=comma20.2
              , w.WAIR               format=12.9
              , &avg_wair as AVG_WAIR format=12.9
        from      work.wpop as p
        left join work.wair as w
          on p.RT_TYP_DESC = w.RT_TYP_DESC
         and p.CURCY_CODE  = w.CURCY_CODE
        order by p.RT_TYP_DESC, p.CURCY_CODE, p.LCY_NET desc
        ;
    quit;

    data mth.MTH_FVOCI_MTM
        (keep=PROC_DTE UNIQUE_ID_NO RCY_FAIR_VALUE LCY_FAIR_VALUE);
        length PROC_DTE $9 UNIQUE_ID_NO $50 RCY_FAIR_VALUE 8 LCY_FAIR_VALUE 8;
        set mth.fvocimtm(rename=(PROC_DTE = _dttm));

        _dt = datepart(_dttm);
        PROC_DTE = catx("-", put(day(_dt), z2.),
                             put(_dt, monname3.),
                             put(mod(year(_dt), 100), z2.));

        UNIQUE_ID_NO   = AC_CODE;
        RCY_FAIR_VALUE = round(RCY_MKT_VALUE_CHG, 0.01);
        LCY_FAIR_VALUE = round(LCY_MKT_VALUE_CHG, 0.01);

        format RCY_FAIR_VALUE LCY_FAIR_VALUE 24.2;
        label PROC_DTE       = "PROC_DTE"
              UNIQUE_ID_NO   = "UNIQUE_ID_NO"
              RCY_FAIR_VALUE = "RCY_FAIR_VALUE"
              LCY_FAIR_VALUE = "LCY_FAIR_VALUE";
    run;

    proc sql noprint;
        create table work.mark_cur as
        select  CURCY_CODE                          as CCY
              , round(sum(RCY_MKT_VALUE_CHG), 0.01) as CURR_RCY
              , round(sum(LCY_MKT_VALUE_CHG), 0.01) as CURR_LCY
        from mth.fvocimtm
        group by CURCY_CODE
        ;

        create table work.mark_prv as
        select  CURCY_CODE                       as CCY
              , round(sum(RCY_FAIR_VALUE), 0.01) as PRIOR_RCY
              , round(sum(LCY_FAIR_VALUE), 0.01) as PRIOR_LCY
        from LBFRS9.T_MTH_FRS9_RDL_AC_DTL
             (keep=PROC_DTE CURCY_CODE SEC_CLS_CD RCY_FAIR_VALUE LCY_FAIR_VALUE)
        where PROC_DTE >= &prv_lo and PROC_DTE < &prv_hi
          and upcase(strip(SEC_CLS_CD)) = "FVOCI"
        group by CURCY_CODE
        ;
    quit;

    proc sql noprint;
        create table work.post_prep as
        select CCY, CURR_RCY as AMT
        from work.mark_cur
        where CURR_RCY not in (0, .)
        order by CCY
        ;

        create table work.rev_prep as
        select CCY, PRIOR_RCY as AMT
        from work.mark_prv
        where PRIOR_RCY not in (0, .)
        order by CCY
        ;
    quit;

    %gl_legs(in=rev_prep,  out=rev_ent, sign=-1, remark=&rev_rmk)
    %gl_legs(in=post_prep, out=cur_ent, sign=1,  remark=&remark)

    data glte.fvoci_mtm_entries;
        set work.rev_ent
            work.cur_ent;
    run;

    proc sql;
        create table work.summ as
        select  coalesce(c.CCY, p.CCY) as CCY length=5
              , coalesce(p.PRIOR_RCY, 0)                              as PRIOR_RCY
              , coalesce(c.CURR_RCY,  0)                              as CURR_RCY
              , coalesce(c.CURR_RCY, 0) - coalesce(p.PRIOR_RCY, 0)    as MOVE_RCY
              , coalesce(p.PRIOR_LCY, 0)                              as PRIOR_LCY
              , coalesce(c.CURR_LCY,  0)                              as CURR_LCY
              , coalesce(c.CURR_LCY, 0) - coalesce(p.PRIOR_LCY, 0)    as MOVE_LCY
        from      work.mark_cur as c
        full join work.mark_prv as p on c.CCY = p.CCY
        order by CCY
        ;
    quit;

    title "FVOCI Loan MTM &yymm - mark by currency, &prv_lbl to &rpt_lbl";
    proc report data=work.summ nowd;
        column CCY PRIOR_RCY CURR_RCY MOVE_RCY PRIOR_LCY CURR_LCY MOVE_LCY;
        define CCY       / display      "Currency";
        define PRIOR_RCY / analysis sum "Prior mark RCY"   format=comma20.2;
        define CURR_RCY  / analysis sum "Current mark RCY" format=comma20.2;
        define MOVE_RCY  / analysis sum "Movement RCY"     format=comma20.2;
        define PRIOR_LCY / analysis sum "Prior mark LCY"   format=comma20.2;
        define CURR_LCY  / analysis sum "Current mark LCY" format=comma20.2;
        define MOVE_LCY  / analysis sum "Movement LCY"     format=comma20.2;

        compute after;
            CCY = "Total";
        endcomp;

        rbreak after / summarize style={font_weight=bold};
    run;
    title;

    proc sql noprint;
        select count(*) into :n_nil trimmed
          from mth.fvocimtm where LCY_MKT_VALUE_CHG is missing;
    quit;

    %if &n_nil ne 0 %then %do;
        title "FVOCI Loan MTM &yymm - &n_nil account(s) could not be marked";
        proc print data=mth.fvocimtm noobs label;
            where LCY_MKT_VALUE_CHG is missing;
            var AC_CODE CIF_NAME CURCY_CODE RPYM_TYP INT_PYM_FREQ
                INT_PYM_FREQ_UNIT MOB RESIDUAL_MTH WAIR LCY_END_PERIOD_BAL;
            format LCY_END_PERIOD_BAL comma20.2;
            label AC_CODE      = "Account"    CIF_NAME     = "Name"
                  CURCY_CODE   = "Ccy"        RPYM_TYP     = "Repayment type"
                  INT_PYM_FREQ = "Freq"       INT_PYM_FREQ_UNIT = "Unit"
                  MOB          = "MOB"        RESIDUAL_MTH = "Residual mths"
                  WAIR         = "WAIR"       LCY_END_PERIOD_BAL = "Balance";
        run;
        title;
    %end;

%mend;
%fvoci_mtm

proc datasets library=work nolist;
    delete fx ln_cur wpop wair prv_mark fv_prep
           mark_cur mark_prv post_prep rev_prep rev_ent cur_ent summ;
quit;
