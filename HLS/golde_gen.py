import random
import csv
import math


N = 1024            
BITSIZE = 10       
NUM_SAMPLES = 100   

INPUT_FILE = "golden_inputs.csv"
REF_FILE   = "golden_ref.csv"

OP_DOT = 0
OP_EUC = 1


print(f"Generating {NUM_SAMPLES} samples for N={N}, Unsigned {BITSIZE}-bit...")

all_inputs = [] 
all_refs = []   

for i in range(NUM_SAMPLES):

    vec_a = [random.randint(0, (1 << BITSIZE) - 1) for _ in range(N)]
    vec_b = [random.randint(0, (1 << BITSIZE) - 1) for _ in range(N)]
    
    opcode = random.choice([OP_DOT, OP_EUC])
    result = 0.0

    if opcode == OP_DOT:
        dot_sum = sum(x * y for x, y in zip(vec_a, vec_b))
        result = float(dot_sum)
        
    elif opcode == OP_EUC:
        diff_sq_sum = sum((x - y) ** 2 for x, y in zip(vec_a, vec_b))
        result = math.sqrt(diff_sq_sum)

    row = [opcode] + vec_a + vec_b
    all_inputs.append(row)
    all_refs.append(result)

    if (i+1) % 10 == 0:
        print(f"Generated {i+1}/{NUM_SAMPLES}...")


with open(INPUT_FILE, "w", newline="") as f:
    writer = csv.writer(f)
    header = ["OPCODE"] + [f"A{k}" for k in range(N)] + \
                          [f"B{k}" for k in range(N)]
    writer.writerow(header)
    writer.writerows(all_inputs)

with open(REF_FILE, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["RESULT"])
    for val in all_refs:
        writer.writerow([f"{val:.10f}"])

print("Data Generation Complete.")