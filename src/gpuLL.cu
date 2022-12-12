#include <stdio.h>
#include <time.h> 
#include <cuda.h>
#include <malloc.h>
#include <iostream>
#include <fstream>
#include <string>
#include <string.h>
using namespace std;

// #define DEBUG

// the first 3 bits of a pointer are empty, use the first bit as marker
#define IS_MARKED(p)  ((int)(((unsigned long long)(p)) & 1))
#define GET_MARKED_REF(p) (((unsigned long long)(p)) | 1)
#define GET_UNMARKED_REF(p) (((unsigned long long)(p)) & ~1)

struct node {
	int data;
	struct node *next;
};

__device__ struct node *head;

__device__ struct node *createNode(int val) {
	struct node *newnode = (struct node *)malloc(sizeof(struct node));
	newnode->data = val;
	newnode->next = NULL;
	return newnode;
}

__global__ void listInit()
{
	head = createNode(-1);
	struct node *tail = createNode(-1);
	head->next=tail;
}

__device__ void addFront(struct node *newnode)
{
	newnode->next = head->next;
	head->next = newnode;
}

__global__ void addFront(int val)
{
	// need to modify
	struct node *newnode=createNode(val);
	addFront(newnode);
}

__global__ void addFront(int *arr, int N)
{
	for(int i=0;i<N;i++)
	{
		struct node *newnode=createNode(arr[i]);
		addFront(newnode);
	}
}

__device__ void nodePrint(struct node *ptr) {
	if (ptr->data==-1)
		if(ptr->next)
			printf("head ");
		else
			printf("tail\n");
	else
		printf("%d ", ptr->data);
}

__global__ void listPrint() {
	printf("listPrint\n");
	int nnodes = 0;
	for (struct node *ptr = head; ptr; ptr = (struct node *)GET_UNMARKED_REF(ptr->next), ++nnodes)
	{
		nodePrint(ptr);
	}
	printf("Number of nodes = %d\n", nnodes);
}

__global__ void listPrintLen() {
	int nnodes = 0;
	for (struct node *ptr = head; ptr; ptr = (struct node *)GET_UNMARKED_REF(ptr->next), ++nnodes)
	{
	}
	printf("Number of nodes = %d\n", nnodes);
}

__global__ void listPrintRaw() {
	// print with marked nodes
	printf("listPrintRaw\n");
	int nnodes = 0;
	for (struct node *ptr = head; ptr; ptr = (struct node *)GET_UNMARKED_REF(ptr->next))
	{	
		if(!IS_MARKED(ptr->next))
		{
			nodePrint(ptr);
			nnodes++;
		}
	}
	printf("Number of nodes = %d\n", nnodes);
}

__device__ void printVal(int val)
{
	printf("val: %d\n",val);
}

__global__ void printVal(int *arr, int N)
{
	for (int i=0;i<N;i++)
	{
		printVal(arr[i]);
	}
}

