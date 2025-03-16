#include <stdbool.h>
#include <stdio.h>
#include <math.h>
#include "Verify.h"

bool verify_matrix_product(float *A, float *B, float *C, int rowsA, int colsA, int colsB) {
    // Loop through rows of A and columns of B
    for (int i = 0; i < rowsA; i++) {
        for (int j = 0; j < colsB; j++) {
            float sum = 0.0;
            // Calculate dot product of A's row and B's column
            for (int k = 0; k < colsA; k++) {
                sum += A[i * colsA + k] * B[k * colsB + j];
            }
            // Check against the provided C matrix
            if (sum != C[i * colsB + j]) {
                printf("Mismatch at C[%d][%d]: Expected %.2f, Found %.2f\n", i, j, sum, C[i * colsB + j]);
                return false; // Return false if any element does not match
            }
        }
    }
    return true; // Return true if all elements match
}

bool verify_matrix_product_16bits(float *A, float *B, float *C, int rowsA, int colsA, int colsB) {
    // Define a tolerance for floating-point comparison
    float tolerance = 1;

    // Loop through rows of A and columns of B
    for (int i = 0; i < rowsA; i++) {
        for (int j = 0; j < colsB; j++) {
            float sum = 0.0;
            // Calculate dot product of A's row and B's column
            for (int k = 0; k < colsA; k++) {
                sum += A[i * colsA + k] * B[k * colsB + j];
            }
            // Check if the absolute difference between sum and C[i * colsB + j] is within the tolerance
            if (fabs(sum - C[i * colsB + j]) > tolerance) {
                printf("Mismatch at C[%d][%d]: Expected %.6f, Found %.6f\n", i, j, sum, C[i * colsB + j]);
                return false; // Return false if any element does not match within the tolerance
            }
        }
    }
    return true; // Return true if all elements match within the tolerance
}
