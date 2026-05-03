# Data Reorganization Patterns

- data transfer is many times a bottleneck
- for data-intensive applications primary design focus should be on data movement, adding computation later
- shared-memory systems add additional cost
  - for efficient vectorization it is important to properly declare structures
  - effect of cache size on scalability (avoid false sharing)

## Gather

- gather collects all data from a collection of location indices and source arrays and places them into an output collection
- combination of a random read and map
- output data has
  - the same number of elements as the number of indices in input collections
  - the same dimensionality as location index collection
- ```MPI_Gather```
  - less general
  - a lot can be gained with derived MPI data types

### Shift / Rotate

- special gathers
- have regular data access pattern
- can be efficiently implemented using vector instructions
- in multi-dimensions shift/rotate offsets may differ
- leads to coalesced data access
- efficient implementations using vector operations
- boundary elements handling

### Zip / Unzip

- zip interleaves data
- example: assemble complex data by interleaving real and imaginary parts
- convert from structure of arrays to array of structures
- unzip reverses zip operation

## Scatter

- a collection of input data is written to specified write locations
- multiple writes to the same location are possible
- resolutions
  - permutation scatter
    - collisions are illegal, array of indices should not have duplicates
    - can be always turned into gather when addresses are known in advance
    - example: matrix transpose
    - ```MPI_Scatter```
  - merge scatter
    - combines values
    - only works with associative and commutative operators
    - example: histogram computation
  - atomic scatter
    - atomic writes, non-deterministic
    - can be deterministic when written input elements gave the same value
    - example: parallel disjunction (output array is initially cleared, writing true is actually OR operation)
  - priority scatter (deterministic using priorities)
    - priority based on a position of an element in input array
    - higher priority for elements at the end of the array is consistent with serial code

## Gather vs Scatter

- scatter is more expensive
- gather reads versus scatter reads & writes (whole cache line); scatter on shared memory systems requires cores synchronization to keep cache coherent, false sharing may occur
- if addresses are known in advance, scatter can be converted to gather
- one option is also to scatter the addresses first and later gather data
- conversion takes resources
  - makes sense when it is used repeatedly
- suitable for shared-memory systems
- ```MPI_Gather``` and ```MPI_Scatter```
  - optimized, not so general
  - no need for conversion

## Pack and Unpack

- eliminates unused elements from collection
- output is contiguous in memory, which leads to better memory access and vectorization
- pack is combination of scan with conditional scatter
- pack can be fused with map
- useful when small number of elements is discarded

### Split

- generalization
- separate elements to two or more sets

### Expand

- in combination with map
- when map can produce arbitrary number of elements

### ```MPI_Pack``` and ```MPI_Unpack````

- packs a datatype into a contiguous memory
- useful for combining data of different data types to reduce number of sends
- ```MPI_Pack_size``` gives size of data in bytes; used to dynamically allocate size of pack structure
- copies data to new location (better to use data types)

## Geometric Decomposition

- common parallelization strategy
  - divide computational domain to sections
  - work on sections individually
  - combine the results
  - divide-and-conquer
- geometric decomposition
  - spatially regular structure
  - image, grid, also sorting and graphs

### Partition

- non-overlapping sections to avoid write conflicts and race conditions
- partitions are of equal size
- 1D or multi dimensions
- combined with map – no problems as it has exclusive access to partition
- can be further split to allow for nested (hierarchical) parallelism
- boundary elements require special treatment
  - partial sections along the edges, special code, but can be commonly parallelized/vectorized
- cache line size, vector-unit size
  - related to stencil strip-based operations

### Segment