__device__ struct node *listSearch(int val)
{
#ifdef DEBUG
	printf("listSearch val: %d\n", val);
#endif
	struct node *cur=NULL, *p, *prev_next;
	struct node *prev;
	int cnt = 0;
	while(1)
	{
		// step1: traverse the list and find the node
		for(cur=head; cur->next; cur=(struct node *)GET_UNMARKED_REF(cur->next))
		{
			if(IS_MARKED(cur->next))  // p->next is marked means p is deleted logically
			{
#ifdef DEBUG
				printf("next is marked\n");
#endif
				continue;  // skip this node
			}
			if(cur->data == val)  // found
			{
				break;
			}
			prev=cur;

		}
#ifdef DEBUG
		if(cur->next==NULL)  // cur is the tail node
		{
			printf("listSearch %d not found, prev data: %d, prev->next data: %d\n", val, prev->data, prev->next->data);
		}
		else
			printf("listSearch val found, cur->data: %d, cur ref: %llu\n", cur->data, GET_UNMARKED_REF(cur));
#endif
		// no marked nodes between prev and cur
		if (prev->next == cur)
		{
			if (!cur->next)  // cur not found, cur is tail node
			{
#ifdef DEBUG
				printf("cur reaches the tail\n");
#endif
				break;  // then return cur
			}
			else
				if (!IS_MARKED(cur->next))  // if cur is marked as removed during the time, search again
					break;  // then return cur
		}
		
		// step2: remove marked nodes between prev and cur
		else
		{
#ifdef DEBUG
			printf("prev data: %d, prev->next data: %d, cur data: %d\n", prev->data, (prev->next)->data, cur->data);
#endif 
			// Step 2.1: If an insertions was made in the meantime between left and right, repeat search.
			int inserted = 0;
			for(p=(struct node *)GET_UNMARKED_REF(prev->next); p==cur; p=(struct node *)GET_UNMARKED_REF(p->next))
			{
				// loop from prev to cur, if there is any unmarked node, it is inserted meantime, need to search again
                if (!IS_MARKED(p->next))
					inserted = 1;
			}
			if (inserted==1)
				continue;  // search again
			
			// No unmarked nodes in between now
			// Step 2.2: Try to "remove" the marked nodes between left and right.
			prev_next = (struct node *)atomicCAS((unsigned long long *)&prev->next, GET_UNMARKED_REF(prev->next), (unsigned long long)cur);  
			// update prev->next to cur, delete marked nodes in between (no garbage collection yet)
            if(prev_next!=(struct node *)GET_UNMARKED_REF(prev->next))
			{
#ifdef DEBUG
				if(!prev_next) printf("prev_next NULL\n");
				else printf("prev_next->data: %d\n",prev_next->data);
				if(!prev->next) printf("prev->next NULL\n");
#endif
				// somone changed left->next, deletion failed, search again
				continue;
			}
        }
	}
	return cur;
}

__global__ void listSearchOne(int val, struct node **p)
{
	(*p) = listSearch(val);
}

__device__ void listTraverseDel()
{
	struct node *cur, *prev, *p, *prev_next;
	prev=head;
	cur=head->next;
	for(cur=head->next; cur->next; cur=(struct node*)GET_UNMARKED_REF(cur->next))
	{
		if(IS_MARKED(cur->next))  // p->next is marked means p is deleted logically
		{
			continue;  // skip this node
		}
		if(prev->next!=cur)  // stop here and do deletion
		{
#ifdef DEBUG
			printf("listTraversalDel delete: %d between prev: %d and cur: %d\n", prev->next->data, prev->data, cur->data);
#endif
			prev->next=cur;
		}
		prev=cur;
	}
}

__global__ void listTraverse()
{
	// delete marked nodes during traversal
	listTraverseDel();
}

__global__ void listInsert(int *ops, int *insertVals, int *insertPrevs, int N) {
	// insert ater a certain value
	unsigned idx = blockIdx.x * blockDim.x + threadIdx.x; 
	if (idx<N && ops[idx]==1)
	{
		struct node *myold, *actualold;
		struct node *prev = listSearch(insertPrevs[idx]);
		if (prev)
		{
#ifdef DEBUG
			printf("Insert Prev %d found %d\n", insertPrevs[idx], prev->data);
#endif
			struct node *newnode = createNode(insertVals[idx]);

			do {
				myold = prev->next;  // should reload every iteration
				newnode->next = myold;
				actualold = (struct node *)atomicCAS((unsigned long long *)&prev->next, (unsigned long long)myold, (unsigned long long)newnode);  
			} while (actualold != myold);
		}
#ifdef DEBUG
		else printf("Insert Prev %d not found\n", insertPrevs[idx]);
#endif
	}
}

