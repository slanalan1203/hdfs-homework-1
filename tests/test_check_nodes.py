import json
import subprocess
import unittest
from pathlib import Path

CHECK = Path(__file__).resolve().parents[1] / 'scripts' / 'check-nodes.py'


class CheckNodesTest(unittest.TestCase):
    def run_check(self, nodes, dead=None, decom=None, safe=''):
        payload = {'beans': [{
            'name': 'Hadoop:service=NameNode,name=NameNodeInfo',
            'LiveNodes': json.dumps(nodes),
            'DeadNodes': json.dumps(dead or {}),
            'DecomNodes': json.dumps(decom or {}),
            'Safemode': safe,
        }]}
        return subprocess.run(['python3', str(CHECK)], input=json.dumps(payload),
                              capture_output=True, text=True)

    def healthy(self):
        return {f'datanode{i}:9866': {'adminState': 'In Service', 'volfails': 0}
                for i in (1, 2, 3)}

    def test_three_normal_nodes_pass(self):
        self.assertEqual(self.run_check(self.healthy()).returncode, 0)

    def test_two_nodes_fail(self):
        nodes = self.healthy()
        del nodes['datanode3:9866']
        self.assertNotEqual(self.run_check(nodes).returncode, 0)

    def test_dead_node_fails(self):
        self.assertNotEqual(self.run_check(self.healthy(), dead={'old': {}}).returncode, 0)

    def test_decommissioned_node_fails(self):
        nodes = self.healthy()
        nodes['datanode1:9866']['adminState'] = 'Decommissioned'
        self.assertNotEqual(self.run_check(nodes).returncode, 0)

    def test_failed_disk_fails(self):
        nodes = self.healthy()
        nodes['datanode1:9866']['volfails'] = 1
        self.assertNotEqual(self.run_check(nodes).returncode, 0)

    def test_safe_mode_fails(self):
        self.assertNotEqual(self.run_check(self.healthy(), safe='Safe mode is ON').returncode, 0)

    def test_missing_health_fields_fail(self):
        nodes = self.healthy()
        nodes['datanode1:9866'].pop('volfails')
        self.assertNotEqual(self.run_check(nodes).returncode, 0)


if __name__ == '__main__':
    unittest.main()
