#!/usr/bin/python2

import json
import subprocess
import argparse
import os
import inspect

contracts_dir = "../"
currentdir = os.path.dirname(
    os.path.abspath(inspect.getfile(inspect.currentframe()))
)
os.sys.path.insert(0, os.path.dirname(currentdir))
from tests.utils import determine_binary, edit_dao_source, rm_file


class TestDeployContext():
    def __init__(self, args):
        self.args = args
        self.args.solc = determine_binary(args.solc, 'solc')

    def compile_contract(self, contract_name):
        contract_path = os.path.join(
          self.args.contracts_dir,
          contract_name
        )
        print("    Compiling {}...".format(contract_path))
        data = subprocess.check_output([
          self.args.solc,
          contract_path,
          "--optimize",
          "--combined-json",
          "abi,bin"
        ])
        return json.loads(data)

    def cleanup(self):
        rm_file(os.path.join(self.args.contracts_dir, "FoundationCopy.sol"))
        rm_file(
          os.path.join(self.args.contracts_dir, "FoundationCreationCopy.sol")
        )


if __name__ == "__main__":
    p = argparse.ArgumentParser(description='Foundation deployment script')
    p.add_argument(
        '--solc',
        help='Full path to the solc binary to use'
    )
    p.add_argument(
        '--max-delegate-number',
        type=int,
        default=9,
        help='Max delegates in contract'
    )
    p.add_argument(
        '--contracts-dir',
        default="..",
        help='The directory where the contracts are located'
    )
    p.add_argument(
        '--debating-days',
        type=int,
        default=7,
        help='Debating days before a new budget goes into vote state'
    )
    args = p.parse_args()
    ctx = TestDeployContext(args)
    comp = ctx.compile_contract("Foundation.sol")

    with open("prepare.js", "w") as f:
        f.write("foundation_abi = {};\n".format(comp['contracts']['Foundation']['abi']))
        f.write("foundation_bin = '{}';\n".format(comp['contracts']['Foundation']['bin']))
        f.write("max_Delegate_number = {};\n".format(
          args.max_delegate_number)
        )
        f.write("debating_days = \"{}\";\n".format(args.debating_days))

    #ctx.cleanup()
