import sys
import json
from utils import extract_test_dict, seconds_in_future


scenario_description = (
    "Deploying of the Foundation contracts in the "
    "blockchain and noting down of their addresses"
)


def calculate_closing_time(obj, script_name, substitutions):
    obj.closing_time = seconds_in_future(obj.args.deploy_creation_seconds)
    substitutions['closing_time'] = obj.closing_time
    return substitutions


def run(ctx):
    ctx.create_js_file(
        substitutions={
            "foundation_abi": ctx.foundation_abi,
            "foundation_bin": ctx.foundation_bin,
            "max_delegate_number": ctx.args.deploy_max_delegate_number,
            "debating_days": ctx.args.deploy_debating_days
        }
    )
    output = ctx.run_script('deploy.js')
    results = extract_test_dict('deploy', output)

    try:
        ctx.foundation_addr = results['foundation_address']
    except:
        print(
            "ERROR: Could not find expected results in the deploy scenario"
            ". The output was:\n{}".format(output)
        )
        sys.exit(1)
    print("Foundation address is: {}".format(ctx.foundation_addr))
    with open(ctx.save_file, "w") as f:
        f.write(json.dumps({
            "foundation_addr": ctx.foundation_addr
        }))

    # after deployment recalculate for the subsequent tests what the min
    # amount of tokens is in the case of extrabalance tests
    if ctx.scenario_uses_extrabalance():
        ctx.args.deploy_min_tokens_to_create = (
            int(ctx.args.deploy_min_tokens_to_create * 1.5)
        )
