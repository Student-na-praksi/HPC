// nvcc -Xcompiler -fopenmp -o mm-1 mm-1.cu
// srun --reservation=fri --partition=gpu --gpus=1 ./mm-1
// block multiplication algorithm -- warp assigment matches row-major matrix format 

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include "omp.h"
#include "cuda.h"
#include "helper_cuda.h"


#define SIZE 				2048
#define THREADS_PER_BLOCK	16


// gpu kernel
__global__ void matrixMultiply(float *A, float *B, float *C, int widthA, int heightA, int widthB, int heightB)						
{
 	// shared memory allocation
    __shared__ float s_A[THREADS_PER_BLOCK][THREADS_PER_BLOCK];
    __shared__ float s_B[THREADS_PER_BLOCK][THREADS_PER_BLOCK];

    // block index
    int bi = blockIdx.y;
    int bj = blockIdx.x;
 
    // thread index
    int ti = threadIdx.y;
    int tj = threadIdx.x;
 
    // first element in a row of matrix A
    int aBegin = widthA * (THREADS_PER_BLOCK * bi);
    // first element in a row + 1
    int aEnd   = aBegin + widthA;
	// step size (block) 
    int aStep  = THREADS_PER_BLOCK;
    // first element in a block of matrix B
    int bBegin = THREADS_PER_BLOCK * bj;
    // step to the first element in the next block of B
    int bStep  = THREADS_PER_BLOCK * widthB;
	// first element in a block of matrix C
    int cBegin = bStep * bi + aStep * bj;
  
    // initialize sum
	float sum = 0.0f;

    // go over all blocks of A and B
    for (int a = aBegin, b = bBegin; a < aEnd; a += aStep, b += bStep) 
    {
		// transfer data to the shared memory
        s_A[ti][tj] = A[a + widthA * ti + tj];
        s_B[ti][tj] = B[b + widthB * ti + tj];
 
		__syncthreads();
 
		// multiply blocks in the shared memory
        for (int k = 0; k < THREADS_PER_BLOCK; k++)
            sum += s_A[ti][k] * s_B[k][tj];
		
		__syncthreads();
    }

	// write the result to the global memory
    C[cBegin + widthB * ti + tj] = sum;
}


// cpu main routine
int main(int argc, char *argv[]) 
{
	int hA = SIZE;
	int wA = SIZE;
	int hB = wA;
	int wB = SIZE;

	// memory allocation
	float *h_A = (float *)malloc(hA*wA*sizeof(float));
    float *h_B = (float *)malloc(hB*wB*sizeof(float));
    float *h_C_cpu = (float *)malloc(hA*wB*sizeof(float));
    float *h_C_gpu = (float *)malloc(hA*wB*sizeof(float));

    // initialization of A and B
	srand((int)time(NULL));
	for(int i=0; i<hA; i++) 
		for(int j=0; j<wA; j++)
			h_A[i*wA+j] = rand()/(float)RAND_MAX;
	for(int i=0; i<hB; i++) 
		for(int j=0; j<wB; j++)
			h_B[i*wB+j] = rand()/(float)RAND_MAX;
	for(int i=0; i<hA; i++) 
		for(int j=0; j<wB; j++)
			h_C_cpu[i*wB+j] = 0.0;

	double d_dt = omp_get_wtime();

    // allocate memory @ device and transfer data from host
	float *d_A, *d_B, *d_C;
    checkCudaErrors(cudaMalloc((void **)&d_A, hA*wA * sizeof(float)));
    checkCudaErrors(cudaMalloc((void **)&d_B, hB*wB * sizeof(float)));
    checkCudaErrors(cudaMalloc((void **)&d_C, hA*wB * sizeof(float)));

    // data transfer to device
    checkCudaErrors(cudaMemcpy(d_A, h_A, hA*wA*sizeof(float), cudaMemcpyHostToDevice));
    checkCudaErrors(cudaMemcpy(d_B, h_B, hB*wB*sizeof(float), cudaMemcpyHostToDevice));

    // computation
	float d_dt_kernel;
    cudaEvent_t start, stop;
    checkCudaErrors(cudaEventCreate(&start));
    checkCudaErrors(cudaEventCreate(&stop));

	dim3 gridsize((hA-1)/THREADS_PER_BLOCK+1, (wB-1)/THREADS_PER_BLOCK+1);
	dim3 blocksize(THREADS_PER_BLOCK, THREADS_PER_BLOCK);

    checkCudaErrors(cudaEventRecord(start));
    matrixMultiply<<<gridsize, blocksize>>>(d_A, d_B, d_C, hA, wA, hB, wB);
    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaEventRecord(stop));
    checkCudaErrors(cudaEventSynchronize(stop));

    checkCudaErrors(cudaEventElapsedTime(&d_dt_kernel, start, stop));
    d_dt_kernel /= 1000;

    // data transfer from device
    checkCudaErrors(cudaMemcpy(h_C_gpu, d_C, hA*wB*sizeof(float), cudaMemcpyDeviceToHost));

	// release memory @ device
	checkCudaErrors(cudaFree(d_A));
	checkCudaErrors(cudaFree(d_B));
	checkCudaErrors(cudaFree(d_C));

	d_dt = omp_get_wtime() - d_dt;

    // results host
	double h_dt = omp_get_wtime();
    if (argc > 1)
        for(int i=0; i<hA; i++)
            for(int j=0; j<wB; j++)
                for(int k=0; k<wA; k++)
                    h_C_cpu[i*wB+j] += h_A[i*wA+k] * h_B[k*wB+j];
	h_dt = omp_get_wtime() - h_dt;

	printf("host: %lfs, device: %lfs (%lfs), speedup: %lf\n", h_dt, d_dt, d_dt_kernel, h_dt/d_dt);

	// check for correctness
	if(argc > 2)
		for(int i=0; i<hA; i++)
			for(int j=0; j<wB; j++)
				printf("C[%d,%d] = %f : %f\n", i, j, h_C_cpu[i*wB+j], h_C_gpu[i*wB+j]);
 
    // release memory @ host
	free(h_A);
	free(h_B);
	free(h_C_cpu);
	free(h_C_gpu);

    return 0;
}
