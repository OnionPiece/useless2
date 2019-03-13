#!/usr/bin/env python2
# writen by zongkai@polex.com.cn

import os
from shutil import copy
import sys


def read_file(file_path):
    # NOTE data = {'alias': [],
    #              'source': [],
    #              'function-name1': [],
    #              'function-nameN': []}
    data = {}
    function_lines = {}
    in_function = False
    with open(file_path) as f:
       for line in f:
           words = line.split()
           if words:
               if words[0] in ('alias', 'source'):
                   data.setdefault(words[0], [])
                   data[words[0]].append(line)
               elif words[0] == 'function':
                   function_lines[words[1]] = [line]
                   in_function = True
               elif words[0] == '}':
                   function_lines.values()[0].append(line)
                   data.update(function_lines)
                   function_lines = {}
                   in_function = False
               elif in_function:
                   function_lines.values()[0].append(line)
    return data


def get_append_data(src_data, dst_data):
    ret = {}
    # NOTE ret = {'alias': [],
    #             'source': [],
    #             'function-name1': [],
    #             'function-nameN': []}
    def single_find(src, dst):
        ret = []
        for line in src:
            if line not in dst:
                ret.append(line)
        return ret
    src_alias = src_data.pop('alias', [])
    dst_alias = dst_data.pop('alias', [])
    ret['alias'] = single_find(src_alias, dst_alias)
    src_source = src_data.pop('source', [])
    dst_source = dst_data.pop('source', [])
    ret['source'] = single_find(src_source, dst_source)

    for func in src_data:
        if func not in dst_data:
            ret[func] = src_data[func]
        elif dst_data[func] != src_data[func]:
            ret[func] = src_data[func]
    return ret


def append_data(data, file_path):
    alias = data.pop('alias')
    source = data.pop('source')
    with file(file_path, 'a') as f:
        for line in alias:
            f.writelines(line)
        for line in source:
            f.writelines(line)
        for func_lines in data.values():
            for line in func_lines:
                f.write(line)


def main():
    data_file = os.path.join(os.path.dirname(__file__), 'dot_bashrc')
    our_bashrc_data = read_file(data_file)
    bashrc_path = os.path.join(os.popen('echo ~').read().strip(), '.bashrc')
    if not os.path.exists(bashrc_path):
        print "no %s found, creating a new one..." % bashrc_path
        open(bashrc_path, 'w+').close()
    else:
        print "before updating %s, copy existing it as %s.backup" % (
            bashrc_path, bashrc_path)
        copy(bashrc_path, bashrc_path + '.backup')
    env_bashrc_data = read_file(bashrc_path)
    data_to_append = get_append_data(our_bashrc_data, env_bashrc_data)
    append_data(data_to_append, bashrc_path)
    print '%s updating complete, you should run `source %s`' % (
        bashrc_path, bashrc_path)


if __name__ == '__main__':
    main()
