*ProcessBody;

libname sasfiles "C:/Users/FNLNJE/Documents/My SAS Files";

%let rpt_dt  = %sysfunc(inputn(&proc_dte, date9.));
%let prv_dt  = %sysfunc(intnx(month, &rpt_dt, -1, e));
%let yymm    = %sysfunc(putn(&rpt_dt, yymmn4.));
%let rpt_lbl = %sysfunc(putn(&rpt_dt, date9.));
%let prv_lbl = %sysfunc(putn(&prv_dt, date9.));

options dlcreatedir;
libname mth "C:/Users/FNLNJE/Documents/My SAS Files/&yymm";

%macro pull_month(dt=, out=, ftm=);
    data work.&out;
        set LBFRS9.T_MTH_FRS9_RDL_AC_DTL
            (keep=PROC_DTE CIF_NO LEGAL_ENTITY RATING STAGE_CLASSIFICATION
                  LCY_ECL_CLOSING_FY LCY_EAD_AMT
                  %if &ftm %then LCY_ECL_CHARGE_FTM LCY_ECL_WRITEBACK_FTM;
             where=(datepart(PROC_DTE) = &dt));
        length ENTITY $3;
        select (strip(LEGAL_ENTITY));
            when ("001") ENTITY = "MBS";
            when ("003") ENTITY = "MSL";
            otherwise    ENTITY = "???";
        end;
        %if &ftm %then %do;
            PNL = sum(LCY_ECL_CHARGE_FTM, LCY_ECL_WRITEBACK_FTM);
        %end;
    run;

    proc means data=work.&out noprint nway;
        class CIF_NO ENTITY;
        var LCY_ECL_CLOSING_FY LCY_EAD_AMT %if &ftm %then PNL;;
        output out=work.&out._tot(drop=_type_ _freq_)
               sum=ECL EAD %if &ftm %then PNL;;
    run;

    proc sort data=work.&out out=work.&out._r;
        by CIF_NO ENTITY descending LCY_EAD_AMT;
    run;

    data work.&out._r(keep=CIF_NO ENTITY RATING STAGE_CLASSIFICATION);
        set work.&out._r;
        by CIF_NO ENTITY;
        if first.ENTITY;
    run;

    data work.&out._fin;
        merge work.&out._tot(in=a) work.&out._r;
        by CIF_NO ENTITY;
        if a;
    run;
%mend;

%pull_month(dt=&rpt_dt, out=cur, ftm=1)
%pull_month(dt=&prv_dt, out=prv, ftm=0)

proc sort data=LBDWH.V_T_CIF_MSTR(keep=CIF_NO CIF_NAME)
          out=work.cifname nodupkey;
    by CIF_NO;
run;

proc sort data=LBFRS9.T_MTH_FRS9_PARTY_MSTR
              (keep=PROC_DTE CIF_NO MKT_SUB_SEG_DESC
               where=(datepart(PROC_DTE) = &rpt_dt))
          out=work.party(drop=PROC_DTE) nodupkey;
    by CIF_NO;
run;

data mth.eclflux;

    retain CIF_NO CIF_NAME ENTITY MKT_SUB_SEG_DESC ECL_PNL_FTM
           CURRENT_ECL PREVIOUS_ECL CURRENT_EAD PREV_EAD
           CURR_RATING PREV_RATING CURRENT_STAGE PREV_STAGE;
    merge work.cur_fin(in=c rename=(ECL=CURRENT_ECL EAD=CURRENT_EAD
                                    PNL=ECL_PNL_FTM
                                    RATING=CURR_RATING
                                    STAGE_CLASSIFICATION=CURRENT_STAGE))
          work.prv_fin(rename=(ECL=PREVIOUS_ECL EAD=PREV_EAD
                               RATING=PREV_RATING
                               STAGE_CLASSIFICATION=PREV_STAGE));
    by CIF_NO ENTITY;
    if not c then delete;

    length CIF_NAME $255 MKT_SUB_SEG_DESC $60;
    if _n_ = 1 then do;
        declare hash N(dataset:"work.cifname");
        N.definekey("CIF_NO");
        N.definedata("CIF_NAME");
        N.definedone();

        declare hash P(dataset:"work.party");
        P.definekey("CIF_NO");
        P.definedata("MKT_SUB_SEG_DESC");
        P.definedone();
    end;
    call missing(CIF_NAME, MKT_SUB_SEG_DESC);
    if N.find() ne 0 then call missing(CIF_NAME);
    if P.find() ne 0 then call missing(MKT_SUB_SEG_DESC);

    if PREVIOUS_ECL = . then PREVIOUS_ECL = 0;
    if PREV_EAD     = . then PREV_EAD     = 0;
    if ECL_PNL_FTM  = . then ECL_PNL_FTM  = 0;

    if round(ECL_PNL_FTM, 0.01) = 0 then delete;

    ABS_PNL = abs(ECL_PNL_FTM);

    keep CIF_NO CIF_NAME ENTITY MKT_SUB_SEG_DESC ECL_PNL_FTM
         CURRENT_ECL PREVIOUS_ECL CURRENT_EAD PREV_EAD
         CURR_RATING PREV_RATING CURRENT_STAGE PREV_STAGE ABS_PNL;
run;

proc sort data=mth.eclflux;
    by descending ABS_PNL;
run;

proc sql noprint;
    select coalesce(sum(ECL_PNL_FTM), 0) format=32.2
      into :mbs_pnl trimmed
      from mth.eclflux
     where ENTITY = "MBS";

    select coalesce(sum(ECL_PNL_FTM), 0) format=32.2
      into :ind_pnl trimmed
      from mth.eclflux
     where ENTITY = "MSL"
       and upcase(strip(MKT_SUB_SEG_DESC)) = "CFS-IND";

    select coalesce(sum(ECL_PNL_FTM), 0) format=32.2
      into :msl_pnl trimmed
      from mth.eclflux
     where ENTITY = "MSL";
quit;

data work.flux_sum;
    length ENTITY $3 SEGMENT $7;
    ENTITY = "MBS";  SEGMENT = "Total";    ECL_PNL_FTM = &mbs_pnl;  output;
    ENTITY = "MSL";  SEGMENT = "CFS-IND";  ECL_PNL_FTM = &ind_pnl;  output;
    ENTITY = "MSL";  SEGMENT = "Total";    ECL_PNL_FTM = &msl_pnl;  output;
run;

title "ECL Flux &prv_lbl to &rpt_lbl";
proc print data=work.flux_sum noobs label;
    var ENTITY SEGMENT ECL_PNL_FTM;
    format ECL_PNL_FTM comma20.2;
    label ENTITY      = "Entity"
          SEGMENT     = "Segment"
          ECL_PNL_FTM = 'ECL P&L (month)';
run;
title;

proc datasets library=work nolist;
    delete cur cur_tot cur_r cur_fin prv prv_tot prv_r prv_fin
           cifname party flux_sum;
quit;
