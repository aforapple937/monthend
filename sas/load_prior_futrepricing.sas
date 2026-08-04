

libname FUTREP "C:/Users/FNLNJE/Documents/My SAS Files/futrep";

proc sql noprint;
    select  count(distinct datepart(PROC_DTE))
                into :n_months  trimmed
          , put(datepart(max(PROC_DTE)), yymmn4.)
                into :load_yymm trimmed
          , put(datepart(max(PROC_DTE)), date9.)
                into :load_lbl  trimmed
    from WORK.PREV_FUT_REPRICING
    ;
quit;

%macro load_prior;

    %if &n_months ne 1 %then %do;
        %put ERROR: WORK.PREV_FUT_REPRICING holds &n_months distinct months - expected exactly 1.;
        %return;
    %end;

    %if %sysfunc(exist(FUTREP.FUT_REPRICING_&load_yymm)) %then %do;
        %put ERROR: FUTREP.FUT_REPRICING_&load_yymm already exists - delete it first if you intend to reload.;
        %return;
    %end;

    data FUTREP.FUT_REPRICING_&load_yymm;
        length PROC_DTE        8
               AC_CODE         $50
               PRD_CODE        $50
               REPRICE_DATE    8
               BIZ_UNIT_CODE   $20
               FINANCING_CODE  $1
               CURR_MTH_EIR    8
               PREV_MTH_EIR    8
               EIR_DIFF        8;
        set WORK.PREV_FUT_REPRICING;
        format PROC_DTE REPRICE_DATE datetime20.;
        format CURR_MTH_EIR PREV_MTH_EIR EIR_DIFF 24.3;
    run;

    %put NOTE: Loaded FUTREP.FUT_REPRICING_&load_yymm for &load_lbl..;

%mend load_prior;

%load_prior
