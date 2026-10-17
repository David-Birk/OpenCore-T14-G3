#!/usr/bin/env python3
"""Read-only: run OCLP's root-patch hardware detection on this machine.

Prints the detected patch sets and every validation flag; patches nothing and
mounts nothing. Run with the OCLP source tree's interpreter:
  cd ~/dev/OpenCore-Legacy-Patcher && PYTHONPATH=. .venv/bin/python PATH/TO/oclp-detect.py
"""
import importlib.abc, importlib.machinery, json, logging, sys, types, warnings

warnings.filterwarnings('ignore')
logging.disable(logging.WARNING)


# OCLP's package imports its wx GUI; detection never touches it. Use the real wx
# when installed, otherwise inert placeholders.
class _Any(type):
    def __getattr__(cls, n): return _Dummy
class _Dummy(metaclass=_Any):
    def __init__(self, *a, **k): pass
    def __getattr__(self, n): return _Dummy
class _Mod(types.ModuleType):
    def __getattr__(self, n): return _Dummy
class _Finder(importlib.abc.MetaPathFinder, importlib.abc.Loader):
    def find_spec(self, name, path, target=None):
        if name == 'wx' or name.startswith('wx.'):
            return importlib.machinery.ModuleSpec(name, self, is_package=True)
    def create_module(self, spec): return _Mod(spec.name)
    def exec_module(self, m): m.__path__ = []
try:
    import wx  # noqa: F401
except ImportError:
    sys.meta_path.insert(0, _Finder())

from opencore_legacy_patcher import constants
from opencore_legacy_patcher.detections import device_probe, os_probe
from opencore_legacy_patcher.sys_patch.patchsets.detect import HardwarePatchsetDetection

c = constants.Constants()
o = os_probe.OSProbe()
c.detected_os, c.detected_os_minor = o.detect_kernel_major(), o.detect_kernel_minor()
c.detected_os_build, c.detected_os_version = o.detect_os_build(), o.detect_os_version()
c.computer = device_probe.Computer.probe()
print('OS', c.detected_os, c.detected_os_build, '| GPUs', [(hex(g.vendor_id), hex(g.device_id)) for g in c.computer.gpus])
d = HardwarePatchsetDetection(c)
print(json.dumps({str(k): v for k, v in d.device_properties.items()}, indent=1, default=str))
print('patch sets:', json.dumps(d.patches, indent=1, default=str))
