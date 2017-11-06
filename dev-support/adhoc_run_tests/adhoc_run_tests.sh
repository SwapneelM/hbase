#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

set -e
function usage {
  echo "Usage: ${0} [options] TestSomeTestName [TestOtherTest...]"
  echo ""
  echo "    --force-timeout seconds               Seconds to wait before killing a given test run."
  echo "    --maven-local-repo /path/to/use       Path for maven artifacts while building"
  echo "    --repeat times                        number of times to repeat if successful"
  echo "    --log-output /path/to/use             path to directory to hold attempt log"
  exit 1
}
# Get arguments
declare -i force_timeout=7200
declare -i attempts=1
declare maven_repo="${HOME}/.m2/repository"
declare output="."
while [ $# -gt 0 ]
do
  case "$1" in
    --force-timeout) shift; force_timeout=$1; shift;;
    --maven-local-repo) shift; maven_repo=$1; shift;;
    --repeat) shift; attempts=$1; shift;;
    --log-output) shift; output=$1; shift;;
    --) shift; break;;
    -*) usage ;;
    *)  break;;  # terminate while loop
  esac
done

if [ "$#" -lt 1 ]; then
  usage
fi

function find_module
{
  declare testname=$1
  declare path
  path=$(find . -name "${testname}.java")
  while [ -n "${path}" ]; do
    path=$(dirname "${path}")
    if [ -f "${path}/pom.xml" ]; then
      basename "${path}"
      break
    fi
  done
}

declare -a modules

for test in "${@}"; do
  module=$(find_module "${test}")
  if [[ ! "${modules[*]}" =~ ${module} ]]; then
    modules+=(${module})
  fi
done

declare -a mvn_module_arg

for module in "${modules[@]}"; do
  mvn_module_arg+=(-pl "${module}")
done
declare tests="${*}"
for attempt in $(seq "${attempts}"); do
  echo "Attempt ${attempt}" >&2
  mvn --batch-mode -Dmaven.repo.local="${maven_repo}" -Dtest="${tests// /,}" -Dsurefire.rerunFailingTestsCount=0 -Dsurefire.parallel.forcedTimeout="${force_timeout}" -Dsurefire.shutdown=kill -DtrimStackTrace=false -am "${mvn_module_arg[@]}" package >"${output}/mvn_test.log" 2>&1
done
