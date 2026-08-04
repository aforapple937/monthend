*ProcessBody;

libname sasfiles "C:/Users/FNLNJE/Documents/My SAS Files";

%let rpt_dt  = %sysfunc(inputn(&proc_dte, date9.));
%let yymm    = %sysfunc(putn(&rpt_dt, yymmn4.));
%let rpt_lbl = %sysfunc(putn(&rpt_dt, date9.));

%let rpt_dtm = "&rpt_lbl:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

options dlcreatedir;
libname mth "C:/Users/FNLNJE/Documents/My SAS Files/&yymm";

proc sort data=LBFRS9.T_FRS_RT_INTF
              (keep=PROC_DTE AC_CODE RT_EFF_DTE PRM_RT_NO
               where=(PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm))
          out=work.rt_intf(drop=PROC_DTE);
    by AC_CODE descending RT_EFF_DTE;
run;

data work.rt_intf;
    set work.rt_intf;
    by AC_CODE;
    if first.AC_CODE;
    if PRM_RT_NO in (90, 91);
run;

proc sql;
    create table work.sora_fixed as
    select l.PROC_DTE, l.AC_CODE, l.BASE_RT, l.RT_TYP_DESC, i.PRM_RT_NO
      from LBFRS9.T_MTH_FRS9_LN_DTL as l
     inner join work.rt_intf as i
        on l.AC_CODE = i.AC_CODE
     where l.PROC_DTE >= &rpt_dtm and l.PROC_DTE < &nxt_dtm
       and upcase(strip(l.RT_TYP_DESC)) = "FIXED RATE";
quit;

proc sql noprint;
    select count(*) into :n_acct trimmed from work.sora_fixed;
quit;

%macro sora_patch;
%if &n_acct = 0 %then %do;
    %put ERROR: No fixed-rate SORA-pegged accounts found for &rpt_lbl - check;
    %put ERROR- that LBFRS9.T_FRS_RT_INTF has loaded for the month.;
    %return;
%end;

data mth.frs9_ln_dtl_patch_sora;
    retain PROC_DTE AC_CODE BASE_RT_PREV RT_TYP_DESC PRM_RT_NO BASE_RT_PATCH;
    set work.sora_fixed(rename=(BASE_RT=BASE_RT_PREV));

    select (PRM_RT_NO);
        when (90) BASE_RT_PATCH = &one_month_sora;
        when (91) BASE_RT_PATCH = &three_month_sora;
        otherwise do;

            put "ERROR: Unexpected PRM_RT_NO - " AC_CODE= PRM_RT_NO=;
            stop;
        end;
    end;

    keep PROC_DTE AC_CODE BASE_RT_PREV RT_TYP_DESC PRM_RT_NO BASE_RT_PATCH;
    format PROC_DTE datetime20.
           BASE_RT_PREV BASE_RT_PATCH 20.9;
run;

proc sql;
    create table work.rt_match as
    select r.PROC_DTE, r.AC_CODE, r.RT_EFF_DTE, r.RT_END_DTE, r.BASE_RT,
           r.VAR_RT, r.TIER_INT_RT, s.PRM_RT_NO
      from work.sora_fixed as s
     inner join LBFRS9.T_MTH_FRS9_RT_DTL as r
        on  s.AC_CODE = r.AC_CODE
       and  s.BASE_RT = r.BASE_RT
     where r.PROC_DTE >= &rpt_dtm and r.PROC_DTE < &nxt_dtm;
quit;

data mth.frs9_rt_dtl_patch_sora;
    retain PROC_DTE AC_CODE RT_EFF_DTE RT_END_DTE BASE_RT_PREV VAR_RT
           TIER_INT_RT_PREV PRM_RT_NO BASE_RT_PATCH TIER_INT_RT_PATCH;
    set work.rt_match(rename=(BASE_RT=BASE_RT_PREV
                              TIER_INT_RT=TIER_INT_RT_PREV));

    select (PRM_RT_NO);
        when (90) BASE_RT_PATCH = &one_month_sora;
        when (91) BASE_RT_PATCH = &three_month_sora;
        otherwise do;
            put "ERROR: Unexpected PRM_RT_NO - " AC_CODE= PRM_RT_NO=;
            stop;
        end;
    end;

    TIER_INT_RT_PATCH = BASE_RT_PATCH + VAR_RT;

    RT_EFF_DTE = datepart(RT_EFF_DTE);
    RT_END_DTE = datepart(RT_END_DTE);

    keep PROC_DTE AC_CODE RT_EFF_DTE RT_END_DTE BASE_RT_PREV VAR_RT
         TIER_INT_RT_PREV PRM_RT_NO BASE_RT_PATCH TIER_INT_RT_PATCH;
    format PROC_DTE                    datetime20.
           RT_EFF_DTE RT_END_DTE       date11.
           BASE_RT_PATCH
           TIER_INT_RT_PATCH           20.9;
run;

proc sql;
    create table work.summ as
    select l.PRM_RT_NO                label = "Peg code",
           l.BASE_RT_PREV             label = "SORA current" format = 20.9,
           l.BASE_RT_PATCH            label = "SORA applied" format = 20.9,
           count(distinct l.AC_CODE)  label = "Accounts",
           (select count(*) from mth.frs9_rt_dtl_patch_sora as r
             where r.PRM_RT_NO    = l.PRM_RT_NO
               and r.BASE_RT_PREV = l.BASE_RT_PREV)
                                      label = "Tiers patched",

           (select count(*) from mth.frs9_rt_dtl_patch_sora as r
             where r.PRM_RT_NO    = l.PRM_RT_NO
               and r.BASE_RT_PREV = l.BASE_RT_PREV
               and (r.VAR_RT = 0 or r.VAR_RT is missing))
                                      label = "of which nil spread"
      from mth.frs9_ln_dtl_patch_sora as l
     group by l.PRM_RT_NO, l.BASE_RT_PREV, l.BASE_RT_PATCH;
quit;

title "SORA Rate Patch &yymm";
proc print data=work.summ noobs label;
run;
title;
%mend;
%sora_patch

proc datasets library=work nolist;
    delete rt_intf sora_fixed rt_match summ;
quit;
