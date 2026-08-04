*ProcessBody;

libname sasfiles "C:/Users/FNLNJE/Documents/My SAS Files";

%let rpt_dt = %sysfunc(inputn(&proc_dte, date9.));
%let tb_dir = C:/Users/FNLNJE/Documents/My SAS Files/PRETB;

data work.fmt_inscope(keep=fmtname type start label hlo);
    length fmtname $8 type $1 start $7 label $1 hlo $1;
    retain fmtname "INSCOPE" type "C";
    set sasfiles.egl_mapping end=eof;

    array gl{*} $ ECL_OPENING ECL_CHARGE ECL_WRITEBACK ECL_WRITEOFF
                  ECL_PNL_CHARGE ECL_PNL_WRITEBACK
                  UWI_OPENING UWI_CHARGE UWI_WRITEBACK UWI_WRITEOFF
                  UWI_PNL_CHARGE UWI_PNL_WRITEBACK
                  EIR_BS EIR_PNL FVOCI_BS FVOCI_OCI;

    do i = 1 to dim(gl);
        if not missing(gl{i}) then do;
            start = gl{i};  label = "Y";  hlo = "";  output;
        end;
    end;

    if eof then do;
        start = "";  label = "N";  hlo = "O";  output;
    end;
run;

data work.fmt_swept(keep=fmtname type start label hlo);
    length fmtname $8 type $1 start $7 label $1 hlo $1;
    retain fmtname "SWEPT" type "C";
    set sasfiles.egl_mapping end=eof;

    array sw{*} $ ECL_CHARGE ECL_WRITEBACK ECL_WRITEOFF
                  UWI_CHARGE UWI_WRITEBACK UWI_WRITEOFF
                  ECL_PNL_CHARGE ECL_PNL_WRITEBACK
                  UWI_PNL_CHARGE UWI_PNL_WRITEBACK
                  EIR_PNL;

    do i = 1 to dim(sw);
        if not missing(sw{i}) then do;
            start = sw{i};  label = "Y";  hlo = "";  output;
        end;
    end;

    if eof then do;
        start = "";  label = "N";  hlo = "O";  output;
    end;
run;

data work.fmt_open(keep=fmtname type start label hlo);
    length fmtname $8 type $1 start $7 label $1 hlo $1;
    retain fmtname "NOTEST" type "C";
    set sasfiles.egl_mapping end=eof;

    array op{*} $ ECL_OPENING UWI_OPENING FVOCI_OCI;

    do i = 1 to dim(op);
        if not missing(op{i}) then do;
            start = op{i};  label = "Y";  hlo = "";  output;
        end;
    end;

    if eof then do;
        start = "";  label = "N";  hlo = "O";  output;
    end;
run;

proc sort data=work.fmt_inscope nodupkey;
    by start hlo;
run;

proc sort data=work.fmt_swept nodupkey;
    by start hlo;
run;

proc sort data=work.fmt_open nodupkey;
    by start hlo;
run;

proc format cntlin=work.fmt_inscope;
run;

proc format cntlin=work.fmt_swept;
run;

proc format cntlin=work.fmt_open;
run;

%let is_jan = %eval(%sysfunc(month(&rpt_dt)) = 1);

