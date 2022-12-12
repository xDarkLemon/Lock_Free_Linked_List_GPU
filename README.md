## Introduction
This library is a CUDA implementation of lock-free linked list [Harris, T. (2001), A Pragmatic Implementation of Non-Blocking Linked Lists](https://www.cl.cam.ac.uk/research/srg/netos/papers/2001-caslists.pdf)

This library is the course project of GPUs: Architecture and Programming 2022 Fall at NYU.

## Performance

When number of list nodes = 30,000, the number of operations = 100,000, it reaches 141x speedup.

## APIs
Note: head is defined on device, inaccessible from the host. The APIs are global kernel functions.
```
__global__ void listInit()
```
Initialize a linked list, create a head node, with node->data equal to -1 and node->next pointing to tail, and a tail node, with node->data equal to -1 and node->next pointing to NULL.
```
__global__ void addFront(int val)
```
Create a node with the given value and add it after the head node.
```
__global__ void addFront(int *arr, int N)
```
Create a sequence of nodes and add the after head node sequentially.
```
__global__ void listPrint() 
```
Print the linked list from head to tail, and print the number of nodes.
```
__global__ void listPrintLen() 
```
Print the list length.
```
__global__ void listPrintRaw()
```
Print all nodes in the list, including those marked as deleted logically but not deleted physically yet.
```
__global__ void listSearchOne(int val, struct node **p)
```
It is a wrapper of  `__device__ struct node *listSearch(int val)`. Search the node with the given value and return.
```
__global__ void listTraverse()
```
It is a wrapper of `__device__ void listTraverseDel()`. Traverse the linked list and delete all the marked nodes physically (modify the pointers pointing to them). 
```
__global__ void listInsert(int *ops, int *insertVals, int *insertPrevs, int N)
```
Operate insertions in parallel.
```
__global__ void listRemove(int *ops, int *Vals, int N)
```
Operate deletions in parallel. Remove the nodes logically, marking them as deleted.

## Usage
Compile gpu version:
`nvcc -o gpull gpuLL.cu`

Run gpu version on test data:
`./gpull`

Run the gpu version demo:
`./gpull demo`

Compile cpu version:
`g++ -o cpull cpuLL.cpp`

Run cpu version on test data:
`./cpull`

Generate test data:
```
python3 gendata.py -n1 <number of list nodes> -n2 <number of operations>
```
Ensureing all nodes have different values as keys. The generated data will be saved to the directory `data/`. 

Data format:

`listnodes.txt`:  including initial linked list node values
```
5  // The number of nodes
5  // The node value
4
3
2
1
```

`operations.txt`: including operations to be conducted in parallel
```
3       // The number of operations
1 2 6   // <insert> <target node value> <insert value>
0 1     // <remove> <target node value>
1 3 8
```