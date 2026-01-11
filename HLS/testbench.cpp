#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <cmath>    
#include <iomanip>  
#include <stdexcept> 

#include "core.hpp"

const std::string INPUT_FILE = "golden_inputs.csv";
const std::string REF_FILE   = "golden_ref.csv";

const double EPSILON = 0.05; 

std::string clean_token(std::string in) {
    if (!in.empty() && in.back() == '\r') {
        in.pop_back();
    }
    return in;
}

std::vector<std::string> get_next_line_tokens(std::ifstream& str) {
    std::vector<std::string> result;
    std::string line, cell;

    if (!std::getline(str, line)) return result; 

    std::stringstream lineStream(line);
    while(std::getline(lineStream, cell, ',')) {
        result.push_back(clean_token(cell));
    }
    return result;
}

int main() {
    std::cout << "=============================================" << std::endl;
    std::cout << "   Starting Debug HLS Testbench (N=" << N << ")" << std::endl;
    std::cout << "=============================================" << std::endl;

    std::ifstream file_in(INPUT_FILE);
    std::ifstream file_ref(REF_FILE);

    if (!file_in.is_open() || !file_ref.is_open()) {
        std::cerr << "ERROR: Could not open CSV files." << std::endl;
        return 1;
    }

    std::string dummy;
    std::getline(file_in, dummy); 
    std::getline(file_ref, dummy);

    int test_count = 0;
    static vec_t A[N];
    static vec_t B[N];
    ap_uint<2> opcode;
    out_t dut_result; 

    try {
        while (true) {
            std::vector<std::string> in_tokens = get_next_line_tokens(file_in);
            std::vector<std::string> ref_tokens = get_next_line_tokens(file_ref);

            if (in_tokens.empty() || ref_tokens.empty()) break; 

            test_count++;
            
            if (in_tokens.size() < (1 + N + N)) {
                throw std::runtime_error("Line " + std::to_string(test_count) + " has insufficient tokens!");
            }

            opcode = std::stoi(in_tokens[0]);
            int offset = 1;
            
            for (int i = 0; i < N; i++) A[i] = (vec_t)std::stoul(in_tokens[offset++]);
            for (int i = 0; i < N; i++) B[i] = (vec_t)std::stoul(in_tokens[offset++]);

            proc_core(&dut_result, A, B, opcode);

            double golden = std::stod(ref_tokens[0]);
            double actual = (double)dut_result; 
            
            if (test_count == 1) {
                 std::cout << "Debug: First Result HLS=" << actual << " Ref=" << golden << std::endl;
            }

            if (std::abs(actual - golden) > EPSILON) {
                std::cout << ">> TEST " << test_count << " FAILED" << std::endl;
            }
            
            if (test_count % 10 == 0) std::cout << "Tested " << test_count << " samples..." << std::endl;
        }
    } catch (const std::exception& e) {
        std::cerr << "\n\nCRITICAL ERROR in Testbench: " << e.what() << std::endl;
        std::cerr << "Crash occurred at Test Sample #" << test_count << std::endl;
        return 1;
    }

    std::cout << "SUCCESS: Finished " << test_count << " tests." << std::endl;
    return 0;
}