data work.tb_all(drop=_dlm);
    length LEDGER_ID 8 PERIOD $10 ACCOUNT_NAME $100 ACCOUNTS $60
           CURRENCY $3 ACC_PROD $20 ENTITY $3 ENTITY_NAME $3 GL_NO $7 _dlm $1;
    retain _dlm ",";
    infile "&tb_dir/*.txt" dsd truncover dlm=_dlm;

    input @;
    if _infile_ = " " then delete;
    if _infile_ =: "LEDGER_ID" then delete;
    if      index(_infile_, "09"x) then _dlm = "09"x;
    else if index(_infile_, ",")   then _dlm = ",";
    else do;
        put "ERROR: Unrecognised delimiter - " _infile_;
        stop;
    end;

    input LEDGER_ID PERIOD $ EFFECTIVE_DATE : anydtdte10. ACCOUNT_NAME $
          ACCOUNTS $ CURRENCY $ PTD_NET_ENTERED PTD_NET_ACCOUNTED
          YTD_NET_ENTERED YTD_NET_ACCOUNTED ACC_PROD $;

    ENTITY = scan(ACCOUNTS, 1, "-");
    GL_NO  = scan(ACCOUNTS, 3, "-");

    select (ENTITY);
        when ("128") ENTITY_NAME = "MBS";
        when ("252") ENTITY_NAME = "MSL";
        otherwise    ENTITY_NAME = "???";
    end;
run;

%let per_exp = %upcase(%sysfunc(putn(&rpt_dt, monyy5.)));

proc sql noprint;
    select count(distinct ENTITY),
           sum(compress(upcase(PERIOD), "-") ne "&per_exp")
      into :n_ent trimmed, :n_bad trimmed
      from work.tb_all;
quit;

%macro precheck_breaks;
    %if &n_ent ne 2 %then %do;
        %put ERROR: Expected 2 entities in &tb_dir, found &n_ent - check WORK.TB_ALL.;
        %return;
    %end;
    %if &n_bad ne 0 %then %do;
        %put ERROR: &n_bad line(s) are not period &per_exp - stale TB in &tb_dir..;
        %return;
    %end;

    data work.precheck
            (keep=ENTITY ENTITY_NAME GL_NO ACCOUNTS ACCOUNT_NAME CURRENCY
                  PERIOD TEST PTD_NET_ENTERED YTD_NET_ENTERED
                  PTD_NET_ACCOUNTED BREAK_FLG);
        length BREAK_FLG $1 TEST $12;
        set work.tb_all;
        if put(GL_NO, $inscope.) ne "Y" then delete;

        if &is_jan = 1 and put(GL_NO, $notest.) = "Y" then do;
            TEST      = "Not tested";
            BREAK_FLG = "N";
        end;
        else if &is_jan = 1 and put(GL_NO, $swept.) = "Y" then do;
            TEST      = "Balance nil";
            BREAK_FLG = ifc(round(YTD_NET_ENTERED, 0.01) ne 0, "Y", "N");
        end;
        else do;
            TEST      = "No movement";
            BREAK_FLG = ifc(round(PTD_NET_ENTERED, 0.01) ne 0, "Y", "N");
        end;
    run;

    proc sql noprint;
        select count(*) into :n_brk trimmed
          from work.precheck where BREAK_FLG = "Y";
    quit;

    %if &n_brk = 0 %then %do;
        data work.no_break;
            length Result $110;
            %if &is_jan = 1 %then %do;
                Result = "No breaks - swept GLs nil, no movement elsewhere, opening GLs not tested, &per_exp";
            %end;
            %else %do;
                Result = "No breaks - all in-scope GLs clean for &per_exp";
            %end;
        run;

        title "Pre-Check TB &per_exp";
        proc print data=work.no_break noobs label;
            label Result = "Result";
        run;
        title;
    %end;
    %else %do;
        title "Pre-Check TB &per_exp - &n_brk break(s)";
        proc print data=work.precheck noobs label;
            where BREAK_FLG = "Y";
            var ENTITY_NAME GL_NO ACCOUNT_NAME CURRENCY TEST
                PTD_NET_ENTERED YTD_NET_ENTERED PTD_NET_ACCOUNTED ACCOUNTS;
            format PTD_NET_ENTERED YTD_NET_ENTERED PTD_NET_ACCOUNTED comma18.2;
            label TEST = "Test applied";
        run;
        title;
    %end;

    proc datasets library=work nolist;
        delete fmt_inscope fmt_swept fmt_open tb_all precheck no_break;
    quit;
%mend;
%precheck_breaks
