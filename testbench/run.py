#!/usr/bin/env python
# -*- coding: utf-8 -*-

__author__ = "Tomasz Oczkowski"


from vunit import VUnit
from os.path import abspath, join, dirname
from os import pardir

from model.moving_integrator_model import fpga_moving_integrator
import random

vector_length = 8192

# top module generic parameters configuration
# if using GHDL comment G_CLK_FREQ generic as real generics are not supported by GHDL
generics = {
    'G_DATA_IN_WIDTH': 16,
    'G_DATA_OUT_WIDTH': 24,
    'G_SAMPLES': 32,
    'G_INPUT_SIGNED': False,
    'G_ROUND_EVEN': False,
    'G_PROTECTION_BITS': 0,
    'G_CLK_FREQ': 100.0e6
}

# VUNIT configuration
prj = VUnit.from_argv()
prj.add_com()

# add libraries
lib = prj.add_library('moving_integrator')
lib.add_source_files(join(dirname(__file__), 'moving_integrator_tb.vhd'))
lib.add_source_files(join(dirname(__file__), pardir, '*.vhd'))

testbench = lib.test_bench("MOVING_INTEGRATOR_TB")

# Just set a generic for all configurations within the test bench
for key, value in generics.items():
    testbench.set_generic(key, value)


def generate_test_vectors(filename, bit_width=generics['G_DATA_IN_WIDTH'], out_width=generics['G_DATA_OUT_WIDTH'],
    integration=generics['G_SAMPLES'], round_even=generics['G_ROUND_EVEN'],
    signed=generics['G_INPUT_SIGNED'], extra_bits=-generics['G_PROTECTION_BITS']):
    """
    generates test vectos and golde values based on testunit generic parameters.
    for calculating golden vector function uses python model.
    """
    with open(filename, "w") as output:
        if signed:
            vector = [random.randrange(-2**(bit_width-1), 2**(bit_width-1)-1) for _ in range(vector_length)]
        else:
            vector = [random.randrange(0, 2**bit_width-1) for _ in range(vector_length)]
        result = fpga_moving_integrator(vector, integration, round_even, extra_bits=out_width-bit_width+extra_bits)
        result = [int(res*2**(out_width-bit_width+extra_bits)) for res in result]
        for sam, res in zip(vector, result):
            output.write("{}  {}\n".format(sam, res))


def set_generics(obj, suffix=0):
    """
    generates test vector and sets generic for a given object
    :param obj: testcase in main testbench unit
    :param suffix: number of test
    :return: None
    """
    filename = join(dirname(abspath(__file__)), 'vunit_out/test_vector_{}.txt'.format(suffix))
    generate_test_vectors(filename)
    obj.set_generic("G_FILE_PATH", filename.replace('\\', '/'))


for nr, test in enumerate(testbench.get_tests()):
    # for everytest generate input vector file and set it path as generic
    set_generics(test, nr)


prj.main()
