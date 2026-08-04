*ProcessBody;

%let rpt_dt  = %sysfunc(inputn(&proc_dte, date9.));
%let rpt_lbl = %sysfunc(putn(&rpt_dt, date9.));
%let nxt_lbl = %sysfunc(putn(%eval(&rpt_dt + 1), date9.));

%let patch_dir = C:/Users/FNLNJE/Documents/My SAS Files/patch;
%let rdl_ds    = LBFRS9.T_MTH_FRS9_RDL_AC_DTL;
%let tol       = 0.005;

filename _pdir "&patch_dir";

data work._files;
    length _FILE $200 _EXT $8;
    drop _did _i _n _rc;
    _did = dopen("_pdir");
    if _did = 0 then do;
        put "ERROR: Cannot open the patch folder - &patch_dir";
        stop;
    end;
    _n = dnum(_did);
    do _i = 1 to _n;
        _FILE = dread(_did, _i);
        _EXT  = lowcase(scan(_FILE, -1, "."));

        if _EXT in ("csv", "xls", "xlsx", "xlsm")
           and substr(_FILE, 1, 2) ne "~$" then output;
    end;
    _rc = dclose(_did);
run;

%let nfile = 0;
data _null_;
    set work._files;
    call symputx(cats("fnm", _n_), _FILE);
    call symputx(cats("fex", _n_), _EXT);
    call symputx("nfile", _n_);
run;

%macro rdl_verify;

%local i fnm fex has_key ktype nrow ncol fstat
       nkeep keeplist n_fdup n_rdup n_exc n_res;

%if &nfile = 0 %then %do;
    %put ERROR: No csv or Excel files found in &patch_dir..;
    %return;
%end;

proc datasets library=work nolist nowarn;
    delete _filelong _imp _fl;
quit;

proc sql;
    create table work._inv
        (FILE char(200), EXT char(8), ROWS num, COLS num,
         KEY_TYPE char(4), STATUS char(40));
quit;

%do i = 1 %to &nfile;

    %let fnm   = &&fnm&i;
    %let fex   = &&fex&i;
    %let ktype = ;
    %let nrow  = .;
    %let ncol  = .;

    proc datasets library=work nolist nowarn;
        delete _imp _fl;
    quit;

    %if &fex = csv %then %do;
        proc import datafile="&patch_dir/&fnm" out=work._imp dbms=csv replace;
            getnames=yes;
            guessingrows=max;
        run;
    %end;
    %else %if &fex = xls %then %do;
        proc import datafile="&patch_dir/&fnm" out=work._imp dbms=xls replace;
            getnames=yes;
        run;
    %end;
    %else %do;
        proc import datafile="&patch_dir/&fnm" out=work._imp dbms=xlsx replace;
            getnames=yes;
        run;
    %end;

    %if not %sysfunc(exist(work._imp)) %then %do;
        proc sql;
            insert into work._inv
                values("&fnm", "&fex", ., ., "", "Import failed - not verified");
        quit;
    %end;
    %else %do;

    proc sql noprint;
        select sum(upcase(name) = "UNIQUE_ID_NO"), count(*)
          into :has_key trimmed, :ncol trimmed
          from dictionary.columns
         where libname = "WORK" and memname = "_IMP";

        select type into :ktype trimmed
          from dictionary.columns
         where libname = "WORK" and memname = "_IMP"
           and upcase(name) = "UNIQUE_ID_NO";

        select count(*) into :nrow trimmed from work._imp;
    quit;

    %if &has_key = 0 %then %do;
        proc sql;
            insert into work._inv
                values("&fnm", "&fex", &nrow, &ncol, "&ktype",
                       "No UNIQUE_ID_NO - not verified");
        quit;
    %end;
    %else %do;

    data work._fl;
        set work._imp;
        _DUMN = .;
        length _DUMC $1;
        _DUMC = "";
        array _n{*} _numeric_;
        array _c{*} _character_;
        length _FILE $200 _KEY $50 _COL $32 _FTXT $255 _FNUM 8 _FISNUM 8;
        _FILE = "&fnm";

        %if &ktype = char %then %do;
            _KEY = strip(UNIQUE_ID_NO);
        %end;
        %else %do;
            _KEY = strip(put(UNIQUE_ID_NO, best32.));
        %end;

        do _i = 1 to dim(_n);
            _COL = upcase(vname(_n{_i}));
            if _COL in ("PROC_DTE", "UNIQUE_ID_NO", "_DUMN") then continue;
            _FNUM = _n{_i};  _FTXT = "";  _FISNUM = 1;
            output;
        end;
        do _i = 1 to dim(_c);
            _COL = upcase(vname(_c{_i}));
            if _COL in ("PROC_DTE", "UNIQUE_ID_NO", "_DUMC") then continue;
            _FTXT = _c{_i};  _FNUM = .;  _FISNUM = 0;
            output;
        end;

        keep _FILE _KEY _COL _FTXT _FNUM _FISNUM;
    run;

    proc append base=work._filelong data=work._fl;
    run;

    %let fstat = Imported;
    %if &nrow = 0 %then %let fstat = Imported - no rows;

    proc sql;
        insert into work._inv
            values("&fnm", "&fex", &nrow, &ncol, "&ktype", "&fstat");
    quit;

    %end;
    %end;
