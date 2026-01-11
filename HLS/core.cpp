#include "core.hpp"

#define U 128

template<int UNROLL_FACTOR>
static acc_t dot_kernel(const vec_t C[N], const vec_t D[N]) {

    acc_t lane_acc[UNROLL_FACTOR];
#pragma HLS ARRAY_PARTITION variable=lane_acc complete dim=1

    for (int k = 0; k < UNROLL_FACTOR; k++) {
#pragma HLS UNROLL
        lane_acc[k] = 0;
    }

    for (int i = 0; i < N; i += UNROLL_FACTOR) {
#pragma HLS PIPELINE II=1
        for (int k = 0; k < UNROLL_FACTOR; k++) {
#pragma HLS UNROLL
            acc_t a = (acc_t)C[i + k];
            acc_t b = (acc_t)D[i + k];
            acc_t prod = a * b;
#pragma HLS BIND_OP variable=prod op=mul impl=dsp
            lane_acc[k] += prod;
        }
    }

    acc_t sum = 0;
    for (int k = 0; k < UNROLL_FACTOR; k++) {
#pragma HLS UNROLL
        sum += lane_acc[k];
    }
    return sum;
}

template<int UNROLL_FACTOR>
static out_t euc_kernel(const vec_t A[N], const vec_t B[N]) {
    acc_t lane_acc[UNROLL_FACTOR];
#pragma HLS ARRAY_PARTITION variable=lane_acc complete dim=1

    for (int k = 0; k < UNROLL_FACTOR; k++) {
#pragma HLS UNROLL
        lane_acc[k] = 0;
    }

    for (int i = 0; i < N; i += UNROLL_FACTOR) {
#pragma HLS PIPELINE II=1
        for (int k = 0; k < UNROLL_FACTOR; k++) {
#pragma HLS UNROLL
            acc_t d = (acc_t)A[i + k] - (acc_t)B[i + k]; 
            acc_t sq = d * d;
#pragma HLS BIND_OP variable=sq op=mul impl=dsp
            lane_acc[k] += sq;
        }
    }

    acc_t sumsq = 0;
    for (int k = 0; k < UNROLL_FACTOR; k++) {
#pragma HLS UNROLL
        sumsq += lane_acc[k];
    }
    out_t val_fixed = (out_t)sumsq;     
    out_t r_fixed = hls::sqrt(val_fixed);
    return r_fixed;
}


void proc_core(out_t *result, const vec_t A[N], const vec_t B[N], ap_uint<2> opcode) {
#pragma HLS INTERFACE ap_ctrl_hs port=return
#pragma HLS INTERFACE ap_none port=result
#pragma HLS INTERFACE ap_none port=opcode
#pragma HLS INTERFACE ap_none port=A
#pragma HLS INTERFACE ap_none port=B

#pragma HLS ARRAY_PARTITION variable=A cyclic factor=1024 dim=1
#pragma HLS ARRAY_PARTITION variable=B cyclic factor=1024 dim=1


    out_t r = 0;
    if (opcode == OP_DOT)      
        r = dot_kernel<64>(A, B);
    else if (opcode == OP_EUC) 
        r = euc_kernel<128>(A, B);
    
    *result = r;
}