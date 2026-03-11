%%BoundingBox: 0 0 1 1
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Name:        UtilJC.pro
% Description: PostScript Utilities for XY plots and tables
% Author:      Jinchi Chu (jinchi@pangea.stanford.edu), 1993
% CopyRights:  Sharewhare, modify as you wish but keep this header intact. 
%              Use at your own risk.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%BEGIN UtilJC.pro
%
% variables you can reset
%/XYOutWidth 120 def               % Outer Box width 
%/XYOutHeight 100 def              % Outer Box height 
%/XYWidth XYOutWidth 0.9 mul def   % Inner Box width 
%/XYHeight XYOutHeight 0.9 mul def % Inner Box height
%/XYNumberingX false def           % plot the numbers on X axis? 
%/XYNumberingY false def           % plot the numbers on Y axis?
%/XYTitlePosition 0 def
%/XYPlot { lineto bullet } def     % how the points are plotted
%
 
% functions
/ctext { dup stringwidth pop 2 div neg 0 rmoveto show } def
/bullet { gsave currentpoint newpath 1 0 360 arc closepath fill grestore } def

/XYBox {
    /majorticklength 4 def
    /minorticklength 2 def

    /gtitle exch def
    /nyy exch def /dy exch def /ymax exch def /ymin exch def /ylabel exch def
    /nxx exch def /dx exch def /xmax exch def /xmin exch def /xlabel exch def
    /y0 exch def /x0 exch def

    /xunits { XYWidth xmax xmin sub div mul } def
    /yunits { XYHeight ymax ymin sub div mul } def
    gsave
    1.0 setlinewidth newpath x0 y0 moveto 
    XYWidth 0 rlineto 0 XYHeight rlineto XYWidth neg 0 rlineto closepath stroke
    grestore

    %%% title 
    /Helvetica-Oblique findfont 9 scalefont setfont
    x0 2 add y0 XYHeight 1.05 mul add 
    moveto gtitle show

    %%% x axis
    /Helvetica findfont 7 scalefont setfont
    x0 XYWidth 2 div add y0 30 sub moveto xlabel ctext
    xmin dx xmax {
		/x exch def
		/xx x xmin sub xunits x0 add def
        xx y0 moveto 
        gsave 0.75 setlinewidth 0 majorticklength rlineto stroke grestore
        gsave
        0.5 setlinewidth
        xx  dx xunits nxx div  xx dx xunits add {
            /xx exch def
            xx XYWidth x0 add lt {
                xx y0 moveto 0 minorticklength rlineto stroke
            } if
        } for
        grestore
    } for

    %%% y axis
    x0 35 sub  y0 XYHeight 2 div add  moveto  
    gsave 90 rotate ylabel ctext grestore
    ymin dy ymax {
		/y exch def
		/yy y ymin sub yunits y0 add def
        x0 yy moveto 
        gsave 0.75 setlinewidth majorticklength 0 rlineto stroke grestore
        gsave
        0.5 setlinewidth
        yy  dy yunits nyy div  yy dy yunits add {
            /yy exch def
            yy XYHeight y0 add lt {
                x0 yy moveto minorticklength 0 rlineto stroke
            } if
        } for
        grestore
    } for
} def

/XYNumberX {
	XYNumberingX {
		{
        	dup cvr xmin sub xunits x0 add y0 moveto 
        	0 -12 rmoveto 
			64 string cvs ctext 
		} forall
	} if
} def

/XYNumberY {
	XYNumberingY {
		{
			/y exch def
        	/yt y 64 string cvs def
        	x0 y cvr ymin sub yunits y0 add moveto 
       		yt stringwidth pop neg 3 sub -3 rmoveto 
			yt show
		} forall
	} if
} def

/XYGetFirstPoint {
    x0 xmin xunits sub  y0 ymin yunits sub translate
    /y exch yunits def /x exch xunits def
    x y moveto
} def

/XYPlotPoints {
    gsave
    XYGetFirstPoint
    /odd true def
    %%% loop through xy pairs on stack
    {
        odd {
			/x exch def
            /odd false def
        } {
			/y exch def
			x xmin ge {
				x xmax le {
					y ymin ge {
						y ymax le {
            				x xunits y yunits XYPlot
						} if
					} if
				} if
			} if
            /odd true def
        } ifelse
    } forall
    stroke
    grestore
} def

%%BEGIN Example
%
%200 200 300 200              % (x0, y0, w, h)
%(LAG DISTANCE) -10.0 30.0 6 5  % xlabel, xmin, xmax, dx, ntick
%(VARIOGRAM)    5.0 20.0 5 2  % ylabel, ymin, ymax, dy, ntick
%(Traditional Variogram) XYBox
%
%/XYPlot {lineto bullet} def 
%[
%8 14 
%15 16 
%16 9 
%20 10
%] 
%8 14  XYPlotPoints        
%
%/XYPlot {moveto bullet} def
%[
%0 6 
%5 10 
%10 20 
%15 17
%20 19
%] 
%0 6  XYPlotPoints
%
%%END Example

/XYMatrix {
  /Matrix exch def
  /ncol exch def 
  /dy exch def /dx exch def
  /top exch def /left exch def

  /Times-Roman findfont 12 scalefont setfont
  left top 5 add moveto show

  /i 0 def /x left def /y top def
  /Helvetica findfont 10 scalefont setfont
  Matrix {
    /str exch def 
    x 5 add y 12 sub moveto
    str show
    /x x dx add def
    /i i 1 add def
    i ncol eq {
        /y y dy sub def
        /x left def
        /i 0 def
    } if
  } forall
  newpath 
  /right ncol dx mul left add def
  /bottom y def
  left top moveto right top lineto right bottom lineto left bottom lineto
  closepath stroke
} def

%BEGIN Example
%(Title of Table)
%100 400 40 20
%5
%[
%(11) (12) (13) (14) (15)
%(21) (22) (23) (24) (25)
%(31) (32) (33) (34) (35)
%(41) (42) (43) (44) (45)
%(51) (52) (53) (54) (55)
%] 
%XYMatrix
%
%END Example
%END UtilJC.pro
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
