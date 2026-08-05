*ProcessBody;

%let rpt_dt  = %sysfunc(inputn(&PROC_DTE, date9.));
%let prv_dt  = %sysfunc(intnx(month, &rpt_dt, -1, e));
%let yymm    = %sysfunc(putn(&rpt_dt, yymmn4.));
%let rpt_lbl = %sysfunc(putn(&rpt_dt, date9.));
%let prv_lbl = %sysfunc(putn(&prv_dt, date9.));

%macro read_cif_prompt;
    %local i n;

    %if %symexist(CIF_LIST_count) %then %let n = &CIF_LIST_count;
    %else %let n = 0;

    data work.cif_raw;
        length RAW $32767;
        %if &n = 0 %then %do;
            RAW = symget("CIF_LIST");  output;
        %end;
        %else %do i = 1 %to &n;
            RAW = symget("CIF_LIST&i");  output;
        %end;
    run;
%mend read_cif_prompt;

%read_cif_prompt

data work.req_cif;
    set work.cif_raw;
    length CIF_NO $50;
    do _k = 1 to countw(RAW, ", ");
        CIF_NO = strip(scan(RAW, _k, ", "));
        if CIF_NO ne "" then output;
    end;
    keep CIF_NO;
run;

proc sort data=work.req_cif nodupkey;
    by CIF_NO;
run;

proc sql noprint;
    select quote(strip(CIF_NO))
             into :cif_in separated by ","
      from work.req_cif;
    select count(*) into :n_cif trimmed
      from work.req_cif;
quit;

%macro pull_month(dt=, out=);
    %local dtm nxt;
    %let dtm = "%sysfunc(putn(&dt, date9.)):00:00:00"dt;
    %let nxt = "%sysfunc(putn(%eval(&dt + 1), date9.)):00:00:00"dt;

    data work.&out;
        set LBFRS9.T_MTH_FRS9_RDL_AC_DTL
            (keep=PROC_DTE CIF_NO LEGAL_ENTITY RATING STAGE_CLASSIFICATION
                  LCY_ECL_CLOSING_FY LCY_EAD_AMT
             where=(PROC_DTE >= &dtm and PROC_DTE < &nxt
                    and CIF_NO in (&cif_in)));
        length ENTITY $3;
        select (strip(LEGAL_ENTITY));
            when ("001") ENTITY = "MBS";
            when ("003") ENTITY = "MSL";
            otherwise    ENTITY = "???";
        end;
    run;

    proc means data=work.&out noprint nway;
        class CIF_NO ENTITY;
        var LCY_ECL_CLOSING_FY LCY_EAD_AMT;
        output out=work.&out._tot(drop=_type_ _freq_) sum=ECL EAD;
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
%mend pull_month;

