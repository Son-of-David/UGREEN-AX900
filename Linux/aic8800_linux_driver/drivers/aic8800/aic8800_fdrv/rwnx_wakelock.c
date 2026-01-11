// Linux/aic8800_linux_driver/drivers/aic8800/aic8800_fdrv/rwnx_wakeup.c
//
// Updated for newer kernels (Kali 6.16+ / 6.17+):
// - Removes use of deprecated/removed APIs:
//     wakeup_source_create()
//     wakeup_source_add()
//     wakeup_source_remove()
//     wakeup_source_destroy()
// - Uses the supported API:
//     wakeup_source_register(dev, name) / wakeup_source_unregister()
// - Keeps your existing helper wrappers and logging.
//
// Copy/paste this entire file over your current rwnx_wakeup.c.
//
#include <linux/kernel.h>
#include <linux/version.h>
#include <linux/platform_device.h>
#include <linux/pm_wakeup.h>

#include "rwnx_defs.h"
#include "rwnx_wakelock.h"

struct wakeup_source *rwnx_wakeup_init(const char *name)
{
	/*
	 * New kernels removed wakeup_source_create/add.
	 * Register a wakeup source without binding to a specific device.
	 */
	return wakeup_source_register(NULL, name);
}

void rwnx_wakeup_deinit(struct wakeup_source *ws)
{
	if (!ws)
		return;

	/* If held, release it before unregistering */
	if (ws->active)
		__pm_relax(ws);

	wakeup_source_unregister(ws);
}

struct wakeup_source *rwnx_wakeup_register(struct device *dev, const char *name)
{
	/*
	 * Modern kernels support wakeup_source_register(struct device *, const char *).
	 * Keep backward-compat paths for older vendor/Android kernels.
	 */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 4, 0)
	return wakeup_source_register(dev, name);
#else

#if defined(CONFIG_PLATFORM_ROCKCHIP2) || defined(CONFIG_PLATFORM_ROCKCHIP)
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 5, 0)
	return wakeup_source_register(dev, name);
#else
	/* Very old signature */
	return wakeup_source_register(name);
#endif

#else
	/* Very old signature */
	return wakeup_source_register(name);
#endif /* CONFIG_PLATFORM_ROCKCHIP2 || CONFIG_PLATFORM_ROCKCHIP */

#endif /* LINUX_VERSION_CODE >= 5.4.0 */
}

void rwnx_wakeup_unregister(struct wakeup_source *ws)
{
	if (!ws)
		return;

	if (ws->active)
		__pm_relax(ws);

	wakeup_source_unregister(ws);
}

void rwnx_wakeup_lock(struct wakeup_source *ws)
{
	AICWFDBG(LOGDEBUG, "%s enter \r\n", __func__);
	if (ws)
		__pm_stay_awake(ws);
}

void rwnx_wakeup_unlock(struct wakeup_source *ws)
{
	AICWFDBG(LOGDEBUG, "%s enter \r\n", __func__);
	if (ws)
		__pm_relax(ws);
}

void rwnx_wakeup_lock_timeout(struct wakeup_source *ws, unsigned int msec)
{
	if (ws)
		__pm_wakeup_event(ws, msec);
}

void aicwf_wakeup_lock_init(struct rwnx_hw *rwnx_hw)
{
	rwnx_hw->ws_tx = rwnx_wakeup_init("rwnx_tx_wakelock");
	rwnx_hw->ws_rx = rwnx_wakeup_init("rwnx_rx_wakelock");
	rwnx_hw->ws_irqrx = rwnx_wakeup_init("rwnx_irqrx_wakelock");
	rwnx_hw->ws_pwrctrl = rwnx_wakeup_init("rwnx_pwrcrl_wakelock");
}

void aicwf_wakeup_lock_deinit(struct rwnx_hw *rwnx_hw)
{
	rwnx_wakeup_deinit(rwnx_hw->ws_tx);
	rwnx_wakeup_deinit(rwnx_hw->ws_rx);
	rwnx_wakeup_deinit(rwnx_hw->ws_irqrx);
	rwnx_wakeup_deinit(rwnx_hw->ws_pwrctrl);

	rwnx_hw->ws_tx = NULL;
	rwnx_hw->ws_rx = NULL;
	rwnx_hw->ws_irqrx = NULL;
	rwnx_hw->ws_pwrctrl = NULL;
}
