#!/usr/bin/env python2.7

from argparse import ArgumentParser
import sys

from cmds import api_cmd
from cmds import build_cmd
from cmds import demo_cmd
from cmds import hosting_cmd
from cmds import list_cmd
from cmds import utils


METHODS = {
    'api': api_cmd.main,
}

UNIQ_METHODS = {
    'build': build_cmd,
    'hosting': hosting_cmd,
    'list': list_cmd,
    'demo': demo_cmd,
}


def parse_args():
    main_parser = ArgumentParser(
        prog='oceana',
        description='A helper tool writen by zongkai@polex.com.cn',
    )
    method_subparsers = main_parser.add_subparsers(dest='method')

    for (meth_name, module) in UNIQ_METHODS.items():
        utils.arg_register(method_subparsers, module.__name__, meth_name)

    for method in METHODS.values():
        sys.modules[method.__module__].arg_register(method_subparsers)

    return vars(main_parser.parse_args())


def main():
    kwargs = parse_args()
    method = kwargs.pop('method')
    try:
        if method in UNIQ_METHODS:
            module = UNIQ_METHODS[method]
            sub_cmd = kwargs.pop('sub_cmd')
            method = getattr(module, method + '_' + sub_cmd)
            method(**kwargs)
        else:
            return METHODS[method](**kwargs)
    except utils.InnerException as e:
        print e


if __name__ == '__main__':
    main()
