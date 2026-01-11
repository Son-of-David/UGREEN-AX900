# UGREEN-AX900

AIC8800 wireless driver for UGREEN AX900 adapter.

Currently the Driver supports Kali Linux 2026.1 on VMware and BareMetal AMD64 working on PinePhone Ubuntu RPI and Radxa.

## Repository Structure

The driver package is organized in the `/Linux` directory:

- **aic8800_linux_driver/drivers/aic8800/aic8800_fdrv** - Main driver code
- **aic8800_linux_driver/drivers/aic8800/aic_load_fw** - Firmware loader
- **aic8800_linux_driver/fw/aic8800D80** - Firmware binaries
- **aic8800_linux_driver/tools** - Utilities and helper scripts
- **linux_driver_package** - Packaged driver releases

See [Linux/README.md](Linux/README.md) for more details.
