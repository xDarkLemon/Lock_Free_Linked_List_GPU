#include <stdio.h>
#include <cuda.h>

// compile with nvcc -o ll gpuLL.cu

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
		// printf("ptr: %llu, ",GET_UNMARKED_REF(ptr));
		nodePrint(ptr);
	}
	printf("Number of nodes = %d\n", nnodes);
}

__global__ void listPrintRaw() {
	// print with marked nodes
	printf("listPrintRaw\n");
	int nnodes = 0;
	for (struct node *ptr = head; ptr; ptr = (struct node *)GET_UNMARKED_REF(ptr->next))
	{	
		// printf("ptr: %llu, ",GET_UNMARKED_REF(ptr));
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

__device__ struct node *searchNode(int val)
{
	struct node *cur;
	for (struct node *ptr = head; ptr->next; ptr = (struct node *)GET_UNMARKED_REF(ptr->next))
	{
		cur = (struct node *)GET_UNMARKED_REF(ptr->next);
		if (cur->data == val)
		{
			return cur;
		}
	}
	return NULL;
}

__device__ struct node *listSearch(int val)
{
	printf("listSearch val: %d\n", val);
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
				// printf("next is marked\n");
				continue;  // skip this node
			}
			if(cur->data == val)  // found
			{
				// cur = p;
				// printf("cur data %d found\n", cur->data);
				break;
			}
			prev=cur;

		}
		if(cur->next==NULL)  // cur is the tail node
		{
			printf("%d not found\n", val);
			printf("prev data: %d, prev->next data: %d\n", prev->data, prev->next->data);
			// break;  // now break, future point cur to tail node
		}
		else
			printf("val found, cur->data: %d, cur ref: %llu\n", cur->data, GET_UNMARKED_REF(cur));
		// breaks;

		// no marked nodes between prev and cur
		if (prev->next == cur)
		{
			if (!cur->next)  // cur not found, cur is tail node
			{
				printf("cur reaches the tail\n");
				break;  // then return cur
			}
			else
				if (!IS_MARKED(cur->next))  // if cur is marked as removed during the time, search again
					break;  // then return cur
		}
		
		// step2: remove marked nodes between prev and cur
		else
		{
			// printf("prev data: %d, prev->next data: %d, cur data: %d\n", prev->data, (prev->next)->data, cur->data);
            
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
				if(!prev_next) printf("prev_next NULL\n");
				else printf("prev_next->data: %d\n",prev_next->data);
				if(!prev->next) printf("prev->next NULL\n");
				// somone changed left->next, deletion failed, search again
				continue;
			}
        }
	}
	return cur;
}

