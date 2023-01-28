#!/usr/bin/env python3

'''
Analyze the results for the "quality" experiment.
The input to this script should be the output from parse-results.py, ex:
```
./scripts/parse-results.py > results.txt
./scripts/analyze-results.py results.txt AGGREGATE
```
'''

import math
import os
import sqlite3
import sys

ENGINES = [
    'Logic_Weighted_Discrete',
    'MLN_Native',
    'MLN_PySAT',
    'ProbLog',
    'ProbLog_NonCollective',
    'PSL',
    'Random_Continuous',
    'Random_Discrete',
    'Tuffy',
]

# Get the base rows.
BASE_QUERY = '''
    SELECT *
    FROM Stats
    WHERE experiment == 'quality'
'''

# Aggregate over splits and iterations.
AGGREGATE_QUERY = '''
    SELECT
        S.experiment,
        S.example,
        S.engine,
        COUNT(*) AS aggregate_count,
        AVG(S.runtime) AS runtime_mean,
        STDEV(S.runtime) AS runtime_std,
        AVG(S.learn_time) AS learn_time_mean,
        STDEV(S.learn_time) AS learn_time_std,
        AVG(S.infer_time) AS infer_time_mean,
        STDEV(S.infer_time) AS infer_time_std,
        AVG(S.eval_0_value) AS eval_0_value_mean,
        STDEV(S.eval_0_value) AS eval_0_value_std,
        AVG(S.eval_1_value) AS eval_1_value_mean,
        STDEV(S.eval_1_value) AS eval_1_value_std
    FROM
        (
            ''' + BASE_QUERY + '''
        ) S
    WHERE
        S.runtime != -1
    GROUP BY
        S.experiment,
        S.example,
        S.engine,
        S.eval_0_id,
        S.eval_1_id
    ORDER BY
        S.experiment,
        S.example,
        S.engine,
        S.eval_0_id,
        S.eval_1_id
'''

FULL_TABLE_QUERY = '''
    WITH A AS (
        ''' + AGGREGATE_QUERY + '''
    )
    SELECT
        E.example,
        ''' + ', '.join(["""(
            SELECT
                CAST(ROUND(eval_0_value_mean, 2) AS TEXT)
                    || ' ± '
                    || CAST(ROUND(eval_0_value_std, 2) AS TEXT)
            FROM A
            WHERE
                A.example = E.example
                AND A.engine = '%s'
        ) AS '%s'""" % (engine, engine) for engine in ENGINES]) + '''
    FROM
        (
            SELECT DISTINCT example
            FROM
                (
                    ''' + BASE_QUERY + '''
                )
        ) E
'''

BOOL_COLUMNS = {
    'timeout'
}

INT_COLUMNS = {
    'iteration',
    'split',
    'runtime',
    'learn_time',
    'infer_time',
}

FLOAT_COLUMNS = {
    'eval_0_value',
    'eval_1_value',
}

# {key: (query, description), ...}
RUN_MODES = {
    'BASE': (
        BASE_QUERY,
        'Get the base results.',
    ),
    'AGGREGATE': (
        AGGREGATE_QUERY,
        'Aggregate over iteration and split.',
    ),
    'FULL_TABLE': (
        FULL_TABLE_QUERY,
        'Get the full aggregate table.',
    ),
}

# ([header, ...], [[value, ...], ...])
def fetchResults(path):
    rows = []
    header = None

    with open(path, 'r') as file:
        for line in file:
            line = line.strip("\n ")
            if (line == ''):
                continue

            row = line.split("\t")

            # Get the header first.
            if (header is None):
                header = row
                continue

            assert(len(header) == len(row))

            for i in range(len(row)):
                if (row[i] == ''):
                    row[i] = None
                elif (header[i] in BOOL_COLUMNS):
                    row[i] = (row[i].upper() == 'TRUE')
                elif (header[i] in INT_COLUMNS):
                    row[i] = int(row[i])
                elif (header[i] in FLOAT_COLUMNS):
                    row[i] = float(row[i])

            rows.append(row)

    return header, rows

# Standard deviation UDF for sqlite3.
# Taken from: https://www.alexforencich.com/wiki/en/scripts/python/stdev
class StdevFunc:
    def __init__(self):
        self.M = 0.0
        self.S = 0.0
        self.k = 1

    def step(self, value):
        if value is None:
            return
        tM = self.M
        self.M += (value - tM) / self.k
        self.S += (value - tM) * (value - self.M)
        self.k += 1

    def finalize(self):
        if self.k < 3:
            return None
        return math.sqrt(self.S / (self.k-2))

def main(mode, resultsPath):
    columns, data = fetchResults(resultsPath)
    if (len(data) == 0):
        return

    quotedColumns = ["'%s'" % column for column in columns]

    columnDefs = []
    for i in range(len(columns)):
        column = columns[i]
        quotedColumn = quotedColumns[i]

        if (column in BOOL_COLUMNS):
            columnDefs.append("%s INTEGER" % (quotedColumn))
        elif (column in INT_COLUMNS):
            columnDefs.append("%s INTEGER" % (quotedColumn))
        elif (column in FLOAT_COLUMNS):
            columnDefs.append("%s FLOAT" % (quotedColumn))
        else:
            columnDefs.append("%s TEXT" % (quotedColumn))

    connection = sqlite3.connect(":memory:")
    connection.create_aggregate("STDEV", 1, StdevFunc)

    connection.execute("CREATE TABLE Stats(%s)" % (', '.join(columnDefs)))

    connection.executemany("INSERT INTO Stats(%s) VALUES (%s)" % (', '.join(columns), ', '.join(['?'] * len(columns))), data)

    query = RUN_MODES[mode][0]
    rows = connection.execute(query)

    print("\t".join([column[0] for column in rows.description]))
    for row in rows:
        print("\t".join(map(str, row)))

    connection.close()

def _load_args(args):
    executable = args.pop(0)
    if (len(args) != 2 or ({'h', 'help'} & {arg.lower().strip().replace('-', '') for arg in args})):
        print("USAGE: python3 %s <results path> <mode>" % (executable), file = sys.stderr)
        print("modes:", file = sys.stderr)
        for (key, (query, description)) in RUN_MODES.items():
            print("    %s - %s" % (key, description), file = sys.stderr)
        sys.exit(1)

    resultsPath = args.pop(0)
    if (not os.path.isfile(resultsPath)):
        raise ValueError("Can't find the specified results path: " + resultsPath)

    mode = args.pop(0).upper()
    if (mode not in RUN_MODES):
        raise ValueError("Unknown mode: '%s'." % (mode))

    return mode, resultsPath

if (__name__ == '__main__'):
    main(*_load_args(sys.argv))
