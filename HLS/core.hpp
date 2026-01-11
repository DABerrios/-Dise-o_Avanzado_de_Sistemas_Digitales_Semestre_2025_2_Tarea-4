#pragma once
#include "hls_math.h"
#include "ap_int.h"
#include "ap_fixed.h"

static const int N = 1024;

typedef ap_uint<10> vec_t;
typedef ap_int<45>  acc_t; 
typedef ap_fixed<48, 32> out_t;

static const ap_uint<2> OP_DOT = 0;
static const ap_uint<2> OP_EUC = 1;
void proc_core(out_t *result, const vec_t A[N], const vec_t B[N], ap_uint<2> opcode);