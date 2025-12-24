#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include "draw.h"
#include "global.h"

#define	Pi	3.14159
struct	d2point plane_cast(struct d3point user3d);
void	encode(float,float,int*);
int	trip(struct line);
struct	d2point	toview(struct d2point);
void 	translate();
void	init();
void	draw_line(Window win,GC gc,Display *display,int screen, XColor color);
void 	readline();
void 	draw_guide(Window,GC,Display *,int,XColor,XColor,int);
