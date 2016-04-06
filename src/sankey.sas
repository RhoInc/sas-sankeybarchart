/*--------------------------------------------------------------------------------------------------

SAS Sankey macro created by Shane Rosanbalm of Rho, Inc. 2015

*---------- high-level overview ----------;

-  This macro creates a stacked bar chart with sankey-like links between the stacked bars. 
   It is intended to display the change over time in subject endpoint values.
   These changes are depicted by bands flowing from left to right between the stacked bars. 
   The thickness of each band corresponds to the number of subjects moving from the left to 
   the right.
-  The macro assumes two input datasets exist: NODES and LINKS.
   -  Use the macro %RawToSankey to help build NODES and LINKS from a vertical dataset.
   -  The NODES dataset must be one record per bar segment, with variables:
      -  X and Y (the time and response), 
      -  XC and YC (the character versions of X and Y),
      -  SIZE (the number of subjects represented by the bar segment).
      -  The values of X and Y should be integers starting at 1.
      -  Again, %RawToSankey will build this dataset for you.
   -  The LINKS dataset must be one record per link, with variables:
      -  X1 and Y1 (the time and response to the left), 
      -  X2 and Y2 (the time and response to the right), 
      -  THICKNESS (the number of subjects represented by the band). 
      -  The values of X1, Y1, X2, and Y2 should be integers starting at 1.
      -  Again, %RawToSankey will build this dataset for you.
-  The chart is produced using SGPLOT. 
   -  The procedure contains one HIGHLOW statement per node (i.e., per bar segment).
   -  The procedure contains one BAND statement per link (i.e., per connecting band).
   -  The large volume of HIGHLOW and BAND statements is necessary to get color consistency in 
      v9.3 (in v9.4 we perhaps could have used attribute maps to clean things up a bit).
-  Any ODS GRAPHICS adjustments (e.g., HEIGHT=, WIDTH=, IMAGEFMT=, etc.) should be made prior to 
   calling the macro.
-  Any fine tuning of axes or other appearance options will need to be done in (a copy of) the 
   macro itself.

*---------- required parameters ----------;

There are no required parameters for this macro.

*---------- optional parameters ----------;

sankeylib=        Library where NODES and LINKS datasets live.
                  Default: WORK
                  
colorlist=        A space-separated list of colors: one color per response group.
                  Not compatible with color descriptions (e.g., very bright green).
                  Default: the qualitative Brewer palette.

barwidth=         Width of bars.
                  Values must be in the 0-1 range.
                  Default: 0.25.
                  
xfmt=             Format for x-axis/time.
                  Default: values of xvar variable in original dataset.

legendtitle=      Text to use for legend title.
                     e.g., legendtitle=%quote(Response Value)

interpol=         Method of interpolating between bars.
                  Valid values are: cosine, linear.
                  Default: cosine.

percents=         Show percents inside each bar.
                  Valid values: yes/no.
                  Default: yes.
                  
*---------- outstanding issues ----------;

-------------------------------------------------------------------------------------------------*/



