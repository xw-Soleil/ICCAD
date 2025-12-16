#!/usr/bin/python
"""A program solving 8-Queens Problem on a chess board. Source code
copied from web, but heavily modified for clarity in Python 3.
"""

BOARD_SIZE = 8


def under_attack(column, queens):
    '''Answer whether a queen on this column being attacked by existing
    queens under the current row (one list of queens per row)'''
    left = right = column  # set initial checking position on this column

    # the graph below illustrates the checking positions,
    #      c
    #     lcr
    #    l c r
    #   l  c  r
    #  l   c   r
    # ......
    # thus to check all left, right positions for all rows underneath

    # input queen lists are sorted with row order (the least first), so
    # reverse this order to start check from the closest neighbor row
    for r, c in reversed(queens):
        left, right = left - 1, right + 1  # expand one position each row
        # for each loop, a further downside row is checked
        # is c==column? (another queen is straight down)
        # is c==left? (another queen is diagonally left down)
        # is c==right? (another queen is diagonally right down)
        if c in (left, column, right):
            return True
    return False


def solve(n):
    '''Recursively call "solve(n-1)" for smaller row number solutions,
    then find all legal solutions after adding a queen on current row'''

    if n == 0:
        return [[]]

    smaller_solutions = solve(n-1)

# The 4 lines of the "return" statement below are just a one sentence
# example of Python's "List Comprehension" feature, whose basic syntax is,
# newList = [ expression(element) for element in oldList if condition ]
#
# Try to analyze and use such a feature.
#
    return [solution+[(n, i+1)]
            for i in range(BOARD_SIZE)
            for solution in smaller_solutions
            if not under_attack(i+1, solution)]

# Below are the equivalent expressions for "return sentence" above.
#    newList = []
#    # check all 8 positions on current row
#    for i in range(BOARD_SIZE):
#        for solution in smaller_solutions:
#            if not under_attack(i+1, solution):
#                newList += [solution + [(n, i+1)]]
#    # check what is returned in newList?
#    # a list of row list based on any smaller solution plus legal (n,i+1)
#    return newList

# try to run
# for answer in solve(1):
# for answer in solve(2):
# check with the results and get the idea of the program


for answer in solve(BOARD_SIZE):
    print(answer)
