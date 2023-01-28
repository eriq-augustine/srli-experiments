#!/usr/bin/env python3

# Parse out the results.
# TODO(eriq): This does not properly parse number of query results for IG runs (but we only need that data in one place).

import glob
import os
import re
import sys

THIS_DIR = os.path.abspath(os.path.dirname(os.path.realpath(__file__)))
RESULTS_DIR = os.path.join(THIS_DIR, '..', 'results')

LOG_FILENAME = 'out.txt'

HEADER = [
    # Identifiers
    'experiment',
    'iteration',
    'example',
    'split',
    'engine',
    # Results
    'runtime',
    'learn_time',
    'infer_time',
    'timeout',
    # Eval
    'eval_0_id',
    'eval_0_value',
    'eval_1_id',
    'eval_1_value',
    'eval_raw',
]

# All times are in sec.
def parseLog(logPath):
    results = {}

    # Fetch the run identifiers off of the path.
    for (key, value) in re.findall(r'([\w\-]+)::([\w\-]+)', logPath):
        results[key] = value

    results['timeout'] = False

    startTime = None
    learnStartTime = None
    inferDataStartTime = None
    inferStartTime = None
    evalStartTime = None

    evals = []

    with open(logPath, 'r') as file:
        for line in file:
            line = line.strip()
            if (line == ''):
                continue

            match = re.search(r'^-- TIMEOUT --$', line)
            if (match is not None):
                results['timeout'] = True

            match = re.search(r'^(\d+) -- Starting learning engine.$', line)
            if (match is not None):
                learnStartTime = int(match.group(1))

            match = re.search(r'^(\d+) -- Loading inference data.$', line)
            if (match is not None):
                inferDataStartTime = int(match.group(1))

            match = re.search(r'^(\d+) -- Starting inference engine.$', line)
            if (match is not None):
                inferStartTime = int(match.group(1))

            match = re.search(r'^(\d+) -- Starting evaluation.$', line)
            if (match is not None):
                evalStartTime = int(match.group(1))

            match = re.search(r'^Evaluation Result -- Metric: ([^,]+), Relation: ([^,]+), Value: (\d+(?:\.\d+))$', line)
            if (match is not None):
                metric = match.group(1)
                relation = match.group(2)
                value = float(match.group(3))

                evals.append((relation, metric, value))

    if ((learnStartTime is not None) and (evalStartTime is not None)):
        # An example with weight learning.
        learnTime = inferDataStartTime - learnStartTime
        inferTime = evalStartTime - inferStartTime

        results['runtime'] = learnTime + inferTime
        results['learn_time'] = learnTime
        results['infer_time'] = inferTime
    elif ((inferStartTime is not None) and (evalStartTime is not None)):
        # An inference-only example.
        learnTime = 0
        inferTime = evalStartTime - inferStartTime

        results['runtime'] = learnTime + inferTime
        results['learn_time'] = learnTime
        results['infer_time'] = inferTime
    elif (results['timeout']):
        # A timeout.
        results['runtime'] = -2
        results['learn_time'] = -2
        results['infer_time'] = -2
    else:
        # An incomplete run.
        results['runtime'] = -1
        results['learn_time'] = -1
        results['infer_time'] = -1

    results['eval_raw'] = ';'.join([str(eval_info) for eval_info in evals])

    for i in range(len(evals)):
        if (i >= 2):
            break

        results["eval_%d_id" % (i)] = "%s: %s" % (evals[i][0], evals[i][1])
        results["eval_%d_value" % (i)] = evals[i][2]

    return results

# [{key, value, ...}, ...]
def fetchResults():
    runs = []

    for logPath in glob.glob("%s/**/%s" % (RESULTS_DIR, LOG_FILENAME), recursive = True):
        run = parseLog(logPath)
        if (run is not None):
            runs.append(run)

    return runs

def main():
    runs = fetchResults()
    if (len(runs) == 0):
        return

    rows = []
    for run in runs:
        rows.append([run.get(key, '') for key in HEADER])

    print("\t".join(HEADER))
    for row in rows:
        print("\t".join(map(str, row)))

def _load_args(args):
    executable = args.pop(0)
    if (len(args) != 0 or ({'h', 'help'} & {arg.lower().strip().replace('-', '') for arg in args})):
        print("USAGE: python3 %s" % (executable), file = sys.stderr)
        sys.exit(1)

if (__name__ == '__main__'):
    _load_args(sys.argv)
    main()