%macro sankey
   (sankeylib=work
   ,colorlist=
   ,barwidth=0.25
   ,xfmt=
   ,legendtitle=
   ,interpol=cosine
   ,percents=yes
   );



   %*----------------------------------------------------------------------------------------------;
   %*----------------------------------------------------------------------------------------------;
   %*---------- some preliminaries ----------;
   %*----------------------------------------------------------------------------------------------;
   %*----------------------------------------------------------------------------------------------;



   %*---------- localization ----------;
   
   %local i j;
   
   
   %*---------- dataset exists ----------;
   
   %let _dataexist = %sysfunc(exist(&sankeylib..nodes));
   %if &_dataexist = 0 %then %do;
      %put Sankey -> DATASET [&sankeylib..nodes] DOES NOT EXIST;
      %put Sankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   
   data nodes;
      set &sankeylib..nodes;
   run;
   
   %let _dataexist = %sysfunc(exist(&sankeylib..links));
   %if &_dataexist = 0 %then %do;
      %put Sankey -> DATASET [&sankeylib..links] DOES NOT EXIST;
      %put Sankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   
   data links;
      set &sankeylib..links;
   run;
   
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
   
   %if %varexist(nodes,x) = 0 or %varexist(nodes,y) = 0 or %varexist(nodes,size) = 0 %then %do;
      %put Sankey -> DATASET [work.nodes] MUST HAVE VARIABLES [x y size];
      %put Sankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   
   %if %varexist(links,x1) = 0 or %varexist(links,y1) = 0 or %varexist(links,x2) = 0 
         or %varexist(links,y2) = 0 or %varexist(links,thickness) = 0 %then %do;
      %put Sankey -> DATASET [work.links] MUST HAVE VARIABLES [x1 y1 x2 y2 thickness];
      %put Sankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   
   %*---------- preliminary sorts (and implicit dataset/variable checking) ----------;
   
   proc sort data=nodes;
      by y x size;
   run;

   proc sort data=links;
      by x1 y1 x2 y2 thickness;
   run;
   
   %*---------- break apart colors ----------;

   %if &colorlist eq %str() 
      %then %let colorlist = cxa6cee3 cx1f78b4 cxb2df8a cx33a02c cxfb9a99 cxe31a1c 
                             cxfdbf6f cxff7f00 cxcab2d6 cx6a3d9a cxffff99 cxb15928;
   %let n_colors = %sysfunc(countw(&colorlist));
   %do i = 1 %to &n_colors;
      %let color&i = %scan(&colorlist,&i,%str( ));
      %put color&i = [&&color&i];
   %end;
   
   %*---------- xfmt ----------;
   
   %if &xfmt eq %str() %then %do;
   
      %let xfmt = xfmt.;
      
      proc format;
         value xfmt
         %do i = 1 %to &n_xvar;
            &i = "&&xvarord&i"
         %end;
         ;
      run;
      
   %end;
   
   %put &=xfmt;
   
   %*---------- number of rows ----------;

   proc sql noprint;
      select   max(y)
      into     :maxy
      from     nodes
      ;
   quit;
   
   %*---------- number of time points ----------;

   proc sql noprint;
      select   max(x)
      into     :maxx
      from     nodes
      ;
   quit;
   
   %*---------- corresponding text ----------;
   
   proc sql noprint;
      select   distinct y, yc
      into     :dummy1-, :yvarord1-
      from     nodes
      ;
   quit;
   
   %do i = 1 %to &sqlobs;
      %put yvarord&i = [&&yvarord&i];
   %end;
   
   %*---------- validate interpol ----------;
   
   %let _badinterpol = 0;
   data _null_;
      if      upcase("&interpol") = 'LINEAR' then call symput('interpol','linear');
      else if upcase("&interpol") = 'COSINE' then call symput('interpol','cosine');
      else call symput('_badinterpol','1');
   run;
   
   %if &_badinterpol eq 1 %then %do;
      %put Sankey -> THE VALUE INTERPOL= [&interpol] IS INVALID.;
      %put Sankey -> THE MACRO WILL STOP EXECUTING.;
      %return;
   %end;
   


   %*----------------------------------------------------------------------------------------------;
   %*----------------------------------------------------------------------------------------------;
   %*---------- convert counts to percents for nodes ----------;
   %*----------------------------------------------------------------------------------------------;
   %*----------------------------------------------------------------------------------------------;
   
   
   
   ods select none;
   ods output crosstabfreqs=_ctfhl (where=(_type_='11'));
   proc freq data=nodes;
      table x*y;
      weight size;
   run;
   ods select all;
   
   data _highlow;
      set _ctfhl;
      by x;
      node = _N_;
      retain cumpct;
      if first.x then cumpct = 0;
      low = cumpct;
      high = cumpct + rowpercent;
      cumpct = high;   
      keep x y node low high;   
   run;
   
   proc sql noprint;
      select   max(node)
      into     :maxhighlow
      from     _highlow
      ;
   quit;



   %*----------------------------------------------------------------------------------------------;
   %*----------------------------------------------------------------------------------------------;
   %*---------- write a bunch of highlow statements ----------;
   %*----------------------------------------------------------------------------------------------;
   %*----------------------------------------------------------------------------------------------;



   data _highlow_statements;
      set _highlow;
      by x;
      length highlow $200 color $20 legendlabel $40 scatter $200;

      %*---------- choose color based on y ----------;
      %do c = 1 %to &maxy;
         if y = &c then color = "&&color&c";
      %end;

      %*---------- create node specific x, low, high variables and write highlow statement ----------;
      %do j = 1 %to &maxhighlow;
         %let jc = %sysfunc(putn(&j,z%length(&maxhighlow).));
         %let jro = %sysfunc(mod(&j,&maxy));
         %if &jro = 0 %then %let jro = &maxy;
         if node = &j then do;
            xb&jc = x;
            lowb&jc = low;
            highb&jc = high;
            legendlabel = "&&yvarord&jro";
            highlow = "highlow x=xb&jc low=lowb&jc high=highb&jc / type=bar barwidth=&barwidth" ||
               " fillattrs=(color=" || trim(color) || ")" ||
               " name='" || trim(color) || "' legendlabel='" || trim(legendlabel) || "';";
            *--- sneaking in a scatter statement for percent annotation purposes ---;
            mean = mean(low,high);
            percent = high - low;
            if percent >= 1 then do;
               meanb&jc = mean;
               textb&jc = compress(put(percent,3.)) || '%';
               scatter = "scatter x=xb&jc y=meanb&jc / x2axis markerchar=textb&jc;";
            end;
         end;
      %end;

   run;

   proc sql noprint;
      select   distinct trim(highlow)
      into     :highlow
      separated by ' '
      from     _highlow_statements
      where    highlow is not missing
      ;
   quit;

   %put highlow = [%nrbquote(&highlow)];

   proc sql noprint;
      select   distinct trim(scatter)
      into     :scatter
      separated by ' '
      from     _highlow_statements
      where    scatter is not missing
      ;
   quit;

   %put scatter = [%nrbquote(&scatter)];
   
   
   %*---------- calculate offset based on bar width and maxx ----------;
   
   data _null_;
      if &maxx = 2 then offset = 0.25;
      else if &maxx = 3 then offset = 0.15;
      else offset = 0.05 + 0.03*((&barwidth/0.25)-1);
      call symputx ('offset',offset);
   run;   



   %*----------------------------------------------------------------------------------------------;
   %*----------------------------------------------------------------------------------------------;
   %*---------- convert counts to percents for links ----------;
   %*----------------------------------------------------------------------------------------------;
   %*----------------------------------------------------------------------------------------------;



   %*---------- number of subjects overall ----------;
   
   proc sql noprint;
      select   sum(size)
      into     :denom trimmed
      from     nodes
      where    x = 1
      ;
   quit;
   
   %put NOTE- &=denom;
      
   %*---------- left edge of each band ----------;
   
   data _links2;
      set links;
      by x1 y1 x2 y2;
      link = _N_;
      retain lastybhigh1;
      if first.x1 then lastybhigh1 = 0;
      xt1 = x1;
      yblow1 = lastybhigh1;
      ybhigh1 = lastybhigh1 + thickness/&denom;
      lastybhigh1 = ybhigh1;
   run;
   
   proc sort data=_links2 out=_links3;
      by x2 y2 x1 y1;
   run;
   
   %*---------- right edge of each band ----------;
   
   data _links3;
      set _links3;
      by x2 y2 x1 y1;
      retain lastybhigh2;
      if first.x2 then lastybhigh2 = 0;
      xt2 = x2;
      yblow2 = lastybhigh2;
      ybhigh2 = lastybhigh2 + thickness/&denom;
      lastybhigh2 = ybhigh2;
   run;
   
   %*---------- make vertical ----------;
   
   data _links4;
      set _links3;
      
      xt1alt = xt1 + &barwidth*0.48;
      xt2alt = xt2 - &barwidth*0.48;
      
      %if &interpol eq linear %then %do;
      
         do xt = xt1alt to xt2alt by 0.01;
            *--- low ---;
            mlow = (yblow2 - yblow1) / (xt2alt - xt1alt);
            blow = yblow1 - mlow*xt1alt;
            yblow = mlow*xt + blow;
            *--- high ---;
            mhigh = (ybhigh2 - ybhigh1) / (xt2alt - xt1alt);
            bhigh = ybhigh1 - mhigh*xt1alt;
            ybhigh = mhigh*xt + bhigh;
            output;
         end;
         
      %end;

      %if &interpol eq cosine %then %do;
      
         do xt = xt1alt to xt2alt by 0.01;
            b = constant('pi')/(xt2alt-xt1alt);
            c = xt1alt;
            *--- low ---;
            alow = (yblow1 - yblow2) / 2;
            dlow = yblow1 - ( (yblow1 - yblow2) / 2 );
            yblow = alow * cos( b*(xt-c) ) + dlow;
            *--- high ---;
            ahigh = (ybhigh1 - ybhigh2) / 2;
            dhigh = ybhigh1 - ( (ybhigh1 - ybhigh2) / 2 );
            ybhigh = ahigh * cos( b*(xt-c) ) + dhigh;
            output;
         end;
         
      %end;
      
      keep xt yblow ybhigh link y1;
   run;
   
   proc sort data=_links4;
      by link xt;
   run;
   
   %*---------- number of links ----------;

   proc sql noprint;
      select   max(link)
      into     :maxband
      from     _links4
      ;
   quit;
   
   %*---------- write the statements ----------;
   
   data _band_statements;
      set _links4;
      by link xt;
      length band $200 color $20;

      %*---------- choose color based on y1 ----------;
      %do c = 1 %to &maxy;
         if y1 = &c then color = "&&color&c";
      %end;

      %*---------- create link specific x, y variables and write series statements ----------;
      %do j = 1 %to &maxband;
         %let jc = %sysfunc(putn(&j,z%length(&maxband).));
         if link = &j then do;
            xt&jc = xt;
            yblow&jc = 100*yblow;
            ybhigh&jc = 100*ybhigh;
            band = "band x=xt&jc lower=yblow&jc upper=ybhigh&jc / x2axis transparency=0.5" || 
               " fill fillattrs=(color=" || trim(color) || ")" ||
               " ;";
         end;
      %end;

   run;

   proc sql noprint;
      select   distinct trim(band)
      into     :band
      separated by ' '
      from     _band_statements
      where    band is not missing
      ;
   quit;

   %put band = [%nrbquote(&band)];
   
                     
   
   %*----------------------------------------------------------------------------------------------;
   %*----------------------------------------------------------------------------------------------;
   %*---------- plot it ----------;
   %*----------------------------------------------------------------------------------------------;
   %*----------------------------------------------------------------------------------------------;
   
   
   
   data _all;
      set _highlow_statements _band_statements;
   run;
   
   proc sgplot data=_all noautolegend;
      %*---------- plotting statements ----------;
      &band;
      &highlow;
      %if &percents = yes %then &scatter;;
      %*---------- axis and legend statements ----------;
      x2axis display=(nolabel noticks) min=1 max=&maxx integer offsetmin=&offset offsetmax=&offset 
         tickvalueformat=&xfmt;
      xaxis display=none type=discrete offsetmin=&offset offsetmax=&offset 
         tickvalueformat=&xfmt;
      yaxis offsetmin=0.02 offsetmax=0.02 label="Percent" grid;
      keylegend %do i = 1 %to &maxy; "&&color&i" %end; / title="&legendtitle";
   run;
   

   %*--------------------------------------------------------------------------------;
   %*---------- clean up ----------;
   %*--------------------------------------------------------------------------------;
   
   
   proc datasets library=work nolist;
      delete _nodes: _links: _all: _band: _highlow: _ctfhl;
   run; quit;
   


%mend sankey;