%end;

title "Patch files found in &patch_dir";
proc print data=work._inv noobs label;
    var FILE EXT ROWS COLS KEY_TYPE STATUS;
    label FILE     = "File"
          EXT      = "Type"
          ROWS     = "Rows"
          COLS     = "Columns"
          KEY_TYPE = "UNIQUE_ID_NO read as"
          STATUS   = "Status";
run;
title;

%if not %sysfunc(exist(work._filelong)) %then %do;
    %put ERROR: Nothing could be read from &patch_dir - nothing verified.;
    %return;
%end;

proc sql noprint;
    create table work._rdlcols as
    select upcase(name) as _COL length = 32
      from dictionary.columns
     where libname = "%upcase(%scan(&rdl_ds, 1, .))"
       and memname = "%upcase(%scan(&rdl_ds, 2, .))";

    select distinct _COL into :keeplist separated by " "
      from work._filelong
     where _COL in (select _COL from work._rdlcols);

    select count(distinct _COL) into :nkeep trimmed
      from work._filelong
     where _COL in (select _COL from work._rdlcols);

    create table work._keys as
    select distinct _KEY from work._filelong;
quit;

%if &nkeep = 0 %then %do;
    title "No column in any file matches a column on &rdl_ds";
    proc sql;
        select distinct _FILE label = "File", _COL label = "Column"
          from work._filelong;
    quit;
    title;
    %return;
%end;

data work._rdllong;
    set &rdl_ds (keep  = PROC_DTE UNIQUE_ID_NO &keeplist
                 where = (PROC_DTE >= "&rpt_lbl:00:00:00"dt
                      and PROC_DTE <  "&nxt_lbl:00:00:00"dt));
    array _n{*} _numeric_;
    array _c{*} _character_;
    length _KEY $50 _COL $32 _RTXT $255 _RNUM 8 _RISNUM 8;
    if _n_ = 1 then do;
        declare hash k(dataset: "work._keys");
        k.definekey("_KEY");
        k.definedone();
    end;

    _KEY = strip(UNIQUE_ID_NO);
    if k.check() ne 0 then return;

    do _i = 1 to dim(_n);
        _COL = upcase(vname(_n{_i}));
        if _COL = "PROC_DTE" then continue;
        _RNUM = _n{_i};  _RTXT = "";  _RISNUM = 1;
        output;
    end;
    do _i = 1 to dim(_c);
        _COL = upcase(vname(_c{_i}));
        if _COL = "UNIQUE_ID_NO" then continue;
        _RTXT = _c{_i};  _RNUM = .;  _RISNUM = 0;
        output;
    end;

    keep _KEY _COL _RTXT _RNUM _RISNUM;
run;

proc sql noprint;
    create table work._rdlkeys as
    select distinct _KEY from work._rdllong;

    select count(*) into :n_fdup trimmed from
        (select _FILE, _KEY, _COL from work._filelong
          group by 1, 2, 3 having count(*) > 1);

    select count(*) into :n_rdup trimmed from
        (select _KEY, _COL from work._rdllong
          group by 1, 2 having count(*) > 1);
quit;

%if &n_fdup > 0 %then %do;
    title "UNIQUE_ID_NO appearing more than once in one file - each copy is verified";
    proc sql;
        select distinct _FILE label = "File", _KEY label = "UNIQUE_ID_NO"
          from work._filelong
         group by _FILE, _KEY, _COL
        having count(*) > 1;
    quit;
    title;
