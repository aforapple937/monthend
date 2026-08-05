%let rpt_mth     = 30APR2026;
%let rpt_dt      = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm     = "&rpt_mth:00:00:00"dt;
%let nxt_dtm     = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;

%let rpt_mth_num = %sysfunc(month(&rpt_dt));
%let prev_mth    = %sysfunc(intnx(month, &rpt_dt, -1, end));
%let prev_dtm    = "%sysfunc(putn(&prev_mth, date9.)):00:00:00"dt;
%let prv_nxt     = "%sysfunc(putn(%eval(&prev_mth + 1), date9.)):00:00:00"dt;

proc sql;
    create table WORK.curr_loans as
    select  PROC_DTE
          , AC_CODE
          , CIF_NO
          , BIZ_PRD_CODE
          , LCY_TOT_OS
          , case
                when BIZ_PRD_CODE = 'CPPTYLN'           then 'CPPTYLN'
                when BIZ_PRD_CODE in ('HL','HDBHL')     then 'HL_HDBHL'
                when BIZ_PRD_CODE = 'ISLMCPPTYLN'       then 'ISLMCPPTYLN'
            end as PRD_GRP length=20
    from LBDWH.V_T_MTH_AC_DTL
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
      and CO_CODE = '003'
      and LCY_TOT_OS > 0
      and CR_STS_CODE = '1'
      and BIZ_PRD_CODE in ('CPPTYLN','HDBHL','HL','ISLMCPPTYLN')
    ;
quit;

proc sql;
    create table WORK.prev_loans as
    select distinct AC_CODE
    from LBFRS9.T_MTH_FRS9_LN_DTL
    where PROC_DTE >= &prev_dtm and PROC_DTE < &prv_nxt
    ;
quit;

proc sql;
    create table WORK.repriced as
    select distinct AC_CODE
    from LBDWH.T_MSG_AC_DTL
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
      and MSG_TYP_CODE = '400'
    ;
quit;

proc sql;
    create table WORK.rsme_cifs as
    select distinct CIF_NO
    from LBFRS9.T_MTH_RSME_CMPLX_PRD_WRK_TBL
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
      and RSME_IN_OUT_FLG = 'IN'
    ;
quit;

proc sql;
    create table WORK.new_loans as
    select  c.PROC_DTE
          , c.AC_CODE
          , c.CIF_NO
          , c.BIZ_PRD_CODE
          , c.LCY_TOT_OS
          , c.PRD_GRP
          , case when rs.CIF_NO is not missing then 'Y' else 'N' end
                                                   as RSME_FLG length=1
    from        WORK.curr_loans  as c
    left join   WORK.prev_loans  as p   on c.AC_CODE = p.AC_CODE
    left join   WORK.repriced    as r   on c.AC_CODE = r.AC_CODE
    left join   WORK.rsme_cifs   as rs  on c.CIF_NO  = rs.CIF_NO
    where p.AC_CODE is missing
      and r.AC_CODE is missing
    ;
quit;

