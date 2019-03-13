!/usr/bin/python

import sys

def load_file(fName):
    fset = set()
    sec = ''
    for line in open(fName):
        if not line or line.startswith('#'):
            continue
        if line.startswith('['):
            sec= line.strip()
        elif '=' in line:
            k,v = line.split('=', 1)
            k = k.strip()
            v = v.strip()
            fset.add('%s\x01%s\x01%s' % (sec, k, v))
    return sorted(list(fset))

def diff(fName1, fName2):
    """Diff two files, and return four lists of strings
       as result, different_values, keys_only_in_left,
       keys_only_in_right, same_key_values.
       Strings in different_values are in format:
           [section]\x01key\x01value_left\x01right
       Strings in these list are in format:
           [section]\x01key\x01value
       so you need split('\x01') to get each part.
    """

    diff_values = []
    keys_left = []
    keys_right = []
    same = []
    left, right = load_file(fName1), load_file(fName2)
    len_left, len_right = len(left), len(right)
    pl, pr = 0, 0
    while pl < len_left and pr < len_right:
        if left[pl] == right[pr]:
            same.append(left[pl])
            pl += 1
            pr += 1
        else:
            sepl = left[pl].rfind('\x01')
            sepr = right[pr].rfind('\x01')
            if left[pl][:sepl] == right[pr][:sepr]:
                diff_values.append(left[pl]+right[pr][sepr:])
                pl += 1
                pr += 1
            elif left[pl][:sepl] < right[pr][:sepr]:
                keys_left.append(left[pl])
                pl += 1
            else:
                keys_right.append(right[pr])
                pr += 1
    if len_left - pl > 1:
        keys_left.extend(left[pl:])
    else:
        keys_right.extend(right[pr:])
    return diff_values, keys_left, keys_right, same


if __name__ == '__main__':
    import sys
    from os.path import exists
    if len(sys.argv) < 2:
        print "Usage: python diff.py file1 file2"
        sys.exit(1)
    if not exists(sys.argv[1]) or not exists(sys.argv[2]):
        print "Usage: python diff.py file1 file2"
        print "file1 or file2 not exists"
        sys.exit(1)
    lists = diff(sys.argv[1], sys.argv[2])
    if lists[0]:
        print 'Different values:'
        for i in lists[0]:
            print '\t', i.replace('\x01', '\t')
    if lists[1]:
        print 'Only in left:'
        for i in lists[1]:
            print '\t', i.replace('\x01', '\t')
    if lists[2]:
        print 'Only in right:'
        for i in lists[2]:
            print '\t', i.replace('\x01', '\t')
    if lists[3]:
        print 'Same:'
        for i in lists[3]:
            print '\t', i.replace('\x01', '\t')
