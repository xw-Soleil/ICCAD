/* readline.c -- readline() to read the line point data in file and 
 * 		construct the linklist;
 */

#include "all.h" 

void readline()
{
	FILE	*file;
	int	number=0;
	float	fTemp;
	struct	listnode * node;
	int	state;

	file=fopen("cube.line","rt");
	if (file==NULL)
	{
		printf("can't open file");
		exit(-1);
	}
	while (1)
	{
		node=(struct listnode *)malloc(sizeof(struct listnode));
		if (node == NULL) {
			perror("malloc failed");
			fclose(file);
			exit(-1);
		}

		/* each time, read two sets of x, y, z. */ 	
		if (fscanf(file,"%f",&fTemp) != 1) { free(node); break; }
		node->line1.p1.x=fTemp;
        
		if (fscanf(file,"%f",&fTemp) != 1) { free(node); break; }
		node->line1.p1.y=fTemp;

		if (fscanf(file,"%f",&fTemp) != 1) { free(node); break; }
		node->line1.p1.z=fTemp;

		if (fscanf(file,"%f",&fTemp) != 1) { free(node); break; }
		node->line1.p2.x=fTemp;

		if (fscanf(file,"%f",&fTemp) != 1) { free(node); break; }
		node->line1.p2.y=fTemp;

		state=fscanf(file,"%f",&fTemp);
		if (state != 1) { free(node); break; }
		node->line1.p2.z=fTemp;

		node->off = 0;           /* ensure visible */
		node->next=listhead;
		listhead=node;
		number++;
	}

}
