/* drawline.c - draw_line() to draw line to the screen using the x function */

#include "all.h"

void draw_line(Window win,GC gc,Display *display,
		int screen, XColor color)
{
	struct listnode 	*ltp;
	float		x1,y1,x2,y2;
	XSetForeground(display, gc, color.pixel);
	lineNum=0;
	ltp=listhead;
	
	while(ltp!=NULL)
	{
		if(ltp->off==0)
		{

			x1=ltp->line2.p1.x;
			y1=ltp->line2.p1.y;
			x2=ltp->line2.p2.x;
			y2=ltp->line2.p2.y;
			XDrawLine(display,win,gc,(int)x1,(int)y1,(int)x2,(int)y2);
		}
		ltp=ltp->next;
	}
}
