"""Set the Windows lock screen image using the WinRT UserProfile API."""

from __future__ import annotations

from pathlib import Path


def set_lockscreen(image_path: Path) -> None:
    """
    Set the Windows lock screen image.

    Requires the winrt-Windows.System.UserProfile package:
        pip install winrt-Windows.System.UserProfile

    This package is Windows-only and is intentionally excluded from
    requirements.txt — install it manually on Windows hosts.
    """
    try:
        import winrt.windows.system.userprofile as userprofile
        import winrt.windows.storage as storage
        import asyncio
    except ImportError as exc:
        raise ImportError(
            "winrt packages are required on Windows.\n"
            "Run: pip install winrt-Windows.System.UserProfile"
        ) from exc

    abs_path = str(image_path.resolve())

    async def _apply() -> None:
        file = await storage.StorageFile.get_file_from_path_async(abs_path)
        await userprofile.LockScreen.set_image_file_async(file)

    asyncio.run(_apply())
