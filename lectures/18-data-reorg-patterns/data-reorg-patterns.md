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

### ```MPI_Pack``` and ```MPI_Unpack```

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
    - first $r= (n\mod S)$ segments have one element more, $\left\lceil N/S\right\rceil$
    - other segments are of size $\lfloor 𝑁/S \rfloor$
    - index of the first element in segment $s$: $i_L = \lfloor N/S \rfloor s + \min(s, r)$
    - index of the last element in segment $s$: $i_H = \lfloor N/S \rfloor (s+1) + \min(s+1, r) - 1$
    - complex function to determine to which segment belongs element $i$:
    $s = \min⁡(\lfloor i / (\lfloor N/S \rfloor + 1) \rfloor, \lfloor (i-r) / \lfloor N/S \rfloor\rfloor)$
  - mixed approach
    - larger and smaller segments are mixed
    - index of first element in segment $s$: $i_L = \lfloor s N / S \rfloor$
    - index of last element in segment $s$: $i_H = \lfloor (s+1) N / S \rfloor - 1$
    - element $i$ belongs to segment $s = \left\lfloor (S(i+1)-1)/N \right\rfloor$
- segments in two dimensions
  - row-wise stripped
  - column-wise stripped
  - checkerboard
  - example: halo exchange
    - square matrix of size $N\times N$
    - exchange of edge elements between neighbouring segments
    - row stripped and column stripped: $2\times N$
    - checkerboard: $4\times \lceil N/\sqrt{S}\rceil$
- exchange of bordering elements
  - new cell value depends on the values of its neighbours
  - exchanging one element needed for next step od communication
  - exchanging $k$ elements
    - exchange is needed only on every $k$-th step
    - some additional computation
  - latency hiding
    - initialization of communication cost more than some additional data transfer and computation
  
## Array of Structures (AoS) vs Structures of Arrays (SoA)

- common data representation approach (AoS)
  - object-oriented programming
  - declare structures representing some object
    - vehicle has mass, position, velocity, acceleration, ...
  - create collection of that structure
    - vehicles can be presented as an array of data type vehicle
  - data is not aligned well for transfer, vectorization
  - nice for writing code, also beneficial when data is randomly read
- alternative approach (SoA)
  - for data transfer and vectorization, data layout may have to be modified for better performance
  - declare structure of collections
    - collection of masses, positions, velocities, accelerations, ...
  - data is now contiguous, better aligned
  - better way of representing data when majority of data is used
- conversion between AoS and SoA is not an easy task
  - significant changes in data structures
  - brakes data encapsulation
- data can be padded for alignment
  - improves data transfer, can be adjusted to cache line, simplifies vectorization
  - important for AoS
  - for SoA can be added, but is usually not really needed

## MPI: Derived Data Types

- any data layout can be described with them
- derived from basic MPI data types
  - for passing data organized as AoS
- allow for efficient transfer of non-contiguous and heterogeneous data
  - example: halo exchange
  - during communication MPI data type tells MPI system where to get the data and where to put it
- both solutions help user to avoid hand-coding
- libraries should have efficient implementations
  - more general data types are slower
  - no need for ```MPI_Pack``` and ```MPI_Unpack```
  - overhead is reduced as only one long message is sent

### Derived Data type

- an object used to describe a data layout in memory by
  - a sequence of basic data types
  - a sequence of displacements
- constructed and destroyed during runtime
- structure
  - ```Typemap```: pairs of basic MPI data types and displacements
    - ```{(type 0, displacement 0), ..., (type N-1, displacement N-1)}```
    - example: ```{(int, 0}, (double, 8), (char, 16)}```
- data type routines
  - construction
    - ```MPI_Type_contiguous```: contiguous data type
    - ```MPI_Type_vector```: regularly spaced data type
    - ```MPI_Type_indexed```: variably spaced data type
    - ```MPI_Type_create_subarray```: describes subarray of an array
    - ```MPI_Type_create_struct```: general data type
  - commit
    - ```MPI_Type_commit```: must be called before new data type can be used
  - free
    - ```MPI_Type_free```: marks a data type for deallocation

- ```MPI_Type_contiguous```

  - output data type is obtained by concatenating defined number of copies of input data type
  - constructs a ```typemap``` for output data type consisting of replications of input data type

- ```MPI_Type_contiguous```

  - example: matrix row as a data type

- ```MPI_Type_vector```

  - similar to ```MPI_Type_continuous``` but with self-defined stride
  - input
    - number of blocks
    - number of elements of input data type in each block
    - stride - number of elements between beginnings of neighbouring blocks
    - example: matrix column as a data type

- ```MPI_Type_indexed```
  
  - generalization of MPI_Type_vector
    - number of blocks
    - for each block we specify number of elements and stride

- ```MPI_Type_create_subarray```

  - creates a data type which is a subarray of an array
  - useful for column-wise distribution of data

- ```MPI_Type_create_struct```

  - ```Typemap```
    - pairs of basic data types and displacements
  - extent
    - span from the lower to the upper bound
    - inner holes are counted, holes at the end are not!
    - important for alignment of data types to data, not for construction and memory allocation
    - query: ```MPI_Type_get_extent```
  - size
  - number of bytes that has to be transferred
  - holes are not counted
  - query: ```MPI_Type_size```
  - Example
    - to get displacements
    - ```MPI_Type_get_extent```
    - ```MPI_Get_address```
  
- ```MPI_Type_create_resized```

  - output data type is identical to the input data type but lower bound and extent are changed
  - useful to correct stride for communication
    - example: zip
  - when size of MPI data type and system data type are not equal, the MPI data type can be corrected for portability
  
    <img src="figures/bcast.png" alt="MPI collectives: broadcast" width="50%">
    - [conway.c](files/conway/conway.c)
