// Placeholder driver entry point (workspace-qoj.1 project skeleton).
//
// The real HmdDriverFactory implementation lands in workspace-qoj.6
// (device provider + driver entry point); this stub exists only because
// CMake requires at least one translation unit in the MODULE target, so the
// skeleton builds out of the box. It already demonstrates the export +
// version-dispatch pattern: with OpenVR headers available it resolves
// IServerTrackedDeviceProvider_Version and reports InterfaceNotFound (the
// provider is not registered yet); without headers it reports
// InterfaceNotFound for every interface.

#include <cstring>

#if __has_include(<openvr_driver.h>)
#include <openvr_driver.h>
#define FREETRL_HAS_OPENVR 1
#else
#define FREETRL_HAS_OPENVR 0
#endif

// Export the entry point: dllexport on Windows, default visibility on
// GCC/Clang (see r57zone/OpenVR-OpenTrack HMD_DLL_EXPORT pattern).
#if defined(_WIN32)
#define FREETRL_EXPORT __declspec(dllexport)
#else
#define FREETRL_EXPORT __attribute__((visibility("default")))
#endif

extern "C" FREETRL_EXPORT void* HmdDriverFactory(const char* pInterfaceName, int* pReturnCode)
{
#if FREETRL_HAS_OPENVR
	if (0 == std::strcmp(vr::IServerTrackedDeviceProvider_Version, pInterfaceName))
	{
		// The DeviceProvider is implemented in workspace-qoj.6; until then
		// report the interface as not implemented.
		if (pReturnCode)
		{
			*pReturnCode = vr::VRInitError_Init_InterfaceNotFound;
		}
		return nullptr;
	}
#endif

	if (pReturnCode)
	{
		*pReturnCode = 105; // vr::VRInitError_Init_InterfaceNotFound
	}
	return nullptr;
}
