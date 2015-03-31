from __future__ import absolute_import
import json
import os
import sys

import lit.Test
import lit.TestRunner
import lit.util
from .base import TestFormat

kIsWindows = sys.platform in ['win32', 'cygwin']

class BenchmarkTest(TestFormat):
    def __init__(self, benchmark_flags=None):
        if benchmark_flags is not None:
            self.benchmark_flags = list(benchmark_flags)
        else:
            self.benchmark_flags = []

    def getBenchmarkTestTests(self, path, litConfig, localConfig):
        """getBenchmarkTestTests(path) - [name]

        Return the tests available in gtest executable.

        Args:
          path: String path to a gtest executable
          litConfig: LitConfig instance
          localConfig: TestingConfig instance"""

        try:
            lines = lit.util.capture([path, '--benchmark_list_tests'],
                                     env=localConfig.environment)
            if kIsWindows:
              lines = lines.replace('\r', '')
            lines = lines.split('\n')
        except:
            litConfig.error("unable to discover benchmark-tests in %r" % path)
            raise StopIteration

        for ln in lines:
            if not ln.strip():
                continue
            yield ln.strip()

    # Note: path_in_suite should not include the executable name.
    def getTestsInExecutable(self, testSuite, path_in_suite, execpath,
                             litConfig, localConfig):
        if not any(execpath.endswith(suffix)
                   for suffix in localConfig.suffixes):
            return
        (dirname, basename) = os.path.split(execpath)
        # Discover the tests in this executable.
        for testname in self.getBenchmarkTestTests(execpath, litConfig,
                                                   localConfig):
            testPath = path_in_suite + (basename, testname)
            yield lit.Test.Test(testSuite, testPath, localConfig,
                                file_path=execpath)

    def getTestsInDirectory(self, testSuite, path_in_suite,
                            litConfig, localConfig):
        source_path = testSuite.getSourcePath(path_in_suite)
        for filename in os.listdir(source_path):
            filepath = os.path.join(source_path, filename)
            if os.path.isdir(filepath):
                dirpath_in_suite = path_in_suite + (filename, )
                for subfilename in os.listdir(filepath):
                    execpath = os.path.join(filepath, subfilename)
                    for test in self.getTestsInExecutable(
                            testSuite, dirpath_in_suite, execpath,
                            litConfig, localConfig):
                      yield test
            else:
                for test in self.getTestsInExecutable(
                        testSuite, path_in_suite, filepath,
                        litConfig, localConfig):
                    yield test

    def execute(self, test, litConfig):
        if litConfig.noExecute:
            return lit.Test.PASS, ''

        testPath,testName = os.path.split(test.getSourcePath())
        while not os.path.exists(testPath):
            # Handle BenchmarkTest parametrized and typed tests, whose name
            # includes some '/'s.
            testPath, namePrefix = os.path.split(testPath)
            testName = os.path.join(namePrefix, testName)

        cmd = [testPath,
               '--benchmark_filter=' + testName + '$',
               '--color_output=false', '--benchmark_format=json']
        cmd += self.benchmark_flags

        out, err, exitCode = lit.util.executeCommand(
            cmd, env=test.config.environment)

        if exitCode != 0:
            return lit.Test.FAIL, out + err

        benchmark_data = json.loads(out)
        result = lit.Test.Result(lit.Test.PASS, '')
        result.addMetric('benchmark_results',
                         lit.Test.toMetricValue(benchmark_data))

        return result
