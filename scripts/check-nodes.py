#!/usr/bin/env python3
"""Validate NameNodeInfo JMX data; malformed or incomplete data fails closed."""
import json
import sys

try:
    payload = json.load(sys.stdin)
    bean, = [b for b in payload['beans']
             if b['name'] == 'Hadoop:service=NameNode,name=NameNodeInfo']
    live = json.loads(bean['LiveNodes'])
    dead = json.loads(bean['DeadNodes'])
    decom = json.loads(bean['DecomNodes'])
    if len(live) != 3 or dead or decom or bean['Safemode']:
        raise ValueError(f'live={len(live)}, dead={len(dead)}, decom={len(decom)}, '
                         f'safemode={bean["Safemode"]!r}')
    for name, node in live.items():
        if node['adminState'] != 'In Service' or node['volfails'] != 0:
            raise ValueError(f'degraded node: {name}: {node}')
    print('PASS: 3 live DataNodes, 0 dead, all In Service, 0 failed volumes, safe mode OFF')
except (ValueError, KeyError, TypeError) as exc:
    print(f'FAIL: {exc}', file=sys.stderr)
    sys.exit(1)
