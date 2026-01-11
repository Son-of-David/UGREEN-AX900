# Linux Driver Structure

This directory contains the AIC8800 Linux driver package organized as follows:

## Directory Structure

```
Linux
├── aic8800_linux_driver
│   ├── drivers
│   │   └── aic8800
│   │       ├── aic8800_fdrv      # Main driver code
│   │       └── aic_load_fw       # Firmware loader
│   ├── fw
│   │   └── aic8800D80            # Firmware files
│   └── tools                     # Driver utilities and tools
└── linux_driver_package          # Packaged driver releases
```

## Components

- **aic8800_fdrv**: Main wireless driver for AIC8800 chipset
- **aic_load_fw**: Firmware loading utilities
- **fw/aic8800D80**: Firmware binaries for AIC8800D80
- **tools**: Helper scripts and configuration tools
- **linux_driver_package**: Pre-built driver packages for various distributions
