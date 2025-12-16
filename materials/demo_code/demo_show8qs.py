#!/usr/bin/env python
''' Show the chess boards from text output of 8-queens problem solutions'''
import sys

def get_pos_lst(l):
    i = 5
    tt = []
    while(i < 64):
        tt.append(l[i])
        i += 8
    return tt

try:
    f = open("8qs.out", "rt")
except IOError:
    print('getting data from stdin...')
    f = sys.stdin

for line in f:
    lst = get_pos_lst(line)
    print(lst)

    for j in range(8):
        for k in range(8):
            if (int(lst[j]) == k+1):
                print('Q', end = ' ')
            else:
                print('-', end = ' ')
        print()

if f is not sys.stdin:
    f.close()