__global__ void listRemove(int *ops, int *Vals, int N)
{
	unsigned idx = blockIdx.x * blockDim.x + threadIdx.x; 
	if (idx<N && ops[idx]==0)
	{
		int val = Vals[idx];
		struct node *prev, *cur, *succ, *actual_succ;
		prev = cur = succ = NULL;
		int cnt=0;

		while(1)
		{
			cur = listSearch(val);
			// cur = listSearch(val, &prev);
			if (cur==NULL || cur->data != val)
			{
#ifdef DEBUG
				printf("Remove node %d not found\n", val);
#endif
				break;
			}
			else
			{
#ifdef DEBUG
				printf("Remove node %d found %d\n", val, cur->data);
#endif
				succ = cur->next;
				if(!IS_MARKED(succ))
				{
					actual_succ = (struct node *)atomicCAS((unsigned long long *)&cur->next, (unsigned long long)succ, GET_MARKED_REF(succ));  // actual cur->next set as marked succ
					if(actual_succ==succ)
					{
#ifdef DEBUG
						printf("Remove found %d\n", val);
						printf("unmarked succ: %llu, marked succ: %llu, succ: %llu, actual succ: %llu, cur->next: %llu\n", GET_UNMARKED_REF(succ), GET_MARKED_REF(succ), (unsigned long long)succ, (unsigned long long)actual_succ, (unsigned long long)cur->next);
#endif
						break;
					}
				}
			}
		}

		// try to delete physically, envoke search(succ)
		// slows down too much, use listTraverseDel instead. good for demo.
/*
		struct node *actual_prev_next = (struct node*)atomicCAS((unsigned long long *)&prev->next, (unsigned long long)cur, GET_UNMARKED_REF(succ));
		if (actual_prev_next!=cur)
		{
#ifdef DEBUG
			printf("Physically delete in remove, call listSearch\n");
#endif
			// listSearch(succ->data, &cur);
		}
#ifdef DEBUG
		else printf("Physically delete in remove\n");
#endif
*/
	}
}

