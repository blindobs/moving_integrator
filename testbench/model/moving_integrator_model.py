#!/usr/bin/env python
# -*- coding: utf-8 -*-

__author__ = "Tomasz Oczkowski"

import numpy as np
from collections import deque


def moving_integrator(samples, integration, trim_output=True):
    """
    function performs moving window mean calculation of samples data over integration factor
    :param samples: array of input samples
    :param integration: integration factor (number of samples to integrate over)
    :param trim_output: if True len(return) is equal len(samples)
    :return: array of sliding window integration samples
    """
    moving_mean = np.convolve(samples, np.ones(integration)/integration)
    if trim_output:
        moving_mean = moving_mean[0:len(samples)]
    return moving_mean


def fpga_moving_integrator(samples, integration, math_round=False, extra_bits=0):
    """
    function performs moving window mean calculation of samples data over integration factor
    in exact way as fpga algorithm does
    :param samples: array of input samples
    :param integration: integration factor (number of samples to integrate over)
    :param math_round: perform rounding or truncate operation
    :param extra_bits: add extar bits for sfixed values
    :return: array of sliding window integration samples
    """
    sreg = deque(np.zeros(integration))
    result = []
    acc = 0
    for sample in samples:
        acc += sample - sreg.pop()
        sreg.appendleft(sample)
        if math_round:
            value = int(round(acc/integration*2**extra_bits))/2**extra_bits
        else:
            value = int(np.floor(acc/integration*2**extra_bits))/2**extra_bits
        result.append(value)
    return result


if __name__ == "__main__":

    print(moving_integrator([1, 2, 3, 4, 5, 6, 7, 8], 4, True))
    print(fpga_moving_integrator([1, 2, 3, 4, 5, 6, 7, 8], 4, math_round=False, extra_bits=3))