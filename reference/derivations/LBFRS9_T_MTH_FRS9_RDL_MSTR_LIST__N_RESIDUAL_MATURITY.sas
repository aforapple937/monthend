%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;
%let far_dt  = '31DEC9999'd;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER D_REVISED_MATURITY_DATE
                            N_RESIDUAL_MATURITY);
    retain PROC_DTE V_ACCOUNT_NUMBER D_REVISED_MATURITY_DATE
           N_RESIDUAL_MATURITY;
    format N_RESIDUAL_MATURITY 12.3;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS
                                             D_REVISED_MATURITY_DATE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    call missing(N_RESIDUAL_MATURITY);

    if not missing(D_REVISED_MATURITY_DATE)
       and datepart(D_REVISED_MATURITY_DATE) ne &far_dt then do;
        _from = datepart(PROC_DTE);
        _to   = datepart(D_REVISED_MATURITY_DATE);
        _mth  = intck('MONTH', _from, _to, 'C');
        _annv = intnx('MONTH', _from, _mth, 'SAMEDAY');
        if _annv > _to then do;
            _mth  = _mth - 1;
            _annv = intnx('MONTH', _from, _mth, 'SAMEDAY');
        end;
        N_RESIDUAL_MATURITY = (_mth + (_to - _annv) / 31) / 12;
    end;

    drop _from _to _mth _annv;
run;
