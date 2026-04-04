// Poisson equation solver using finite difference method on CPU
//      d2T/dx2 + d2T/dy2 = 0
//      T(0,y) = T(N-1,y) = T(x,0) = 100; T(x,N-1) = 0
// compile and run:
//      nvcc -o heat0 heat0.cu
//      srun --reservation=fri --partition=gpu --gpus=1 ./heat0 64

#include <stdio.h>
#include "cuda.h"
#include "helper_cuda.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#define MAXITERS	1000000
#define BLOCK_SIZE	32

void heatStep(float* surfaceOut, float* surfaceIn, int width, int height) {

    for(int y = 1; y < height-1; y++) {
        for(int x = 1; x < width-1; x++) {
            surfaceOut[y * width + x] = 0.25 * (
                surfaceIn[y * width + (x - 1)] + surfaceIn[y * width + (x + 1)] +
                surfaceIn[(y - 1) * width + x] + surfaceIn[(y + 1) * width + x]
            );
        }
    }
}
 
int main(int argc, char *argv[]) {
	
	int N = atoi(argv[1]);

	// init surface
	float* h_surface = (float*)malloc(N * N * sizeof(float));
	for(int i = 0; i < N * N; i++)
		h_surface[i] = 0.0;
	for(int i = 0; i < N; i++) {
		h_surface[i * N] = 100.0;
		h_surface[i * N + N - 1] = 100.0;
		h_surface[i] = 100.0;
	}

	// timing 
    cudaEvent_t start, stop;
    checkCudaErrors(cudaEventCreate(&start));
    checkCudaErrors(cudaEventCreate(&stop));

    checkCudaErrors(cudaEventRecord(start));

    float* h_surfaceNew = (float*)malloc(N * N * sizeof(float));
	for(int i = 0; i < N; i++) {
		h_surfaceNew[i * N] = h_surface[i * N];
		h_surfaceNew[i * N + N - 1] = h_surface[i * N + N - 1];
		h_surfaceNew[i] = h_surface[i];
	}

    for(int i = 0; i < MAXITERS; i++) {
        heatStep(h_surfaceNew, h_surface, N, N);
        float *temp = h_surface;
        h_surface = h_surfaceNew;
        h_surfaceNew = temp;
    }

    unsigned char* img = (unsigned char*)malloc(N * N * sizeof(unsigned char));
    for(int i = 0; i < N * N; i++)
        img[i] = 255 - (unsigned char)(h_surface[i] * 255.0 / 100.0);
   	stbi_write_png("heat0.png", N, N, 1, img, N);
    free(img);

    free(h_surfaceNew);

    checkCudaErrors(cudaEventRecord(stop));
    checkCudaErrors(cudaEventSynchronize(stop));

   	free(h_surface);

    float time;
    checkCudaErrors(cudaEventElapsedTime(&time, start, stop));
	printf("Time: host = %f s\n", time/1000.0);

	return 0;
}
