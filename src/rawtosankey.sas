/*--------------------------------------------------------------------------------------------------

SAS RawToSankey macro created by Shane Rosanbalm of Rho, Inc. 2015

*---------- high-level overview ----------;

-  The Sankey diagram macro requires data in two structures:
   -  The NODES dataset must be one record per bar segment.
   -  The LINKS dataset must be one record per connection between bar segments. 
-  This macro transforms a vertical dataset (i.e., one record per SUBJECT and XVAR) into the 
   Sankey NODES and LINKS structures.

*---------- required parameters ----------;

data=             vertical dataset to be converted to sankey structures

subject=          subject identifier

yvar=             categorical y-axis variable
                  converted to values 1-N for use in plotting
                  
xvar=             categorical x-axis variable
                  converted to values 1-N for use in plotting

*---------- optional parameters ----------;

completecases=    whether or not to require non-missing yvar at all xvar values
                  valid values: yes/no.
                  default: yes.
                  
outlib=           library in which to save NODES and LINKS datasets
                  default is the WORK library
                  
yvarord=          sort order for y-axis conversion, in a comma separated list
                     e.g., yvarord=%quote(red rum, george smith, tree)
                  default sort is equivalent to ORDER=DATA
                  
xvarord=          sort order for x-axis conversion, in a comma separated list
                     e.g., xvarord=%quote(pink plum, fred funk, grass)
                  default sort is equivalent to ORDER=DATA

-------------------------------------------------------------------------------------------------*/