%end;

%if &n_rdup > 0 %then %do;
    title "UNIQUE_ID_NO appearing more than once on &rdl_ds at &rpt_lbl";
    proc sql;
        select distinct _KEY label = "UNIQUE_ID_NO"
          from work._rdllong
         group by _KEY, _COL
        having count(*) > 1;
    quit;
    title;
%end;

proc sql;
    create table work._cmp as
    select f._FILE, f._KEY, f._COL,
           f._FNUM, f._FTXT, f._FISNUM,
           r._RNUM, r._RTXT, r._RISNUM,
           (c._COL is not null) as _COLOK,
           (k._KEY is not null) as _KEYOK
      from work._filelong as f
           left join work._rdlcols as c
             on f._COL = c._COL
           left join work._rdlkeys as k
             on f._KEY = k._KEY
           left join work._rdllong as r
             on f._KEY = r._KEY and f._COL = r._COL;
quit;

data work._res;
    set work._cmp;
    length _STATUS $20 _NOTE $40 _FVAL _RVAL $80;
    drop _match _fn _rn;

    if _FISNUM then _FVAL = strip(put(_FNUM, best16.));
    else            _FVAL = _FTXT;

    if      not _COLOK       then _STATUS = "Column not on RDL";
    else if not _KEYOK       then _STATUS = "Key not on RDL";
    else if missing(_RISNUM) then _STATUS = "No RDL value";
    else do;
        if _RISNUM then _RVAL = strip(put(_RNUM, best16.));
        else            _RVAL = _RTXT;

        if _FISNUM and _RISNUM then
            _match = (missing(_FNUM) and missing(_RNUM))
                     or (abs(_FNUM - _RNUM) <= &tol);
        else if not _FISNUM and not _RISNUM then
            _match = (upcase(strip(_FTXT)) = upcase(strip(_RTXT)));
        else do;

            _NOTE = "Type differs - file vs RDL";
            if _FISNUM then do;
                _fn = _FNUM;
                _rn = input(strip(_RTXT), ?? best32.);
            end;
            else do;
                _fn = input(strip(_FTXT), ?? best32.);
                _rn = _RNUM;
            end;
            if nmiss(_fn, _rn) = 0 then _match = (abs(_fn - _rn) <= &tol);
            else _match = (upcase(strip(_FVAL)) = upcase(strip(_RVAL)));
        end;

        if _match then _STATUS = "Patched";
        else           _STATUS = "Differs";
    end;

    label _FILE   = "File"
          _KEY    = "UNIQUE_ID_NO"
          _COL    = "Column"
          _FVAL   = "In file"
          _RVAL   = "On RDL"
          _STATUS = "Status"
          _NOTE   = "Note";
run;

title "Patch verification against &rdl_ds at &rpt_lbl";
title2 "Every column in the files except PROC_DTE and UNIQUE_ID_NO, matched to &tol";
proc freq data=work._res;
    tables _FILE * _COL * _STATUS / list nocum nopercent;
run;
title;

proc sql noprint;
    select count(*) into :n_exc trimmed from work._res where _STATUS ne "Patched";
    select count(*) into :n_res trimmed from work._res;
quit;

%if &n_exc = 0 %then %do;
    data work._ok;
        length Result $110;
        Result = "Every value in every patch file matches &rdl_ds - &n_res values checked";
    run;
    title "Patch verification &rpt_lbl - result";
    proc print data=work._ok noobs label;
        label Result = "Result";
    run;
    title;
%end;
%else %do;
    proc sort data=work._res out=work._exc;
        where _STATUS ne "Patched";
        by _FILE _COL _KEY;
    run;

    title "Exceptions &rpt_lbl - &n_exc of &n_res values checked";
    %if &n_exc > 300 %then %do;
        title2 "First 300 shown";
    %end;
    proc print data=work._exc(obs=300) noobs label;
        var _FILE _KEY _COL _FVAL _RVAL _STATUS _NOTE;
    run;
    title;
%end;

proc datasets library=work nolist nowarn;
    delete _files _imp _fl _filelong _rdlcols _rdlkeys _rdllong
           _keys _cmp _res _exc _inv _ok;
quit;

%mend rdl_verify;

%rdl_verify

filename _pdir clear;