%macro build_gl_cost_detail;

    proc sql;
        create table WORK.gl_cost_detail as
        select  GL_AC_CODE
              , case
                    when GL_AC_CODE in ('634095','634097','634099')
                        then 'CPPTYLN'
                    when GL_AC_CODE in ('634094','634096','651652')
                        then 'HL_HDBHL'
                    when GL_AC_CODE in ('863451','863461','863480')
                        then 'ISLMCPPTYLN'
                end as PRD_GRP length=20

              , case
                    when GL_AC_CODE in ('634097','863461')
                        then 'RSME'
                    else 'GEN'
                end as COST_POOL length=4

              , sum(case when PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
                         then LCY_AGR_BAL else 0 end) as LCY_AGR_BAL_CURR

        %if &rpt_mth_num ne 1 %then %do;
              , sum(case when PROC_DTE >= &prev_dtm and PROC_DTE < &prv_nxt
                         then LCY_AGR_BAL else 0 end) as LCY_AGR_BAL_PREV

              , calculated LCY_AGR_BAL_CURR - calculated LCY_AGR_BAL_PREV
                                                           as TOTAL_COST
        %end;
        %else %do;
              , calculated LCY_AGR_BAL_CURR                as TOTAL_COST
        %end;

        from LBDWH.T_DAL_GLBAL
        %if &rpt_mth_num ne 1 %then %do;
        where ( (PROC_DTE >= &rpt_dtm  and PROC_DTE < &nxt_dtm)
             or (PROC_DTE >= &prev_dtm and PROC_DTE < &prv_nxt) )
        %end;
        %else %do;
        where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
        %end;
          and CO_CODE = '003'
          and (
                  GL_AC_CODE in ('634095','634097','634099')
               or ( GL_AC_CODE in ('634094','634096','651652')
                    and UNIT_CODE in ('013','073') )
               or GL_AC_CODE in ('863451','863461','863480')
              )
        group by GL_AC_CODE, calculated PRD_GRP, calculated COST_POOL
        order by PRD_GRP, COST_POOL, GL_AC_CODE
        ;
    quit;

%mend build_gl_cost_detail;

%build_gl_cost_detail;

proc sql;
    create table WORK.gl_cost_by_grp as
    select  PRD_GRP
          , sum(LCY_AGR_BAL_CURR) as LCY_AGR_BAL_CURR

          %if &rpt_mth_num ne 1 %then %do;
          , sum(LCY_AGR_BAL_PREV) as LCY_AGR_BAL_PREV
          %end;

          , sum(case when COST_POOL = 'GEN'  then TOTAL_COST else 0 end)
                                              as GRP_GEN_COST
          , sum(case when COST_POOL = 'RSME' then TOTAL_COST else 0 end)
                                              as GRP_RSME_COST
          , sum(TOTAL_COST)                   as GRP_TOTAL_COST
    from WORK.gl_cost_detail
    where PRD_GRP is not missing
    group by PRD_GRP
    ;
quit;

proc sql;
    create table WORK.grp_total_os as
    select  PRD_GRP
          , sum(LCY_TOT_OS) as GRP_TOTAL_OS
          , sum(case when RSME_FLG = 'Y' then LCY_TOT_OS else 0 end)
                                              as GRP_RSME_OS
    from WORK.new_loans
    group by PRD_GRP
    ;
quit;

proc sql;
    create table WORK.new_loans_allocated as
    select  n.PROC_DTE
          , n.AC_CODE
          , n.CIF_NO
          , n.BIZ_PRD_CODE
          , n.PRD_GRP
          , n.RSME_FLG
          , n.LCY_TOT_OS
          , s.GRP_TOTAL_OS
          , s.GRP_RSME_OS
          , g.GRP_GEN_COST
          , g.GRP_RSME_COST

          , case when s.GRP_TOTAL_OS > 0
                 then (n.LCY_TOT_OS / s.GRP_TOTAL_OS) * g.GRP_GEN_COST
                 else 0
            end as GEN_ALLOC_COST

          , case when n.RSME_FLG = 'Y' and s.GRP_RSME_OS > 0
                 then (n.LCY_TOT_OS / s.GRP_RSME_OS) * g.GRP_RSME_COST
                 else 0
            end as RSME_ALLOC_COST

          , calculated GEN_ALLOC_COST + calculated RSME_ALLOC_COST
                                              as ALLOCATED_COST
    from        WORK.new_loans       as n
    left join   WORK.grp_total_os    as s  on n.PRD_GRP = s.PRD_GRP
    left join   WORK.gl_cost_by_grp  as g  on n.PRD_GRP = g.PRD_GRP
    order by n.PRD_GRP, n.RSME_FLG, n.AC_CODE
    ;
quit;

proc datasets library=WORK nolist;
    delete curr_loans
           prev_loans
           repriced
           rsme_cifs
           new_loans
           gl_cost_by_grp
           grp_total_os
           ;
quit;