%macro rawtosankey
   (data=
   ,subject=
   ,yvar=
   ,xvar=
   ,completecases=
   ,outlib=work
   ,yvarord=
   ,xvarord=
   );


   %*---------- localization ----------;
   
   %local i;
   
   
   %*---------- return code ----------;
   
   %global rts;
   %let rts = 0;
   

   %*-----------------------------------------------------------------------------------------;
   %*---------- display parameter values at the top (for debugging) ----------;
   %*-----------------------------------------------------------------------------------------;
   
   %put &=data;
   %put &=subject;
   %put &=yvar;
   %put &=xvar;
   %put &=outlib;
   %put &=yvarord;
   %put &=xvarord;
   
   
   
   %*-----------------------------------------------------------------------------------------;
   %*---------- basic parameter checks ----------;
   %*-----------------------------------------------------------------------------------------;
   
   
   %*---------- dataset exists ----------;
   
   %let _dataexist = %sysfunc(exist(&data));
   %if &_dataexist = 0 %then %do;
      %put RawToSankey -> DATASET [&data] DOES NOT EXIST;
      %put RawToSankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   
   
   %*---------- variables exist ----------;
   
   %macro varexist(data,var);
      %let dsid = %sysfunc(open(&data)); 
      %if &dsid %then %do; 
         %let varnum = %sysfunc(varnum(&dsid,&var));
         %if &varnum %then &varnum; 
         %else 0;
         %let rc = %sysfunc(close(&dsid));
      %end;
      %else 0;
   %mend varexist;
   
   %if %varexist(&data,&subject) = 0 %then %do;
      %put RawToSankey -> VARIABLE [&subject] DOES NOT EXIST;
      %put RawToSankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   
   %if %varexist(&data,&yvar) = 0 %then %do;
      %put RawToSankey -> VARIABLE [&yvar] DOES NOT EXIST;
      %put RawToSankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   
   %if %varexist(&data,&xvar) = 0 %then %do;
      %put RawToSankey -> VARIABLE [&xvar] DOES NOT EXIST;
      %put RawToSankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   

   %*---------- eject missing yvar records ----------;
   
   data _nodes00;
      set &data;
      %if &completecases = yes %then %do;
         where not missing(&yvar);
      %end;
   run;
   
   
   %*---------- convert numeric yvar to character (for easier processing) ----------;
   
   %let dsid = %sysfunc(open(&data)); 
   %let varnum = %sysfunc(varnum(&dsid,&yvar));
   %let vartype = %sysfunc(vartype(&dsid,&varnum));
   %if &vartype = N %then %do; 
      data _nodes00;
         set _nodes00 (rename=(&yvar=_&yvar));
         &yvar = compress(put(_&yvar,best.));
         drop _&yvar;
      run;
   %end;
   %let rc = %sysfunc(close(&dsid));
   
   
   %*---------- convert numeric xvar to character (for easier processing) ----------;
   
   %let dsid = %sysfunc(open(&data)); 
   %let varnum = %sysfunc(varnum(&dsid,&xvar));
   %let vartype = %sysfunc(vartype(&dsid,&varnum));
   %if &vartype = N %then %do; 
      data _nodes00;
         set _nodes00 (rename=(&xvar=_&xvar));
         &xvar = compress(put(_&xvar,best.));
         drop _&xvar;
      run;
   %end;
   %let rc = %sysfunc(close(&dsid));
   
   
   %*---------- left justify xvar and yvar values (inelegant solution) ----------;
   
   data _nodes00;
      set _nodes00;
      &yvar = left(&yvar);
      &xvar = left(&xvar);
   run;
   
   
   %*---------- if no yvarord specified, build one using ORDER=DATA model ----------;
   
   proc sql noprint;
      select   distinct &yvar
      into     :yvar1-
      from     _nodes00
      ;
      %global n_yvar;
      %let n_yvar = &sqlobs;
      %put &=n_yvar;
   quit;
      
   %if &yvarord eq %str() %then %do;
   
      proc sql noprint;
         select   max(length(&yvar))
         into     :ml_yvar
         from     _nodes00
         ;
         %put &=ml_yvar;
      quit;
   
      data _null_;
         set _nodes00 (keep=&yvar) end=eof;
         array ordered {&n_yvar} $&ml_yvar;
         retain filled ordered1-ordered&n_yvar;
      
         *--- first record seeds array ---;
         if _N_ = 1 then do;
            filled = 1;
            ordered[filled] = &yvar;
         end;
      
         *--- if subsequent records not yet in array, add them ---;
         else do;
            hit = 0;
            do i = 1 to &n_yvar;
               if ordered[i] = &yvar then hit = 1;
            end;
            if hit = 0 then do;
               filled + 1;
               ordered[filled] = &yvar;
            end;
         end;
      
         *--- concatenate array elements into one variable ---;
         if eof then do;
            yvarord = catx(', ',of ordered1-ordered&n_yvar);
            call symputx('yvarord',yvarord);
         end;
      run;
      
   %end;

   %put &=yvarord;


   %*---------- if no xvarord specified, build one using ORDER=DATA model ----------;
   
   proc sql noprint;
      select   distinct &xvar
      into     :xvar1-
      from     _nodes00
      ;
      %global n_xvar;
      %let n_xvar = &sqlobs;
      %put &=n_xvar;
   quit;
      
   %if &xvarord eq %str() %then %do;
   
      proc sql noprint;
         select   max(length(&xvar))
         into     :ml_xvar
         from     _nodes00
         ;
         %put &=ml_xvar;
      quit;
   
      data _null_;
         set _nodes00 (keep=&xvar) end=eof;
         array ordered {&n_xvar} $&ml_xvar;
         retain filled ordered1-ordered&n_xvar;
      
         *--- first record seeds array ---;
         if _N_ = 1 then do;
            filled = 1;
            ordered[filled] = &xvar;
         end;
      
         *--- if subsequent records not yet in array, add them ---;
         else do;
            hit = 0;
            do i = 1 to &n_xvar;
               if ordered[i] = &xvar then hit = 1;
            end;
            if hit = 0 then do;
               filled + 1;
               ordered[filled] = &xvar;
            end;
         end;
      
         *--- concatenate array elements into one variable ---;
         if eof then do;
            xvarord = catx(', ',of ordered1-ordered&n_xvar);
            call symputx('xvarord',xvarord);
         end;
      run;
      
   %end;

   %put &=xvarord;


   %*---------- parse yvarord ----------;
   
   %let commas = %sysfunc(count(%bquote(&yvarord),%bquote(,)));
   %let n_yvarord = %eval(&commas + 1);
   %put &=commas &=n_yvarord;
   
   %do i = 1 %to &n_yvarord;
      %global yvarord&i;      
      %let yvarord&i = %scan(%bquote(&yvarord),&i,%bquote(,));
      %put yvarord&i = [&&yvarord&i];      
   %end;
   
   
   %*---------- parse xvarord ----------;
   
   %let commas = %sysfunc(count(%bquote(&xvarord),%bquote(,)));
   %let n_xvarord = %eval(&commas + 1);
   %put &=commas &=n_xvarord;
   
   %do i = 1 %to &n_xvarord;      
      %global xvarord&i;
      %let xvarord&i = %scan(%bquote(&xvarord),&i,%bquote(,));
      %put xvarord&i = [&&xvarord&i];      
   %end;
      
   
   %*-----------------------------------------------------------------------------------------;
   %*---------- yvarord vs. yvar ----------;
   %*-----------------------------------------------------------------------------------------;
   
   
   %*---------- same number of values ----------;

   %if &n_yvarord ne &n_yvar %then %do;
      %put RawToSankey -> NUMBER OF yvarord= VALUES [&n_yvarord];
      %put RawToSankey -> DOES NOT MATCH NUMBER OF yvar= VALUES [&n_yvar];
      %put RawToSankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   
   %*---------- put yvarord and yvar into quoted lists ----------;
   
   proc sql noprint;
      select   distinct quote(trim(left(&yvar)))
      into     :_yvarlist
      separated by ' '
      from     _nodes00
      ;
   quit;
   
   %put &=_yvarlist;
   
   data _null_;
      length _yvarordlist $2000;
      %do i = 1 %to &n_yvarord;
         _yvarordlist = trim(_yvarordlist) || ' ' || quote("&&yvarord&i");
      %end;
      call symputx('_yvarordlist',_yvarordlist);
   run;
   
   %put &=_yvarordlist;
   
   %*---------- check lists in both directions ----------;
   
   data _null_;
      array yvarord (&n_yvarord) $200 (&_yvarordlist);
      array yvar (&n_yvar) $200 (&_yvarlist);
      call symputx('_badyvar',0);
      %do i = 1 %to &n_yvarord;
         if "&&yvarord&i" not in (&_yvarlist) then call symputx('_badyvar',1);
      %end;
      %do i = 1 %to &n_yvar;
         if "&&yvar&i" not in (&_yvarordlist) then call symputx('_badyvar',2);
      %end;
   run;
   
   %if &_badyvar eq 1 %then %do;
      %put RawToSankey -> VALUE WAS FOUND IN yvarord= [&_yvarordlist];
      %put RawToSankey -> THAT IS NOT IN yvar= [&_yvarlist];
      %put RawToSankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   
   %if &_badyvar eq 2 %then %do;
      %put RawToSankey -> VALUE WAS FOUND IN yvar= [&_yvarlist];
      %put RawToSankey -> THAT IS NOT IN yvarord= [&_yvarordlist];
      %put RawToSankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
      

   %*-----------------------------------------------------------------------------------------;
   %*---------- xvarord vs. xvar ----------;
   %*-----------------------------------------------------------------------------------------;
   
   
   %*---------- same number of values ----------;
   
   %if &n_xvarord ne &n_xvar %then %do;
      %put RawToSankey -> NUMBER OF xvarord= VALUES [&n_xvarord];
      %put RawToSankey -> DOES NOT MATCH NUMBER OF xvar= VALUES [&n_xvar];
      %put RawToSankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   
   %*---------- put xvarord and xvar into quoted lists ----------;
   
   proc sql noprint;
      select   distinct quote(trim(left(&xvar)))
      into     :_xvarlist
      separated by ' '
      from     _nodes00
      ;
   quit;
   
   %put &=_xvarlist;
   
   data _null_;
      length _xvarordlist $2000;
      %do i = 1 %to &n_xvarord;
         _xvarordlist = trim(_xvarordlist) || ' ' || quote("&&xvarord&i");
      %end;
      call symputx('_xvarordlist',_xvarordlist);
   run;
   
   %put &=_xvarordlist;
   
   %*---------- check lists in both directions ----------;
   
   data _null_;
      array xvarord (&n_xvarord) $200 (&_xvarordlist);
      array xvar (&n_xvar) $200 (&_xvarlist);
      call symputx('_badxvar',0);
      %do i = 1 %to &n_xvarord;
         if "&&xvarord&i" not in (&_xvarlist) then call symputx('_badxvar',1);
      %end;
      %do i = 1 %to &n_xvar;
         if "&&xvar&i" not in (&_xvarordlist) then call symputx('_badxvar',2);
      %end;
   run;
   
   %if &_badxvar eq 1 %then %do;
      %put RawToSankey -> VALUE WAS FOUND IN xvarord= [&_xvarordlist];
      %put RawToSankey -> THAT IS NOT IN xvar= [&_xvarlist];
      %put RawToSankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   
   %if &_badxvar eq 2 %then %do;
      %put RawToSankey -> VALUE WAS FOUND IN xvar= [&_xvarlist];
      %put RawToSankey -> THAT IS NOT IN xvarord= [&_xvarordlist];
      %put RawToSankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
      

   %*-----------------------------------------------------------------------------------------;
   %*---------- enumeration ----------;
   %*-----------------------------------------------------------------------------------------;


   %*---------- enumerate yvar values ----------;
   
   proc sort data=_nodes00 out=_nodes05;
      by &yvar;
   run;
   
   data _nodes10;
      set _nodes05;
      by &yvar;
      %do i = 1 %to &n_yvarord;
         if &yvar = "&&yvarord&i" then y = &i;
      %end;
   run;
   
   %*---------- enumerate xvar values ----------;
   
   proc sort data=_nodes10 out=_nodes15;
      by &xvar;
   run;   
   
   data _nodes20;
      set _nodes15;
      by &xvar;
      %do i = 1 %to &n_xvarord;
         if &xvar = "&&xvarord&i" then x = &i;
      %end;
   run;
   
   %*---------- subset if doing complete cases ----------;
   
   proc sql noprint;
      select   max(x)
      into     :xmax
      from     _nodes20
      ;
      %put &=xmax;
   quit;
   
   proc sql;
      create table _nodes30 as
      select   *
      from     _nodes20
      %if &completecases eq yes %then %do;
         group by &subject
         having   count(*) eq &xmax
      %end;
      ;
   quit;

   %*---------- count subjects in case not doing complete cases ----------;

   %global subject_n;
   
   proc sql noprint;
      select   count(distinct &subject)
      into     :subject_n
      from     _nodes10
      ;
      %put &=subject_n;
   quit;
   
   
   %*-----------------------------------------------------------------------------------------;
   %*---------- transform raw data to nodes structure ----------;
   %*-----------------------------------------------------------------------------------------;


   proc sql;
      create table _nodes40 as
      select   x, y, count(*) as size
      from     _nodes30
      group by x, y
      ;
   quit;
   
   data &outlib..nodes;
      set _nodes40;
      length xc yc $200;
      %do i = 1 %to &n_xvarord;
         if x = &i then xc = "&&xvarord&i";
      %end;
      %do i = 1 %to &n_yvarord;
         if y = &i then yc = "&&yvarord&i";
      %end;
   run;

   
   %*-----------------------------------------------------------------------------------------;
   %*---------- transform raw data to links structure ----------;
   %*-----------------------------------------------------------------------------------------;


   proc sort data=_nodes30 out=_links00;
      by &subject x;
   run;
   
   data _links10;
      set _links00;
      by &subject x;
      retain lastx lasty;
      if first.&subject then call missing(lastx,lasty);
      else if lastx + 1 eq x then do;
         x1 = lastx;
         y1 = lasty;
         x2 = x;
         y2 = y;
         output;
      end;
      lastx = x;
      lasty = y;
   run;

   proc sql noprint;
      create table &outlib..links as
      select   x1, y1, x2, y2, count(*) as thickness
      from     _links10
      group by x1, y1, x2, y2
      ;
   quit;
   
   
   %*--------------------------------------------------------------------------------;
   %*---------- clean up ----------;
   %*--------------------------------------------------------------------------------;
   
   
   %if &debug eq no %then %do;
   
      proc datasets library=work nolist;
         delete _nodes: _links:;
      run; quit;
   
   %end;
   
   
   %*---------- return code ----------;
   
   %let rts = 1;
   


%mend rawtosankey;