__global__ void listSearchOne(int val)
{
	listSearch(val);
	// printf("\nFind node %d\nunmarked addr: %llu, marked addr: %llu, data: %d\n", val, GET_UNMARKED_REF(p), GET_MARKED_REF(p), ((struct node *)GET_UNMARKED_REF(p))->data);
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
			printf("prev: %d, cur: %d\n", prev->data, cur->data);
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

__global__ void listInsert(int *insertVals, int *insertPrevs, int N) {
	// insert ater a certain value
	unsigned idx = blockIdx.x * blockDim.x + threadIdx.x; 
	if (idx<N)
	{
		struct node *myold, *actualold;
		struct node *prev = listSearch(insertPrevs[idx]);
		// struct node *prev = searchNode(insertPrevs[idx]);
		if (prev)
		{
			struct node *newnode = createNode(insertVals[idx]);

			do {
				myold = prev->next;  // should reload every iteration
				newnode->next = myold;
				actualold = (struct node *)atomicCAS((unsigned long long *)&prev->next, (unsigned long long)myold, (unsigned long long)newnode);  
			} while (actualold != myold);
		}
		else
			printf("Prev %d not found\n", insertPrevs[idx]);
	}
}

__global__ void listRemove(int *Vals, int N)
{
	unsigned idx = blockIdx.x * blockDim.x + threadIdx.x; 
	if (idx<N)
	{
		int val = Vals[idx];
		// printf("thread idx: %d, remove val: %d\n", idx, val);
		struct node *prev, *cur, *succ, *actual_succ;
		prev = cur = succ = NULL;
		int cnt=0;

		while(1)
		{
			// printf("cnt: %d\n", cnt++);
			cur = listSearch(val);
			// cur = listSearch(val, &prev);  // question: why prev is not used later?
			// cur = searchNode(val);
			// cur = searchNode(val, &prev);
			// printf("cur ptr: %llu\n", (unsigned long long) cur);
			if (cur==NULL || cur->data != val)
			{
				// printf("Remove node %d not found\n", val);
				break;
			}
			else
			{
				succ = cur->next;
				if(!IS_MARKED(succ))
				{
					actual_succ = (struct node *)atomicCAS((unsigned long long *)&cur->next, (unsigned long long)succ, GET_MARKED_REF(succ));  // actual cur->next set as marked succ
					if(actual_succ==succ)
					{
/*
						printf("Remove found %d\n", val);
						printf("unmarked succ: %llu, marked succ: %llu, succ: %llu, actual succ: %llu, cur->next: %llu\n", GET_UNMARKED_REF(succ), GET_MARKED_REF(succ), (unsigned long long)succ, (unsigned long long)actual_succ, (unsigned long long)cur->next);
						for (struct node *ptr = head; ptr; ptr = (struct node *)GET_UNMARKED_REF(ptr->next))
						{
							if (!ptr->data)
								printf("head ");
							else
							{
								if(!IS_MARKED(ptr->next))
									printf("%d ", ptr->data);
							}
						}
						printf("\n");
*/
						break;
					}
				}
			}
		}
		// listPrintRawDev();
	}
}

void Demo() {
	printf("listInit\n");
	listInit<<<1,1>>>();
	addFront<<<1,1>>>(3);
	addFront<<<1,1>>>(2);
	addFront<<<1,1>>>(1);
	listPrint<<<1, 1>>>();
	cudaDeviceSynchronize();

	int *insert_h = (int *)malloc(sizeof(int)*5);
	insert_h[0]=50;
	insert_h[1]=60;
	insert_h[2]=70;
	insert_h[3]=80;
	insert_h[4]=90;
	int *insert_d;
	cudaMalloc((void **)&insert_d, sizeof(int)*5);
	cudaMemcpy(insert_d, insert_h, sizeof(int)*5, cudaMemcpyHostToDevice);
	// printf("Insert vals\n");
	// printVal<<<1,1>>>(insert_d, 5);
	// cudaDeviceSynchronize();

	int *prev_h = (int *)malloc(sizeof(int)*5);
	prev_h[0]=2;
	prev_h[1]=2;
	prev_h[2]=2;
	prev_h[3]=1;
	prev_h[4]=3;
	int *prev_d;
	cudaMalloc((void **)&prev_d, sizeof(int)*5); 
	cudaMemcpy(prev_d, prev_h, sizeof(int)*5, cudaMemcpyHostToDevice);
	// printf("Insert prevs\n");
	// printVal<<<1,1>>>(prev_d, 5);
	// cudaDeviceSynchronize();

	int *rm_h = (int *)malloc(sizeof(int)*3);
	rm_h[0]=1;
	rm_h[1]=80;
	rm_h[2]=70;
	int *rm_d;
	cudaMalloc((void **)&rm_d, sizeof(int)*3); 
	cudaMemcpy(rm_d, rm_h, sizeof(int)*3, cudaMemcpyHostToDevice);
	// printf("Remove vals\n");
	// printVal<<<1,1>>>(rm_d, 3);
	// cudaDeviceSynchronize();
	
	printf("\nlistInsert\n");
	listInsert<<<4, 4>>>(insert_d, prev_d, 5);
	cudaDeviceSynchronize();
	listPrint<<<1, 1>>>();
	cudaDeviceSynchronize();
	
	printf("\nlistRemove\n");
	listRemove<<<1, 4>>>(rm_d, 3);
	cudaDeviceSynchronize();  // necessary!
	listPrintRaw<<<1, 1>>>();
	cudaDeviceSynchronize();  // necessary!	
	listPrint<<<1, 1>>>();
	cudaDeviceSynchronize();  // necessary!
	
	printf("\nlistTraverse\n");
	// listSearchOne<<<1,1>>>(80);
	listTraverse<<<1,1>>>();
	cudaDeviceSynchronize();  // necessary!
	listPrintRaw<<<1, 1>>>();
	cudaDeviceSynchronize();  // necessary!	
	listPrint<<<1, 1>>>();
	cudaDeviceSynchronize();  // necessary!
}

void parallelOperate(const int *Nodes, const int N, const int *ops, const int *opNodes, const int *insertNodes, const int opN) 
{
}

int main()
{
	Demo();
	return 0;
}