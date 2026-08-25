%let rpt_mth = 31JUL2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));
%let rpt_dtm = "&rpt_mth:00:00:00"dt;
%let nxt_dtm = "%sysfunc(putn(%eval(&rpt_dt + 1), date9.)):00:00:00"dt;
%let far_dt  = '31DEC9999'd;

data WORK.ccmat(keep=AC_CODE CC_MATURITY_DTE);
    length AC_CODE $50;
    set LBFRS9.T_MTH_FRS9_CC_DTL(keep=PROC_DTE AC_CODE MATURITY_DTE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm;
    CC_MATURITY_DTE = MATURITY_DTE;
    drop MATURITY_DTE;
run;

data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER D_REVISED_MATURITY_DATE
                            CC_MATURITY_DTE N_RESIDUAL_MATURITY);
    retain PROC_DTE V_ACCOUNT_NUMBER D_REVISED_MATURITY_DATE
           CC_MATURITY_DTE N_RESIDUAL_MATURITY;
    length AC_CODE $50;
    format CC_MATURITY_DTE datetime20. N_RESIDUAL_MATURITY 12.3;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER
                                             V_D_ACCOUNT_STATUS
                                             D_REVISED_MATURITY_DATE);
    where PROC_DTE >= &rpt_dtm and PROC_DTE < &nxt_dtm
          and V_D_ACCOUNT_STATUS = "Active";

    if _n_ = 1 then do;
        declare hash c(dataset:"WORK.ccmat");
        c.definekey("AC_CODE");
        c.definedata("CC_MATURITY_DTE");
        c.definedone();
    end;

    call missing(CC_MATURITY_DTE, N_RESIDUAL_MATURITY);
    AC_CODE = V_ACCOUNT_NUMBER;
    rc = c.find();

    _basis = coalesce(D_REVISED_MATURITY_DATE, CC_MATURITY_DTE);

    if not missing(_basis) and datepart(_basis) ne &far_dt then do;
        _from = datepart(PROC_DTE);
        _to   = datepart(_basis);
        _mth  = intck('MONTH', _from, _to, 'C');
        _annv = intnx('MONTH', _from, _mth, 'SAMEDAY');
        if _annv > _to then do;
            _mth  = _mth - 1;
            _annv = intnx('MONTH', _from, _mth, 'SAMEDAY');
        end;
        N_RESIDUAL_MATURITY = (_mth + (_to - _annv) / 31) / 12;
    end;

    drop _basis _from _to _mth _annv;
run;

proc datasets library=WORK nolist;
    delete ccmat;
quit;
