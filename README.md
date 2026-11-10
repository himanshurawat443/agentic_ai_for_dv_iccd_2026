# Proving Ground challenge design: design-1

This package contains scored design `design-1`: a streaming fixed-point sample conditioner (datapath block).

## What is inside

| Path | Content |
|---|---|
| `spec.md` | The specification. Numbered requirements (REQ-xx) define correct behavior. |
| `change_request.md` | The change you must implement (CR-D1: round toward zero and output frame length). |
| `rtl/` | The baseline RTL (SystemVerilog). `rtl/filelist.f` lists the files in compile order, relative to this directory. Top module: `dsp_stream`. |
| `tb/public/` | The public testbench (cocotb with Verilator) and its Makefile. It passes on the baseline. |
| `flow/constraint.sdc` | The clock constraint used for synthesis and place and route (15 ns). |
| `design.yaml` | Machine-readable design facts: top module, clock and reset ports, clock period, filelist. |

The baseline contains a few seeded deviations from the specification. The public testbench does not detect them, and they are not listed anywhere in this package.

## Running the public tests

You need Verilator 5.036 or later, Python 3.9 or later and cocotb 2.x (tested with Verilator 5.048 and cocotb 2.0.1). The flow image contains all of them.

```
pip install "cocotb==2.0.1"
make -C tb/public                 # run every public test on rtl/
make -C tb/public RTL_ROOT=/path/to/your/tree   # run them on another tree with rtl/filelist.f
```

Results are written to `tb/public/results.xml`.

## The task

1. Read the specification and find the deviations: behaviors of the baseline that contradict a requirement.
2. Fix them and implement the change request.
3. Deliver evidence: tests and assertions that fail on the baseline where it is wrong, pass on your design, and detect faults injected into your design.
4. Keep or improve power, performance and area under the released clock constraint.

Do not change the module name, the ports, `rtl/filelist.f` or `flow/constraint.sdc`. Designs must be synthesizable and must not read files at run time.

## Checking your submission

Run the flow image from the practice kit on your archive, as described in `flow-image/README.md` in the kit. It runs every stage except the hidden checks and reports V, P and a projected score that assumes C = 1.

```
docker run --rm --cpus 4 -u $(id -u):$(id -g) -e HOME=/tmp \
  -v /path/to/design-1:/design:ro -v $PWD/runs:/runs proving-ground/flow:public \
  run --design /design --submission /runs/sub.tar.gz --out /runs/out --jobs 4 --cache /runs/cache
```

## Submission format

One archive named `<handle>-design-1-<n>.tar.gz`:

```
rtl/          your modified design, same layout and filelist as released
tests/        your cocotb tests (test_*.py plus any helper modules)
assertions/   SystemVerilog assertions bound to the design (bind files)
report.md     one page: deviations found, changes made, how verified
trajectory/   optional: your agent's transcript or log
```

Your tests and assertions must pass on your own submission and must run within ten minutes in the flow image. How to upload is announced on the competition page.

## Dates

The scored window closes on November 16, 2026, at 23:59 Hong Kong Time (UTC+8).