- like partition, but sections vary in size
- more complex functions for data manipulation must be used
- ```MPI_Scatterv``` instead of ```MPI_Scatter```, ...
- segmentation along each dimension is possible (kD-tree)
- distributing $N$ elements to $S$ segments
  - larger-first approach
    - first $r=n \mod S$ segments have one element more, $\left\ceil N/S\right\ceil$ 
    - other segments are of size $\lfloor 𝑁/S \rfloor
    - index of the first element in segment $s$: $i_L = \lfloor N/S \rfloor s + \min(s, r)$
    - index of the last element in segment $s$: $i_H = \lfloor N/S \rfloor (s+1) + \min(s+1, r) - 1$
    - complex function to determine to which segment belongs element $i$: $s = \min⁡(\lfloor i / (\lfloor N/S \rfloor + 1)\rfloor, \lfloor (i-r) / \lfloor N/S\rfloor \rfloor $

## xxx

- processes in communicator
  - ```MPI_COMM_WORLD``` is default
  - can create own subsets
  - MPI-2+ can create even bigger sets if dynamic process allocation is supported
- programs using only collective communication are easy to understand
  - every process does roughly the same thing
  - no inventive communication patterns
- functions for collective communication are optimized
  - devised by experts
  - detailed implementation depends on infrastructure
    - existing protocols in network infrastructure (broadcast)
- all collective functions must be called by all processes in the communicator
- functions work with any number of processes from 1 onwards
- all collective functions are blocking (MPI-1, MPI-2)
- there are no tags
- basic data types (MPI-1, MPI-2)
- types of collectives
  - synchronization
  - data transfer
  - collective computation
  
## Synchronization

- ```MPI_Barrier```
  - rarely used
  - for performance measurements

## Data Transfer

- ```MPI_Bcast```
  - one to all (broadcast)

    <img src="figures/bcast.png" alt="MPI collectives: broadcast" width="50%">

- ```MPI_Scatter```and ```MPI_Gather```
  - scatters or gathers data across processes in the same communicator

    <img src="figures/scatter-gather.png" alt="MPI collectives: scatter and gather" width="50%">

  - expect all data chunks to be of the same size
  - root process takes care of one data chunk
  - some parameters are valid on side of sender, some on side of receiver
  - tree-like implementation of gather

    <img src="figures/gather-by-tree.png" alt="MPI collectives: scatter and gather" width="70%">

- ```MPI_Scatterv``` and ```MPI_Scatterv```
  - more general but slower functions
  - size of data chunk can vary

- ```MPI_Allgather```
  - combines gather and broadcast
  - can be efficiently implemented by only one pass of the tree

    <img src="figures/allgather.png" alt="MPI collectives: gather on all" width="50%">

- ```MPI_Alltoall```
  - transpose of data
  - tricky to implement efficiently
  
    <img src="figures/alltoall.png" alt="MPI collectives: all to all" width="50%">

- example: The Conway's Game of Life
  - the board is split to horizontal stripes
  - cells on borders are exchanged via ```MPI_Sendrecv```
  - code:
    - [conway.c](files/conway/conway.c)
    - [board.h](files/conway/board.h)
    - [conway.sh](files/conway/conway.sh)

## Collective computation

- ```MPI_Reduce```
  - reduces data from several processes
  - reduce operations
    - extreme: ```MPI_MIN```, ```MPI_MAX```
    - sum and product: ```MPI_SUM```, ```MPI_PROD```
    - logical operations: ```MPI_LAND```, ```MPI_LOR```, ```MPI_LXOR```
    - bit-wise operations: ```MPI_BAND```, ```MPI_BOR```, ```MPI_BXOR```
    - extreme with location: ```MPI_MAXLOC```, ```MPI_MINLOC```

    <img src="figures/reduce.png" alt="MPI collectives: reduce" width="45%">

- ```MPI_Scan``` and ```MPI_Exscan```
  - inclusive and exclusive scan

    <img src="figures/scan.png" alt="MPI collectives: scans" width="45%">

- ```MPI_Allreduce```
  - combination of reduce and broadcast

    <img src="figures/allreduce.png" alt="MPI collectives: all reduce" width="45%">

  - can be implemented with one pass of a tree

    <img src="figures/allreduce-by-tree.png" alt="MPI collectives: all reduce in one pass" width="85%">

- determinism
  - rounding error, truncation, depends on order of computation
  - MPI does not guarantee the same result on the same input
    - encouraged but not required
    - not all applications need it
    - more efficient implementations of collectives are possible without it

- example: reduce with location information
  - combined data type
  - code:
    - [maxloc.c](files/maxloc/maxloc.c)
    - [maxloc.sh](files/maxloc/maxloc.sh)

## Advanced MPI Features

- data types
- communicators
- virtual topology
  - reflects actual system configuration
  - Cartesian, graph
- MPI-IO
- collective functions
  - neighborhood
  - immediate