void Demo() {
	// init list
	printf("listInit\n");
	listInit<<<1,1>>>();
	addFront<<<1,1>>>(3);
	addFront<<<1,1>>>(2);
	addFront<<<1,1>>>(1);
	listPrint<<<1, 1>>>();
	cudaDeviceSynchronize();

	// generate insert operation data
	int in_ops_h[5] = {1,1,1,1,1};
	int *in_ops;
	cudaMalloc((void**)&in_ops, sizeof(int)*5);
	cudaMemcpy(in_ops, in_ops_h, sizeof(int)*5, cudaMemcpyHostToDevice);

	int *insert_h = (int *)malloc(sizeof(int)*5);
	insert_h[0]=50;
	insert_h[1]=60;
	insert_h[2]=70;
	insert_h[3]=80;
	insert_h[4]=90;
	int *insert_d;
	cudaMalloc((void **)&insert_d, sizeof(int)*5);
	cudaMemcpy(insert_d, insert_h, sizeof(int)*5, cudaMemcpyHostToDevice);

	int *prev_h = (int *)malloc(sizeof(int)*5);
	prev_h[0]=2;
	prev_h[1]=2;
	prev_h[2]=2;
	prev_h[3]=1;
	prev_h[4]=3;
	int *prev_d;
	cudaMalloc((void **)&prev_d, sizeof(int)*5); 
	cudaMemcpy(prev_d, prev_h, sizeof(int)*5, cudaMemcpyHostToDevice);
	
	// generate remove operation data
	int *rm_ops;
	cudaMalloc((void**)&rm_ops, sizeof(int)*3);
	cudaMemset(rm_ops, 0, sizeof(int)*3);

	int *rm_h = (int *)malloc(sizeof(int)*3);
	rm_h[0]=1;
	rm_h[1]=80;
	rm_h[2]=70;
	int *rm_d;
	cudaMalloc((void **)&rm_d, sizeof(int)*3); 
	cudaMemcpy(rm_d, rm_h, sizeof(int)*3, cudaMemcpyHostToDevice);
	
	// test insert
	printf("\nlistInsert\n");
	listInsert<<<4, 4>>>(in_ops, insert_d, prev_d, 5);
	cudaDeviceSynchronize();
	listPrint<<<1, 1>>>();
	cudaDeviceSynchronize();
	
	// test remove
	printf("\nlistRemove\n");
	listRemove<<<4, 4>>>(rm_ops, rm_d, 3);
	cudaDeviceSynchronize();  // necessary!
	listPrintRaw<<<1, 1>>>();
	cudaDeviceSynchronize();
	listPrint<<<1, 1>>>();
	cudaDeviceSynchronize();
	
	// traverse to delete the marked nodes
	printf("\nlistTraverse\n");
	listTraverse<<<1,1>>>();
	cudaDeviceSynchronize();
	listPrintRaw<<<1, 1>>>();
	cudaDeviceSynchronize();
	listPrint<<<1, 1>>>();
	cudaDeviceSynchronize();
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

void parallelOperate()
{
	struct timespec start, end;
	double time_taken;

	// read node file
	int *Nodes_h, N;
	readFileNodes(Nodes_h, N);
	// read operation file
	int *ops_h, *opNodes_h, *insertNodes_h, opN;
	readFileOps(ops_h, opNodes_h, insertNodes_h, opN);
	
	// move data to gpu
	int *Nodes, *ops, *opNodes, *insertNodes;
	cudaMalloc((void**)&Nodes, sizeof(int)*N);
	cudaMalloc((void**)&ops, sizeof(int)*opN);
	cudaMalloc((void**)&opNodes, sizeof(int)*opN);
	cudaMalloc((void**)&insertNodes, sizeof(int)*opN);
	cudaMemcpy(Nodes,Nodes_h,sizeof(int)*N,cudaMemcpyHostToDevice);
	cudaMemcpy(ops,ops_h,sizeof(int)*opN,cudaMemcpyHostToDevice);
	cudaMemcpy(opNodes,opNodes_h,sizeof(int)*opN,cudaMemcpyHostToDevice);
	cudaMemcpy(insertNodes,insertNodes_h,sizeof(int)*opN,cudaMemcpyHostToDevice);

	// init list
	listInit<<<1,1>>>();
	addFront<<<1,1>>>(Nodes, N);
	listPrintLen<<<1, 1>>>();
	cudaDeviceSynchronize();

	// parallel insert and remove operations
	int n_blocks = opN/1024+1;

	clock_gettime(CLOCK_REALTIME, &start);
	
	listInsert<<<n_blocks, 1024>>>(ops, insertNodes, opNodes, opN);
	listRemove<<<n_blocks, 1024>>>(ops, opNodes, opN);
	cudaDeviceSynchronize();
  	// traverse to physically delete the marked nodes (no garbage collection yet)
  	listTraverse<<<1,1>>>();
	cudaDeviceSynchronize();
	
	clock_gettime(CLOCK_REALTIME, &end);
  	time_taken = ( end.tv_sec - start.tv_sec ) * 1000000000.0 + ( end.tv_nsec - start.tv_nsec );
	
	listPrintLen<<<1, 1>>>();
	cudaDeviceSynchronize();

  	printf("Time taken = %lf nano sec\n", time_taken);
}

int main(int argc, char *argv[])
{
	if (argc==2)
	{
		Demo();
	}
	else
	{
		parallelOperate();
	}
	return 0;
}

/* Demo output

listInit
listPrint
head 1 2 3 tail
Number of nodes = 5

listInsert
listSearch val: 2
listSearch val: 2
listSearch val: 2
listSearch val: 1
listSearch val: 3
val found, cur->data: 2, cur ref: 140077894203920
val found, cur->data: 2, cur ref: 140077894203920
val found, cur->data: 2, cur ref: 140077894203920
val found, cur->data: 1, cur ref: 140077894204000
val found, cur->data: 3, cur ref: 140077894203840
listPrint
head 1 80 2 70 60 50 3 90 tail
Number of nodes = 10

listRemove
listSearch val: 1
listSearch val: 80
listSearch val: 70
val found, cur->data: 1, cur ref: 140077894204000
val found, cur->data: 80, cur ref: 140077894204400
val found, cur->data: 70, cur ref: 140077894204320
listPrintRaw
head 2 60 50 3 90 tail
Number of nodes = 7
listPrint
head 1 80 2 70 60 50 3 90 tail
Number of nodes = 10

listTraverse
prev: -1, cur: 2
prev: 2, cur: 60
listPrintRaw
head 2 60 50 3 90 tail
Number of nodes = 7
listPrint
head 2 60 50 3 90 tail
Number of nodes = 7

*/