%macro overlay_watch;

    %if &n_cif = 0 %then %do;
        %put ERROR: No CIF supplied on the prompt - nothing to report.;
        %return;
    %end;

    %pull_month(dt=&rpt_dt, out=cur)
    %pull_month(dt=&prv_dt, out=prv)

    data work.cif_all;
        length CIF_NO $50 CIF_NAME $255;
        set LBDWH.V_T_CIF_MSTR
            (keep=CIF_NO CIF_NAME where=(CIF_NO in (&cif_in)));
    run;

    proc sort data=work.cif_all out=work.cif nodupkey;
        by CIF_NO;
    run;

    data work.overlay_watch;
        merge work.cur_fin(in=c rename=(ECL=CURRENT_ECL EAD=CURRENT_EAD
                                        RATING=CURR_RATING
                                        STAGE_CLASSIFICATION=CURRENT_STAGE))
              work.prv_fin(in=p rename=(ECL=PREVIOUS_ECL EAD=PREV_EAD
                                        RATING=PREV_RATING
                                        STAGE_CLASSIFICATION=PREV_STAGE));
        by CIF_NO ENTITY;

        length CIF_NAME $255 STAGE_MOVE $3 RATING_MOVE $3;

        if _n_ = 1 then do;
            declare hash NM(dataset:"work.cif");
            NM.definekey("CIF_NO");
            NM.definedata("CIF_NAME");
            NM.definedone();
        end;
        call missing(CIF_NAME);
        if NM.find() ne 0 then call missing(CIF_NAME);

        if CURRENT_ECL  = . then CURRENT_ECL  = 0;
        if PREVIOUS_ECL = . then PREVIOUS_ECL = 0;
        if CURRENT_EAD  = . then CURRENT_EAD  = 0;
        if PREV_EAD     = . then PREV_EAD     = 0;

        ECL_MOVE = CURRENT_ECL - PREVIOUS_ECL;
        EAD_MOVE = CURRENT_EAD - PREV_EAD;

        STAGE_MOVE  = "";
        RATING_MOVE = "";
        if c and p then do;
            if strip(CURRENT_STAGE) ne strip(PREV_STAGE)  then STAGE_MOVE  = "Yes";
            if strip(CURR_RATING)   ne strip(PREV_RATING) then RATING_MOVE = "Yes";
        end;

        keep CIF_NO CIF_NAME ENTITY
             PREV_STAGE CURRENT_STAGE STAGE_MOVE
             PREV_RATING CURR_RATING RATING_MOVE
             PREV_EAD CURRENT_EAD EAD_MOVE
             PREVIOUS_ECL CURRENT_ECL ECL_MOVE;
    run;

    proc sql;
        create table work.not_found as
        select CIF_NO
          from work.req_cif
         where CIF_NO not in (select CIF_NO from work.overlay_watch)
        ;
    quit;

    proc sql noprint;
        select count(*) into :n_row trimmed from work.overlay_watch;
        select count(*) into :n_gap trimmed from work.not_found;
    quit;

    %if &n_row = 0 %then %do;
        data work.no_row;
            length Result $120;
            Result = "None of the &n_cif requested CIF(s) has an RDL row in &prv_lbl or &rpt_lbl";
        run;
        title "Overlay Watchlist &yymm";
        proc print data=work.no_row noobs label;  label Result = "Result";  run;
        title;
    %end;
    %else %do;
        title "Overlay Watchlist &yymm - &n_row row(s) from &n_cif CIF(s), &prv_lbl to &rpt_lbl";
        proc print data=work.overlay_watch noobs label;
            var CIF_NO CIF_NAME ENTITY
                PREV_STAGE CURRENT_STAGE STAGE_MOVE
                PREV_RATING CURR_RATING RATING_MOVE
                PREV_EAD CURRENT_EAD EAD_MOVE
                PREVIOUS_ECL CURRENT_ECL ECL_MOVE;
            format PREV_EAD CURRENT_EAD EAD_MOVE
                   PREVIOUS_ECL CURRENT_ECL ECL_MOVE comma20.2;
            label CIF_NO        = "CIF"          CIF_NAME      = "Name"
                  ENTITY        = "Entity"
                  PREV_STAGE    = "Stage prior"  CURRENT_STAGE = "Stage now"
                  STAGE_MOVE    = "Stage moved"
                  PREV_RATING   = "Rating prior" CURR_RATING   = "Rating now"
                  RATING_MOVE   = "Rating moved"
                  PREV_EAD      = "EAD prior"    CURRENT_EAD   = "EAD now"
                  EAD_MOVE      = "EAD movement"
                  PREVIOUS_ECL  = "ECL prior"    CURRENT_ECL   = "ECL now"
                  ECL_MOVE      = "ECL movement";
        run;
        title;
    %end;

    %if &n_gap ne 0 %then %do;
        title "Overlay Watchlist &yymm - &n_gap requested CIF(s) with no RDL row in either month";
        proc print data=work.not_found noobs label;
            label CIF_NO = "CIF";
        run;
        title;
    %end;

%mend overlay_watch;

%overlay_watch

proc datasets library=work nolist;
    delete cif_raw req_cif cur cur_tot cur_r cur_fin prv prv_tot prv_r prv_fin
           cif_all cif overlay_watch not_found no_row;
quit;
