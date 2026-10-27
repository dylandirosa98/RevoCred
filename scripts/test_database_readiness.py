import subprocess
import unittest
from unittest.mock import patch

import test_database


class DatabaseStartupTests(unittest.TestCase):
    def test_waits_for_final_tcp_server_not_temporary_socket_server(self):
        attempts = [subprocess.CompletedProcess([], 1), subprocess.CompletedProcess([], 0)]
        with patch.object(test_database.subprocess, 'run', side_effect=attempts) as run, \
                patch.object(test_database.time, 'sleep') as sleep:
            test_database.wait_for_database('disposable-test')
        self.assertEqual(run.call_count, 2)
        for call in run.call_args_list:
            args = call.args[0]
            self.assertIn('-h', args)
            self.assertEqual(args[args.index('-h') + 1], '127.0.0.1')
        sleep.assert_called_once_with(1)
