/*--------------------------------------------------------------------------------------------------

SAS Sankey macro created by Shane Rosanbalm of Rho, Inc. 2015

*---------- high-level overview ----------;

-  This macro creates a stacked bar chart with Sankey-like links between the stacked bars. 
   The graphic is intended to display the change over time in categorical subject endpoint 
   values. These changes are depicted by bands flowing from left to right between the stacked 
   bars. The thickness of each band corresponds to the number of subjects moving from the left 
   to the right.
-  This macro is actually just a wrapper macro that contains two smaller macros. 
   -  The first inner macro, %RawToSankey, performs a data transformation. Assuming an input  
      dataset that is vertical (i.e., one record per subject and visit), the macro 
      generates two sets of counts:
      (a)   The number of subjects at each endpoint*visit combination (aka, NODES).
            E.g., how many subjects had endpoint=1 at visit=3?
      (b)   The number of subjects transitioning between endpoint categories at adjacent 
            visits (aka LINKS).
            E.g., how many subjects had endpoint=1 at visit=3 and endpoint=3 at visit=4?
      -  By default the endpoint and visit values are sorted using the ORDER=DATA principle.
         The optional parameter yvarord= and xvarord= can be used to change the display order.
   -  The second inner macro, %Sankey, uses SGPLOT to generate the bar chart (using the NODES 
      dataset) and the Sankey-like connectors (using the LINKS dataset).
      -  Any ODS GRAPHICS adjustments (e.g., HEIGHT=, WIDTH=, IMAGEFMT=, etc.) should be made 
         prior to calling the macro.
      -  There are a few optional parameters for changing the appearance of the graph (colors, 
         bar width, x-axis format, etc.), but it is likely that most seasoned graphers will want 
         to further customize the resulting figure. In that case, it is probably best to simply 
         make a copy of the %Sankey macro and edit away.

*---------- required parameters ----------;

data=             vertical dataset to be converted to sankey structures

subject=          subject identifier

yvar=             categorical y-axis variable
                  converted to values 1-N for use in plotting
                  
xvar=             categorical x-axis variable
                  converted to values 1-N for use in plotting

*---------- optional parameters ----------;

yvarord=          sort order for y-axis conversion, in a comma separated list
                     e.g., yvarord=%quote(red rum, george smith, tree)
                  default sort is equivalent to ORDER=DATA
                  
xvarord=          sort order for x-axis conversion, in a comma separated list
                     e.g., xvarord=%quote(pink plum, fred funk, grass)
                  default sort is equivalent to ORDER=DATA

colorlist=        A space-separated list of colors: one color per yvar group.
                  Not compatible with color descriptions (e.g., very bright green).
                  Default: the qualititive Brewer palette.

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
                  
-------------------------------------------------------------------------------------------------*/


%macro sankeybarchart
   (data=
   ,subject=
   ,yvar=
   ,xvar=
   ,yvarord=
   ,xvarord=
   ,colorlist=
   ,barwidth=0.25
   ,xfmt=
   ,legendtitle=
   ,interpol=cosine
   ,percents=yes
   );
   

   %*---------- first inner macro ----------;

   %include "rawtosankey.sas";
   
   %if &data eq %str() or &subject eq %str() or &yvar eq %str() or &xvar eq %str() %then %do;
      %put SankeyBarChart -> AT LEAST ONE REQUIRED PARAMETER IS MISSING;
      %put SankeyBarChart -> THE MACRO WILL STOP EXECUTING;
      %return;
   %end;

   %rawtosankey
      (data=&data
      ,subject=&subject
      ,yvar=&yvar
      ,xvar=&xvar
      %if &yvarord ne %then ,yvarord=&yvarord;
      %if &xvarord ne %then ,xvarord=&xvarord;
      );


   %*---------- second inner macro ----------;

   %include "sankey.sas";

   %if &rts = 1 %then %do;
   
      %sankey
         (barwidth=&barwidth
         ,interpol=&interpol
         ,percents=&percents
         %if &colorlist ne %then ,colorlist=&colorlist;
         %if &xfmt ne %then ,xfmt=&xfmt;
         %if &legendtitle ne %then ,legendtitle=&legendtitle;
         );
      
   %end;

%mend;



















