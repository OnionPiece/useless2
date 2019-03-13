#!/bin/bash

DST_PATH=/root/neutron-lbaas
cp -r /usr/lib64/python2.7/site-packages/cryptography $DST_PATH/.tox/pep8/lib64/python2.7/site-packages/
cp /usr/lib/python2.7/site-packages/ipaddress.py $DST_PATH/.tox/pep8/lib/python2.7/site-packages/
cp -r /usr/lib/python2.7/site-packages/pyasn1 $DST_PATH/.tox/pep8/lib/python2.7/site-packages/
cp /usr/lib64/python2.7/site-packages/_cffi_backend.so $DST_PATH/.tox/pep8/lib64/python2.7/site-packages/
cp -r /usr/lib/python2.7/site-packages/idna $DST_PATH/.tox/pep8/lib/python2.7/site-packages/
cp -r /usr/lib/python2.7/site-packages/barbicanclient/ $DST_PATH/.tox/pep8/lib/python2.7/site-packages/
