%let rpt_mth = 30JUN2026;
%let rpt_dt  = %sysfunc(inputn(&rpt_mth, date9.));

/* MKT_SUB_SEGMENT maps the V_CUST_MKT_SUB_SEG code to its label.
   Unmapped codes are left blank. */
data WORK.mstr_derived(keep=PROC_DTE V_ACCOUNT_NUMBER V_CUST_MKT_SUB_SEG MKT_SUB_SEGMENT);
    retain PROC_DTE V_ACCOUNT_NUMBER V_CUST_MKT_SUB_SEG MKT_SUB_SEGMENT;
    length MKT_SUB_SEGMENT $20;
    set LBFRS9.T_MTH_FRS9_RDL_MSTR_LIST(keep=PROC_DTE V_ACCOUNT_NUMBER V_D_ACCOUNT_STATUS
                                             V_CUST_MKT_SUB_SEG);
    where datepart(PROC_DTE) = &rpt_dt and V_D_ACCOUNT_STATUS = "Active";

    select (strip(V_CUST_MKT_SUB_SEG));
        when ('1')  MKT_SUB_SEGMENT = 'SME BANKING';
        when ('2')  MKT_SUB_SEGMENT = 'BUSINESS BANKING';
        when ('3')  MKT_SUB_SEGMENT = 'CONSUMER';
        when ('11') MKT_SUB_SEGMENT = 'COMMERCIAL BANKING';
        when ('13') MKT_SUB_SEGMENT = 'GWB-CORPORATE BANK';
        when ('16') MKT_SUB_SEGMENT = 'GWB-GLOBAL MARKET';
        otherwise   call missing(MKT_SUB_SEGMENT);
    end;
run;
