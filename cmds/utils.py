import os
import re
import subprocess
import time

import constants as const


def _run_cmd(cmd, shell=True, debug=False, ignore_err=False):
    _cmd = subprocess.Popen(cmd, shell=True,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    if _cmd.wait() not in [0]:
        if ignore_err:
            print _cmd.stderr.read()
        else:
            raise InnerException(_cmd.stderr.read())
    if debug:
        return _cmd.stderr.readlines() + _cmd.stdout.readlines()
    return _cmd.stdout.readlines()


def run_cmds(func):
    def func_wrapper(**kwargs):
        cmds = func(**kwargs)
        if not cmds:
            return
        if isinstance(cmds, str) or isinstance(cmds, unicode):
            cmds = [cmds]
        if kwargs.get('inner'):
            ret_obj = []
            for cmd in cmds:
                ret_obj.append(''.join([
                    line.strip() for line in _run_cmd(cmd)]))
            return ret_obj
        else:
            dry = kwargs.get('dry')
            dbg = kwargs.get('debug')
            ignore_e = kwargs.get('ignore_err')
            for cmd in cmds:
                print cmd
                if not kwargs.get('dry'):
                    for line in _run_cmd(cmd, debug=dbg, ignore_err=ignore_e):
                        print line.rstrip()
    return func_wrapper


def token_store_file():
    return __file__.rsplit(os.sep, 1)[0] + os.sep + '.os_token'


def store_token():
    try:
        data = _run_cmd('openstack token issue | egrep "(expire| id )"')
    except InnerException:
        return False
    else:
        for line in data:
            if line.startswith('| id'):
                token = line.split()[3]
            else:
                pattern = re.compile(
                    '.+?(\d+)-(\d+)-(\d+).+?(\d+):(\d+):(\d+).+')
                sch = re.search(pattern, line)
                if not sch:
                    raise InnerException(
                        'Cannot parse token, you can manually set it in ENV')
                expire = '-'.join(sch.groups())

        token_file = token_store_file()
        with open(token_file, 'w+') as f:
            f.write(expire + os.sep + token)
        return True


def get_stored_token():
    token_file = token_store_file()
    if not (os.path.exists(token_file) or store_token()):
        return
    data = open(token_file).read().strip()
    if not data:
        return
    expire_time, token = data.split(os.sep)
    if time.strptime(expire_time, '%Y-%m-%d-%H-%M-%S') <= time.gmtime():
        os.remove(token_file)
        return get_stored_token()
    else:
        return token


def env_token(func):
    env_token = os.getenv(const.TOKEN) or get_stored_token()

    def func_wrapper(**kwargs):
        kwargs.update({'env_token': env_token})
        return func(**kwargs)
    return func_wrapper


def env_api_ip(func):
    def func_wrapper(**kwargs):
        kwargs.update({'env_api_ip': os.getenv(const.API_IP)})
        return func(**kwargs)
    return func_wrapper


def inner(func):
    def func_wrapper(**kwargs):
        kwargs.update({'inner': True})
        return func(**kwargs)
    return func_wrapper


def dry(func):
    def func_wrapper(**kwargs):
        kwargs.update({'dry': True})
        return func(**kwargs)
    return func_wrapper


def ignore_err(func):
    def func_wrapper(**kwargs):
        kwargs.update({'ignore_err': True})
        return func(**kwargs)
    return func_wrapper


def reg_with_sub_resource(func):
    def func_wrapper():
        ret = func()
        ret.append((
            "sub_resource", {'help': "Name or ID of resource"}))
        return ret
    return func_wrapper


def get_module_registers(name, uniq_head):
    methods = dir(os.sys.modules[name])
    head_n = len(uniq_head)
    reg = 'register_%s'
    return {
        i[head_n:]: getattr(os.sys.modules[name], reg % i[head_n:], None)
        for i in methods
        if i.startswith(uniq_head)}


def arg_register(method_subparsers, module_name, meth_name):
    meth_subparser = method_subparsers.add_parser(meth_name)
    sub_cmd_subparser = meth_subparser.add_subparsers(dest='sub_cmd')
    for (k, v) in get_module_registers(module_name, meth_name + '_').items():
        action_parser = sub_cmd_subparser.add_parser(k)
        if v is not None:
            sub_arguments = v() or []
            for (arg, kwargs) in sub_arguments:
                action_parser.add_argument(arg, **kwargs)
        else:
            action_parser.add_argument(
                "sub_resource",
                help="Name or ID of resource")


class InnerException(Exception):
    def __init__(self, msg):
        self.msg = msg

    def __str__(self):
        return self.msg
