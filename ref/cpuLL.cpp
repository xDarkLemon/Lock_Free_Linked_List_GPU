#include <stdio.h>
#include <malloc.h>
#include <iostream>
#include <fstream>
#include <string>
#include <string.h>
using namespace std;

// #define DEBUG

struct node {
	struct node *next;
	int data;
};

struct node *createNode(int val) {
	struct node *nn = (struct node *)malloc(sizeof(struct node));
	nn->data = val;
	nn->next = NULL;

	return nn;
}

struct node *listInit(int *Nodes, int N) {
	struct node *head = createNode(-1);
	struct node *tmp = NULL;
	for (int i=0; i<N; i++) {
		struct node *nn = createNode(Nodes[i]);
		nn->next = tmp;
		tmp = nn;
	}
	head->next = tmp;
	return head;
}

struct node *listSearch(struct node *head, const int opNode) {
	struct node *p = head->next;
	while(p!=NULL && p->data!=opNode)
	{
		p=p->next;
	}
	return p;  // if not found, return NULL
}

void listInsert(struct node *&head, const int opNode, const int insertNode) {
	struct node *p = listSearch(head, opNode);
	if (p)
	{
		struct node *nn = createNode(insertNode);
		nn->next = p->next;
		p->next = nn;
	}
#ifdef DEBUG
	else printf("Insert Prev %d not found\n", opNode);
#endif
}

void listRemove(struct node *&head, const int opNode)
{
	struct node *p = head->next;
	struct node *prev = head;
	while(p!=NULL && p->data!=opNode)
	{
		p=p->next;
		prev=prev->next;
	}
	if (p)
	{
		prev->next = p->next;
		free(p);
	}	
#ifdef DEBUG
	else printf("Remove node %d not found\n", opNode);
#endif
}

void printList(struct node *head, int n) {
	if (head) 
	{
		n++;
		if (head->data==-1)
			printf("head ");
		else
			printf("%d ", head->data);
		printList(head->next,n);
	} 
	else 
	{
		printf("tail\nNumber of nodes = %d\n",n+1);
	}
}

void printListLen(struct node *head, int n) {
	if (head) 
	{
		n++;
		printListLen(head->next,n);
	} 
	else 
	{
		printf("Number of nodes = %d\n",n+1);
	}
}

void readFileNodes(int *&Nodes, int &N)
{
    ifstream f;
    f.open("../data/listnodes.txt");
    if(f.is_open())
    {
        f >> N;
        printf("Read From File Nodes: %d\n",N);
        Nodes = (int *)malloc(sizeof(int)*N);
        int i=0;
        while(!f.eof())
        {
            f >> Nodes[i];
            i++;
        }
    }
    f.close();
}

void readFileOps(int *&ops, int *&opNodes, int *&insertNodes, int &N)
{
    ifstream f;
    f.open("../data/operations.txt");
    if(f.is_open())
    {
        f >> N;
        printf("Read From File Operations: %d\n",N);
        ops = (int *)malloc(sizeof(int)*N);
        opNodes = (int *)malloc(sizeof(int)*N);
        insertNodes = (int *)malloc(sizeof(int)*N);
        memset(insertNodes, 0, sizeof(int)*N);
        int i=0;
        while(!f.eof())
        {
            f >> ops[i];
            f >> opNodes[i];
            if(ops[i]==1)
            {
                f >> insertNodes[i];
            }
            i++;
        }
    }
    f.close();
}

void sequentialOperate()
{
	struct timespec start, end;
	double time_taken;

	// read node file
	int *Nodes, N;
	readFileNodes(Nodes, N);
	// read operation file
	int *ops, *opNodes, *insertNodes, opN;
	readFileOps(ops, opNodes, insertNodes, opN);
	
	// create list on cpu
	struct node *head = listInit(Nodes, N);
	printf("CPU Before:\n");
	printListLen(head,0);

	// CPU sequential operate
	clock_gettime(CLOCK_REALTIME, &start);

	for (int i=0; i<opN; i++)
	{
		if (ops[i]==1)
		{
			listInsert(head, opNodes[i], insertNodes[i]);
		}
		else if (ops[i]==0)
		{
			listRemove(head, opNodes[i]);
		}
	}

	clock_gettime(CLOCK_REALTIME, &end);
  	time_taken = ( end.tv_sec - start.tv_sec ) * 1000000000.0 + ( end.tv_nsec - start.tv_nsec );
	printf("CPU After:\n");
	printListLen(head,0);
  	printf("Time taken = %lf nano sec\n", time_taken);
}

int main()
{
	sequentialOperate();
	return 0;
}