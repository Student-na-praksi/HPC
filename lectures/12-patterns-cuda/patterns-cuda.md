# Patterns with CUDA Programming

## Stencil

- Special case of map
  - 1D or multiple dimensions
- Has regular data access pattern
  - Each output depends on a neighborhood of inputs
  - Inputs have fixed offsets relative to the output
  - Can be implemented as
    - Set of random reads for each output
    - Shifts
- Applications
  - Image and signal processing (convolution)
  - Physics, mechanical engineering, CFD (PDE solvers over regular grids)
  - Cellular automata
- Different neighborhoods
  - Square compact, ..., sparse
  - Cache optimizations
  - Stencils reuse samples required for neighboring elements
- Boundaries of grids given to a processor
  - Exchange data with other processors
  - Additional communication costs

### Implementation with Shift Operation

- Beneficial for 1D stencils
- Allow vectorization of data reads
- Does not reduce memory traffic


### Implementation with tiles

- Multidimensional stencils
- Strip-mining (optimized for cache)
- Example
  - Two-dimensional array organized in row-by-row fashion
  - Horizontal data in the same cache line, vertical far away
  - Horizontal split
    - Whole line does not fit cache, a lot of cache misses when accessing adjacent rows
  - Vertical split
    - Processors redundantly read the same cache line
  - Strips (vertical)
    - Each processor gets its strip of width equal to a multiple of cache line size
    - Processing goes sequentially from top to bottom to maximize cache reuse
    - Multiple of cache line size prevents false sharing between adjacent strips on output

### Communication

- Commonly the output of stencil is used as the input for the next iteration
  - Double buffering
  - Pointers to buffers are interchanged between iterations
- Need for synchronization
- Boundary regions (halo) of the grid may need explicit communication with neighboring processors
  - Halo can be exchanged each iteration
  - Data exchange can take place on each k-th iteration when halo is increased, and some redundant computation takes place on each processor
  - Latency hiding (update of internal grid cells when waiting for halo exchange)

### Example: Heat distribution

- Square surface, three edges touch boiling water, one edge is put in ice
- How is the heat distributed inside the surface?
- Laplace equation

  $$ \partial^2 T(x,y)\over \partial x^2 $$
  $$ \frac{\partial f}{\partial x} $$

## Reduce

## Scan


- a CUDA kernel represents code that runs on a GPU
- the kernel is written as a sequential program
- the programming interface handles the compilation and transfer of the kernel to the device
- the kernel executes individually on its own data for each thread

## Hierarchical Organization of Threads

- a grid of threads
  - all threads in the grid execute the same kernel
  - threads in the grid share global memory on the GPU
  - the grid consists of thread blocks

- a thread block
  - all threads in a block are executed on the same compute unit
  - they can exchange and synchronize through local (shared) memory

- a thread warp
  - group of consecutive threads that follows SIMT (single instruction multiple threads principle)
  - 32 threads at Nvidia GPUs and 64 at AMD GPUs
  
- a thread
  - executes the kernel sequentially on its own data
  - uses its private memory
  - shares the local memory with other threads in the block
  - can access global memory and constant memory

## Thread Indexing

- 1D, 2D, or 3D indexing
- threads are grouped in thread warps first by dimension x, then y, and finally z
- the number of dimensions is chosen based on the nature of the problem
- CUDA C supports a set of variables reflecting thread organization:
  - ```threadIdx.x```, ```threadIdx.y```, ```threadIdx.z```
  - ```blockIdx.x```, ```blockIdx.y```, ```blockIdx.z```
  - ```blockDim.x```, ```blockDim.y```, ```blockDim.z```
  - ```gridDim.x```, ```gridDim.y```, ```gridDim.z```
- thread indexing
  
  <img src="figures/thread-indexing.png" alt="Thread inexing" width="70%" />

## GPU Kernel

- a GPU kernel is code that is started from the host but runs on the device
- the kernel is written as a function, prefixed by the keyword ```__global__```
- the kernel does not return a value
- a kernel example:

  ```C
  __global__ void greetings(void) {
    printf("Hello from thread %d.%d!\n", blockIdx.x, threadIdx.x);
  }
  ```

- the kernel is launched on the host, where triple angle brackets are inserted between the name and arguments
- thread organization in the grid - the number of blocks and the number of threads in each dimension - is specified within the triple angle brackets
- for describing multidimensional thread organization, the CUDA C language provides the ```dim3``` structure:

  ```C
  dim3 gridSize(numBlocks, 1, 1);
  dim3 blockSize(numThreads, 1, 1);
  greetings<<<gridSize, blockSize>>>();
  ```

- a kernel can also call other device functions marked with the ```__device__``` keyword
- to emphasize that a function runs only on the host, it is marked with ```__host__```

## The first GPU program

- [hello-gpu.cu](files/hello-gpu.cu)
- load the module: ```module load CUDA```
- compile the code with the CUDA C compiler: ```nvcc -o hello-gpu hello-gpu.cu```
- run the program: ```srun --partition=gpu --gpus=1 ./hello-gpu 2 4```


## Memory Allocation and Data Transfer

- the host has access only to the global memory of the device

### Explicit Data Transfer

- on the host, memory is allocated using the ```malloc``` function
- global memory on the device is allocated using the function call:

  ```C
  cudaError_t cudaMalloc(void** dPtr, size_t count)
  ````

- this function allocates ```count``` bytes and returns the address in the device's global memory to the pointer ```dPtr```
- to transfer data between the device’s global memory and the host memory, we use the function:

  ```C
  cudaError_t cudaMemcpy(void* dst, const void* src, size_t count, cudaMemcpyKind kind)
  ```

- this function copies ```count``` bytes from the address ```src``` to the address ```dst``` in the direction specified by kind, which is
  - for transferring data from host to device ```cudaMemcpyHostToDevice```, and
  - for transferring data from device to host ```cudaMemcpyDeviceToHost```
- the function is blocking - the program execution continues only after the data transfer is complete

- device memory is freed with the function call:

  ```C
  cudaError_t cudaFree(void *devPtr)
  ```

- memory on the host is freed using function ```free```

### Unified Memory

- newer versions of CUDA support unified memory
- CUDA performs data transfers as needed
- a programmer has no control, and it is often less efficient than explicit transfers
- the unified memory is allocated using the function call:

  ```C
  cudaError_t cudaMallocManaged(void **hdPtr, size_t count);
  ```

- the unified memory is freed using the function call:

  ```C
  cudaError_t cudaFree(void *hdPtr)
  ```

- in our examples we will not work with the unified memory

## Example: SAXPY

- Single precision A times X Plus Y
- vectors **x** and **y**
- element-wise operation ```y[i] = a * x[i] + y[i]```
- the map pattern
- solutions
  - [saxpy0.cu](files/saxpy0.cu): support for one thread block
  - [saxpy1.cu](files/saxpy1.cu): added support for multiple thread blocks, the number of blocks is calculated based on the problem size
  - [saxpy2.cu](files/saxpy2.cu): improved code, threads with global index out of the vector (array) bounds don't do any work
  - [saxpy3.cu](files/saxpy3.cu): in case when total number of threads is smaller than the problem size, some threads do additional work
  - [saxpy4.cu](files/saxpy4.cu): unified memory
